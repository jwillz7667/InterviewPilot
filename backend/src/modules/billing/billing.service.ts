import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  Environment,
  SignedDataVerifier,
  type JWSRenewalInfoDecodedPayload,
  type JWSTransactionDecodedPayload,
  type ResponseBodyV2DecodedPayload,
} from '@apple/app-store-server-library';
import {
  AccessSource,
  AppStoreEnvironment,
  BillingProvider,
  InterviewQuality,
  Prisma,
  SessionMode,
  SubscriptionProduct,
  SubscriptionStatus,
  SubscriptionTier,
  type UserEntitlement,
} from '@prisma/client';

import { getPrisma, withDatabaseRetry, type DatabaseClient } from '../../config/database.js';
import { getEnv } from '../../config/env.js';
import { withSpan } from '../../config/telemetry.js';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  PaymentRequiredError,
  ValidationError,
} from '../../utils/errors.js';
import { getLogger } from '../../utils/logger.js';
import { ensureAppAccountToken } from '../users/app-account-token.js';

import {
  getCachedBillingSummary,
  setCachedBillingSummary,
  invalidateBillingCache,
  type CachedBillingSummary,
  type QuotaSummaryDTO,
  type QuotaWindowDTO,
} from './billing.cache.js';
import {
  FEATURE_KEYS,
  findCatalogItemByProductId,
  getSubscriptionCatalog,
  isSubscriptionActive,
  isUnlimitedQuota,
  resolveFeatureSet,
  SESSION_MODE_FEATURE,
  getTierModelConfig,
  TIER_PROFILE_LIMITS,
  TIER_QUOTA,
  TIER_RESPONSE_QUALITY,
  requiredTierForQuality,
  selectModel,
  tierMeetsRequirement,
  tierRank,
  type FeatureKey,
  type ModelChoice,
  type QuestionRouting,
} from './billing.constants.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const APPLE_ROOT_CERT_PATHS = [
  path.resolve(__dirname, '../../../certs/apple/AppleRootCA-G2.cer'),
  path.resolve(__dirname, '../../../certs/apple/AppleRootCA-G3.cer'),
];

const QUOTA_PERIOD_MS = 30 * 24 * 60 * 60 * 1000;

const log = getLogger().child({ module: 'billing' });

interface BillingContext {
  user: {
    id: string;
    email: string;
    appAccountToken: string;
    isSandboxTester: boolean;
  };
  entitlement: UserEntitlement;
  profilesUsed: number;
}

type BillingDbClient = DatabaseClient | Prisma.TransactionClient;

interface VerifiedAppStoreTransaction {
  payload: JWSTransactionDecodedPayload;
  renewalInfo?: JWSRenewalInfoDecodedPayload;
  environment: AppStoreEnvironment;
  signedTransaction: string;
}

export type BillingSummary = CachedBillingSummary;

export interface AccessClaimResult {
  sessionClientId: string;
  sessionMode: string;
  accessSource: string;
  accessTier: string;
  quality: InterviewQuality;
  consumedTrial: boolean;
  trialInterviewNumber: number | null;
  entitlement: BillingSummary;
}

let appleRootCAsPromise: Promise<Buffer[]> | undefined;
const verifierCache = new Map<AppStoreEnvironment, SignedDataVerifier>();

async function loadAppleRootCAs(): Promise<Buffer[]> {
  if (!appleRootCAsPromise) {
    appleRootCAsPromise = Promise.all(APPLE_ROOT_CERT_PATHS.map((certPath) => readFile(certPath)));
  }

  return appleRootCAsPromise;
}

async function getSignedDataVerifier(
  environment: AppStoreEnvironment
): Promise<SignedDataVerifier> {
  const cached = verifierCache.get(environment);
  if (cached) {
    return cached;
  }

  const env = getEnv();
  const appAppleId =
    environment === AppStoreEnvironment.PRODUCTION
      ? coerceAppAppleId(env.APP_STORE_APPLE_ID)
      : undefined;

  const verifier = new SignedDataVerifier(
    await loadAppleRootCAs(),
    env.APP_STORE_ENABLE_ONLINE_CHECKS,
    environment === AppStoreEnvironment.SANDBOX ? Environment.SANDBOX : Environment.PRODUCTION,
    env.APP_STORE_BUNDLE_ID,
    appAppleId
  );

  verifierCache.set(environment, verifier);
  return verifier;
}

function coerceAppAppleId(value: string | undefined): number {
  if (!value) {
    throw new ValidationError(
      'APP_STORE_APPLE_ID must be configured for production App Store validation'
    );
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new ValidationError('APP_STORE_APPLE_ID must be a positive integer');
  }

  return parsed;
}

function serializeEnum(value: string): string {
  return value.toLowerCase().replaceAll(/_([a-z])/g, (_match, char: string) => char.toUpperCase());
}

function serializeDate(value?: Date | null): string | null {
  return value ? value.toISOString() : null;
}

function createDigest(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function toDate(epochMs?: number): Date | null {
  return typeof epochMs === 'number' ? new Date(epochMs) : null;
}

function isDeveloperFullAccessEmail(email: string): boolean {
  const raw = getEnv().DEVELOPER_FULL_ACCESS_EMAILS;
  if (!raw) return false;
  const allowed = raw
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return allowed.includes(email.trim().toLowerCase());
}

function isSandboxTesterEmail(email: string): boolean {
  const raw = getEnv().SANDBOX_TESTER_EMAILS;
  if (!raw) return false;
  const allowed = raw
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return allowed.includes(email.trim().toLowerCase());
}

async function ensureBillingContext(
  prisma: Pick<BillingDbClient, 'user' | 'userEntitlement' | 'interviewProfile'>,
  userId: string
): Promise<BillingContext> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      email: true,
      appAccountToken: true,
      isSandboxTester: true,
      entitlement: true,
    },
  });

  if (!user) {
    throw new NotFoundError('User');
  }

  // Auto-promote users whose email is in SANDBOX_TESTER_EMAILS or DEVELOPER_FULL_ACCESS_EMAILS.
  // Server-authoritative — moves the dev override from the iOS bundle to backend env so a patched
  // client cannot self-promote.
  const isPromotedTester =
    isSandboxTesterEmail(user.email) || isDeveloperFullAccessEmail(user.email);
  if (!user.isSandboxTester && isPromotedTester) {
    user.isSandboxTester = true;
    await (prisma as BillingDbClient).user.update({
      where: { id: userId },
      data: { isSandboxTester: true },
    });
  }

  let entitlement = user.entitlement;
  if (!entitlement) {
    const env = getEnv();
    const trialStartedAt = new Date();
    const trialEndsAt = new Date(
      trialStartedAt.getTime() + env.TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000
    );
    const now = new Date();
    const tier = isPromotedTester ? SubscriptionTier.SANDBOX : SubscriptionTier.FREE;
    const status = isPromotedTester ? SubscriptionStatus.SANDBOX : SubscriptionStatus.FREE;
    const quota = TIER_QUOTA[tier];
    entitlement = await prisma.userEntitlement.create({
      data: {
        userId,
        tier,
        status,
        sandboxFullAccess: isPromotedTester,
        trialInterviewLimit: env.TRIAL_INTERVIEW_LIMIT,
        trialStartedAt,
        trialEndsAt,
        monthlyStandardLimit: quota.standardMonthly,
        monthlyPremiumLimit: quota.premiumMonthly,
        quotaPeriodStartedAt: now,
        quotaPeriodEndsAt: new Date(now.getTime() + QUOTA_PERIOD_MS),
      },
    });
  }

  // Self-healing reconciliation: enforce TIER_QUOTA as the canonical source of
  // truth for limit columns and force `sandboxFullAccess` true for promoted
  // testers. Drift can occur when (a) a tier change happened before the
  // per-quality limit columns were added, (b) a transaction sync was partially
  // applied, or (c) the dev allowlist was extended after a user signed up.
  // Without this, a Premium subscriber whose row still carries FREE-era limit
  // columns would see "1 premium left" instead of unlimited.
  entitlement = await reconcileEntitlementInvariants(
    prisma as BillingDbClient,
    entitlement,
    isPromotedTester
  );

  // Quota window roll-over: stateless reset for any caller.
  entitlement = await maybeResetQuotaWindow(prisma as BillingDbClient, entitlement);

  const profilesUsed = await (prisma as BillingDbClient).interviewProfile.count({
    where: { userId, deletedAt: null },
  });

  return {
    user: {
      id: user.id,
      email: user.email,
      appAccountToken: await ensureAppAccountToken(prisma, user),
      isSandboxTester: user.isSandboxTester,
    },
    entitlement,
    profilesUsed,
  };
}

async function reconcileEntitlementInvariants(
  prisma: BillingDbClient,
  entitlement: UserEntitlement,
  isPromotedTester: boolean
): Promise<UserEntitlement> {
  const expected = TIER_QUOTA[entitlement.tier];
  const expectedSandboxFlag = isPromotedTester || entitlement.sandboxFullAccess;

  const limitsDrift =
    entitlement.monthlyStandardLimit !== expected.standardMonthly ||
    entitlement.monthlyPremiumLimit !== expected.premiumMonthly;
  const sandboxFlagDrift = entitlement.sandboxFullAccess !== expectedSandboxFlag;

  if (!limitsDrift && !sandboxFlagDrift) {
    return entitlement;
  }

  const reconciled = await prisma.userEntitlement.update({
    where: { id: entitlement.id },
    data: {
      monthlyStandardLimit: expected.standardMonthly,
      monthlyPremiumLimit: expected.premiumMonthly,
      sandboxFullAccess: expectedSandboxFlag,
    },
  });

  log.info(
    {
      event: 'billing.entitlement.reconciled',
      userId: entitlement.userId,
      tier: entitlement.tier,
      from: {
        standardLimit: entitlement.monthlyStandardLimit,
        premiumLimit: entitlement.monthlyPremiumLimit,
        sandboxFullAccess: entitlement.sandboxFullAccess,
      },
      to: {
        standardLimit: expected.standardMonthly,
        premiumLimit: expected.premiumMonthly,
        sandboxFullAccess: expectedSandboxFlag,
      },
      isPromotedTester,
    },
    'Reconciled persisted entitlement to match policy'
  );

  await invalidateBillingCache(entitlement.userId).catch(() => {});

  return reconciled;
}

async function maybeResetQuotaWindow(
  prisma: BillingDbClient,
  entitlement: UserEntitlement
): Promise<UserEntitlement> {
  const now = Date.now();
  const endsAt = entitlement.quotaPeriodEndsAt?.getTime();

  if (endsAt && endsAt > now) {
    return entitlement;
  }

  const newStart = new Date();
  const newEnd = new Date(newStart.getTime() + QUOTA_PERIOD_MS);

  // Best-effort race-safe reset: only the row whose endsAt matches what we observed gets reset.
  // Concurrent callers either win the WHERE-conditional or read the freshly reset row on retry.
  await prisma.userEntitlement.updateMany({
    where: {
      id: entitlement.id,
      OR: [
        { quotaPeriodEndsAt: null },
        { quotaPeriodEndsAt: entitlement.quotaPeriodEndsAt ?? undefined },
      ],
    },
    data: {
      monthlyStandardUsed: 0,
      monthlyPremiumUsed: 0,
      monthlyInterviewsUsed: 0,
      quotaPeriodStartedAt: newStart,
      quotaPeriodEndsAt: newEnd,
      monthlyInterviewsResetAt: newEnd,
    },
  });

  await invalidateBillingCache(entitlement.userId).catch(() => {});

  const refreshed = await prisma.userEntitlement.findUnique({
    where: { id: entitlement.id },
  });
  return refreshed ?? entitlement;
}

function buildQuotaWindow(used: number, limit: number, endsAt: Date | null): QuotaWindowDTO {
  const unlimited = isUnlimitedQuota(limit);
  return {
    used,
    limit,
    remaining: unlimited ? Number.MAX_SAFE_INTEGER : Math.max(limit - used, 0),
    isUnlimited: unlimited,
    resetsAt: serializeDate(endsAt),
  };
}

function buildQuotaSummary(
  entitlement: UserEntitlement,
  effectiveTier: SubscriptionTier
): QuotaSummaryDTO {
  // Effective tier governs limit (sandbox/expired-trial overrides), counters are always read from
  // the persisted row to preserve audit trail integrity.
  const policy = TIER_QUOTA[effectiveTier];
  const standardLimit = policy.standardMonthly;
  const premiumLimit = policy.premiumMonthly;
  const endsAt = entitlement.quotaPeriodEndsAt;

  return {
    standard: buildQuotaWindow(entitlement.monthlyStandardUsed, standardLimit, endsAt),
    premium: buildQuotaWindow(entitlement.monthlyPremiumUsed, premiumLimit, endsAt),
    periodStartedAt: entitlement.quotaPeriodStartedAt.toISOString(),
    periodEndsAt: serializeDate(endsAt),
  };
}

function buildSummary(context: BillingContext): BillingSummary {
  const sandboxFullAccess = context.user.isSandboxTester || context.entitlement.sandboxFullAccess;

  const isTrialExpired =
    context.entitlement.tier === SubscriptionTier.TRIAL &&
    context.entitlement.trialEndsAt !== null &&
    context.entitlement.trialEndsAt.getTime() < Date.now();

  const effectiveTier = sandboxFullAccess
    ? SubscriptionTier.SANDBOX
    : isTrialExpired
      ? SubscriptionTier.FREE
      : context.entitlement.tier;

  const effectiveStatus = sandboxFullAccess
    ? SubscriptionStatus.SANDBOX
    : isTrialExpired
      ? SubscriptionStatus.FREE
      : context.entitlement.status;

  const hasPaidSubscription =
    !sandboxFullAccess &&
    isSubscriptionActive(
      context.entitlement.status,
      context.entitlement.currentPeriodEndsAt,
      context.entitlement.gracePeriodEndsAt
    ) &&
    context.entitlement.product !== SubscriptionProduct.NONE &&
    context.entitlement.tier !== SubscriptionTier.TRIAL &&
    context.entitlement.tier !== SubscriptionTier.FREE;

  const accessSource = sandboxFullAccess
    ? AccessSource.SANDBOX
    : hasPaidSubscription
      ? AccessSource.SUBSCRIPTION
      : AccessSource.TRIAL;
  const features = resolveFeatureSet(effectiveTier, sandboxFullAccess);

  const trialDaysRemaining =
    context.entitlement.tier === SubscriptionTier.TRIAL &&
    context.entitlement.trialEndsAt !== null &&
    !isTrialExpired
      ? Math.ceil((context.entitlement.trialEndsAt.getTime() - Date.now()) / (24 * 60 * 60 * 1000))
      : null;

  const quotas = buildQuotaSummary(context.entitlement, effectiveTier);

  // Legacy aggregate counter fields for older iOS clients still on the pre-quotas shape.
  // They reflect the standard-quality window only; premium activity is invisible to legacy UI.
  const monthlyUsed = quotas.standard.used;
  const monthlyLimit = quotas.standard.limit;
  const monthlyRemaining = quotas.standard.isUnlimited
    ? Number.MAX_SAFE_INTEGER
    : quotas.standard.remaining;
  const interviewsRemaining =
    quotas.standard.isUnlimited || quotas.premium.isUnlimited
      ? Number.MAX_SAFE_INTEGER
      : quotas.standard.remaining + quotas.premium.remaining;

  const paywallRequired = !sandboxFullAccess && !hasPaidSubscription && interviewsRemaining === 0;

  return {
    tier: serializeEnum(effectiveTier),
    status: serializeEnum(effectiveStatus),
    accessSource: serializeEnum(accessSource),
    product: serializeEnum(
      sandboxFullAccess ? SubscriptionProduct.SANDBOX_FULL_ACCESS : context.entitlement.product
    ),
    productId: context.entitlement.productId,
    features,
    featureFlags: FEATURE_KEYS.reduce<Record<FeatureKey, boolean>>(
      (result, feature) => {
        result[feature] = features.includes(feature);
        return result;
      },
      {} as Record<FeatureKey, boolean>
    ),
    sandboxFullAccess,
    trialInterviewLimit: context.entitlement.trialInterviewLimit,
    trialInterviewsUsed: context.entitlement.trialInterviewsUsed,
    interviewsRemaining,
    hasActiveSubscription: hasPaidSubscription || sandboxFullAccess,
    paywallRequired,
    appAccountToken: context.user.appAccountToken,
    currentPeriodEndsAt: serializeDate(context.entitlement.currentPeriodEndsAt),
    gracePeriodEndsAt: serializeDate(context.entitlement.gracePeriodEndsAt),
    trialDaysRemaining,
    responseQuality: TIER_RESPONSE_QUALITY[effectiveTier],
    modelConfig: getTierModelConfig(effectiveTier),
    profileLimit: TIER_PROFILE_LIMITS[effectiveTier],
    profilesUsed: context.profilesUsed,
    monthlyInterviewsUsed: monthlyUsed,
    monthlyInterviewLimit: monthlyLimit,
    monthlyInterviewsRemaining: monthlyRemaining,
    quotas,
    catalog: getSubscriptionCatalog().map((item) => ({
      product: serializeEnum(item.product),
      productId: item.productId,
      tier: serializeEnum(item.tier),
      displayName: item.displayName,
      billingLabel: item.billingLabel,
      features: item.features,
    })),
  };
}

function chooseBestTransaction(
  transactions: VerifiedAppStoreTransaction[]
): VerifiedAppStoreTransaction | undefined {
  return transactions.slice().sort((left, right) => {
    const leftCatalog = findCatalogItemByProductId(left.payload.productId ?? '');
    const rightCatalog = findCatalogItemByProductId(right.payload.productId ?? '');
    const leftTier =
      left.environment === AppStoreEnvironment.SANDBOX
        ? SubscriptionTier.SANDBOX
        : (leftCatalog?.tier ?? SubscriptionTier.FREE);
    const rightTier =
      right.environment === AppStoreEnvironment.SANDBOX
        ? SubscriptionTier.SANDBOX
        : (rightCatalog?.tier ?? SubscriptionTier.FREE);

    const tierDelta = tierRank(rightTier) - tierRank(leftTier);
    if (tierDelta !== 0) {
      return tierDelta;
    }

    const leftExpiry = left.payload.expiresDate ?? 0;
    const rightExpiry = right.payload.expiresDate ?? 0;
    return rightExpiry - leftExpiry;
  })[0];
}

function deriveSubscriptionStatus(
  payload: JWSTransactionDecodedPayload,
  renewalInfo?: JWSRenewalInfoDecodedPayload,
  notificationType?: string
): SubscriptionStatus {
  const expiresAt = toDate(payload.expiresDate);
  const now = Date.now();

  if (payload.revocationDate) {
    return SubscriptionStatus.REVOKED;
  }

  if (notificationType === 'DID_FAIL_TO_RENEW' || renewalInfo?.isInBillingRetryPeriod) {
    if (renewalInfo?.gracePeriodExpiresDate && renewalInfo.gracePeriodExpiresDate >= now) {
      return SubscriptionStatus.IN_GRACE_PERIOD;
    }
  }

  if (expiresAt && expiresAt.getTime() < now) {
    return SubscriptionStatus.EXPIRED;
  }

  if (notificationType === 'EXPIRED') {
    return SubscriptionStatus.EXPIRED;
  }

  if (renewalInfo?.autoRenewStatus === 0 || notificationType === 'DID_CHANGE_RENEWAL_STATUS') {
    return SubscriptionStatus.CANCELED;
  }

  return SubscriptionStatus.ACTIVE;
}

async function verifySignedTransaction(
  signedTransaction: string
): Promise<VerifiedAppStoreTransaction> {
  const environments = [AppStoreEnvironment.SANDBOX, AppStoreEnvironment.PRODUCTION];
  let lastError: unknown;

  for (const environment of environments) {
    try {
      const verifier = await getSignedDataVerifier(environment);
      const payload = await verifier.verifyAndDecodeTransaction(signedTransaction);

      return {
        payload,
        environment,
        signedTransaction,
      };
    } catch (error) {
      lastError = error;
    }
  }

  throw new ValidationError(
    `Unable to verify App Store transaction${lastError instanceof Error ? `: ${lastError.message}` : ''}`
  );
}

async function verifyNotificationPayload(signedPayload: string): Promise<{
  notification: ResponseBodyV2DecodedPayload;
  transaction?: VerifiedAppStoreTransaction;
}> {
  const environments = [AppStoreEnvironment.SANDBOX, AppStoreEnvironment.PRODUCTION];
  let lastError: unknown;

  for (const environment of environments) {
    try {
      const verifier = await getSignedDataVerifier(environment);
      const notification = await verifier.verifyAndDecodeNotification(signedPayload);
      const signedTransaction = notification.data?.signedTransactionInfo;
      const signedRenewalInfo = notification.data?.signedRenewalInfo;

      if (!signedTransaction) {
        return { notification };
      }

      const payload = await verifier.verifyAndDecodeTransaction(signedTransaction);
      const renewalInfo = signedRenewalInfo
        ? await verifier.verifyAndDecodeRenewalInfo(signedRenewalInfo)
        : undefined;

      return {
        notification,
        transaction: {
          payload,
          renewalInfo,
          environment,
          signedTransaction,
        },
      };
    } catch (error) {
      lastError = error;
    }
  }

  throw new ValidationError(
    `Unable to verify App Store notification${lastError instanceof Error ? `: ${lastError.message}` : ''}`
  );
}

// Whether a transaction from the given App Store environment may be honored for
// this user. Sandbox transactions in production would otherwise be promoted to
// SANDBOX-tier full access — a privilege-escalation vector for anyone holding a
// sandbox Apple ID. Only designated testers (isSandboxTester) may use sandbox
// purchases in production; non-prod environments accept them freely for testing.
function isSandboxTransactionAllowed(
  environment: AppStoreEnvironment,
  user: { isSandboxTester: boolean }
): boolean {
  if (environment !== AppStoreEnvironment.SANDBOX) return true;
  if (user.isSandboxTester) return true;
  return getEnv().NODE_ENV !== 'production';
}

async function writeEntitlementFromTransaction(
  prisma: BillingDbClient,
  context: BillingContext,
  transaction: VerifiedAppStoreTransaction,
  eventType: string
): Promise<BillingSummary> {
  const productId = transaction.payload.productId;
  if (!productId) {
    throw new ValidationError('Verified App Store transaction is missing a product identifier');
  }

  const catalogItem = findCatalogItemByProductId(productId);
  if (!catalogItem) {
    throw new ValidationError(`Unsupported App Store product: ${productId}`);
  }

  const appAccountToken =
    transaction.payload.appAccountToken ?? transaction.renewalInfo?.appAccountToken;
  if (appAccountToken && appAccountToken !== context.user.appAccountToken) {
    throw new ForbiddenError('App Store transaction does not belong to the authenticated user');
  }

  if (!isSandboxTransactionAllowed(transaction.environment, context.user)) {
    throw new ForbiddenError('Sandbox App Store transactions are not honored in production');
  }

  // Idempotent replay guard. A verified transaction already recorded for this
  // exact event type is a no-op — return the current summary without re-writing.
  // New transaction IDs (renewals) and distinct lifecycle events (EXPIRED,
  // REFUND, …) still process; only literal replays of the same
  // (transactionId, eventType) pair are skipped.
  const transactionId = transaction.payload.transactionId;
  if (transactionId) {
    const alreadyProcessed = await prisma.billingEvent.findFirst({
      where: { appStoreTransactionId: transactionId, eventType },
      select: { id: true },
    });
    if (alreadyProcessed) {
      log.info(
        {
          event: 'billing.transaction.duplicate_ignored',
          userId: context.user.id,
          transactionId,
          eventType,
        },
        'Skipping already-processed App Store transaction'
      );
      const profilesUsed = await prisma.interviewProfile.count({
        where: { userId: context.user.id, deletedAt: null },
      });
      return buildSummary({ user: context.user, entitlement: context.entitlement, profilesUsed });
    }
  }

  const sandboxFullAccess =
    context.user.isSandboxTester || transaction.environment === AppStoreEnvironment.SANDBOX;
  const tier = sandboxFullAccess ? SubscriptionTier.SANDBOX : catalogItem.tier;
  const product = sandboxFullAccess ? SubscriptionProduct.SANDBOX_FULL_ACCESS : catalogItem.product;
  const status = sandboxFullAccess
    ? SubscriptionStatus.SANDBOX
    : deriveSubscriptionStatus(transaction.payload, transaction.renewalInfo, eventType);
  const quota = TIER_QUOTA[tier];

  const previousTier = context.entitlement.tier;

  const entitlement = await prisma.userEntitlement.update({
    where: { userId: context.user.id },
    data: {
      tier,
      status,
      provider: BillingProvider.APP_STORE,
      product,
      productId,
      featuresOverride: Prisma.JsonNull,
      monthlyStandardLimit: quota.standardMonthly,
      monthlyPremiumLimit: quota.premiumMonthly,
      currentPeriodStartedAt:
        toDate(transaction.payload.originalPurchaseDate) ??
        toDate(transaction.payload.purchaseDate) ??
        context.entitlement.currentPeriodStartedAt,
      currentPeriodEndsAt: toDate(transaction.payload.expiresDate),
      gracePeriodEndsAt: toDate(transaction.renewalInfo?.gracePeriodExpiresDate),
      lastPurchasedAt: toDate(transaction.payload.purchaseDate),
      lastVerifiedAt: new Date(),
      appStoreEnvironment: transaction.environment,
      appStoreOriginalTransactionId: transaction.payload.originalTransactionId,
      appStoreLatestTransactionId: transaction.payload.transactionId,
      sandboxFullAccess,
    },
  });

  await prisma.billingEvent.create({
    data: {
      userId: context.user.id,
      entitlementId: entitlement.id,
      provider: BillingProvider.APP_STORE,
      eventType,
      product,
      productId,
      appStoreTransactionId: transaction.payload.transactionId,
      appStoreOriginalTransactionId: transaction.payload.originalTransactionId,
      appStoreEnvironment: transaction.environment,
      effectiveAt: toDate(transaction.payload.purchaseDate),
      expiresAt: toDate(transaction.payload.expiresDate),
      payloadDigest: createDigest(transaction.signedTransaction),
      payload: {
        transactionId: transaction.payload.transactionId ?? null,
        originalTransactionId: transaction.payload.originalTransactionId ?? null,
        environment:
          typeof transaction.payload.environment === 'string'
            ? transaction.payload.environment
            : transaction.environment,
        productId,
        expiresDate: transaction.payload.expiresDate ?? null,
        appAccountToken: appAccountToken ?? null,
      } satisfies Prisma.JsonObject,
      quotaDelta: {
        reason: 'tier_change',
        fromTier: previousTier,
        toTier: tier,
        standardLimit: quota.standardMonthly,
        premiumLimit: quota.premiumMonthly,
      } satisfies Prisma.JsonObject,
    },
  });

  if (previousTier !== tier) {
    log.info(
      {
        event: 'billing.tier.changed',
        userId: context.user.id,
        fromTier: previousTier,
        toTier: tier,
        product,
        productId,
      },
      'Subscription tier changed'
    );
  }

  await invalidateBillingCache(context.user.id);

  const profilesUsed = await prisma.interviewProfile.count({
    where: { userId: context.user.id, deletedAt: null },
  });

  return buildSummary({
    user: context.user,
    entitlement,
    profilesUsed,
  });
}

function quotaFieldsForQuality(quality: InterviewQuality): {
  usedField: 'monthlyStandardUsed' | 'monthlyPremiumUsed';
  limitField: 'monthlyStandardLimit' | 'monthlyPremiumLimit';
} {
  return quality === InterviewQuality.PREMIUM
    ? { usedField: 'monthlyPremiumUsed', limitField: 'monthlyPremiumLimit' }
    : { usedField: 'monthlyStandardUsed', limitField: 'monthlyStandardLimit' };
}

async function consumeQuotaAtomically(
  prisma: BillingDbClient,
  entitlementId: string,
  quality: InterviewQuality,
  effectiveTier: SubscriptionTier
): Promise<{ consumed: boolean; usedAfter: number; limit: number }> {
  const policy = TIER_QUOTA[effectiveTier];
  const limit =
    quality === InterviewQuality.PREMIUM ? policy.premiumMonthly : policy.standardMonthly;
  const { usedField, limitField } = quotaFieldsForQuality(quality);

  if (isUnlimitedQuota(limit)) {
    // No counter increment; surface a synthetic remaining=∞ for the caller's audit log.
    const row = await prisma.userEntitlement.findUnique({
      where: { id: entitlementId },
      select: { [usedField]: true },
    });
    const used = ((row as Record<string, number> | null)?.[usedField] ?? 0) + 0;
    return { consumed: true, usedAfter: used, limit };
  }

  // Atomic per-quality decrement: only the row whose used < effective limit (using the smaller of
  // the persisted limit and the tier policy limit) gets the increment. This is the linchpin of
  // the quota gate — `updateMany` with a WHERE-conditional is race-safe under Postgres
  // READ COMMITTED isolation because each row-level UPDATE re-checks the predicate.
  const updated = await prisma.userEntitlement.updateMany({
    where: {
      id: entitlementId,
      [usedField]: { lt: limit },
      // Defence in depth: also enforce the persisted limit so a stale TIER_QUOTA constant
      // can never grant more than what a billing event committed.
      [limitField]: { gte: limit },
    },
    data: {
      [usedField]: { increment: 1 },
      monthlyInterviewsUsed: { increment: 1 },
    },
  });

  if (updated.count !== 1) {
    return { consumed: false, usedAfter: limit, limit };
  }

  const row = await prisma.userEntitlement.findUnique({
    where: { id: entitlementId },
    select: { [usedField]: true },
  });
  const usedAfter = (row as Record<string, number> | null)?.[usedField] ?? limit;
  return { consumed: true, usedAfter, limit };
}

function quotaExhaustedError(
  quality: InterviewQuality,
  tier: SubscriptionTier,
  limit: number
): PaymentRequiredError {
  const requiredTier = requiredTierForQuality(quality);
  const message =
    quality === InterviewQuality.PREMIUM
      ? `You've used your ${limit === 0 ? 'available' : limit} Premium interview${limit === 1 ? '' : 's'} this period. Upgrade to Premium for unlimited.`
      : `You've used all ${limit} Standard interviews this period. Upgrade for more.`;
  return new PaymentRequiredError(message, {
    quality,
    currentTier: tier,
    requiredTier,
    remaining: { standard: 0, premium: 0 },
  });
}

function featureGatedError(feature: FeatureKey, message: string): PaymentRequiredError {
  return new PaymentRequiredError(message, {
    requiredFeature: feature,
    currentTier: null,
    requiredTier: SubscriptionTier.PREMIUM,
  });
}

async function withSessionAccessGrant(
  userId: string,
  sessionClientId: string,
  sessionMode: SessionMode,
  quality: InterviewQuality
): Promise<AccessClaimResult> {
  try {
    return await getPrisma().$transaction(async (prisma) => {
      const existingGrant = await prisma.sessionAccessGrant.findUnique({
        where: { sessionClientId },
      });

      if (existingGrant) {
        if (existingGrant.userId !== userId) {
          throw new ForbiddenError('This session access grant belongs to another user');
        }
        if (existingGrant.quality !== quality) {
          throw new ConflictError(
            `Session ${sessionClientId} was already claimed at ${existingGrant.quality} quality; resubmit with the original quality.`
          );
        }
        const context = await ensureBillingContext(prisma, userId);
        return {
          sessionClientId: existingGrant.sessionClientId,
          sessionMode: serializeEnum(existingGrant.sessionMode),
          accessSource: serializeEnum(existingGrant.accessSource),
          accessTier: serializeEnum(existingGrant.accessTier),
          quality: existingGrant.quality,
          consumedTrial: existingGrant.consumedTrial,
          trialInterviewNumber: existingGrant.trialInterviewNumber ?? null,
          entitlement: buildSummary(context),
        };
      }

      const context = await ensureBillingContext(prisma, userId);
      const summary = buildSummary(context);
      const requiredFeature = SESSION_MODE_FEATURE[sessionMode];

      if (!summary.featureFlags[requiredFeature]) {
        throw featureGatedError(
          requiredFeature,
          sessionMode === SessionMode.VOICE_PREP
            ? 'Voice Prep requires an active Premium subscription'
            : 'Upgrade required to start this interview session'
        );
      }

      const sandboxFullAccess = summary.sandboxFullAccess;

      const isTrialExpired =
        context.entitlement.tier === SubscriptionTier.TRIAL &&
        context.entitlement.trialEndsAt !== null &&
        context.entitlement.trialEndsAt.getTime() < Date.now();
      const effectiveTier = sandboxFullAccess
        ? SubscriptionTier.SANDBOX
        : isTrialExpired
          ? SubscriptionTier.FREE
          : context.entitlement.tier;

      // Premium-quality gate: every tier has a non-zero premium quota EXCEPT users who already
      // exhausted theirs — those go to the paywall with explicit reason.
      const requiredTier = requiredTierForQuality(quality);
      if (
        quality === InterviewQuality.PREMIUM &&
        !sandboxFullAccess &&
        !tierMeetsRequirement(effectiveTier, requiredTier) &&
        TIER_QUOTA[effectiveTier].premiumMonthly === 0
      ) {
        throw quotaExhaustedError(quality, effectiveTier, 0);
      }

      const policy = TIER_QUOTA[effectiveTier];
      const limit =
        quality === InterviewQuality.PREMIUM ? policy.premiumMonthly : policy.standardMonthly;

      const consumption = await consumeQuotaAtomically(
        prisma,
        context.entitlement.id,
        quality,
        effectiveTier
      );

      if (!consumption.consumed) {
        log.warn(
          {
            event: 'billing.quota.exhausted',
            userId,
            quality,
            tier: effectiveTier,
            limit,
          },
          'Quota exhausted'
        );
        throw quotaExhaustedError(quality, effectiveTier, limit);
      }

      log.info(
        {
          event: 'billing.quota.consumed',
          userId,
          sessionClientId,
          quality,
          tier: effectiveTier,
          usedAfter: consumption.usedAfter,
          limit,
        },
        'Quota consumed'
      );

      const accessSource = sandboxFullAccess
        ? AccessSource.SANDBOX
        : summary.hasActiveSubscription
          ? AccessSource.SUBSCRIPTION
          : AccessSource.TRIAL;

      // Refresh post-consumption so the snapshot reflects the latest counter values.
      await invalidateBillingCache(userId).catch(() => {});
      const refreshedContext = await ensureBillingContext(prisma, userId);
      const refreshedSummary = buildSummary(refreshedContext);

      const grant = await prisma.sessionAccessGrant.create({
        data: {
          userId,
          sessionClientId,
          sessionMode,
          accessSource,
          accessTier: effectiveTier,
          quality,
          consumedTrial: !summary.hasActiveSubscription && !sandboxFullAccess,
          trialInterviewNumber: refreshedContext.entitlement.trialInterviewsUsed,
          featureSnapshot: {
            features: refreshedSummary.features,
            status: refreshedSummary.status,
            quality,
          } satisfies Prisma.JsonObject,
        },
      });

      await prisma.billingEvent.create({
        data: {
          userId,
          entitlementId: refreshedContext.entitlement.id,
          provider: BillingProvider.INTERNAL,
          eventType: 'QUOTA_CONSUMED',
          product: SubscriptionProduct.NONE,
          quotaDelta: {
            reason: 'session_claim',
            quality,
            standardConsumed: quality === InterviewQuality.STANDARD ? 1 : 0,
            premiumConsumed: quality === InterviewQuality.PREMIUM ? 1 : 0,
            sessionClientId,
          } satisfies Prisma.JsonObject,
        },
      });

      return {
        sessionClientId: grant.sessionClientId,
        sessionMode: serializeEnum(grant.sessionMode),
        accessSource: serializeEnum(grant.accessSource),
        accessTier: serializeEnum(grant.accessTier),
        quality: grant.quality,
        consumedTrial: grant.consumedTrial,
        trialInterviewNumber: grant.trialInterviewNumber ?? null,
        entitlement: refreshedSummary,
      };
    });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      // Race: a concurrent caller created the grant between our check and insert.
      const existingGrant = await withDatabaseRetry((prisma) =>
        prisma.sessionAccessGrant.findUnique({
          where: { sessionClientId },
        })
      );

      if (existingGrant?.userId === userId) {
        if (existingGrant.quality !== quality) {
          throw new ConflictError(
            `Session ${sessionClientId} was already claimed at ${existingGrant.quality} quality; resubmit with the original quality.`
          );
        }
        const summary = await getBillingSummary(userId);
        return {
          sessionClientId: existingGrant.sessionClientId,
          sessionMode: serializeEnum(existingGrant.sessionMode),
          accessSource: serializeEnum(existingGrant.accessSource),
          accessTier: serializeEnum(existingGrant.accessTier),
          quality: existingGrant.quality,
          consumedTrial: existingGrant.consumedTrial,
          trialInterviewNumber: existingGrant.trialInterviewNumber ?? null,
          entitlement: summary,
        };
      }
    }

    throw error;
  }
}

export async function getBillingSummary(userId: string): Promise<BillingSummary> {
  const cached = await getCachedBillingSummary(userId);
  if (cached) {
    return cached;
  }

  const summary = await withDatabaseRetry(async (prisma) =>
    buildSummary(await ensureBillingContext(prisma, userId))
  );

  await setCachedBillingSummary(userId, summary).catch(() => {});

  return summary;
}

export async function claimInterviewAccess(
  userId: string,
  sessionClientId: string,
  sessionMode: SessionMode,
  quality: InterviewQuality
): Promise<AccessClaimResult> {
  return withSpan(
    'billing.claim_interview_access',
    () => withSessionAccessGrant(userId, sessionClientId, sessionMode, quality),
    { 'billing.session_mode': sessionMode, 'billing.requested_quality': quality }
  );
}

export async function getSessionAccessGrant(
  userId: string,
  sessionClientId: string
): Promise<{
  accessSource: AccessSource;
  accessTier: SubscriptionTier;
  quality: InterviewQuality;
  trialInterviewNumber: number | null;
}> {
  const grant = await withDatabaseRetry((prisma) =>
    prisma.sessionAccessGrant.findUnique({ where: { sessionClientId } })
  );
  if (grant?.userId !== userId) {
    throw new NotFoundError('Session access grant');
  }
  return {
    accessSource: grant.accessSource,
    accessTier: grant.accessTier,
    quality: grant.quality,
    trialInterviewNumber: grant.trialInterviewNumber ?? null,
  };
}

export async function authorizeAiCall(
  userId: string,
  sessionClientId: string,
  routing: QuestionRouting = 'default'
): Promise<{ model: ModelChoice; quality: InterviewQuality; tier: SubscriptionTier }> {
  return withSpan(
    'billing.authorize_ai_call',
    async () => {
      const grant = await getSessionAccessGrant(userId, sessionClientId);
      const model = selectModel(grant.quality, routing);
      return {
        model,
        quality: grant.quality,
        tier: grant.accessTier,
      };
    },
    { 'billing.routing': routing }
  );
}

export async function canAccessRuntimeAiConfig(userId: string): Promise<boolean> {
  const summary = await getBillingSummary(userId);
  if (summary.sandboxFullAccess || summary.hasActiveSubscription) return true;
  return summary.quotas.standard.remaining > 0 || summary.quotas.premium.remaining > 0;
}

export async function syncAppStoreTransactions(
  userId: string,
  signedTransactions: string[]
): Promise<BillingSummary> {
  const verified = await Promise.all(
    signedTransactions.map((item) => verifySignedTransaction(item))
  );
  const bestTransaction = chooseBestTransaction(verified);

  return withDatabaseRetry(async (prisma) =>
    prisma.$transaction(async (tx) => {
      const context = await ensureBillingContext(tx, userId);

      if (!bestTransaction) {
        return buildSummary(context);
      }

      return writeEntitlementFromTransaction(tx, context, bestTransaction, 'DEVICE_SYNC');
    })
  );
}

export async function processAppStoreNotification(
  signedPayload: string
): Promise<{ accepted: boolean; entitlement?: BillingSummary }> {
  const { notification, transaction } = await verifyNotificationPayload(signedPayload);
  const appAccountToken =
    transaction?.payload.appAccountToken ?? transaction?.renewalInfo?.appAccountToken;

  if (!transaction || !appAccountToken) {
    return { accepted: true };
  }

  return withDatabaseRetry(async (prisma) =>
    prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({
        where: { appAccountToken },
        select: { id: true },
      });

      if (!user) {
        return { accepted: true };
      }

      const context = await ensureBillingContext(tx, user.id);

      // Acknowledge but ignore sandbox notifications that reach the production
      // webhook for a non-tester. Throwing here would 500 and make Apple retry
      // indefinitely; returning accepted:true tells Apple to stop.
      if (!isSandboxTransactionAllowed(transaction.environment, context.user)) {
        log.warn(
          { event: 'billing.notification.sandbox_ignored', userId: user.id },
          'Ignoring sandbox App Store notification in production'
        );
        return { accepted: true };
      }

      const entitlement = await writeEntitlementFromTransaction(
        tx,
        context,
        transaction,
        notification.notificationType ?? 'APP_STORE_NOTIFICATION'
      );

      return { accepted: true, entitlement };
    })
  );
}

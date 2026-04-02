import { createHash } from 'crypto';
import { readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
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
  Prisma,
  SessionMode,
  SubscriptionProduct,
  SubscriptionStatus,
  SubscriptionTier,
  type UserEntitlement,
} from '@prisma/client';
import { getEnv } from '../../config/env.js';
import { getPrisma, withDatabaseRetry, type DatabaseClient } from '../../config/database.js';
import { ensureAppAccountToken } from '../users/app-account-token.js';
import {
  ForbiddenError,
  NotFoundError,
  PaymentRequiredError,
  ValidationError,
} from '../../utils/errors.js';
import {
  FEATURE_KEYS,
  findCatalogItemByProductId,
  getSubscriptionCatalog,
  isSubscriptionActive,
  resolveFeatureSet,
  SESSION_MODE_FEATURE,
  TIER_MODEL_CONFIG,
  TIER_RESPONSE_QUALITY,
  type FeatureKey,
  type ModelConfig,
  type ResponseQuality,
} from './billing.constants.js';
import {
  getCachedBillingSummary,
  setCachedBillingSummary,
  invalidateBillingCache,
} from './billing.cache.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const APPLE_ROOT_CERT_PATHS = [
  path.resolve(__dirname, '../../../certs/apple/AppleRootCA-G2.cer'),
  path.resolve(__dirname, '../../../certs/apple/AppleRootCA-G3.cer'),
];

type BillingContext = {
  user: {
    id: string;
    email: string;
    appAccountToken: string;
    isSandboxTester: boolean;
  };
  entitlement: UserEntitlement;
};

type BillingDbClient = DatabaseClient | Prisma.TransactionClient;

type VerifiedAppStoreTransaction = {
  payload: JWSTransactionDecodedPayload;
  renewalInfo?: JWSRenewalInfoDecodedPayload;
  environment: AppStoreEnvironment;
  signedTransaction: string;
};

export type BillingSummary = {
  tier: string;
  status: string;
  accessSource: string;
  product: string;
  productId: string | null;
  features: FeatureKey[];
  featureFlags: Record<FeatureKey, boolean>;
  sandboxFullAccess: boolean;
  trialInterviewLimit: number;
  trialInterviewsUsed: number;
  interviewsRemaining: number;
  hasActiveSubscription: boolean;
  paywallRequired: boolean;
  appAccountToken: string;
  currentPeriodEndsAt: string | null;
  gracePeriodEndsAt: string | null;
  trialDaysRemaining: number | null;
  responseQuality: ResponseQuality;
  modelConfig: ModelConfig;
  monthlyInterviewsUsed: number;
  monthlyInterviewLimit: number;
  monthlyInterviewsRemaining: number;
  catalog: Array<{
    product: string;
    productId: string;
    tier: string;
    displayName: string;
    billingLabel: string;
    features: FeatureKey[];
  }>;
};

export type AccessClaimResult = {
  sessionClientId: string;
  sessionMode: string;
  accessSource: string;
  accessTier: string;
  consumedTrial: boolean;
  trialInterviewNumber: number | null;
  entitlement: BillingSummary;
};

let appleRootCAsPromise: Promise<Buffer[]> | undefined;
const verifierCache = new Map<AppStoreEnvironment, SignedDataVerifier>();

async function loadAppleRootCAs(): Promise<Buffer[]> {
  if (!appleRootCAsPromise) {
    appleRootCAsPromise = Promise.all(APPLE_ROOT_CERT_PATHS.map((certPath) => readFile(certPath)));
  }

  return appleRootCAsPromise;
}

async function getSignedDataVerifier(environment: AppStoreEnvironment): Promise<SignedDataVerifier> {
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
    throw new ValidationError('APP_STORE_APPLE_ID must be configured for production App Store validation');
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new ValidationError('APP_STORE_APPLE_ID must be a positive integer');
  }

  return parsed;
}

function serializeEnum(value: string): string {
  return value
    .toLowerCase()
    .replace(/_([a-z])/g, (_match, char: string) => char.toUpperCase());
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

function rankTier(tier: SubscriptionTier): number {
  switch (tier) {
    case SubscriptionTier.SANDBOX:
      return 4;
    case SubscriptionTier.PRO:
      return 3;
    case SubscriptionTier.PLUS:
      return 2;
    case SubscriptionTier.TRIAL:
      return 1;
    case SubscriptionTier.FREE:
    default:
      return 0;
  }
}

function getNextMonthlyReset(): Date {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth() + 1, 1);
}

function isSandboxTesterEmail(email: string): boolean {
  const raw = getEnv().SANDBOX_TESTER_EMAILS;
  if (!raw) return false;
  const allowed = raw.split(',').map((e) => e.trim().toLowerCase()).filter(Boolean);
  return allowed.includes(email.trim().toLowerCase());
}

async function ensureBillingContext(
  prisma: Pick<BillingDbClient, 'user' | 'userEntitlement'>,
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

  // Auto-promote users whose email is in SANDBOX_TESTER_EMAILS
  if (!user.isSandboxTester && isSandboxTesterEmail(user.email)) {
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
    const trialEndsAt = new Date(trialStartedAt.getTime() + env.TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000);
    entitlement = await prisma.userEntitlement.create({
      data: {
        userId,
        trialInterviewLimit: env.TRIAL_INTERVIEW_LIMIT,
        trialStartedAt,
        trialEndsAt,
      },
    });
  }

  return {
    user: {
      id: user.id,
      email: user.email,
      appAccountToken: await ensureAppAccountToken(prisma, user),
      isSandboxTester: user.isSandboxTester,
    },
    entitlement,
  };
}

function buildSummary(context: BillingContext): BillingSummary {
  const sandboxFullAccess =
    context.user.isSandboxTester || context.entitlement.sandboxFullAccess;

  // Detect expired trial — user's stored tier is TRIAL but the trial window has closed
  const isTrialExpired = context.entitlement.tier === SubscriptionTier.TRIAL
    && context.entitlement.trialEndsAt !== null
    && context.entitlement.trialEndsAt.getTime() < Date.now();

  const effectiveTier = sandboxFullAccess
    ? SubscriptionTier.SANDBOX
    : (isTrialExpired ? SubscriptionTier.FREE : context.entitlement.tier);

  const effectiveStatus = sandboxFullAccess
    ? SubscriptionStatus.SANDBOX
    : (isTrialExpired ? SubscriptionStatus.FREE : context.entitlement.status);

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

  // Trial days remaining (only for users still in an active trial)
  const trialDaysRemaining = context.entitlement.tier === SubscriptionTier.TRIAL
    && context.entitlement.trialEndsAt !== null
    && !isTrialExpired
    ? Math.ceil((context.entitlement.trialEndsAt.getTime() - Date.now()) / (24 * 60 * 60 * 1000))
    : null;

  // Monthly interview limits for FREE tier
  const monthlyLimit = getEnv().FREE_MONTHLY_INTERVIEW_LIMIT;
  const monthlyUsed = context.entitlement.monthlyInterviewsUsed;
  const monthlyRemaining = effectiveTier === SubscriptionTier.FREE
    ? Math.max(monthlyLimit - monthlyUsed, 0)
    : Number.MAX_SAFE_INTEGER;

  // For FREE tier, use monthly remaining; for active trial, use trial-based remaining
  const interviewsRemaining = hasPaidSubscription || sandboxFullAccess
    ? Number.MAX_SAFE_INTEGER
    : effectiveTier === SubscriptionTier.FREE
      ? monthlyRemaining
      : Math.max(context.entitlement.trialInterviewLimit - context.entitlement.trialInterviewsUsed, 0);

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
    featureFlags: FEATURE_KEYS.reduce<Record<FeatureKey, boolean>>((result, feature) => {
      result[feature] = features.includes(feature);
      return result;
    }, {} as Record<FeatureKey, boolean>),
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
    modelConfig: TIER_MODEL_CONFIG[effectiveTier],
    monthlyInterviewsUsed: monthlyUsed,
    monthlyInterviewLimit: monthlyLimit,
    monthlyInterviewsRemaining: monthlyRemaining,
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
  return transactions
    .slice()
    .sort((left, right) => {
      const leftCatalog = findCatalogItemByProductId(left.payload.productId ?? '');
      const rightCatalog = findCatalogItemByProductId(right.payload.productId ?? '');
      const leftTier = left.environment === AppStoreEnvironment.SANDBOX
        ? SubscriptionTier.SANDBOX
        : leftCatalog?.tier ?? SubscriptionTier.TRIAL;
      const rightTier = right.environment === AppStoreEnvironment.SANDBOX
        ? SubscriptionTier.SANDBOX
        : rightCatalog?.tier ?? SubscriptionTier.TRIAL;

      const tierDelta = rankTier(rightTier) - rankTier(leftTier);
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

async function verifyNotificationPayload(
  signedPayload: string
): Promise<{
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

  const appAccountToken = transaction.payload.appAccountToken ?? transaction.renewalInfo?.appAccountToken;
  if (appAccountToken && appAccountToken !== context.user.appAccountToken) {
    throw new ForbiddenError('App Store transaction does not belong to the authenticated user');
  }

  const sandboxFullAccess =
    context.user.isSandboxTester || transaction.environment === AppStoreEnvironment.SANDBOX;
  const tier = sandboxFullAccess ? SubscriptionTier.SANDBOX : catalogItem.tier;
  const product = sandboxFullAccess ? SubscriptionProduct.SANDBOX_FULL_ACCESS : catalogItem.product;
  const status = sandboxFullAccess
    ? SubscriptionStatus.SANDBOX
    : deriveSubscriptionStatus(transaction.payload, transaction.renewalInfo, eventType);

  const entitlement = await prisma.userEntitlement.update({
    where: { userId: context.user.id },
    data: {
      tier,
      status,
      provider: BillingProvider.APP_STORE,
      product,
      productId,
      featuresOverride: Prisma.JsonNull,
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
    },
  });

  await invalidateBillingCache(context.user.id);

  return buildSummary({
    user: context.user,
    entitlement,
  });
}

async function withSessionAccessGrant(
  userId: string,
  sessionClientId: string,
  sessionMode: SessionMode
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

        const context = await ensureBillingContext(prisma, userId);
        return {
          sessionClientId: existingGrant.sessionClientId,
          sessionMode: serializeEnum(existingGrant.sessionMode),
          accessSource: serializeEnum(existingGrant.accessSource),
          accessTier: serializeEnum(existingGrant.accessTier),
          consumedTrial: existingGrant.consumedTrial,
          trialInterviewNumber: existingGrant.trialInterviewNumber ?? null,
          entitlement: buildSummary(context),
        };
      }

      let context = await ensureBillingContext(prisma, userId);
      const summary = buildSummary(context);
      const requiredFeature = SESSION_MODE_FEATURE[sessionMode];

      if (!summary.featureFlags[requiredFeature]) {
        throw new PaymentRequiredError(
          sessionMode === SessionMode.VOICE_PREP
            ? 'Voice Prep requires an active Pro subscription'
            : 'Upgrade required to start this interview session',
          { requiredFeature }
        );
      }

      let accessSource: AccessSource = AccessSource.SUBSCRIPTION;
      let accessTier: SubscriptionTier = context.entitlement.tier;
      let consumedTrial = false;
      let trialInterviewNumber: number | null = null;
      let nextContext = context;

      if (summary.sandboxFullAccess) {
        accessSource = AccessSource.SANDBOX;
        accessTier = SubscriptionTier.SANDBOX;
      } else if (summary.hasActiveSubscription) {
        accessSource = AccessSource.SUBSCRIPTION;
        accessTier = context.entitlement.tier;
      } else {
        if (sessionMode !== SessionMode.LIVE_INTERVIEW) {
          throw new PaymentRequiredError('Voice Prep requires an active Pro subscription');
        }

        // Determine effective tier (expired trials become FREE)
        const isTrialExpired = context.entitlement.tier === SubscriptionTier.TRIAL
          && context.entitlement.trialEndsAt !== null
          && context.entitlement.trialEndsAt.getTime() < Date.now();
        const effectiveTier = isTrialExpired ? SubscriptionTier.FREE : context.entitlement.tier;

        if (effectiveTier === SubscriptionTier.FREE) {
          // FREE tier: monthly interview limits
          // Reset monthly counter if the reset window has passed
          const resetAt = context.entitlement.monthlyInterviewsResetAt;
          if (resetAt && resetAt.getTime() < Date.now()) {
            await prisma.userEntitlement.update({
              where: { id: context.entitlement.id },
              data: {
                monthlyInterviewsUsed: 0,
                monthlyInterviewsResetAt: getNextMonthlyReset(),
              },
            });
            context = await ensureBillingContext(prisma, userId);
          }

          const limit = getEnv().FREE_MONTHLY_INTERVIEW_LIMIT;
          if (context.entitlement.monthlyInterviewsUsed >= limit) {
            throw new PaymentRequiredError(
              `You've used all ${limit} free interviews this month. Upgrade for unlimited access.`,
              { requiredTier: 'plus' }
            );
          }

          const updated = await prisma.userEntitlement.updateMany({
            where: {
              id: context.entitlement.id,
              monthlyInterviewsUsed: { lt: limit },
            },
            data: {
              monthlyInterviewsUsed: { increment: 1 },
              monthlyInterviewsResetAt: context.entitlement.monthlyInterviewsResetAt ?? getNextMonthlyReset(),
            },
          });

          if (updated.count !== 1) {
            throw new PaymentRequiredError(
              `You've used all ${limit} free interviews this month. Upgrade for unlimited access.`,
              { requiredTier: 'plus' }
            );
          }

          await invalidateBillingCache(userId);
          const refreshed = await ensureBillingContext(prisma, userId);
          nextContext = refreshed;
          accessSource = AccessSource.TRIAL; // Reuse TRIAL access source for compatibility
          accessTier = SubscriptionTier.FREE;
          consumedTrial = false;
          trialInterviewNumber = null;
        } else {
          // Active trial: use trial-based interview limits
          if (summary.interviewsRemaining <= 0) {
            throw new PaymentRequiredError('Your free trial interviews are complete', {
              requiredTier: 'plus',
            });
          }

          const updated = await prisma.userEntitlement.updateMany({
            where: {
              id: context.entitlement.id,
              trialInterviewsUsed: { lt: context.entitlement.trialInterviewLimit },
            },
            data: {
              trialInterviewsUsed: { increment: 1 },
            },
          });

          if (updated.count !== 1) {
            throw new PaymentRequiredError('Your free trial interviews are complete', {
              requiredTier: 'plus',
            });
          }

          await invalidateBillingCache(userId);

          const refreshed = await ensureBillingContext(prisma, userId);
          nextContext = refreshed;
          accessSource = AccessSource.TRIAL;
          accessTier = SubscriptionTier.TRIAL;
          consumedTrial = true;
          trialInterviewNumber = refreshed.entitlement.trialInterviewsUsed;
        }
      }

      const grant = await prisma.sessionAccessGrant.create({
        data: {
          userId,
          sessionClientId,
          sessionMode,
          accessSource,
          accessTier,
          consumedTrial,
          trialInterviewNumber: trialInterviewNumber ?? undefined,
          featureSnapshot: {
            features: buildSummary(nextContext).features,
            status: buildSummary(nextContext).status,
          } satisfies Prisma.JsonObject,
        },
      });

      return {
        sessionClientId: grant.sessionClientId,
        sessionMode: serializeEnum(grant.sessionMode),
        accessSource: serializeEnum(grant.accessSource),
        accessTier: serializeEnum(grant.accessTier),
        consumedTrial: grant.consumedTrial,
        trialInterviewNumber: grant.trialInterviewNumber ?? null,
        entitlement: buildSummary(nextContext),
      };
    });
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      const existingGrant = await withDatabaseRetry((prisma) =>
        prisma.sessionAccessGrant.findUnique({
          where: { sessionClientId },
        })
      );

      if (existingGrant && existingGrant.userId === userId) {
        const summary = await getBillingSummary(userId);
        return {
          sessionClientId: existingGrant.sessionClientId,
          sessionMode: serializeEnum(existingGrant.sessionMode),
          accessSource: serializeEnum(existingGrant.accessSource),
          accessTier: serializeEnum(existingGrant.accessTier),
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
    return cached as unknown as BillingSummary;
  }

  const summary = await withDatabaseRetry(async (prisma) =>
    buildSummary(await ensureBillingContext(prisma, userId))
  );

  await setCachedBillingSummary(userId, summary as unknown as import('./billing.cache.js').CachedBillingSummary).catch(() => {});

  return summary;
}

export async function claimInterviewAccess(
  userId: string,
  sessionClientId: string,
  sessionMode: SessionMode
): Promise<AccessClaimResult> {
  return withSessionAccessGrant(userId, sessionClientId, sessionMode);
}

export async function getSessionAccessGrant(
  userId: string,
  sessionClientId: string,
  sessionMode: SessionMode
): Promise<{
  accessSource: AccessSource;
  accessTier: SubscriptionTier;
  trialInterviewNumber: number | null;
}> {
  const grant = await withSessionAccessGrant(userId, sessionClientId, sessionMode);
  return {
    accessSource:
      grant.accessSource === 'sandbox'
        ? AccessSource.SANDBOX
        : grant.accessSource === 'subscription'
          ? AccessSource.SUBSCRIPTION
          : AccessSource.TRIAL,
    accessTier:
      grant.accessTier === 'sandbox'
        ? SubscriptionTier.SANDBOX
        : grant.accessTier === 'pro'
          ? SubscriptionTier.PRO
          : grant.accessTier === 'plus'
            ? SubscriptionTier.PLUS
            : grant.accessTier === 'free'
              ? SubscriptionTier.FREE
              : SubscriptionTier.TRIAL,
    trialInterviewNumber: grant.trialInterviewNumber,
  };
}

export async function canAccessRuntimeAiConfig(userId: string): Promise<boolean> {
  const summary = await getBillingSummary(userId);
  return summary.sandboxFullAccess || summary.hasActiveSubscription || summary.interviewsRemaining > 0;
}

export async function syncAppStoreTransactions(
  userId: string,
  signedTransactions: string[]
): Promise<BillingSummary> {
  const verified = await Promise.all(signedTransactions.map((item) => verifySignedTransaction(item)));
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
  const appAccountToken = transaction?.payload.appAccountToken ?? transaction?.renewalInfo?.appAccountToken;

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

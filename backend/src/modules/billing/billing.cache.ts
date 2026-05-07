import { getRedis } from '../../config/redis.js';
import type {
  FeatureKey,
  ModelConfig,
  ResponseQuality,
} from './billing.constants.js';

const BILLING_CACHE_PREFIX = 'billing:summary:';
// 30s TTL keeps clients reasonably fresh on tier upgrades while still absorbing
// the request rate spikes during a live interview launch (paywall + entitlement read).
const BILLING_CACHE_TTL = 30; // seconds

export interface QuotaWindowDTO {
  used: number;
  limit: number;
  remaining: number;
  isUnlimited: boolean;
  resetsAt: string | null;
}

export interface QuotaSummaryDTO {
  standard: QuotaWindowDTO;
  premium: QuotaWindowDTO;
  periodStartedAt: string;
  periodEndsAt: string | null;
}

export interface CachedBillingSummary {
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
  // Legacy aggregate counter kept for one release so older iOS builds still render.
  monthlyInterviewsUsed: number;
  monthlyInterviewLimit: number;
  monthlyInterviewsRemaining: number;
  // New per-quality dimension. iOS 26.1+ reads `quotas` directly.
  quotas: QuotaSummaryDTO;
  profileLimit: number;
  profilesUsed: number;
  catalog: Array<{
    product: string;
    productId: string;
    tier: string;
    displayName: string;
    billingLabel: string;
    features: FeatureKey[];
  }>;
}

export async function getCachedBillingSummary(userId: string): Promise<CachedBillingSummary | null> {
  const redis = await getRedis();
  if (!redis) return null;

  const cached = await redis.get(`${BILLING_CACHE_PREFIX}${userId}`);
  if (!cached) return null;

  try {
    const parsed = JSON.parse(cached) as Partial<CachedBillingSummary>;
    // Reject pre-quotas cache entries so we never serve a stale shape after a deploy.
    if (!parsed.quotas) return null;
    return parsed as CachedBillingSummary;
  } catch {
    return null;
  }
}

export async function setCachedBillingSummary(userId: string, summary: CachedBillingSummary): Promise<void> {
  const redis = await getRedis();
  if (!redis) return;

  await redis.setEx(
    `${BILLING_CACHE_PREFIX}${userId}`,
    BILLING_CACHE_TTL,
    JSON.stringify(summary)
  );
}

export async function invalidateBillingCache(userId: string): Promise<void> {
  const redis = await getRedis();
  if (!redis) return;

  await redis.del(`${BILLING_CACHE_PREFIX}${userId}`);
}

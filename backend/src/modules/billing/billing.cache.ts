import { getRedis } from '../../config/redis.js';
import type { FeatureKey, ModelConfig, ResponseQuality } from './billing.constants.js';

const BILLING_CACHE_PREFIX = 'billing:summary:';
const BILLING_CACHE_TTL = 60; // seconds

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
  monthlyInterviewsUsed: number;
  monthlyInterviewLimit: number;
  profileLimit: number;
  profilesUsed: number;
  monthlyInterviewsRemaining: number;
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
    return JSON.parse(cached) as CachedBillingSummary;
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

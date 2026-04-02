import { getRedis } from '../../config/redis.js';

const BILLING_CACHE_PREFIX = 'billing:summary:';
const BILLING_CACHE_TTL = 60; // seconds

export interface CachedBillingSummary {
  tier: string;
  status: string;
  product: string;
  interviewsRemaining: number | null;
  interviewsUsed: number;
  interviewLimit: number;
  hasUnlimitedInterviews: boolean;
  canStartLiveInterview: boolean;
  canStartVoicePrep: boolean;
  currentPeriodEndsAt: string | null;
  featureFlags: Record<string, boolean>;
  trialDaysRemaining: number | null;
  responseQuality: string;
  modelConfig: {
    defaultModel: string;
    technicalModel: string;
    codingModel: string;
    maxTokens: number;
  };
  monthlyInterviewsUsed: number;
  monthlyInterviewLimit: number;
  monthlyInterviewsRemaining: number;
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

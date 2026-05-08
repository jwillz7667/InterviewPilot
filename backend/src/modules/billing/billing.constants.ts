import type { SessionMode } from '@prisma/client';
import {
  InterviewQuality as PrismaInterviewQuality,
  SubscriptionProduct,
  SubscriptionStatus,
  SubscriptionTier,
} from '@prisma/client';

import { getEnv } from '../../config/env.js';

export const FEATURE_KEYS = [
  'live_interview',
  'session_history',
  'resume_personalization',
  'response_formats',
  'voice_prep',
  'priority_models',
  'post_session_analysis',
] as const;

export type FeatureKey = (typeof FEATURE_KEYS)[number];

export type InterviewQuality = PrismaInterviewQuality;
export const InterviewQuality = PrismaInterviewQuality;

export interface CatalogItem {
  product: SubscriptionProduct;
  productId: string;
  tier: SubscriptionTier;
  displayName: string;
  billingLabel: string;
  features: FeatureKey[];
}

const FREE_FEATURES: FeatureKey[] = ['live_interview', 'session_history'];

const PRO_FEATURES: FeatureKey[] = [
  'live_interview',
  'session_history',
  'resume_personalization',
  'response_formats',
  'priority_models',
];

const PREMIUM_FEATURES: FeatureKey[] = [...PRO_FEATURES, 'voice_prep', 'post_session_analysis'];

export const TIER_FEATURES: Record<SubscriptionTier, FeatureKey[]> = {
  FREE: FREE_FEATURES,
  TRIAL: FREE_FEATURES,
  PLUS: PRO_FEATURES,
  PRO: PRO_FEATURES,
  PREMIUM: PREMIUM_FEATURES,
  SANDBOX: PREMIUM_FEATURES,
};

export const FREE_SESSION_HISTORY_LIMIT = 5;

const UNLIMITED = -1;

export interface QuotaPolicy {
  standardMonthly: number;
  premiumMonthly: number;
}

export const TIER_QUOTA: Record<SubscriptionTier, QuotaPolicy> = {
  FREE: { standardMonthly: 3, premiumMonthly: 1 },
  TRIAL: { standardMonthly: 3, premiumMonthly: 1 },
  PLUS: { standardMonthly: 25, premiumMonthly: 10 },
  PRO: { standardMonthly: 25, premiumMonthly: 10 },
  PREMIUM: { standardMonthly: UNLIMITED, premiumMonthly: UNLIMITED },
  SANDBOX: { standardMonthly: UNLIMITED, premiumMonthly: UNLIMITED },
};

export function isUnlimitedQuota(limit: number): boolean {
  return limit < 0;
}

export interface ModelChoice {
  model: string;
  maxTokens: number;
  temperature: number;
}

export interface QualityModelConfig {
  primary: string;
  technical: string;
  coding: string;
  maxTokens: number;
  temperature: number;
  preGenAnswerBank: number;
}

export const MODEL_BY_QUALITY: Record<InterviewQuality, QualityModelConfig> = {
  STANDARD: {
    primary: 'gpt-4.1-mini',
    technical: 'gpt-4.1-mini',
    coding: 'gpt-4.1-mini',
    maxTokens: 320,
    temperature: 0.7,
    preGenAnswerBank: 25,
  },
  PREMIUM: {
    primary: 'gpt-4.1',
    technical: 'gpt-4.1',
    coding: 'o4-mini',
    maxTokens: 600,
    temperature: 0.55,
    preGenAnswerBank: 50,
  },
};

export type QuestionRouting = 'coding' | 'technical' | 'default';

export function selectModel(
  quality: InterviewQuality,
  routing: QuestionRouting = 'default'
): ModelChoice {
  const cfg = MODEL_BY_QUALITY[quality];
  const model =
    routing === 'coding' ? cfg.coding : routing === 'technical' ? cfg.technical : cfg.primary;

  return {
    model,
    maxTokens: cfg.maxTokens,
    temperature: cfg.temperature,
  };
}

// Legacy: model config keyed by tier — used only as a display hint inside BillingSummary.
// Production AI requests resolve their model server-side via selectModel(quality, routing).
export interface ModelConfig {
  defaultModel: string;
  technicalModel: string;
  codingModel: string;
  maxTokens: number;
}

function modelConfigForQuality(quality: InterviewQuality): ModelConfig {
  const cfg = MODEL_BY_QUALITY[quality];
  return {
    defaultModel: cfg.primary,
    technicalModel: cfg.technical,
    codingModel: cfg.coding,
    maxTokens: cfg.maxTokens,
  };
}

export const TIER_MODEL_CONFIG: Record<SubscriptionTier, ModelConfig> = {
  FREE: modelConfigForQuality('STANDARD'),
  TRIAL: modelConfigForQuality('STANDARD'),
  PLUS: modelConfigForQuality('STANDARD'),
  PRO: modelConfigForQuality('STANDARD'),
  PREMIUM: modelConfigForQuality('PREMIUM'),
  SANDBOX: modelConfigForQuality('PREMIUM'),
};

export type ResponseQuality = 'standard' | 'enhanced' | 'premium';

export const TIER_RESPONSE_QUALITY: Record<SubscriptionTier, ResponseQuality> = {
  FREE: 'standard',
  TRIAL: 'standard',
  PLUS: 'enhanced',
  PRO: 'enhanced',
  PREMIUM: 'premium',
  SANDBOX: 'premium',
};

export const TIER_PROFILE_LIMITS: Record<SubscriptionTier, number> = {
  FREE: 1,
  TRIAL: 1,
  PLUS: 1,
  PRO: 3,
  PREMIUM: 5,
  SANDBOX: 5,
};

export const SESSION_MODE_FEATURE: Record<SessionMode, FeatureKey> = {
  LIVE_INTERVIEW: 'live_interview',
  VOICE_PREP: 'voice_prep',
};

export function getSubscriptionCatalog(): CatalogItem[] {
  const env = getEnv();

  return [
    {
      product: SubscriptionProduct.PRO_MONTHLY,
      productId: env.APP_STORE_PRO_MONTHLY_PRODUCT_ID,
      tier: SubscriptionTier.PRO,
      displayName: 'Pro Monthly',
      billingLabel: 'Monthly',
      features: TIER_FEATURES.PRO,
    },
    {
      product: SubscriptionProduct.PRO_YEARLY,
      productId: env.APP_STORE_PRO_YEARLY_PRODUCT_ID,
      tier: SubscriptionTier.PRO,
      displayName: 'Pro Yearly',
      billingLabel: 'Yearly',
      features: TIER_FEATURES.PRO,
    },
    {
      product: SubscriptionProduct.PREMIUM_MONTHLY,
      productId: env.APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID,
      tier: SubscriptionTier.PREMIUM,
      displayName: 'Premium Monthly',
      billingLabel: 'Monthly',
      features: TIER_FEATURES.PREMIUM,
    },
    {
      product: SubscriptionProduct.PREMIUM_YEARLY,
      productId: env.APP_STORE_PREMIUM_YEARLY_PRODUCT_ID,
      tier: SubscriptionTier.PREMIUM,
      displayName: 'Premium Yearly',
      billingLabel: 'Yearly',
      features: TIER_FEATURES.PREMIUM,
    },
    // Legacy products kept addressable so in-flight subscribers continue to verify cleanly.
    // After the rollout completes and the App Store receipts have rotated, these can be removed.
    {
      product: SubscriptionProduct.PLUS_MONTHLY,
      productId: env.APP_STORE_PLUS_MONTHLY_PRODUCT_ID,
      tier: SubscriptionTier.PRO,
      displayName: 'Plus Monthly (Legacy)',
      billingLabel: 'Monthly',
      features: TIER_FEATURES.PRO,
    },
    {
      product: SubscriptionProduct.PLUS_YEARLY,
      productId: env.APP_STORE_PLUS_YEARLY_PRODUCT_ID,
      tier: SubscriptionTier.PRO,
      displayName: 'Plus Yearly (Legacy)',
      billingLabel: 'Yearly',
      features: TIER_FEATURES.PRO,
    },
  ];
}

export function findCatalogItemByProductId(productId: string): CatalogItem | undefined {
  return getSubscriptionCatalog().find((item) => item.productId === productId);
}

export function isSubscriptionActive(
  status: SubscriptionStatus,
  currentPeriodEndsAt?: Date | null,
  gracePeriodEndsAt?: Date | null
): boolean {
  const now = Date.now();

  if (status === SubscriptionStatus.SANDBOX || status === SubscriptionStatus.ACTIVE) {
    return !currentPeriodEndsAt || currentPeriodEndsAt.getTime() >= now;
  }

  if (status === SubscriptionStatus.IN_GRACE_PERIOD) {
    return !!gracePeriodEndsAt && gracePeriodEndsAt.getTime() >= now;
  }

  return false;
}

export function resolveFeatureSet(
  tier: SubscriptionTier,
  sandboxFullAccess: boolean
): FeatureKey[] {
  if (sandboxFullAccess) {
    return TIER_FEATURES.SANDBOX;
  }

  return TIER_FEATURES[tier];
}

export function tierMeetsRequirement(
  current: SubscriptionTier,
  required: SubscriptionTier
): boolean {
  return tierRank(current) >= tierRank(required);
}

export function tierRank(tier: SubscriptionTier): number {
  switch (tier) {
    case SubscriptionTier.SANDBOX:
      return 5;
    case SubscriptionTier.PREMIUM:
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

export function requiredTierForQuality(quality: InterviewQuality): SubscriptionTier {
  // The minimum tier whose monthly quota allows this quality at all.
  // FREE includes a small premium taste; PRO is the "standard volume" tier; PREMIUM is unlimited.
  return quality === 'PREMIUM' ? SubscriptionTier.PRO : SubscriptionTier.FREE;
}

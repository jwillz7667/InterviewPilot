import {
  SessionMode,
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
] as const;

export type FeatureKey = (typeof FEATURE_KEYS)[number];

export type CatalogItem = {
  product: SubscriptionProduct;
  productId: string;
  tier: SubscriptionTier;
  displayName: string;
  billingLabel: string;
  features: FeatureKey[];
};

const BASE_FEATURES: FeatureKey[] = [
  'live_interview',
  'session_history',
  'resume_personalization',
  'response_formats',
];

const PRO_FEATURES: FeatureKey[] = [...BASE_FEATURES, 'voice_prep', 'priority_models'];

export const TIER_FEATURES: Record<SubscriptionTier, FeatureKey[]> = {
  TRIAL: BASE_FEATURES,
  PLUS: BASE_FEATURES,
  PRO: PRO_FEATURES,
  SANDBOX: PRO_FEATURES,
};

export const SESSION_MODE_FEATURE: Record<SessionMode, FeatureKey> = {
  LIVE_INTERVIEW: 'live_interview',
  VOICE_PREP: 'voice_prep',
};

export function getSubscriptionCatalog(): CatalogItem[] {
  const env = getEnv();

  return [
    {
      product: SubscriptionProduct.PLUS_MONTHLY,
      productId: env.APP_STORE_PLUS_MONTHLY_PRODUCT_ID,
      tier: SubscriptionTier.PLUS,
      displayName: 'Plus Monthly',
      billingLabel: 'Monthly',
      features: TIER_FEATURES.PLUS,
    },
    {
      product: SubscriptionProduct.PLUS_YEARLY,
      productId: env.APP_STORE_PLUS_YEARLY_PRODUCT_ID,
      tier: SubscriptionTier.PLUS,
      displayName: 'Plus Yearly',
      billingLabel: 'Yearly',
      features: TIER_FEATURES.PLUS,
    },
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

-- Per-quality interview quota columns on UserEntitlement.
-- Backfills existing rows so no user loses entitlement: every PLUS subscriber maps to PRO,
-- every PRO subscriber maps to PREMIUM (the new top tier), preserving auto-renewal continuity.

ALTER TABLE "user_entitlements"
  ADD COLUMN "monthlyStandardUsed"   INTEGER       NOT NULL DEFAULT 0,
  ADD COLUMN "monthlyPremiumUsed"    INTEGER       NOT NULL DEFAULT 0,
  ADD COLUMN "monthlyStandardLimit"  INTEGER       NOT NULL DEFAULT 3,
  ADD COLUMN "monthlyPremiumLimit"   INTEGER       NOT NULL DEFAULT 1,
  ADD COLUMN "quotaPeriodStartedAt"  TIMESTAMP(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "quotaPeriodEndsAt"     TIMESTAMP(3);

ALTER TABLE "billing_events"
  ADD COLUMN "quotaDelta" JSONB;

-- Carry over the legacy single-counter (best-effort): treat all prior usage as standard.
UPDATE "user_entitlements"
   SET "monthlyStandardUsed" = LEAST("monthlyInterviewsUsed", 3)
 WHERE "tier" = 'FREE';

-- Tier remap: PRO subscribers ascend to PREMIUM (was previously the top paid tier).
-- Run BEFORE the PLUS->PRO remap so PLUS rows do not double-promote.
UPDATE "user_entitlements" SET "tier" = 'PREMIUM' WHERE "tier" = 'PRO';

-- PLUS subscribers ascend to PRO (now the mid paid tier with 25 std + 10 premium / period).
UPDATE "user_entitlements" SET "tier" = 'PRO'      WHERE "tier" = 'PLUS';

-- Apply per-tier quota limits aligned with TIER_QUOTA in code.
UPDATE "user_entitlements"
   SET "monthlyStandardLimit" = 25,
       "monthlyPremiumLimit"  = 10
 WHERE "tier" = 'PRO';

UPDATE "user_entitlements"
   SET "monthlyStandardLimit" = -1,
       "monthlyPremiumLimit"  = -1
 WHERE "tier" IN ('PREMIUM', 'SANDBOX');

-- TRIAL stays addressable for legacy rows; treat its limits as FREE-equivalent.
UPDATE "user_entitlements"
   SET "monthlyStandardLimit" = 3,
       "monthlyPremiumLimit"  = 1
 WHERE "tier" = 'TRIAL';

-- Initialise rolling 30-day quota window for every existing row.
UPDATE "user_entitlements"
   SET "quotaPeriodStartedAt" = CURRENT_TIMESTAMP,
       "quotaPeriodEndsAt"    = CURRENT_TIMESTAMP + INTERVAL '30 days';

-- Promote BillingEvent rows that referenced the old PRO/PLUS products to keep the audit trail readable.
-- Note: SubscriptionProduct values themselves are NOT renamed — App Store productIds remain stable
-- to preserve in-flight subscriptions. This UPDATE only touches the tier column on entitlements.

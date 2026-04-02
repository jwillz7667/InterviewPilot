-- Add FREE to SubscriptionTier enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'FREE' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'SubscriptionTier')) THEN
        ALTER TYPE "SubscriptionTier" ADD VALUE 'FREE' BEFORE 'TRIAL';
    END IF;
END
$$;

-- Add FREE to SubscriptionStatus enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'FREE' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'SubscriptionStatus')) THEN
        ALTER TYPE "SubscriptionStatus" ADD VALUE 'FREE' BEFORE 'TRIALING';
    END IF;
END
$$;

-- Add trial tracking columns to user_entitlements
ALTER TABLE "user_entitlements" ADD COLUMN IF NOT EXISTS "trialStartedAt" TIMESTAMP(3);
ALTER TABLE "user_entitlements" ADD COLUMN IF NOT EXISTS "trialEndsAt" TIMESTAMP(3);
ALTER TABLE "user_entitlements" ADD COLUMN IF NOT EXISTS "monthlyInterviewsUsed" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "user_entitlements" ADD COLUMN IF NOT EXISTS "monthlyInterviewsResetAt" TIMESTAMP(3);

-- Backfill existing TRIAL users: set trialStartedAt and trialEndsAt
-- Uses currentPeriodStartedAt as the trial start, adds 7 days for end
UPDATE "user_entitlements"
SET
    "trialStartedAt" = "currentPeriodStartedAt",
    "trialEndsAt" = "currentPeriodStartedAt" + INTERVAL '7 days'
WHERE
    "tier" = 'TRIAL'
    AND "trialStartedAt" IS NULL
    AND "currentPeriodStartedAt" IS NOT NULL;

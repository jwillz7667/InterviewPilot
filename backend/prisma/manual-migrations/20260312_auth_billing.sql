CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- CreateEnum
CREATE TYPE "SubscriptionTier" AS ENUM ('TRIAL', 'PLUS', 'PRO', 'SANDBOX');

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('TRIALING', 'ACTIVE', 'IN_GRACE_PERIOD', 'EXPIRED', 'CANCELED', 'REVOKED', 'SANDBOX');

-- CreateEnum
CREATE TYPE "BillingProvider" AS ENUM ('INTERNAL', 'APP_STORE');

-- CreateEnum
CREATE TYPE "SubscriptionProduct" AS ENUM ('NONE', 'PLUS_MONTHLY', 'PLUS_YEARLY', 'PRO_MONTHLY', 'PRO_YEARLY', 'SANDBOX_FULL_ACCESS');

-- CreateEnum
CREATE TYPE "AppStoreEnvironment" AS ENUM ('SANDBOX', 'PRODUCTION');

-- CreateEnum
CREATE TYPE "AccessSource" AS ENUM ('TRIAL', 'SUBSCRIPTION', 'SANDBOX');

-- CreateEnum
CREATE TYPE "SessionMode" AS ENUM ('LIVE_INTERVIEW', 'VOICE_PREP');

-- DropIndex
DROP INDEX "refresh_tokens_token_key";

-- DropIndex
DROP INDEX "refresh_tokens_token_idx";

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "appAccountToken" TEXT,
ADD COLUMN     "isSandboxTester" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "passwordHash" DROP NOT NULL;

UPDATE "users"
SET "appAccountToken" = gen_random_uuid()::text
WHERE "appAccountToken" IS NULL;

ALTER TABLE "users"
ALTER COLUMN "appAccountToken" SET NOT NULL,
ALTER COLUMN "appAccountToken" SET DEFAULT gen_random_uuid()::text;

-- AlterTable
ALTER TABLE "refresh_tokens" ADD COLUMN     "tokenHash" TEXT;

UPDATE "refresh_tokens"
SET "tokenHash" = encode(digest("token", 'sha256'), 'hex')
WHERE "tokenHash" IS NULL;

ALTER TABLE "refresh_tokens"
ALTER COLUMN "tokenHash" SET NOT NULL;

ALTER TABLE "refresh_tokens" DROP COLUMN "token";

-- AlterTable
ALTER TABLE "interview_sessions" ADD COLUMN     "accessSource" "AccessSource" NOT NULL DEFAULT 'TRIAL',
ADD COLUMN     "accessTier" "SubscriptionTier" NOT NULL DEFAULT 'TRIAL',
ADD COLUMN     "sessionMode" "SessionMode" NOT NULL DEFAULT 'LIVE_INTERVIEW',
ADD COLUMN     "trialInterviewNumber" INTEGER;

-- CreateTable
CREATE TABLE "user_entitlements" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tier" "SubscriptionTier" NOT NULL DEFAULT 'TRIAL',
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'TRIALING',
    "provider" "BillingProvider" NOT NULL DEFAULT 'INTERNAL',
    "product" "SubscriptionProduct" NOT NULL DEFAULT 'NONE',
    "productId" TEXT,
    "featuresOverride" JSONB,
    "trialInterviewLimit" INTEGER NOT NULL DEFAULT 5,
    "trialInterviewsUsed" INTEGER NOT NULL DEFAULT 0,
    "currentPeriodStartedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "currentPeriodEndsAt" TIMESTAMP(3),
    "gracePeriodEndsAt" TIMESTAMP(3),
    "lastPurchasedAt" TIMESTAMP(3),
    "lastVerifiedAt" TIMESTAMP(3),
    "appStoreEnvironment" "AppStoreEnvironment",
    "appStoreOriginalTransactionId" TEXT,
    "appStoreLatestTransactionId" TEXT,
    "sandboxFullAccess" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_entitlements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "billing_events" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "entitlementId" TEXT,
    "provider" "BillingProvider" NOT NULL,
    "eventType" TEXT NOT NULL,
    "product" "SubscriptionProduct",
    "productId" TEXT,
    "appStoreTransactionId" TEXT,
    "appStoreOriginalTransactionId" TEXT,
    "appStoreEnvironment" "AppStoreEnvironment",
    "effectiveAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "payload" JSONB,
    "payloadDigest" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "billing_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "session_access_grants" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "sessionClientId" TEXT NOT NULL,
    "sessionMode" "SessionMode" NOT NULL DEFAULT 'LIVE_INTERVIEW',
    "accessSource" "AccessSource" NOT NULL,
    "accessTier" "SubscriptionTier" NOT NULL,
    "featureSnapshot" JSONB,
    "consumedTrial" BOOLEAN NOT NULL DEFAULT false,
    "trialInterviewNumber" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "session_access_grants_pkey" PRIMARY KEY ("id")
);

-- Backfill existing users with a default entitlement row.
INSERT INTO "user_entitlements" (
    "id",
    "userId",
    "tier",
    "status",
    "provider",
    "product",
    "trialInterviewLimit",
    "trialInterviewsUsed",
    "currentPeriodStartedAt",
    "sandboxFullAccess",
    "createdAt",
    "updatedAt"
)
SELECT
    gen_random_uuid()::text,
    "users"."id",
    'TRIAL'::"SubscriptionTier",
    'TRIALING'::"SubscriptionStatus",
    'INTERNAL'::"BillingProvider",
    'NONE'::"SubscriptionProduct",
    5,
    0,
    CURRENT_TIMESTAMP,
    false,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM "users"
WHERE NOT EXISTS (
    SELECT 1
    FROM "user_entitlements"
    WHERE "user_entitlements"."userId" = "users"."id"
);

-- CreateIndex
CREATE UNIQUE INDEX "user_entitlements_userId_key" ON "user_entitlements"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "user_entitlements_appStoreOriginalTransactionId_key" ON "user_entitlements"("appStoreOriginalTransactionId");

-- CreateIndex
CREATE UNIQUE INDEX "user_entitlements_appStoreLatestTransactionId_key" ON "user_entitlements"("appStoreLatestTransactionId");

-- CreateIndex
CREATE INDEX "user_entitlements_status_tier_idx" ON "user_entitlements"("status", "tier");

-- CreateIndex
CREATE INDEX "billing_events_userId_createdAt_idx" ON "billing_events"("userId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "billing_events_appStoreTransactionId_idx" ON "billing_events"("appStoreTransactionId");

-- CreateIndex
CREATE INDEX "billing_events_appStoreOriginalTransactionId_idx" ON "billing_events"("appStoreOriginalTransactionId");

-- CreateIndex
CREATE UNIQUE INDEX "session_access_grants_sessionClientId_key" ON "session_access_grants"("sessionClientId");

-- CreateIndex
CREATE INDEX "session_access_grants_userId_createdAt_idx" ON "session_access_grants"("userId", "createdAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "users_appAccountToken_key" ON "users"("appAccountToken");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_tokenHash_key" ON "refresh_tokens"("tokenHash");

-- CreateIndex
CREATE INDEX "refresh_tokens_tokenHash_idx" ON "refresh_tokens"("tokenHash");

-- AddForeignKey
ALTER TABLE "user_entitlements" ADD CONSTRAINT "user_entitlements_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "billing_events" ADD CONSTRAINT "billing_events_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "billing_events" ADD CONSTRAINT "billing_events_entitlementId_fkey" FOREIGN KEY ("entitlementId") REFERENCES "user_entitlements"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_access_grants" ADD CONSTRAINT "session_access_grants_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

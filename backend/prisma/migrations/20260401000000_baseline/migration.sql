-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

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

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT,
    "displayName" TEXT,
    "avatarUrl" TEXT,
    "appAccountToken" TEXT,
    "appleId" TEXT,
    "googleId" TEXT,
    "isSandboxTester" BOOLEAN NOT NULL DEFAULT false,
    "linkedinUrl" TEXT,
    "primaryGoal" TEXT,
    "resumeFileUrl" TEXT,
    "resumeText" TEXT,
    "currentRole" TEXT,
    "currentCompany" TEXT,
    "yearsInRole" INTEGER,
    "onboardingCompleted" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "lastLoginAt" TIMESTAMP(3),
    "emailVerified" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" TEXT NOT NULL,
    "token" TEXT,
    "tokenHash" TEXT,
    "userId" TEXT NOT NULL,
    "deviceId" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

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

-- CreateTable
CREATE TABLE "user_settings" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "defaultInterviewType" TEXT NOT NULL DEFAULT 'general',
    "defaultResponseFormat" TEXT NOT NULL DEFAULT 'hybrid',
    "defaultModel" TEXT NOT NULL DEFAULT 'gpt-4.1-nano',
    "shouldPreGenerate" BOOLEAN NOT NULL DEFAULT true,
    "responseTemperature" DOUBLE PRECISION NOT NULL DEFAULT 0.7,
    "maxResponseTokens" INTEGER NOT NULL DEFAULT 800,
    "maxPreComputedQs" INTEGER NOT NULL DEFAULT 25,
    "utteranceEndMs" INTEGER NOT NULL DEFAULT 1500,
    "endpointingMs" INTEGER NOT NULL DEFAULT 500,
    "predictiveFireMinWords" INTEGER NOT NULL DEFAULT 8,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_api_keys" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "encryptedKey" TEXT NOT NULL,
    "keyIv" TEXT NOT NULL,
    "keyTag" TEXT NOT NULL,
    "keyPrefix" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_api_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "interview_sessions" (
    "id" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "sessionMode" "SessionMode" NOT NULL DEFAULT 'LIVE_INTERVIEW',
    "accessSource" "AccessSource" NOT NULL DEFAULT 'TRIAL',
    "accessTier" "SubscriptionTier" NOT NULL DEFAULT 'TRIAL',
    "trialInterviewNumber" INTEGER,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "endedAt" TIMESTAMP(3),
    "resumeText" TEXT NOT NULL,
    "jobDescription" TEXT NOT NULL,
    "interviewType" TEXT NOT NULL,
    "responseFormat" TEXT NOT NULL,
    "modelUsed" TEXT NOT NULL,
    "totalTokensUsed" INTEGER NOT NULL DEFAULT 0,
    "estimatedCost" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "telemetrySummary" JSONB,
    "technicalAccuracyScore" DOUBLE PRECISION,
    "communicationScore" DOUBLE PRECISION,
    "confidenceScore" DOUBLE PRECISION,
    "aiStrengths" JSONB,
    "aiImprovements" JSONB,
    "overallScore" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "interview_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "exchanges" (
    "id" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "questionTranscript" TEXT NOT NULL,
    "questionType" TEXT NOT NULL,
    "generatedResponse" TEXT NOT NULL,
    "responseLatencyMs" INTEGER NOT NULL,
    "wasPreComputed" BOOLEAN NOT NULL DEFAULT false,
    "telemetry" JSONB,
    "sequenceOrder" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exchanges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "answer_banks" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "resumeText" TEXT NOT NULL,
    "jobDescription" TEXT NOT NULL,
    "interviewType" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "answer_banks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pre_computed_answers" (
    "id" TEXT NOT NULL,
    "bankId" TEXT NOT NULL,
    "question" TEXT NOT NULL,
    "response" TEXT NOT NULL,
    "questionType" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pre_computed_answers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_experiences" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "company" TEXT NOT NULL,
    "startYear" INTEGER NOT NULL,
    "endYear" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "work_experiences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_skills" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_skills_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_appAccountToken_key" ON "users"("appAccountToken");

-- CreateIndex
CREATE UNIQUE INDEX "users_appleId_key" ON "users"("appleId");

-- CreateIndex
CREATE UNIQUE INDEX "users_googleId_key" ON "users"("googleId");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_key" ON "refresh_tokens"("token");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_tokenHash_key" ON "refresh_tokens"("tokenHash");

-- CreateIndex
CREATE INDEX "refresh_tokens_userId_idx" ON "refresh_tokens"("userId");

-- CreateIndex
CREATE INDEX "refresh_tokens_token_idx" ON "refresh_tokens"("token");

-- CreateIndex
CREATE INDEX "refresh_tokens_tokenHash_idx" ON "refresh_tokens"("tokenHash");

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
CREATE UNIQUE INDEX "user_settings_userId_key" ON "user_settings"("userId");

-- CreateIndex
CREATE INDEX "user_api_keys_userId_idx" ON "user_api_keys"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "user_api_keys_userId_provider_key" ON "user_api_keys"("userId", "provider");

-- CreateIndex
CREATE UNIQUE INDEX "interview_sessions_clientId_key" ON "interview_sessions"("clientId");

-- CreateIndex
CREATE INDEX "interview_sessions_userId_startedAt_idx" ON "interview_sessions"("userId", "startedAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "exchanges_clientId_key" ON "exchanges"("clientId");

-- CreateIndex
CREATE INDEX "exchanges_sessionId_sequenceOrder_idx" ON "exchanges"("sessionId", "sequenceOrder");

-- CreateIndex
CREATE INDEX "answer_banks_userId_idx" ON "answer_banks"("userId");

-- CreateIndex
CREATE INDEX "pre_computed_answers_bankId_idx" ON "pre_computed_answers"("bankId");

-- CreateIndex
CREATE INDEX "work_experiences_userId_idx" ON "work_experiences"("userId");

-- CreateIndex
CREATE INDEX "user_skills_userId_idx" ON "user_skills"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "user_skills_userId_name_key" ON "user_skills"("userId", "name");

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_entitlements" ADD CONSTRAINT "user_entitlements_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "billing_events" ADD CONSTRAINT "billing_events_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "billing_events" ADD CONSTRAINT "billing_events_entitlementId_fkey" FOREIGN KEY ("entitlementId") REFERENCES "user_entitlements"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_access_grants" ADD CONSTRAINT "session_access_grants_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_settings" ADD CONSTRAINT "user_settings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_api_keys" ADD CONSTRAINT "user_api_keys_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "interview_sessions" ADD CONSTRAINT "interview_sessions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exchanges" ADD CONSTRAINT "exchanges_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "interview_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "answer_banks" ADD CONSTRAINT "answer_banks_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pre_computed_answers" ADD CONSTRAINT "pre_computed_answers_bankId_fkey" FOREIGN KEY ("bankId") REFERENCES "answer_banks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_experiences" ADD CONSTRAINT "work_experiences_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_skills" ADD CONSTRAINT "user_skills_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


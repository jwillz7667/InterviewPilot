-- CreateTable
CREATE TABLE "app_attest_keys" (
    "id" TEXT NOT NULL,
    "keyId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "publicKey" BYTEA NOT NULL,
    "receipt" BYTEA NOT NULL,
    "signCount" BIGINT NOT NULL DEFAULT 0,
    "environment" TEXT NOT NULL,
    "attestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastUsedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),

    CONSTRAINT "app_attest_keys_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "app_attest_keys_keyId_key" ON "app_attest_keys"("keyId");

-- CreateIndex
CREATE INDEX "app_attest_keys_userId_idx" ON "app_attest_keys"("userId");

-- AddForeignKey
ALTER TABLE "app_attest_keys" ADD CONSTRAINT "app_attest_keys_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

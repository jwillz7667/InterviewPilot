-- Add session metadata to refresh tokens for the active-sessions UI.
-- userAgent is best-effort (parsed from request headers); legacy rows stay null.
-- lastUsedAt is touched on every successful rotation; backfill from createdAt.

ALTER TABLE "refresh_tokens" ADD COLUMN "userAgent" TEXT;
ALTER TABLE "refresh_tokens" ADD COLUMN "lastUsedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

UPDATE "refresh_tokens" SET "lastUsedAt" = "createdAt";

-- Compound index supports the "list active sessions for user" query
-- (WHERE userId = ? AND revokedAt IS NULL).
CREATE INDEX "refresh_tokens_userId_revokedAt_idx" ON "refresh_tokens"("userId", "revokedAt");

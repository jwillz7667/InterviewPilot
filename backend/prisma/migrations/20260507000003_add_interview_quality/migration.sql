-- InterviewQuality enum + quality columns on grants and sessions.
-- Default STANDARD so every historical row backfills cleanly without user-visible behavior change.

CREATE TYPE "InterviewQuality" AS ENUM ('STANDARD', 'PREMIUM');

ALTER TABLE "session_access_grants"
  ADD COLUMN "quality" "InterviewQuality" NOT NULL DEFAULT 'STANDARD';

ALTER TABLE "interview_sessions"
  ADD COLUMN "quality" "InterviewQuality" NOT NULL DEFAULT 'STANDARD';

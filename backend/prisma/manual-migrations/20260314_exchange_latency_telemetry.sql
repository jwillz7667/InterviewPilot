ALTER TABLE "interview_sessions"
ADD COLUMN "telemetrySummary" JSONB;

ALTER TABLE "exchanges"
ADD COLUMN "telemetry" JSONB;

-- Postgres requires enum value additions to commit before they can be referenced in DML.
-- This migration only ADDs values; the next migration consumes them in UPDATEs.

ALTER TYPE "SubscriptionTier" ADD VALUE IF NOT EXISTS 'PREMIUM';

ALTER TYPE "SubscriptionProduct" ADD VALUE IF NOT EXISTS 'PREMIUM_MONTHLY';
ALTER TYPE "SubscriptionProduct" ADD VALUE IF NOT EXISTS 'PREMIUM_YEARLY';

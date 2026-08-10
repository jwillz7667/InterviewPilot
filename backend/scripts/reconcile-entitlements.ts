#!/usr/bin/env tsx
/**
 * reconcile-entitlements.ts
 *
 * Hourly drift detector. Catches the two most common ways an entitlement gets
 * stuck in a wrong state:
 *
 *   1. Active subscription whose period ended but Apple's EXPIRED notification
 *      didn't arrive — `currentPeriodEndsAt < now() AND tier != FREE
 *      AND status NOT IN (EXPIRED, CANCELLED)`.
 *   2. Trial that should have flipped to FREE — `trialEndsAt < now()
 *      AND tier == TRIAL AND no active subscription`.
 *
 * For each drifted row, we log `billing.entitlement.drift_detected` with
 * enough context for an operator to decide whether to flip the row manually
 * or wait for the iOS client's next sync. We don't auto-flip — drift detection
 * informs alerting; corrective writes go through the existing
 * `syncAppStoreTransactions` and `processAppStoreNotification` paths.
 *
 * A future iteration will call Apple's `getAllSubscriptionStatuses` for
 * authoritative status; that needs the App Store Connect API key wired into
 * env (see docs/runbooks/storekit-notification-failure.md).
 */

import { PrismaClient } from '@prisma/client';
import pino from 'pino';

const log = pino({
  level: 'info',
  base: { service: 'interviewpilot-backend', module: 'reconcile-entitlements' },
});

function getDatabaseUrl(): string {
  const value = process.env.DATABASE_URL?.trim();
  if (!value) {
    throw new Error('DATABASE_URL is required for entitlement reconciliation');
  }

  const url = new URL(value);
  if (!url.searchParams.has('connection_limit')) {
    url.searchParams.set('connection_limit', '2');
  }
  return url.toString();
}

async function main(): Promise<void> {
  const prisma = new PrismaClient({
    datasourceUrl: getDatabaseUrl(),
    log: ['error'],
  });

  try {
    const now = new Date();

    // Drift type 1: paid sub whose period ended without an EXPIRED event.
    const expiredPaid = await prisma.userEntitlement.findMany({
      where: {
        tier: { not: 'FREE' },
        currentPeriodEndsAt: { lt: now },
        status: { notIn: ['EXPIRED', 'CANCELLED', 'REFUNDED'] },
        // Allow grace period — Apple's billing-grace window can extend the
        // legitimate access window past currentPeriodEndsAt.
        OR: [{ gracePeriodEndsAt: null }, { gracePeriodEndsAt: { lt: now } }],
      },
      select: {
        userId: true,
        tier: true,
        status: true,
        currentPeriodEndsAt: true,
        gracePeriodEndsAt: true,
        productId: true,
        appStoreOriginalTransactionId: true,
      },
    });

    // Drift type 2: trial expired but row still says TRIAL.
    const expiredTrial = await prisma.userEntitlement.findMany({
      where: {
        tier: 'TRIAL',
        trialEndsAt: { lt: now },
        status: { not: 'EXPIRED' },
      },
      select: {
        userId: true,
        tier: true,
        status: true,
        trialEndsAt: true,
      },
    });

    for (const row of expiredPaid) {
      log.warn(
        {
          event: 'billing.entitlement.drift_detected',
          kind: 'paid_period_ended_without_event',
          userId: row.userId,
          tier: row.tier,
          status: row.status,
          currentPeriodEndsAt: row.currentPeriodEndsAt,
          gracePeriodEndsAt: row.gracePeriodEndsAt,
          productId: row.productId,
          originalTransactionId: row.appStoreOriginalTransactionId,
        },
        'Paying-tier entitlement past period-end with no EXPIRED event'
      );
    }

    for (const row of expiredTrial) {
      log.warn(
        {
          event: 'billing.entitlement.drift_detected',
          kind: 'trial_ended_not_flipped',
          userId: row.userId,
          status: row.status,
          trialEndsAt: row.trialEndsAt,
        },
        'TRIAL tier past trialEndsAt with no flip to FREE'
      );
    }

    const totalPaid = await prisma.userEntitlement.count({ where: { tier: { not: 'FREE' } } });
    const summary = {
      timestamp: now.toISOString(),
      paidPeriodEnded: expiredPaid.length,
      trialEnded: expiredTrial.length,
      totalPaid,
    };
    log.info({ event: 'billing.reconciliation.done', ...summary }, 'reconciliation pass complete');
    console.log(JSON.stringify(summary, null, 2));

    // Alert threshold: > 0.5% of all paying users showing drift is suspicious.
    if (totalPaid > 0 && expiredPaid.length / totalPaid > 0.005) {
      process.exitCode = 1;
    }
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  log.error({ err }, 'reconcile-entitlements crashed');
  process.exit(2);
});

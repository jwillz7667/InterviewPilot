#!/usr/bin/env tsx
/**
 * audit-entitlements.ts
 *
 * Walks every UserEntitlement row, calls getBillingSummary, and verifies the
 * resulting state is internally consistent. Used by the monthly DR drill
 * (verifies a restored snapshot is healthy) and can be run manually against
 * any DATABASE_URL for a sanity check.
 *
 * Exits 0 on clean audit, 1 on any inconsistency. CI parses the JSON tail
 * to surface drift counts in the workflow summary.
 */

import { getPrisma, disconnectPrisma } from '../src/config/database.js';
import { loadEnv } from '../src/config/env.js';
import { getBillingSummary } from '../src/modules/billing/billing.service.js';

interface AuditFinding {
  userId: string;
  issue: string;
  detail?: Record<string, unknown>;
}

async function main(): Promise<void> {
  loadEnv();
  const prisma = getPrisma();

  // Walk all users with an entitlement row. Users without one will be created
  // lazily on first read; that's fine, we don't need to audit them.
  const entitlements = await prisma.userEntitlement.findMany({
    select: { userId: true, tier: true },
  });

  const findings: AuditFinding[] = [];
  let processed = 0;

  for (const { userId, tier } of entitlements) {
    processed += 1;
    try {
      const summary = await getBillingSummary(userId);

      if (!summary) {
        findings.push({ userId, issue: 'getBillingSummary returned null' });
        continue;
      }
      if (summary.tier !== tier.toLowerCase()) {
        findings.push({
          userId,
          issue: 'tier mismatch between row and summary',
          detail: { row: tier, summary: summary.tier },
        });
      }
      const quotas = (summary.quotas ?? {}) as Record<string, { remaining: number; limit: number }>;
      for (const [name, q] of Object.entries(quotas)) {
        if (q.remaining < 0) {
          findings.push({
            userId,
            issue: `negative remaining quota: ${name}`,
            detail: { remaining: q.remaining, limit: q.limit },
          });
        }
        if (q.limit < q.remaining) {
          findings.push({
            userId,
            issue: `remaining > limit: ${name}`,
            detail: { remaining: q.remaining, limit: q.limit },
          });
        }
      }
    } catch (err) {
      findings.push({
        userId,
        issue: 'getBillingSummary threw',
        detail: { error: err instanceof Error ? err.message : String(err) },
      });
    }
  }

  const summary = {
    timestamp: new Date().toISOString(),
    processed,
    findings: findings.length,
    sample: findings.slice(0, 25),
  };

  console.log(JSON.stringify(summary, null, 2));

  await disconnectPrisma();

  if (findings.length > 0) process.exit(1);
}

main().catch((err) => {
  console.error('audit-entitlements failed:', err);
  process.exit(2);
});

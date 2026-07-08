import { randomBytes, randomUUID } from 'node:crypto';

import { InterviewQuality, SessionMode } from '@prisma/client';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { claimInterviewAccess } from '../../../src/modules/billing/billing.service.js';
import { getTestPrisma } from '../setup.js';

// Concurrency invariant: a FREE-tier user with `standardMonthly = 3` who fires
// 20 simultaneous claims must end up with exactly 3 successful grants and 17
// PaymentRequiredErrors. Each test gets a fresh user so quota state doesn't
// leak between cases.
describe('claim-access concurrency', () => {
  const FREE_STANDARD_LIMIT = 3;
  let userId: string;

  beforeEach(async () => {
    const prisma = getTestPrisma();
    const user = await prisma.user.create({
      data: {
        email: `claim-race-${randomBytes(8).toString('hex')}@test.local`,
        passwordHash: 'unused',
        appAccountToken: randomBytes(16).toString('hex'),
      },
    });
    userId = user.id;
  });

  afterEach(async () => {
    const prisma = getTestPrisma();
    await prisma.sessionAccessGrant.deleteMany({ where: { userId } });
    await prisma.userEntitlement.deleteMany({ where: { userId } });
    await prisma.$executeRaw`DELETE FROM users WHERE id = ${userId}`;
  });

  it('grants exactly the FREE limit when 20 claims race in parallel', async () => {
    const attempts = 20;
    const sessionIds = Array.from({ length: attempts }, () => randomUUID());

    const settled = await Promise.allSettled(
      sessionIds.map((sessionClientId) =>
        claimInterviewAccess(userId, sessionClientId, SessionMode.LIVE_INTERVIEW, InterviewQuality.STANDARD)
      )
    );

    const granted = settled.filter((r) => r.status === 'fulfilled');
    const rejected = settled.filter((r) => r.status === 'rejected');

    expect(granted).toHaveLength(FREE_STANDARD_LIMIT);
    expect(rejected).toHaveLength(attempts - FREE_STANDARD_LIMIT);

    // Every rejection should be a 402 PaymentRequiredError, not a transient
    // crash. A 500 here would mean we're leaking races as server errors.
    for (const failure of rejected) {
      if (failure.status !== 'rejected') continue;
      expect((failure.reason as { statusCode?: number }).statusCode).toBe(402);
    }

    const prisma = getTestPrisma();
    const persistedGrants = await prisma.sessionAccessGrant.count({ where: { userId } });
    expect(persistedGrants).toBe(FREE_STANDARD_LIMIT);
  });

  it('returns the same grant when the same sessionClientId is replayed', async () => {
    const sessionClientId = randomUUID();

    const first = await claimInterviewAccess(userId, sessionClientId, SessionMode.LIVE_INTERVIEW, InterviewQuality.STANDARD);
    const replay = await claimInterviewAccess(userId, sessionClientId, SessionMode.LIVE_INTERVIEW, InterviewQuality.STANDARD);

    expect(replay.sessionClientId).toBe(first.sessionClientId);
    expect(replay.accessTier).toBe(first.accessTier);
    expect(replay.quality).toBe(first.quality);

    const prisma = getTestPrisma();
    const grants = await prisma.sessionAccessGrant.count({
      where: { userId, sessionClientId },
    });
    expect(grants).toBe(1);

    // Burning the remaining quota with replays should still leave exactly
    // one consumed slot — the replay must not double-decrement.
    const ent = await prisma.userEntitlement.findUnique({ where: { userId } });
    expect(ent?.monthlyStandardUsed).toBe(1);
  });

  it('rejects a quality switch on an existing grant with 409', async () => {
    const sessionClientId = randomUUID();
    await claimInterviewAccess(userId, sessionClientId, SessionMode.LIVE_INTERVIEW, InterviewQuality.STANDARD);

    await expect(
      claimInterviewAccess(userId, sessionClientId, SessionMode.LIVE_INTERVIEW, InterviewQuality.PREMIUM)
    ).rejects.toMatchObject({ statusCode: 409 });
  });
});

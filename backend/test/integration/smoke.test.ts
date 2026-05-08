import { describe, expect, it } from 'vitest';

import { getTestPrisma, getTestRedis } from './setup.js';

// Phase C starter — verifies that the integration harness boots: migrations
// applied, prisma + redis connected. Real coverage (claim-access race,
// idempotency replay, refresh-rotation) lands as Phase B endpoints merge in.
describe('integration harness', () => {
  it('connects to postgres and runs a trivial query', async () => {
    const prisma = getTestPrisma();
    const result = await prisma.$queryRaw<{ ok: number }[]>`SELECT 1 as ok`;
    expect(result[0]?.ok).toBe(1);
  });

  it('connects to redis and round-trips a key', async () => {
    const redis = getTestRedis();
    await redis.set('integration:smoke', 'ok', { EX: 30 });
    const value = await redis.get('integration:smoke');
    expect(value).toBe('ok');
    await redis.del('integration:smoke');
  });
});

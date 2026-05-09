import { randomBytes } from 'node:crypto';

import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import {
  createRefreshToken,
  listUserSessions,
  revokeRefreshToken,
  revokeUserSessions,
  rotateRefreshToken,
} from '../../../src/modules/auth/auth.service.js';
import { getTestPrisma } from '../setup.js';

describe('refresh-token rotation + revocation', () => {
  let userId: string;

  beforeEach(async () => {
    const prisma = getTestPrisma();
    const user = await prisma.user.create({
      data: {
        email: `rotation-${randomBytes(8).toString('hex')}@test.local`,
        passwordHash: 'unused',
        appAccountToken: randomBytes(16).toString('hex'),
      },
    });
    userId = user.id;
  });

  afterEach(async () => {
    const prisma = getTestPrisma();
    await prisma.refreshToken.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } });
  });

  it('marks the old token revoked and issues a new one', async () => {
    const oldToken = await createRefreshToken(userId, 'device-1', 'iPhone15,2/iOS 26.4');

    const { newToken, userId: rotatedUserId } = await rotateRefreshToken(oldToken);

    expect(rotatedUserId).toBe(userId);
    expect(newToken).not.toBe(oldToken);

    // Rotating the same old token a second time must fail — that's the
    // refresh-token reuse-detection guarantee.
    await expect(rotateRefreshToken(oldToken)).rejects.toMatchObject({ statusCode: 401 });
  });

  it('rejects rotation of a revoked token', async () => {
    const token = await createRefreshToken(userId, 'device-revoke');
    await revokeRefreshToken(token);

    await expect(rotateRefreshToken(token)).rejects.toMatchObject({ statusCode: 401 });
  });

  it('lists only active sessions and flags the current one', async () => {
    const tokenA = await createRefreshToken(userId, 'device-a', 'UA-A');
    await createRefreshToken(userId, 'device-b', 'UA-B');
    await createRefreshToken(userId, 'device-c', 'UA-C');

    const sessions = await listUserSessions(userId, tokenA);
    expect(sessions).toHaveLength(3);

    const current = sessions.filter((s) => s.current);
    expect(current).toHaveLength(1);
    expect(current[0]?.deviceId).toBe('device-a');
    expect(current[0]?.userAgent).toBe('UA-A');

    // tokenB must appear but not be marked current.
    const b = sessions.find((s) => s.deviceId === 'device-b');
    expect(b?.current).toBe(false);
  });

  it('bulk revokes all sessions except the current one', async () => {
    const keep = await createRefreshToken(userId, 'device-keep', 'UA-keep');
    await createRefreshToken(userId, 'device-other-1', 'UA-1');
    await createRefreshToken(userId, 'device-other-2', 'UA-2');

    await revokeUserSessions(userId, { exceptToken: keep });

    const sessions = await listUserSessions(userId, keep);
    expect(sessions).toHaveLength(1);
    expect(sessions[0]?.deviceId).toBe('device-keep');

    // The kept token still rotates successfully.
    const rotated = await rotateRefreshToken(keep);
    expect(rotated.userId).toBe(userId);
  });

  it('scoped revoke targets a specific deviceId only', async () => {
    const target = await createRefreshToken(userId, 'device-target', 'UA-target');
    const survivor = await createRefreshToken(userId, 'device-survivor', 'UA-survivor');

    await revokeUserSessions(userId, { deviceId: 'device-target' });

    await expect(rotateRefreshToken(target)).rejects.toMatchObject({ statusCode: 401 });
    await expect(rotateRefreshToken(survivor)).resolves.toMatchObject({ userId });
  });
});

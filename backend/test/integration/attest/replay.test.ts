import { createHash, createSign, generateKeyPairSync, randomBytes } from 'node:crypto';

import * as cbor from 'cbor-x';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { getEnv } from '../../../src/config/env.js';
import { verifyAssertion } from '../../../src/modules/attest/attest.service.js';
import type { AppError } from '../../../src/utils/errors.js';
import { getTestPrisma } from '../setup.js';

// Builds a fixture identity: a real ECDSA-P256 key pair plus a registered
// `AppAttestKey` row whose `publicKey` matches. We can't synthesise an Apple
// attestation chain locally, but the assertion-verification path operates
// entirely on the stored public key + monotonic counter, which is exactly
// what we want to lock down with replay tests.
function buildAuthData(rpIdHash: Buffer, signCount: number): Buffer {
  const buf = Buffer.alloc(37);
  rpIdHash.copy(buf, 0);
  buf[32] = 0x40; // attested flag bit irrelevant for assertions; harmless
  buf.writeUInt32BE(signCount, 33);
  return buf;
}

function makeAssertion(
  privateKeyPem: string,
  rpIdHash: Buffer,
  signCount: number,
  clientData: Buffer
): string {
  const authData = buildAuthData(rpIdHash, signCount);
  const clientDataHash = createHash('sha256').update(clientData).digest();
  const nonce = createHash('sha256').update(authData).update(clientDataHash).digest();

  // verifyAssertion uses createVerify('SHA256').update(nonce).verify(...) —
  // which hashes the nonce again with SHA-256 then verifies. We must mirror
  // that on the signing side.
  const signature = createSign('SHA256').update(nonce).sign(privateKeyPem);

  const cborBuf = cbor.encode({ signature, authenticatorData: authData });
  return Buffer.from(cborBuf).toString('base64');
}

describe('attest replay protection', () => {
  let userId: string;
  let keyId: string;
  let privateKeyPem: string;
  let rpIdHash: Buffer;

  beforeAll(async () => {
    const prisma = getTestPrisma();
    const env = getEnv();
    rpIdHash = createHash('sha256')
      .update(`${env.APP_ATTEST_TEAM_ID}.${env.APP_ATTEST_BUNDLE_ID}`)
      .digest();

    // Disposable test user. argon2 hash isn't relevant; we never authenticate.
    const user = await prisma.user.create({
      data: {
        email: `attest-replay-${randomBytes(6).toString('hex')}@test.local`,
        passwordHash: 'unused-for-this-test',
        appAccountToken: randomBytes(16).toString('hex'),
      },
    });
    userId = user.id;

    const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    privateKeyPem = privateKey.export({ type: 'pkcs8', format: 'pem' }) as string;
    const publicKeyDer = publicKey.export({ type: 'spki', format: 'der' });

    keyId = `replay-test-${randomBytes(8).toString('hex')}`;
    await prisma.appAttestKey.create({
      data: {
        keyId,
        userId,
        publicKey: new Uint8Array(publicKeyDer),
        receipt: new Uint8Array(0),
        signCount: BigInt(0),
        environment: 'appattestdevelop',
      },
    });
  });

  afterAll(async () => {
    const prisma = getTestPrisma();
    await prisma.appAttestKey.deleteMany({ where: { userId } });
    await prisma.$executeRaw`DELETE FROM users WHERE id = ${userId}`;
  });

  it('accepts an assertion with counter > stored counter', async () => {
    const clientData = Buffer.from('POST|/api/v1/billing/access-claims|nonce-1|hash-1');

    await expect(
      verifyAssertion({
        keyId,
        userId,
        clientData,
        assertionBase64: makeAssertion(privateKeyPem, rpIdHash, 1, clientData),
      })
    ).resolves.toBeUndefined();

    const prisma = getTestPrisma();
    const stored = await prisma.appAttestKey.findUnique({ where: { keyId } });
    expect(stored?.signCount).toBe(BigInt(1));
  });

  it('rejects a replay with the same counter (ATTEST_COUNTER_REPLAY)', async () => {
    const clientData = Buffer.from('POST|/api/v1/billing/access-claims|nonce-1-replay|hash');

    // Counter is now 1 in the DB. Re-using counter=1 must fail.
    await expect(
      verifyAssertion({
        keyId,
        userId,
        clientData,
        assertionBase64: makeAssertion(privateKeyPem, rpIdHash, 1, clientData),
      })
    ).rejects.toMatchObject({
      statusCode: 401,
      code: 'ATTEST_COUNTER_REPLAY',
    } satisfies Partial<AppError>);
  });

  it('rejects a counter that goes backwards', async () => {
    const clientData = Buffer.from('POST|/api/v1/ai/chat|nonce-back|hash');

    await expect(
      verifyAssertion({
        keyId,
        userId,
        clientData,
        assertionBase64: makeAssertion(privateKeyPem, rpIdHash, 0, clientData),
      })
    ).rejects.toMatchObject({ statusCode: 401, code: 'ATTEST_COUNTER_REPLAY' });
  });

  it('accepts the next strictly-monotonic counter and updates the row', async () => {
    const clientData = Buffer.from('POST|/api/v1/billing/access-claims|nonce-2|hash-2');

    await expect(
      verifyAssertion({
        keyId,
        userId,
        clientData,
        assertionBase64: makeAssertion(privateKeyPem, rpIdHash, 2, clientData),
      })
    ).resolves.toBeUndefined();

    const prisma = getTestPrisma();
    const stored = await prisma.appAttestKey.findUnique({ where: { keyId } });
    expect(stored?.signCount).toBe(BigInt(2));
  });

  it('rejects when signature does not match the stored public key', async () => {
    const clientData = Buffer.from('POST|/api/v1/billing/access-claims|nonce-bad|hash');
    const { privateKey: otherPrivate } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    const wrongKeyPem = otherPrivate.export({ type: 'pkcs8', format: 'pem' }) as string;

    await expect(
      verifyAssertion({
        keyId,
        userId,
        clientData,
        assertionBase64: makeAssertion(wrongKeyPem, rpIdHash, 3, clientData),
      })
    ).rejects.toMatchObject({ statusCode: 401, code: 'ATTEST_SIGNATURE_INVALID' });
  });

  it('rejects when keyId is bound to a different user', async () => {
    const prisma = getTestPrisma();
    const otherUser = await prisma.user.create({
      data: {
        email: `attest-other-${randomBytes(6).toString('hex')}@test.local`,
        passwordHash: 'unused',
        appAccountToken: randomBytes(16).toString('hex'),
      },
    });

    try {
      const clientData = Buffer.from('POST|/api/v1/billing/access-claims|nonce-x|hash');
      await expect(
        verifyAssertion({
          keyId,
          userId: otherUser.id,
          clientData,
          assertionBase64: makeAssertion(privateKeyPem, rpIdHash, 99, clientData),
        })
      ).rejects.toMatchObject({ statusCode: 401, code: 'ATTEST_KEY_MISMATCH' });
    } finally {
      await prisma.$executeRaw`DELETE FROM users WHERE id = ${otherUser.id}`;
    }
  });
});

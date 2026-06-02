import { randomBytes, timingSafeEqual } from 'node:crypto';

import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';

import { getRedis } from '../../config/redis.js';
import { authenticate } from '../../middleware/authenticate.js';

import { registerAttestation } from './attest.service.js';

// Challenges are single-use, short-lived nonces. Redis is the canonical store so
// the issue→consume handshake survives across horizontally-scaled instances and
// restarts; the in-memory Map is only a fallback for local/dev (no REDIS_URL).
const challengeStore = new Map<string, { challenge: Buffer; expiresAt: number }>();
const CHALLENGE_TTL_MS = 5 * 60 * 1000;
const CHALLENGE_TTL_SECONDS = CHALLENGE_TTL_MS / 1000;

function challengeRedisKey(userId: string): string {
  return `attest:challenge:${userId}`;
}

function constantTimeEqualBase64(a: string, b: string): boolean {
  const left = Buffer.from(a, 'base64');
  const right = Buffer.from(b, 'base64');
  if (left.length === 0 || left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

async function newChallenge(userId: string): Promise<string> {
  const challenge = randomBytes(32);
  const challengeBase64 = challenge.toString('base64');

  const redis = await getRedis();
  if (redis) {
    try {
      await redis.set(challengeRedisKey(userId), challengeBase64, { EX: CHALLENGE_TTL_SECONDS });
      return challengeBase64;
    } catch {
      // Redis dropped between readiness check and write — fall back to memory so
      // challenge issuance never 500s. (Single-instance fallback only.)
    }
  }
  challengeStore.set(userId, { challenge, expiresAt: Date.now() + CHALLENGE_TTL_MS });
  return challengeBase64;
}

async function consumeChallenge(userId: string, challengeBase64: string): Promise<boolean> {
  const redis = await getRedis();
  if (redis) {
    try {
      // GETDEL makes consume atomic: a challenge can never be redeemed twice even
      // under concurrent register calls.
      const stored = await redis.getDel(challengeRedisKey(userId));
      if (!stored) return false;
      return constantTimeEqualBase64(stored, challengeBase64);
    } catch {
      // Redis dropped mid-flight — fall back to the in-memory store rather than
      // erroring the register call.
    }
  }

  const record = challengeStore.get(userId);
  if (!record) return false;
  challengeStore.delete(userId);
  if (record.expiresAt < Date.now()) return false;
  return constantTimeEqualBase64(record.challenge.toString('base64'), challengeBase64);
}

const registerSchema = z.object({
  keyId: z.string().min(1),
  attestation: z.string().min(1),
  challenge: z.string().min(1),
});

export async function attestRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('onRequest', authenticate);

  app.post('/api/v1/attest/challenge', async (request: FastifyRequest, reply: FastifyReply) => {
    const challenge = await newChallenge(request.user.sub);
    reply.send({ challenge });
  });

  app.post('/api/v1/attest/register', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = registerSchema.parse(request.body);
    if (!(await consumeChallenge(request.user.sub, body.challenge))) {
      return reply.status(401).send({
        error: 'ATTEST_CHALLENGE_INVALID',
        message: 'Challenge missing, expired, or mismatched',
      });
    }
    await registerAttestation({
      userId: request.user.sub,
      keyId: body.keyId,
      attestationBase64: body.attestation,
      challengeBase64: body.challenge,
    });
    reply.send({ ok: true });
  });
}

import { randomBytes } from 'node:crypto';

import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';

import { authenticate } from '../../middleware/authenticate.js';

import { registerAttestation } from './attest.service.js';

const challengeStore = new Map<string, { challenge: Buffer; expiresAt: number }>();
const CHALLENGE_TTL_MS = 5 * 60 * 1000;

function newChallenge(userId: string): string {
  const challenge = randomBytes(32);
  challengeStore.set(userId, { challenge, expiresAt: Date.now() + CHALLENGE_TTL_MS });
  return challenge.toString('base64');
}

function consumeChallenge(userId: string, challengeBase64: string): boolean {
  const record = challengeStore.get(userId);
  if (!record) return false;
  challengeStore.delete(userId);
  if (record.expiresAt < Date.now()) return false;
  return record.challenge.equals(Buffer.from(challengeBase64, 'base64'));
}

const registerSchema = z.object({
  keyId: z.string().min(1),
  attestation: z.string().min(1),
  challenge: z.string().min(1),
});

export async function attestRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('onRequest', authenticate);

  app.post('/api/v1/attest/challenge', async (request: FastifyRequest, reply: FastifyReply) => {
    const challenge = newChallenge(request.user.sub);
    reply.send({ challenge });
  });

  app.post('/api/v1/attest/register', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = registerSchema.parse(request.body);
    if (!consumeChallenge(request.user.sub, body.challenge)) {
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

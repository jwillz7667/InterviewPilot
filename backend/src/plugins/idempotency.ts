import { createHash } from 'node:crypto';

import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';

import { getRedis } from '../config/redis.js';

const TTL_SECONDS = 24 * 60 * 60;
const HEADER = 'idempotency-key';
const KEY_REGEX = /^[A-Za-z0-9_\-:.]{8,128}$/;

type CachedResponse = {
  status: number;
  body: unknown;
  requestHash: string;
};

function redisKey(userId: string, key: string): string {
  return `idem:${userId}:${key}`;
}

function hashRequest(method: string, url: string, body: unknown): string {
  const payload = JSON.stringify({ method, url, body: body ?? null });
  return createHash('sha256').update(payload).digest('hex');
}

declare module 'fastify' {
  interface FastifyContextConfig {
    idempotent?: boolean;
  }
  interface FastifyRequest {
    idempotencyKey?: string;
  }
}

async function registerIdempotencyHooks(app: FastifyInstance) {
  app.addHook('preHandler', async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.routeOptions?.config?.idempotent) return;

    // Idempotency requires an authenticated user — keys are scoped per-user
    // to prevent cross-tenant collisions.
    const userId = request.user?.sub;
    if (!userId) return;

    const rawKey = request.headers[HEADER];
    if (!rawKey) return;
    if (Array.isArray(rawKey)) {
      reply.status(400).send({
        error: 'INVALID_IDEMPOTENCY_KEY',
        message: 'Idempotency-Key header must appear at most once',
      });
      return;
    }
    if (!KEY_REGEX.test(rawKey)) {
      reply.status(400).send({
        error: 'INVALID_IDEMPOTENCY_KEY',
        message: 'Idempotency-Key must be 8–128 chars of [A-Za-z0-9_-:.]',
      });
      return;
    }

    const redis = await getRedis();
    if (!redis) return; // No Redis — degrade open; per-process retries lose idempotency.

    const requestHash = hashRequest(request.method, request.url, request.body);
    const cacheKey = redisKey(userId, rawKey);
    let cached: string | null;
    try {
      cached = await redis.get(cacheKey);
    } catch {
      return; // Redis dropped mid-flight — degrade open, process the request normally.
    }

    if (cached) {
      try {
        const parsed = JSON.parse(cached) as CachedResponse;
        if (parsed.requestHash !== requestHash) {
          reply.status(422).send({
            error: 'IDEMPOTENCY_KEY_REUSED',
            message:
              'This Idempotency-Key was previously used with a different request body. Use a new key.',
          });
          return;
        }
        reply.header('idempotent-replay', 'true').status(parsed.status).send(parsed.body);
        return;
      } catch {
        // Corrupted entry — fall through and treat as fresh.
      }
    }

    request.idempotencyKey = rawKey;
  });

  app.addHook('onSend', async (request, reply, payload) => {
    const key = request.idempotencyKey;
    if (!key) return payload;
    const userId = request.user?.sub;
    if (!userId) return payload;

    // Only cache success responses. Errors should be retryable with the same key.
    if (reply.statusCode >= 400) return payload;

    const redis = await getRedis();
    if (!redis) return payload;

    const requestHash = hashRequest(request.method, request.url, request.body);
    let bodyToCache: unknown = payload;
    if (typeof payload === 'string') {
      try {
        bodyToCache = JSON.parse(payload);
      } catch {
        // Non-JSON payload — store the raw string.
      }
    }

    const entry: CachedResponse = {
      status: reply.statusCode,
      body: bodyToCache,
      requestHash,
    };

    try {
      await redis.set(redisKey(userId, key), JSON.stringify(entry), { EX: TTL_SECONDS });
    } catch {
      // Caching the response is best-effort; a Redis drop here must not fail the
      // already-successful response.
    }
    return payload;
  });
}

// Hooks must escape Fastify's registration scope so they protect sibling route
// plugins in production. Without fastify-plugin, registering this plugin on the
// root app creates an encapsulated child scope and no application route sees it.
export const idempotencyPlugin = fp(registerIdempotencyHooks, {
  name: 'idempotency',
});

export default idempotencyPlugin;

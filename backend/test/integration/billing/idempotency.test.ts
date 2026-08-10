import { randomBytes } from 'node:crypto';

import Fastify, { type FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { disconnectRedis, getRedis } from '../../../src/config/redis.js';
import { idempotencyPlugin } from '../../../src/plugins/idempotency.js';
import { getTestRedis } from '../setup.js';

// Mirror the production augmentation (`@fastify/jwt` declares `user` on
// FastifyRequest in src/middleware/authenticate.ts). Tests don't import that
// file, so we redeclare the same shape here.
declare module 'fastify' {
  interface FastifyRequest {
    user?: { sub: string; email: string };
  }
}

// Verifies the idempotency plugin contract end-to-end by mounting a real
// Fastify app, a fake auth hook (sets request.user), and a counter route
// flagged `idempotent: true`. We can't reuse the prod billing handler here
// because that would require a full DB + entitlement setup; the plugin
// itself is the unit under test.
describe('idempotency plugin', () => {
  let app: FastifyInstance;
  const userId = `idem-test-${randomBytes(6).toString('hex')}`;
  let counter = 0;

  beforeAll(async () => {
    // Production intentionally connects Redis in the background. Warm that
    // singleton before exercising the strong idempotency contract so the test
    // does not assert against the documented cold-start fail-open path.
    const deadline = Date.now() + 5_000;
    while (!(await getRedis())) {
      if (Date.now() >= deadline) throw new Error('Runtime Redis client did not become ready');
      await new Promise((resolve) => setTimeout(resolve, 25));
    }

    app = Fastify();

    app.addHook('onRequest', async (request) => {
      // Fake auth — every test request is "logged in" as the same user.
      request.user = { sub: userId, email: 'idem@test.local' };
    });

    await app.register(idempotencyPlugin);

    app.post('/test/increment', { config: { idempotent: true } }, async (request) => {
      counter += 1;
      const body = request.body as { input?: string } | undefined;
      return { count: counter, echo: body?.input ?? null };
    });

    await app.ready();
  });

  afterAll(async () => {
    const redis = getTestRedis();
    const keys = await redis.keys(`idem:${userId}:*`);
    if (keys.length > 0) await redis.del(keys);
    await app.close();
    await disconnectRedis();
  });

  it('executes the handler once and replays the cached response on retry', async () => {
    const key = `key-${randomBytes(8).toString('hex')}`;
    const before = counter;

    const first = await app.inject({
      method: 'POST',
      url: '/test/increment',
      headers: { 'idempotency-key': key, 'content-type': 'application/json' },
      payload: { input: 'alpha' },
    });
    expect(first.statusCode).toBe(200);
    expect(first.headers['idempotent-replay']).toBeUndefined();
    const firstBody = first.json();
    expect(firstBody.count).toBe(before + 1);

    const second = await app.inject({
      method: 'POST',
      url: '/test/increment',
      headers: { 'idempotency-key': key, 'content-type': 'application/json' },
      payload: { input: 'alpha' },
    });
    expect(second.statusCode).toBe(200);
    expect(second.headers['idempotent-replay']).toBe('true');
    expect(second.json()).toEqual(firstBody);
    expect(counter).toBe(before + 1); // handler NOT re-run
  });

  it('rejects the same key with a mutated body (422 IDEMPOTENCY_KEY_REUSED)', async () => {
    const key = `key-${randomBytes(8).toString('hex')}`;

    const first = await app.inject({
      method: 'POST',
      url: '/test/increment',
      headers: { 'idempotency-key': key, 'content-type': 'application/json' },
      payload: { input: 'first' },
    });
    expect(first.statusCode).toBe(200);

    const mutated = await app.inject({
      method: 'POST',
      url: '/test/increment',
      headers: { 'idempotency-key': key, 'content-type': 'application/json' },
      payload: { input: 'changed' },
    });
    expect(mutated.statusCode).toBe(422);
    expect(mutated.json().error).toBe('IDEMPOTENCY_KEY_REUSED');
  });

  it('treats a different key as a fresh request', async () => {
    const before = counter;

    await app.inject({
      method: 'POST',
      url: '/test/increment',
      headers: { 'idempotency-key': `a-${randomBytes(6).toString('hex')}` },
      payload: { input: 'one' },
    });
    await app.inject({
      method: 'POST',
      url: '/test/increment',
      headers: { 'idempotency-key': `b-${randomBytes(6).toString('hex')}` },
      payload: { input: 'two' },
    });

    expect(counter).toBe(before + 2);
  });

  it('rejects malformed keys with 400', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/test/increment',
      headers: { 'idempotency-key': 'too-short' }, // 9 chars but contains hyphen — pattern allows
      payload: {},
    });
    // Pattern requires 8–128 chars of [A-Za-z0-9_-:.]; "too-short" passes.
    // Test an actually-bad key:
    expect(res.statusCode).toBe(200);

    const bad = await app.inject({
      method: 'POST',
      url: '/test/increment',
      headers: { 'idempotency-key': 'has spaces!' },
      payload: {},
    });
    expect(bad.statusCode).toBe(400);
    expect(bad.json().error).toBe('INVALID_IDEMPOTENCY_KEY');
  });
});

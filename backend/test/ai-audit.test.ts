import { describe, expect, it, vi, beforeEach } from 'vitest';
import { ZodError } from 'zod';
import Fastify, { FastifyInstance } from 'fastify';

const { warnSpy } = vi.hoisted(() => ({ warnSpy: vi.fn() }));

vi.mock('../src/utils/logger.js', () => ({
  getLogger: () => ({
    child: () => ({
      warn: warnSpy,
      info: vi.fn(),
      debug: vi.fn(),
      error: vi.fn(),
    }),
  }),
}));

const { auditUnknownKeys, parseOrAudit, FORBIDDEN_CLIENT_FIELDS } = await import(
  '../src/modules/ai/ai.audit.js'
);
const { chatSchema } = await import('../src/modules/ai/ai.schema.js');

const validBody = {
  sessionClientId: '550e8400-e29b-41d4-a716-446655440000',
  routing: 'default' as const,
  messages: [{ role: 'user' as const, content: 'Tell me about yourself.' }],
};

const fakeReq = (overrides: Partial<{ userId: string; ip: string; url: string }> = {}) => ({
  user: { sub: overrides.userId ?? 'user-test-123' },
  ip: overrides.ip ?? '203.0.113.42',
  url: overrides.url ?? '/api/v1/ai/chat',
}) as unknown as Parameters<typeof parseOrAudit>[2];

describe('FORBIDDEN_CLIENT_FIELDS', () => {
  it('contains the security-critical engine-control fields', () => {
    expect(FORBIDDEN_CLIENT_FIELDS.has('model')).toBe(true);
    expect(FORBIDDEN_CLIENT_FIELDS.has('max_tokens')).toBe(true);
    expect(FORBIDDEN_CLIENT_FIELDS.has('max_output_tokens')).toBe(true);
  });
});

describe('auditUnknownKeys()', () => {
  beforeEach(() => {
    warnSpy.mockReset();
  });

  it('emits ai.client.model.rejected when ZodError contains a forbidden `model` key', () => {
    const result = chatSchema.safeParse({ ...validBody, model: 'o4-mini' });
    expect(result.success).toBe(false);
    if (result.success) return;

    auditUnknownKeys({ userId: 'user-1', ip: '1.2.3.4', path: '/api/v1/ai/chat' }, result.error);

    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        event: 'ai.client.model.rejected',
        userId: 'user-1',
        ip: '1.2.3.4',
        keys: ['model'],
        path: '/api/v1/ai/chat',
      }),
      expect.any(String)
    );
  });

  it('emits the event when a client tries to override max_tokens', () => {
    const result = chatSchema.safeParse({ ...validBody, max_tokens: 4000 });
    if (result.success) throw new Error('expected schema rejection');

    auditUnknownKeys({ userId: 'u2', ip: '5.6.7.8' }, result.error);

    expect(warnSpy).toHaveBeenCalledTimes(1);
    const callArgs = warnSpy.mock.calls[0][0];
    expect(callArgs.event).toBe('ai.client.model.rejected');
    expect(callArgs.keys).toContain('max_tokens');
  });

  it('does NOT emit the event when the rejection is for a non-security key (e.g. typo)', () => {
    const result = chatSchema.safeParse({ ...validBody, ranndom_key: 'noise' });
    if (result.success) throw new Error('expected schema rejection');

    auditUnknownKeys({ userId: 'u3' }, result.error);

    expect(warnSpy).not.toHaveBeenCalled();
  });

  it('does NOT emit on a non-unrecognized_keys error (e.g. wrong type)', () => {
    const result = chatSchema.safeParse({ ...validBody, sessionClientId: 'not-a-uuid' });
    if (result.success) throw new Error('expected schema rejection');

    auditUnknownKeys({ userId: 'u4' }, result.error);

    expect(warnSpy).not.toHaveBeenCalled();
  });

  it('reports BOTH `model` and `max_tokens` in a single payload when the client sends both', () => {
    const result = chatSchema.safeParse({
      ...validBody,
      model: 'gpt-4.1',
      max_tokens: 999,
    });
    if (result.success) throw new Error('expected schema rejection');

    auditUnknownKeys({ userId: 'u5' }, result.error);

    expect(warnSpy).toHaveBeenCalledTimes(1);
    const reported = warnSpy.mock.calls[0][0].keys as string[];
    expect(reported).toContain('model');
    expect(reported).toContain('max_tokens');
  });
});

describe('parseOrAudit() — full security flow', () => {
  beforeEach(() => {
    warnSpy.mockReset();
  });

  it('returns parsed data on a clean payload, no audit warning', () => {
    const result = parseOrAudit(chatSchema, validBody, fakeReq());
    expect(result.sessionClientId).toBe(validBody.sessionClientId);
    expect(warnSpy).not.toHaveBeenCalled();
  });

  it('throws ZodError on a model-injection attempt AND emits the audit log', () => {
    expect(() => {
      parseOrAudit(
        chatSchema,
        { ...validBody, model: 'o4-mini' },
        fakeReq({ userId: 'attacker-7', ip: '198.51.100.99' })
      );
    }).toThrow(ZodError);

    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy.mock.calls[0][0]).toMatchObject({
      event: 'ai.client.model.rejected',
      userId: 'attacker-7',
      ip: '198.51.100.99',
      keys: ['model'],
    });
  });
});

// ---------------------------------------------------------------------------
// Fastify-inject integration test: verifies the audit log fires through the
// real HTTP routing layer when a client POSTs `model` to /api/v1/ai/chat.
// We mount a minimal Fastify app with the same ZodError → 422 handler used in
// production (src/index.ts:131) and a fake auth hook so we don't need JWT/DB.
// The route body matches ai.routes.ts:104 — `parseOrAudit(chatSchema, body, req)`.
// ---------------------------------------------------------------------------
describe('parseOrAudit() — Fastify HTTP integration', () => {
  let app: FastifyInstance;

  beforeEach(async () => {
    warnSpy.mockReset();
    app = Fastify({ logger: false });

    app.addHook('onRequest', async (req) => {
      (req as unknown as { user: { sub: string } }).user = { sub: 'integration-user-42' };
    });

    app.setErrorHandler((error, _request, reply) => {
      if (error instanceof ZodError) {
        return reply.status(422).send({
          error: 'VALIDATION_ERROR',
          details: error.errors.map((e) => ({ field: e.path.join('.'), message: e.message })),
        });
      }
      return reply.status(500).send({ error: 'INTERNAL', message: error.message });
    });

    app.post('/api/v1/ai/chat', async (request, reply) => {
      const input = parseOrAudit(chatSchema, request.body, request);
      reply.send({ ok: true, sessionClientId: input.sessionClientId });
    });

    await app.ready();
  });

  it('returns 200 for a clean payload, no audit warning', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/ai/chat',
      payload: validBody,
    });

    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ ok: true, sessionClientId: validBody.sessionClientId });
    expect(warnSpy).not.toHaveBeenCalled();
  });

  it('returns 422 AND emits ai.client.model.rejected when client injects `model`', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/ai/chat',
      payload: { ...validBody, model: 'o4-mini' },
      remoteAddress: '198.51.100.99',
    });

    expect(res.statusCode).toBe(422);
    expect(res.json().error).toBe('VALIDATION_ERROR');

    expect(warnSpy).toHaveBeenCalledTimes(1);
    const logged = warnSpy.mock.calls[0][0];
    expect(logged.event).toBe('ai.client.model.rejected');
    expect(logged.userId).toBe('integration-user-42');
    expect(logged.keys).toContain('model');
    expect(logged.path).toBe('/api/v1/ai/chat');
  });

  it('returns 422 AND audits when client injects max_output_tokens', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/ai/chat',
      payload: { ...validBody, max_output_tokens: 8000 },
    });

    expect(res.statusCode).toBe(422);
    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy.mock.calls[0][0].keys).toContain('max_output_tokens');
  });
});

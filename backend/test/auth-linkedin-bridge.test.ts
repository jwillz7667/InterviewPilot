import rateLimit from '@fastify/rate-limit';
import Fastify, { type FastifyInstance } from 'fastify';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

vi.mock('../src/config/env.js', () => ({
  getEnv: () => ({
    LINKEDIN_NATIVE_CALLBACK_URI: 'com.res.jobhopperAI://oauth/linkedin/callback',
  }),
}));

vi.mock('../src/utils/logger.js', () => ({
  getLogger: () => ({
    child: () => ({ info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() }),
  }),
}));

vi.mock('../src/middleware/authenticate.js', () => ({
  authenticate: vi.fn(),
}));

vi.mock('../src/modules/auth/auth.controller.js', () => ({
  buildAuthHandlers: () => ({
    register: vi.fn(),
    login: vi.fn(),
    apple: vi.fn(),
    linkedin: vi.fn(),
    refresh: vi.fn(),
    logout: vi.fn(),
  }),
}));

vi.mock('../src/modules/auth/password-reset.service.js', () => ({
  requestPasswordReset: vi.fn(),
  resetPassword: vi.fn(),
}));

vi.mock('../src/modules/auth/auth.service.js', () => ({
  listUserSessions: vi.fn(),
  revokeUserSessions: vi.fn(),
}));

const { authRoutes } = await import('../src/modules/auth/auth.routes.js');

let app: FastifyInstance;

beforeEach(async () => {
  app = Fastify();
  await app.register(rateLimit, { max: 100, timeWindow: '1 minute' });
  await app.register(authRoutes);
  await app.ready();
});

afterEach(async () => {
  await app.close();
});

describe('GET /auth/linkedin/callback (LinkedIn OAuth bridge)', () => {
  it('302s to native scheme with code + state', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/linkedin/callback?code=abc123&state=xyz789',
    });

    expect(response.statusCode).toBe(302);
    const location = response.headers.location;
    expect(location).toBe('com.res.jobhopperAI://oauth/linkedin/callback?code=abc123&state=xyz789');
  });

  it('forwards LinkedIn error params instead of code', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/linkedin/callback?error=access_denied&error_description=user_canceled',
    });

    expect(response.statusCode).toBe(302);
    expect(response.headers.location).toContain('error=access_denied');
    expect(response.headers.location).toContain('error_description=user_canceled');
  });

  it('drops unrecognized query params (anti-injection)', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/linkedin/callback?code=abc&state=xyz&evil=javascript:alert(1)&extra=foo',
    });

    expect(response.statusCode).toBe(302);
    const location = response.headers.location ?? '';
    expect(location).not.toContain('evil=');
    expect(location).not.toContain('extra=');
    expect(location).toContain('code=abc');
    expect(location).toContain('state=xyz');
  });

  it('rejects bare hits (no code, no error) with HTML 400', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/linkedin/callback',
    });

    expect(response.statusCode).toBe(400);
    expect(response.headers['content-type']).toContain('text/html');
    expect(response.body).toContain('Sign in with LinkedIn');
  });

  it('drops oversize param values (defense-in-depth)', async () => {
    const huge = 'x'.repeat(3000);
    const response = await app.inject({
      method: 'GET',
      url: `/auth/linkedin/callback?code=ok&state=${huge}`,
    });

    expect(response.statusCode).toBe(302);
    const location = response.headers.location ?? '';
    expect(location).toContain('code=ok');
    // state was too long; got dropped from forwarded params
    expect(location).not.toContain('state=');
  });

  it('encodes special characters safely', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/linkedin/callback?code=a%20b%26c&state=x%2By',
    });

    expect(response.statusCode).toBe(302);
    const location = response.headers.location ?? '';
    // URLSearchParams re-encodes — '+' becomes %2B, space stays %20 or +
    expect(location).toMatch(/code=a(%20|\+)b%26c/);
    expect(location).toContain('state=x%2By');
  });
});

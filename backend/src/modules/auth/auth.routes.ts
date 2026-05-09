import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import { getEnv } from '../../config/env.js';
import { authenticate } from '../../middleware/authenticate.js';
import { getLogger } from '../../utils/logger.js';

import { buildAuthHandlers } from './auth.controller.js';
import {
  forgotPasswordSchema,
  listSessionsSchema,
  resetPasswordSchema,
  revokeSessionsSchema,
} from './auth.schema.js';
import { listUserSessions, revokeUserSessions } from './auth.service.js';
import { requestPasswordReset, resetPassword } from './password-reset.service.js';

// LinkedIn rejects custom URL schemes in OAuth redirect URIs, so the iOS app
// registers an HTTPS bridge URL with LinkedIn instead. After LinkedIn redirects
// back here with `code`/`state`, this handler 302s to the native scheme so
// ASWebAuthenticationSession can capture it and return control to iOS.
const BRIDGE_ALLOWED_PARAMS = ['code', 'state', 'error', 'error_description', 'scope'] as const;
const BRIDGE_PARAM_MAX_LENGTH = 2048;

const AUTH_BODY_LIMIT = 4 * 1024;

export async function authRoutes(app: FastifyInstance) {
  const { register, login, apple, linkedin, refresh, logout } = buildAuthHandlers(app);
  const authRouteOptions = {
    bodyLimit: AUTH_BODY_LIMIT,
    config: {
      rateLimit: {
        max: 10,
        timeWindow: '1 minute',
      },
    },
  } as const;
  // /auth/logout is reachable from authenticated clients on logout — same body
  // shape as refresh, so reuse the same tight limit but allow the higher
  // (default 100/min) global rate limit since users may sign out repeatedly
  // when switching accounts on shared devices.
  const logoutOptions = { bodyLimit: AUTH_BODY_LIMIT } as const;

  app.post('/api/v1/auth/register', authRouteOptions, register);
  app.post('/api/v1/auth/login', authRouteOptions, login);
  app.post('/api/v1/auth/apple', authRouteOptions, apple);
  app.post('/api/v1/auth/linkedin', authRouteOptions, linkedin);
  app.post('/api/v1/auth/refresh', authRouteOptions, refresh);
  app.post('/api/v1/auth/logout', logoutOptions, logout);

  // LinkedIn OAuth redirect bridge. Public, GET-only, never reads/writes
  // session state — purely a 302 forwarder. Heavily rate-limited because it
  // is a public endpoint that synthesizes a redirect URL from query input.
  app.get(
    '/auth/linkedin/callback',
    {
      config: {
        rateLimit: {
          max: 30,
          timeWindow: '1 minute',
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const env = getEnv();
      const log = getLogger().child({ module: 'auth-linkedin-bridge' });
      const query = request.query as Record<string, unknown>;
      const params = new URLSearchParams();

      for (const key of BRIDGE_ALLOWED_PARAMS) {
        const value = query[key];
        if (typeof value === 'string' && value.length > 0 && value.length <= BRIDGE_PARAM_MAX_LENGTH) {
          params.set(key, value);
        }
      }

      // Refuse to redirect when LinkedIn returned no code/error — likely a
      // direct browser hit. Render a tiny HTML page instead so users aren't
      // dropped into a broken-looking 302 chain.
      if (!params.has('code') && !params.has('error')) {
        log.info({ event: 'linkedin.bridge.empty' }, 'LinkedIn bridge hit without code/error');
        return reply
          .code(400)
          .type('text/html; charset=utf-8')
          .send(
            '<!doctype html><meta charset="utf-8"><title>Sign in with LinkedIn</title>' +
              '<body style="font-family:-apple-system,system-ui,sans-serif;padding:32px;text-align:center;color:#333">' +
              '<h1>Sign in with LinkedIn</h1>' +
              '<p>This page is reached from the Interview Ace iOS app during LinkedIn sign-in. ' +
              'Open the app to continue.</p></body>'
          );
      }

      const native = env.LINKEDIN_NATIVE_CALLBACK_URI;
      const separator = native.includes('?') ? '&' : '?';
      const target = `${native}${separator}${params.toString()}`;

      log.info(
        {
          event: 'linkedin.bridge.redirect',
          hasCode: params.has('code'),
          hasError: params.has('error'),
        },
        'LinkedIn bridge forwarding to native callback'
      );
      return reply.redirect(target, 302);
    }
  );

  app.post('/api/v1/auth/forgot-password', authRouteOptions, async (request, reply) => {
    const { email } = forgotPasswordSchema.parse(request.body);
    await requestPasswordReset(email);
    // Always return success to prevent email enumeration
    reply.send({ message: 'If an account exists, a password reset email has been sent.' });
  });

  app.post('/api/v1/auth/reset-password', authRouteOptions, async (request, reply) => {
    const { token, password } = resetPasswordSchema.parse(request.body);
    await resetPassword(token, password);
    reply.send({ message: 'Password has been reset successfully.' });
  });

  await app.register(async function protectedAuthRoutes(protectedApp) {
    protectedApp.addHook('onRequest', authenticate);

    protectedApp.post(
      '/api/v1/auth/sessions/list',
      { bodyLimit: AUTH_BODY_LIMIT },
      async (request: FastifyRequest, reply: FastifyReply) => {
        const { refreshToken } = listSessionsSchema.parse(request.body ?? {});
        const sessions = await listUserSessions(request.user.sub, refreshToken);
        reply.send({ sessions });
      }
    );

    protectedApp.post(
      '/api/v1/auth/sessions/revoke',
      { bodyLimit: AUTH_BODY_LIMIT, config: { idempotent: true } },
      async (request: FastifyRequest, reply: FastifyReply) => {
        const input = revokeSessionsSchema.parse(request.body);
        const result = await revokeUserSessions(request.user.sub, {
          deviceId: input.deviceId,
          // allOthers semantics: revoke every active session except the caller's.
          // deviceId-targeted revocation ignores `exceptToken` (we want it gone
          // regardless of which device is calling).
          exceptToken: input.allOthers && !input.deviceId ? input.refreshToken : undefined,
        });
        reply.send(result);
      }
    );
  });
}

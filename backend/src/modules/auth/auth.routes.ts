import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import { authenticate } from '../../middleware/authenticate.js';

import { buildAuthHandlers } from './auth.controller.js';
import {
  forgotPasswordSchema,
  listSessionsSchema,
  resetPasswordSchema,
  revokeSessionsSchema,
} from './auth.schema.js';
import { listUserSessions, revokeUserSessions } from './auth.service.js';
import { requestPasswordReset, resetPassword } from './password-reset.service.js';

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

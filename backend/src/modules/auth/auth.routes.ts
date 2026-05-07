import { FastifyInstance } from 'fastify';
import { buildAuthHandlers } from './auth.controller.js';
import { forgotPasswordSchema, resetPasswordSchema } from './auth.schema.js';
import { requestPasswordReset, resetPassword } from './password-reset.service.js';

const AUTH_BODY_LIMIT = 4 * 1024;

export async function authRoutes(app: FastifyInstance) {
  const { register, login, apple, refresh, logout } = buildAuthHandlers(app);
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
}

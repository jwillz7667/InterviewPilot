import { FastifyInstance } from 'fastify';
import { buildAuthHandlers } from './auth.controller.js';
import { forgotPasswordSchema, resetPasswordSchema } from './auth.schema.js';
import { requestPasswordReset, resetPassword } from './password-reset.service.js';

export async function authRoutes(app: FastifyInstance) {
  const { register, login, apple, refresh, logout } = buildAuthHandlers(app);
  const authRateLimit = {
    config: {
      rateLimit: {
        max: 10,
        timeWindow: '1 minute',
      },
    },
  } as const;

  app.post('/api/v1/auth/register', authRateLimit, register);
  app.post('/api/v1/auth/login', authRateLimit, login);
  app.post('/api/v1/auth/apple', authRateLimit, apple);
  app.post('/api/v1/auth/refresh', authRateLimit, refresh);
  app.post('/api/v1/auth/logout', logout);

  app.post('/api/v1/auth/forgot-password', authRateLimit, async (request, reply) => {
    const { email } = forgotPasswordSchema.parse(request.body);
    await requestPasswordReset(email);
    // Always return success to prevent email enumeration
    reply.send({ message: 'If an account exists, a password reset email has been sent.' });
  });

  app.post('/api/v1/auth/reset-password', authRateLimit, async (request, reply) => {
    const { token, password } = resetPasswordSchema.parse(request.body);
    await resetPassword(token, password);
    reply.send({ message: 'Password has been reset successfully.' });
  });
}

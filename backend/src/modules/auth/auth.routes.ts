import { FastifyInstance } from 'fastify';
import { buildAuthHandlers } from './auth.controller.js';

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
}

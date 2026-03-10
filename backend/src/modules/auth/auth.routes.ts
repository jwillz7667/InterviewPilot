import { FastifyInstance } from 'fastify';
import { buildAuthHandlers } from './auth.controller.js';

export async function authRoutes(app: FastifyInstance) {
  const { register, login, refresh, logout } = buildAuthHandlers(app);

  app.post('/api/v1/auth/register', register);
  app.post('/api/v1/auth/login', login);
  app.post('/api/v1/auth/refresh', refresh);
  app.post('/api/v1/auth/logout', logout);
}

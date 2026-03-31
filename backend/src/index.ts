import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import { loadEnv } from './config/env.js';
import {
  disconnectPrisma,
  isTransientPrismaError,
  reconnectPrisma,
} from './config/database.js';
import { authRoutes } from './modules/auth/auth.routes.js';
import { usersRoutes } from './modules/users/users.routes.js';
import { profileRoutes } from './modules/users/profile.routes.js';
import { settingsRoutes } from './modules/settings/settings.routes.js';
import { apiKeysRoutes } from './modules/api-keys/api-keys.routes.js';
import { sessionsRoutes } from './modules/sessions/sessions.routes.js';
import { exchangesRoutes } from './modules/exchanges/exchanges.routes.js';
import { answerBanksRoutes } from './modules/answer-banks/answer-banks.routes.js';
import { configRoutes } from './modules/config/config.routes.js';
import { billingRoutes } from './modules/billing/billing.routes.js';
import { AppError } from './utils/errors.js';
import { ZodError } from 'zod';

const env = loadEnv();

const app = Fastify({
  logger: {
    level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  },
});

// Plugins
await app.register(cors, { origin: env.CORS_ORIGIN });
await app.register(jwt, { secret: env.JWT_SECRET });
await app.register(rateLimit, {
  max: 100,
  timeWindow: '1 minute',
});

// Health check
app.get('/health', async () => ({
  status: 'ok',
  timestamp: new Date().toISOString(),
  environment: env.NODE_ENV,
}));

// Error handler
app.setErrorHandler((error: Error & { statusCode?: number; code?: string }, _request, reply) => {
  if (error instanceof AppError) {
    return reply.status(error.statusCode).send({
      error: error.code ?? error.name,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
    });
  }

  if (error instanceof ZodError) {
    return reply.status(422).send({
      error: 'VALIDATION_ERROR',
      message: 'Validation failed',
      details: error.errors.map((e) => ({
        field: e.path.join('.'),
        message: e.message,
      })),
    });
  }

  if (isTransientPrismaError(error)) {
    app.log.warn({ err: error }, 'Transient database connectivity issue');
    void reconnectPrisma().catch((reconnectError) => {
      app.log.error({ err: reconnectError }, 'Database reconnect failed');
    });

    return reply.status(503).send({
      error: 'DATABASE_UNAVAILABLE',
      message: 'Database connection was interrupted. Retry your request.',
    });
  }

  // Fastify native errors (rate limit, etc.)
  if (error.statusCode) {
    return reply.status(error.statusCode).send({
      error: error.code ?? 'ERROR',
      message: error.message,
    });
  }

  app.log.error(error);
  reply.status(500).send({
    error: 'INTERNAL_ERROR',
    message: env.NODE_ENV === 'production' ? 'Internal server error' : error.message,
  });
});

// Routes
await app.register(authRoutes);
await app.register(usersRoutes);
await app.register(profileRoutes);
await app.register(settingsRoutes);
await app.register(apiKeysRoutes);
await app.register(sessionsRoutes);
await app.register(exchangesRoutes);
await app.register(answerBanksRoutes);
await app.register(configRoutes);
await app.register(billingRoutes);

function scheduleDatabaseReconnect(delayMs = 5_000) {
  const timer = setTimeout(() => {
    void initializeDatabaseConnection();
  }, delayMs);

  timer.unref?.();
}

async function initializeDatabaseConnection() {
  try {
    await reconnectPrisma();
    app.log.info('Database connected');
  } catch (err) {
    app.log.warn({ err }, 'Database connection failed during startup; retrying');
    scheduleDatabaseReconnect();
  }
}

// Start server
const start = async () => {
  try {
    await app.listen({ port: env.PORT, host: '0.0.0.0' });
    app.log.info(`Server running on port ${env.PORT}`);
    void initializeDatabaseConnection();
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

// Graceful shutdown
const shutdown = async () => {
  app.log.info('Shutting down...');
  await app.close();
  await disconnectPrisma();
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();

import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import helmet from '@fastify/helmet';
import { loadEnv } from './config/env.js';
import { initSentry, captureException } from './config/sentry.js';
import {
  disconnectPrisma,
  getPrisma,
  isTransientPrismaError,
  reconnectPrisma,
} from './config/database.js';
import { disconnectRedis, getRedis } from './config/redis.js';
import { authRoutes } from './modules/auth/auth.routes.js';
import { usersRoutes } from './modules/users/users.routes.js';
import { profileRoutes } from './modules/users/profile.routes.js';
import { settingsRoutes } from './modules/settings/settings.routes.js';
import { apiKeysRoutes } from './modules/api-keys/api-keys.routes.js';
import { sessionsRoutes } from './modules/sessions/sessions.routes.js';
import { exchangesRoutes } from './modules/exchanges/exchanges.routes.js';
import { answerBanksRoutes } from './modules/answer-banks/answer-banks.routes.js';
import { interviewProfilesRoutes } from './modules/profiles/profiles.routes.js';
import { billingRoutes } from './modules/billing/billing.routes.js';
import { uploadsRoutes } from './modules/uploads/uploads.routes.js';
import { aiRoutes } from './modules/ai/ai.routes.js';
import { requestIdPlugin } from './plugins/request-id.js';
import { AppError } from './utils/errors.js';
import { ZodError } from 'zod';

const env = loadEnv();
initSentry();

if (env.CORS_ORIGIN === '*' && env.NODE_ENV === 'production') {
  console.error(
    'CORS_ORIGIN must not be wildcard (*) in production. Set CORS_ORIGIN to your iOS/web origin (comma-separated for multiple).'
  );
  process.exit(1);
}

const app = Fastify({
  logger: {
    level: env.NODE_ENV === 'production' ? 'info' : 'debug',
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.headers["x-api-key"]',
        'req.body.password',
        'req.body.identityToken',
        'req.body.authorizationCode',
        'req.body.refreshToken',
        'req.body.appleSignInToken',
        'req.body.apiKey',
        'req.body.openaiApiKey',
        'req.body.deepgramApiKey',
        '*.password',
        '*.token',
        '*.apiKey',
      ],
      censor: '[REDACTED]',
    },
  },
});

// Plugins
const corsOrigins = env.CORS_ORIGIN.split(',').map((s) => s.trim()).filter(Boolean);
await app.register(cors, {
  origin: corsOrigins.length === 1 && corsOrigins[0] === '*' ? '*' : corsOrigins,
});
await app.register(helmet, { contentSecurityPolicy: false });
await app.register(jwt, {
  secret: env.JWT_SECRET,
  sign: { iss: env.JWT_ISSUER, aud: env.JWT_AUDIENCE },
  verify: { allowedIss: env.JWT_ISSUER, allowedAud: env.JWT_AUDIENCE },
});
await app.register(rateLimit, {
  max: 100,
  timeWindow: '1 minute',
});

await app.register(requestIdPlugin);

// Health check
app.get('/health', async () => {
  const [dbStatus, redisStatus] = await Promise.all([
    (async () => {
      try {
        await getPrisma().$queryRaw`SELECT 1`;
        return 'connected';
      } catch {
        return 'disconnected';
      }
    })(),
    (async () => {
      if (!env.REDIS_URL) return 'unconfigured';
      try {
        const client = await getRedis();
        if (!client) return 'unconfigured';
        const reply = await client.ping();
        return reply === 'PONG' ? 'connected' : 'disconnected';
      } catch {
        return 'disconnected';
      }
    })(),
  ]);

  // Redis is non-critical (cache only) — degraded but not failing if down.
  const status = dbStatus === 'connected' ? 'ok' : 'degraded';
  return {
    status,
    timestamp: new Date().toISOString(),
    environment: env.NODE_ENV,
    database: dbStatus,
    redis: redisStatus,
  };
});

// Error handler
app.setErrorHandler((error: Error & { statusCode?: number; code?: string }, request, reply) => {
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
    app.log.warn({ err: error, requestId: request.id }, 'Transient database connectivity issue');
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

  app.log.error({ err: error, requestId: request.id }, 'Unhandled error');
  captureException(error, { requestId: request.id, userId: request.user?.sub });
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
await app.register(interviewProfilesRoutes);
await app.register(billingRoutes);
await app.register(uploadsRoutes);
await app.register(aiRoutes);

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
  const shutdownTimer = setTimeout(() => {
    app.log.error('Graceful shutdown timed out after 10s, forcing exit');
    process.exit(1);
  }, 10_000);
  shutdownTimer.unref();

  await app.close();
  await Promise.all([disconnectPrisma(), disconnectRedis()]);
  clearTimeout(shutdownTimer);
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();

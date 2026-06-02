// Must be the first import: @peculiar/x509 (used by attest.service for App
// Attest chain validation) pulls in tsyringe, which fails to load without the
// reflect-metadata polyfill installed on the global scope.
import 'reflect-metadata';

import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import Fastify from 'fastify';
import { ZodError } from 'zod';

import {
  disconnectPrisma,
  getPrisma,
  isTransientPrismaError,
  reconnectPrisma,
} from './config/database.js';
import { loadEnv } from './config/env.js';
import { RedisRateLimitStore } from './config/rate-limit-store.js';
import { disconnectRedis, getRedis } from './config/redis.js';
import { initSentry, captureException } from './config/sentry.js';
// Telemetry must boot before any HTTP/Prisma client is constructed so OTel can
// patch them. loadEnv runs first so we have OTEL_* vars; initTelemetry no-ops
// when no exporter endpoint is configured.
import { initTelemetry, shutdownTelemetry } from './config/telemetry.js';
import { aiRoutes } from './modules/ai/ai.routes.js';
import { probeDeepgramKeyScopes } from './modules/ai/ai.service.js';
import { answerBanksRoutes } from './modules/answer-banks/answer-banks.routes.js';
import { apiKeysRoutes } from './modules/api-keys/api-keys.routes.js';
import { attestRoutes } from './modules/attest/attest.routes.js';
import { authRoutes } from './modules/auth/auth.routes.js';
import { billingRoutes } from './modules/billing/billing.routes.js';
import { configRoutes } from './modules/config/config.routes.js';
import { exchangesRoutes } from './modules/exchanges/exchanges.routes.js';
import { interviewProfilesRoutes } from './modules/profiles/profiles.routes.js';
import { sessionsRoutes } from './modules/sessions/sessions.routes.js';
import { settingsRoutes } from './modules/settings/settings.routes.js';
import { uploadsRoutes } from './modules/uploads/uploads.routes.js';
import { profileRoutes } from './modules/users/profile.routes.js';
import { usersRoutes } from './modules/users/users.routes.js';
import entitlementPlugin from './plugins/entitlement.js';
import idempotencyPlugin from './plugins/idempotency.js';
import { requestIdPlugin } from './plugins/request-id.js';
import { AppError } from './utils/errors.js';

const env = loadEnv();
initTelemetry();
initSentry();

if (env.CORS_ORIGIN === '*' && env.NODE_ENV === 'production') {
  console.error(
    'CORS_ORIGIN must not be wildcard (*) in production. Set CORS_ORIGIN to your iOS/web origin (comma-separated for multiple).'
  );
  process.exit(1);
}

const app = Fastify({
  // Railway terminates TLS at its edge proxy and forwards X-Forwarded-For.
  // Without trustProxy, req.ip is the proxy's IP — collapsing every client into
  // one rate-limit bucket and mis-keying the unauthenticated IP fallback.
  trustProxy: true,
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
const corsOrigins = env.CORS_ORIGIN.split(',')
  .map((s) => s.trim())
  .filter(Boolean);
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
  // Share counters across instances when Redis is configured; otherwise fall
  // back to the plugin's default in-process LRU store (correct for a single
  // instance). skipOnError fails open so a Redis blip never blocks the API.
  skipOnError: true,
  ...(env.REDIS_URL ? { store: RedisRateLimitStore } : {}),
});

await app.register(requestIdPlugin);
await app.register(entitlementPlugin);
await app.register(idempotencyPlugin);

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
        // getRedis never blocks: it returns the client only when ready, otherwise
        // undefined while a throttled background reconnect runs. Configured but
        // not ready => disconnected (degraded), not unconfigured.
        if (!client) return 'disconnected';
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
await app.register(configRoutes);
await app.register(authRoutes);
await app.register(usersRoutes);
await app.register(profileRoutes);
await app.register(settingsRoutes);
await app.register(apiKeysRoutes);
await app.register(attestRoutes);
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
    // Probe Deepgram permissions in the background — never block boot on it.
    void probeDeepgramKeyScopes();
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
  await Promise.all([disconnectPrisma(), disconnectRedis(), shutdownTelemetry()]);
  clearTimeout(shutdownTimer);
  process.exit(0);
};

let isShuttingDown = false;
const shutdownOnce = (signal: string) => {
  if (isShuttingDown) return;
  isShuttingDown = true;
  app.log.info({ signal }, 'Received shutdown signal');
  void shutdown();
};

process.on('SIGINT', () => shutdownOnce('SIGINT'));
process.on('SIGTERM', () => shutdownOnce('SIGTERM'));

// Last-resort crash handlers. Without these, an unhandled rejection terminates
// the Node 22 process silently — no Sentry capture, no controlled drain. Log +
// report, then exit so the orchestrator restarts a clean process.
process.on('unhandledRejection', (reason) => {
  const error = reason instanceof Error ? reason : new Error(String(reason));
  app.log.error({ err: error }, 'Unhandled promise rejection');
  captureException(error, { source: 'unhandledRejection' });
});

process.on('uncaughtException', (error) => {
  app.log.error({ err: error }, 'Uncaught exception — shutting down');
  captureException(error, { source: 'uncaughtException' });
  shutdownOnce('uncaughtException');
});

void start();

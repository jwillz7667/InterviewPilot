import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

import { getEnv } from '../../config/env.js';

/**
 * Public client-config endpoint. Returns values the iOS app needs at boot
 * but shouldn't hardcode (Sentry DSN, App Attest enforcement flag, minimum
 * iOS version). Sentry DSNs are safe to expose — they only authorize event
 * ingestion for one project, never reads.
 */
export async function configRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/v1/config', async (_request: FastifyRequest, reply: FastifyReply) => {
    const env = getEnv();
    reply.send({
      sentry: {
        dsn: env.SENTRY_DSN_IOS ?? null,
        environment: env.NODE_ENV,
        tracesSampleRate: 0.1,
      },
      appAttest: {
        required: env.APP_ATTEST_REQUIRED,
        environment: env.APP_ATTEST_ENVIRONMENT,
      },
      linkedin: {
        clientId: env.LINKEDIN_CLIENT_ID ?? null,
        redirectUri: env.LINKEDIN_REDIRECT_URI,
        enabled: Boolean(env.LINKEDIN_CLIENT_ID && env.LINKEDIN_CLIENT_SECRET),
        scope: 'openid profile email',
      },
    });
  });
}

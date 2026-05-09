import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

import { authenticate } from '../../middleware/authenticate.js';
import { appAttestHook } from '../attest/attest.middleware.js';

import {
  accessClaimSchema,
  appStoreNotificationSchema,
  appStoreSyncSchema,
  toPrismaQuality,
  toPrismaSessionMode,
} from './billing.schema.js';
import {
  claimInterviewAccess,
  getBillingSummary,
  processAppStoreNotification,
  syncAppStoreTransactions,
} from './billing.service.js';

export async function billingRoutes(app: FastifyInstance) {
  app.post(
    '/api/v1/billing/app-store/notifications',
    {
      config: {
        rateLimit: {
          max: 30,
          timeWindow: '1 minute',
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const { signedPayload } = appStoreNotificationSchema.parse(request.body);
      const result = await processAppStoreNotification(signedPayload);
      reply.send(result);
    }
  );

  await app.register(async function protectedBillingRoutes(protectedApp) {
    protectedApp.addHook('onRequest', authenticate);
    protectedApp.addHook('preHandler', appAttestHook);

    protectedApp.get(
      '/api/v1/billing/entitlements',
      async (request: FastifyRequest, reply: FastifyReply) => {
        const entitlement = await getBillingSummary(request.user.sub);
        reply.send({ entitlement });
      }
    );

    protectedApp.post(
      '/api/v1/billing/access-claims',
      { config: { idempotent: true } },
      async (request: FastifyRequest, reply: FastifyReply) => {
        const input = accessClaimSchema.parse(request.body);
        const claim = await claimInterviewAccess(
          request.user.sub,
          input.sessionClientId,
          toPrismaSessionMode(input.sessionMode),
          toPrismaQuality(input.quality)
        );
        reply.status(201).send({ claim });
      }
    );

    protectedApp.post(
      '/api/v1/billing/app-store/sync',
      { config: { idempotent: true } },
      async (request: FastifyRequest, reply: FastifyReply) => {
        const { signedTransactions } = appStoreSyncSchema.parse(request.body);
        const entitlement = await syncAppStoreTransactions(request.user.sub, signedTransactions);
        reply.send({ entitlement });
      }
    );
  });
}

import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

import { withDatabaseRetry } from '../../config/database.js';
import { authenticate } from '../../middleware/authenticate.js';

const updateSettingsSchema = z.object({
  defaultInterviewType: z.string().optional(),
  defaultResponseFormat: z.string().optional(),
  shouldPreGenerate: z.boolean().optional(),
  responseTone: z.enum(['natural', 'confident', 'warm', 'executive']).optional(),
  responseEmphasis: z
    .enum(['balanced', 'technicalDepth', 'businessImpact', 'leadership', 'productThinking'])
    .optional(),
  responseBehavior: z.enum(['direct', 'analytical', 'storyLed', 'collaborative']).optional(),
});

export async function settingsRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  app.get('/api/v1/settings', async (request: FastifyRequest, reply: FastifyReply) => {
    const settings = await withDatabaseRetry((prisma) =>
      prisma.userSettings.upsert({
        where: { userId: request.user.sub },
        create: { userId: request.user.sub },
        update: {},
      })
    );

    reply.send({ settings });
  });

  app.put('/api/v1/settings', async (request: FastifyRequest, reply: FastifyReply) => {
    const input = updateSettingsSchema.parse(request.body);
    const settings = await withDatabaseRetry((prisma) =>
      prisma.userSettings.upsert({
        where: { userId: request.user.sub },
        create: { userId: request.user.sub, ...input },
        update: input,
      })
    );
    reply.send({ settings });
  });
}

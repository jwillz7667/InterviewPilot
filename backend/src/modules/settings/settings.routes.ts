import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { getPrisma } from '../../config/database.js';
import { z } from 'zod';

const updateSettingsSchema = z.object({
  defaultInterviewType: z.string().optional(),
  defaultResponseFormat: z.string().optional(),
  defaultModel: z.string().optional(),
  shouldPreGenerate: z.boolean().optional(),
  responseTemperature: z.number().min(0).max(2).optional(),
  maxResponseTokens: z.number().min(100).max(4000).optional(),
  maxPreComputedQs: z.number().min(5).max(50).optional(),
  utteranceEndMs: z.number().min(500).max(5000).optional(),
  endpointingMs: z.number().min(100).max(2000).optional(),
  predictiveFireMinWords: z.number().min(3).max(20).optional(),
});

export async function settingsRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  app.get('/api/v1/settings', async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = getPrisma();
    let settings = await prisma.userSettings.findUnique({
      where: { userId: request.user.sub },
    });

    if (!settings) {
      settings = await prisma.userSettings.create({
        data: { userId: request.user.sub },
      });
    }

    reply.send({ settings });
  });

  app.put('/api/v1/settings', async (request: FastifyRequest, reply: FastifyReply) => {
    const input = updateSettingsSchema.parse(request.body);
    const prisma = getPrisma();
    const settings = await prisma.userSettings.upsert({
      where: { userId: request.user.sub },
      create: { userId: request.user.sub, ...input },
      update: input,
    });
    reply.send({ settings });
  });
}

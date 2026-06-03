import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

import { withDatabaseRetry } from '../../config/database.js';
import { authenticate } from '../../middleware/authenticate.js';
import { ForbiddenError, ValidationError } from '../../utils/errors.js';
import { chatProviderHasKey } from '../ai/ai.provider.js';
import { getBillingSummary } from '../billing/billing.service.js';

const updateSettingsSchema = z.object({
  defaultInterviewType: z.string().optional(),
  defaultResponseFormat: z.string().optional(),
  shouldPreGenerate: z.boolean().optional(),
  responseTone: z.enum(['natural', 'confident', 'warm', 'executive']).optional(),
  responseEmphasis: z
    .enum(['balanced', 'technicalDepth', 'businessImpact', 'leadership', 'productThinking'])
    .optional(),
  responseBehavior: z.enum(['direct', 'analytical', 'storyLed', 'collaborative']).optional(),
  // Per-user AI provider override. null clears the preference (follow the
  // server-wide AI_CHAT_PROVIDER default). Gated to full-access accounts below.
  chatProvider: z.enum(['openai', 'deepseek', 'groq']).nullable().optional(),
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

    // Provider selection is an operator/developer control, not a general
    // preference — deny by default and only honor it for full-access accounts.
    // A stale value can never reach a dead provider (resolveChatProvider falls
    // back), but we still reject up front so the iOS menu fails loudly.
    if (input.chatProvider !== undefined) {
      const billing = await getBillingSummary(request.user.sub);
      if (!billing.sandboxFullAccess) {
        throw new ForbiddenError('Switching the AI provider requires developer access.');
      }
      if (input.chatProvider !== null && !chatProviderHasKey(input.chatProvider)) {
        throw new ValidationError(
          `The "${input.chatProvider}" provider is not configured on the server.`
        );
      }
    }

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

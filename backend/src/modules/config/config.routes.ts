import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { getEnv } from '../../config/env.js';
import { canAccessRuntimeAiConfig } from '../billing/billing.service.js';
import { PaymentRequiredError } from '../../utils/errors.js';

export async function configRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  app.get('/api/v1/config/api-keys', async (request: FastifyRequest, reply: FastifyReply) => {
    const canAccess = await canAccessRuntimeAiConfig(request.user.sub);
    if (!canAccess) {
      throw new PaymentRequiredError('Your free trial is complete. Upgrade to continue.');
    }

    const env = getEnv();
    reply.send({
      deepgramApiKey: env.DEEPGRAM_API_KEY,
      openaiApiKey: env.OPENAI_API_KEY,
    });
  });
}

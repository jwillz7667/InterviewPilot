import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { getEnv } from '../../config/env.js';

export async function configRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // Returns API keys for authenticated users
  // The iOS app uses these to call Deepgram/OpenAI directly for low-latency real-time processing
  app.get('/api/v1/config/api-keys', async (_request: FastifyRequest, reply: FastifyReply) => {
    const env = getEnv();
    reply.send({
      deepgramApiKey: env.DEEPGRAM_API_KEY,
      openaiApiKey: env.OPENAI_API_KEY,
    });
  });
}

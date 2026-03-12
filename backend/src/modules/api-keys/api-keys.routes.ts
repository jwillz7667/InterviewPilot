import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { withDatabaseRetry } from '../../config/database.js';
import { encryptApiKey, decryptApiKey } from '../../utils/encryption.js';
import { z } from 'zod';

const providerParam = z.object({
  provider: z.enum(['deepgram', 'openai']),
});

const storeKeySchema = z.object({
  apiKey: z.string().min(1, 'API key is required'),
});

export async function apiKeysRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // List keys (prefix only)
  app.get('/api/v1/api-keys', async (request: FastifyRequest, reply: FastifyReply) => {
    const keys = await withDatabaseRetry((prisma) =>
      prisma.userApiKey.findMany({
        where: { userId: request.user.sub },
        select: { id: true, provider: true, keyPrefix: true, createdAt: true, updatedAt: true },
      })
    );
    reply.send({ keys });
  });

  // Store/update a key
  app.put(
    '/api/v1/api-keys/:provider',
    async (request: FastifyRequest<{ Params: { provider: string } }>, reply: FastifyReply) => {
      const { provider } = providerParam.parse(request.params);
      const { apiKey } = storeKeySchema.parse(request.body);

      const { encrypted, iv, tag } = encryptApiKey(apiKey);
      const keyPrefix = apiKey.substring(0, 4) + '...';

      const key = await withDatabaseRetry((prisma) =>
        prisma.userApiKey.upsert({
          where: { userId_provider: { userId: request.user.sub, provider } },
          create: {
            userId: request.user.sub,
            provider,
            encryptedKey: encrypted,
            keyIv: iv,
            keyTag: tag,
            keyPrefix,
          },
          update: {
            encryptedKey: encrypted,
            keyIv: iv,
            keyTag: tag,
            keyPrefix,
          },
          select: { id: true, provider: true, keyPrefix: true, updatedAt: true },
        })
      );

      reply.send({ key });
    }
  );

  // Decrypt and return key
  app.get(
    '/api/v1/api-keys/:provider/decrypt',
    async (request: FastifyRequest<{ Params: { provider: string } }>, reply: FastifyReply) => {
      const { provider } = providerParam.parse(request.params);
      const key = await withDatabaseRetry((prisma) =>
        prisma.userApiKey.findUnique({
          where: { userId_provider: { userId: request.user.sub, provider } },
        })
      );

      if (!key) {
        return reply.status(404).send({ error: 'API key not found for this provider' });
      }

      const decrypted = decryptApiKey(key.encryptedKey, key.keyIv, key.keyTag);
      reply.send({ provider, apiKey: decrypted });
    }
  );

  // Delete a key
  app.delete(
    '/api/v1/api-keys/:provider',
    async (request: FastifyRequest<{ Params: { provider: string } }>, reply: FastifyReply) => {
      const { provider } = providerParam.parse(request.params);
      await withDatabaseRetry((prisma) =>
        prisma.userApiKey.deleteMany({
          where: { userId: request.user.sub, provider },
        })
      );
      reply.send({ success: true });
    }
  );
}

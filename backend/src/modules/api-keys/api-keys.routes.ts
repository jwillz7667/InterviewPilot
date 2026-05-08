import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

import { withDatabaseRetry } from '../../config/database.js';
import { authenticate } from '../../middleware/authenticate.js';
import { encryptApiKey, decryptApiKey } from '../../utils/encryption.js';

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

  // Decrypt and return key. Rate-limited tightly because every successful
  // call exposes a long-lived secret in plaintext over the response body.
  app.get(
    '/api/v1/api-keys/:provider/decrypt',
    {
      config: {
        rateLimit: {
          max: 5,
          timeWindow: '1 hour',
        },
      },
    },
    async (request: FastifyRequest<{ Params: { provider: string } }>, reply: FastifyReply) => {
      const { provider } = providerParam.parse(request.params);
      const key = await withDatabaseRetry((prisma) =>
        prisma.userApiKey.findUnique({
          where: { userId_provider: { userId: request.user.sub, provider } },
          select: { id: true, encryptedKey: true, keyIv: true, keyTag: true },
        })
      );

      if (!key) {
        return reply.status(404).send({ error: 'API key not found for this provider' });
      }

      const decrypted = decryptApiKey(key.encryptedKey, key.keyIv, key.keyTag);
      request.log.info(
        { userId: request.user.sub, provider, keyId: key.id, event: 'api_key.decrypt' },
        'User-stored API key decrypted'
      );
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

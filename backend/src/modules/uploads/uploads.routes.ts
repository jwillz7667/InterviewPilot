import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

import { authenticate } from '../../middleware/authenticate.js';
import {
  generateUploadPresignedUrl,
  generateDownloadPresignedUrl,
  isKeyOwnedBy,
} from '../../services/storage.js';

const presignedUrlSchema = z
  .object({
    filename: z.string().min(1).max(255),
    contentType: z.string().min(1).max(100),
  })
  .strict();

export async function uploadsRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // Generate a presigned URL for uploading a file
  app.post(
    '/api/v1/uploads/presigned-url',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const { filename, contentType } = presignedUrlSchema.parse(request.body);
      const result = await generateUploadPresignedUrl(request.user.sub, filename, contentType);

      if (!result) {
        return reply.status(503).send({
          error: 'STORAGE_UNAVAILABLE',
          message: 'File storage is not configured',
        });
      }

      reply.send(result);
    }
  );

  // Get a presigned URL for downloading a file
  app.get(
    '/api/v1/uploads/:key/url',
    async (request: FastifyRequest<{ Params: { key: string } }>, reply: FastifyReply) => {
      const key = decodeURIComponent(request.params.key);

      if (!isKeyOwnedBy(key, request.user.sub)) {
        return reply.status(403).send({
          error: 'FORBIDDEN',
          message: 'Access denied',
        });
      }

      const url = await generateDownloadPresignedUrl(key);

      if (!url) {
        return reply.status(503).send({
          error: 'STORAGE_UNAVAILABLE',
          message: 'File storage is not configured',
        });
      }

      reply.send({ url });
    }
  );
}

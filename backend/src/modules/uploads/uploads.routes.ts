import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

import { authenticate } from '../../middleware/authenticate.js';
import {
  generateUploadPresignedUrl,
  generateDownloadPresignedUrl,
  isKeyOwnedBy,
} from '../../services/storage.js';

// Resumes are documents only. An open contentType lets an authenticated user
// store text/html or image/svg+xml in the bucket — a stored-XSS vector if those
// objects are ever served inline — so we allowlist the document MIME types the
// product accepts and bind the type into the presigned signature.
const ALLOWED_UPLOAD_CONTENT_TYPES = [
  'application/pdf',
  'application/rtf',
  'text/rtf',
  'text/plain',
  'text/markdown',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
] as const;

const presignedUrlSchema = z
  .object({
    filename: z.string().min(1).max(255),
    contentType: z.enum(ALLOWED_UPLOAD_CONTENT_TYPES),
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

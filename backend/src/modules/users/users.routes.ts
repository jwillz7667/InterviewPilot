import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

import { withDatabaseRetry } from '../../config/database.js';
import { authenticate } from '../../middleware/authenticate.js';

import { ensureAppAccountToken } from './app-account-token.js';

const updateProfileSchema = z.object({
  displayName: z.string().min(1).max(100).optional(),
  avatarUrl: z.string().url().optional(),
});

export async function usersRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  app.get('/api/v1/users/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = await withDatabaseRetry(async (prisma) => {
      const userRecord = await prisma.user.findUniqueOrThrow({
        where: { id: request.user.sub },
        select: {
          id: true,
          email: true,
          displayName: true,
          avatarUrl: true,
          appAccountToken: true,
          isSandboxTester: true,
          createdAt: true,
          lastLoginAt: true,
          emailVerified: true,
        },
      });

      return {
        ...userRecord,
        appAccountToken: await ensureAppAccountToken(prisma, userRecord),
      };
    });

    reply.send({ user });
  });

  app.patch(
    '/api/v1/users/me',
    { bodyLimit: 4 * 1024 },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = updateProfileSchema.parse(request.body);
      const user = await withDatabaseRetry((prisma) =>
        prisma.user.update({
          where: { id: request.user.sub },
          data: input,
          select: { id: true, email: true, displayName: true, avatarUrl: true },
        })
      );
      reply.send({ user });
    }
  );

  app.delete('/api/v1/users/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const userId = request.user.sub;
    await withDatabaseRetry((prisma) =>
      prisma.$transaction(async (tx) => {
        // Soft-delete (the extension rewrites delete → deletedAt) and revoke all
        // refresh tokens so existing sessions can't be renewed after deletion.
        await tx.user.delete({ where: { id: userId } });
        await tx.refreshToken.updateMany({
          where: { userId, revokedAt: null },
          data: { revokedAt: new Date() },
        });
      })
    );
    reply.send({ success: true });
  });
}

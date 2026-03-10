import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { getPrisma } from '../../config/database.js';
import { z } from 'zod';

const updateProfileSchema = z.object({
  displayName: z.string().min(1).max(100).optional(),
  avatarUrl: z.string().url().optional(),
});

export async function usersRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  app.get('/api/v1/users/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = getPrisma();
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: request.user.sub },
      select: {
        id: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        createdAt: true,
        lastLoginAt: true,
        emailVerified: true,
        appleId: true,
        googleId: true,
      },
    });
    reply.send({ user });
  });

  app.patch('/api/v1/users/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const input = updateProfileSchema.parse(request.body);
    const prisma = getPrisma();
    const user = await prisma.user.update({
      where: { id: request.user.sub },
      data: input,
      select: { id: true, email: true, displayName: true, avatarUrl: true },
    });
    reply.send({ user });
  });

  app.delete('/api/v1/users/me', async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = getPrisma();
    await prisma.user.delete({ where: { id: request.user.sub } });
    reply.send({ success: true });
  });
}

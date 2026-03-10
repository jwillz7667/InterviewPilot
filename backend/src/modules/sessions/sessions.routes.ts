import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { getPrisma } from '../../config/database.js';
import { buildPaginatedResponse } from '../../utils/pagination.js';
import { z } from 'zod';

const createSessionSchema = z.object({
  clientId: z.string().uuid(),
  startedAt: z.string().datetime(),
  endedAt: z.string().datetime().optional(),
  resumeText: z.string(),
  jobDescription: z.string(),
  interviewType: z.string(),
  responseFormat: z.string(),
  modelUsed: z.string(),
  totalTokensUsed: z.number().int().default(0),
  estimatedCost: z.number().default(0),
});

const updateSessionSchema = z.object({
  endedAt: z.string().datetime().optional(),
  totalTokensUsed: z.number().int().optional(),
  estimatedCost: z.number().optional(),
});

const listQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().min(1).max(50).default(20),
});

export async function sessionsRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // List sessions (paginated)
  app.get('/api/v1/sessions', async (request: FastifyRequest, reply: FastifyReply) => {
    const { cursor, limit } = listQuerySchema.parse(request.query);
    const prisma = getPrisma();

    const sessions = await prisma.interviewSession.findMany({
      where: { userId: request.user.sub },
      orderBy: { startedAt: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { _count: { select: { exchanges: true } } },
    });

    reply.send(buildPaginatedResponse(sessions, limit));
  });

  // Get single session
  app.get(
    '/api/v1/sessions/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const prisma = getPrisma();
      const session = await prisma.interviewSession.findFirst({
        where: { id: request.params.id, userId: request.user.sub },
        include: { exchanges: { orderBy: { sequenceOrder: 'asc' } } },
      });

      if (!session) return reply.status(404).send({ error: 'Session not found' });
      reply.send({ session });
    }
  );

  // Create session
  app.post('/api/v1/sessions', async (request: FastifyRequest, reply: FastifyReply) => {
    const input = createSessionSchema.parse(request.body);
    const prisma = getPrisma();

    const session = await prisma.interviewSession.upsert({
      where: { clientId: input.clientId },
      create: {
        ...input,
        startedAt: new Date(input.startedAt),
        endedAt: input.endedAt ? new Date(input.endedAt) : undefined,
        userId: request.user.sub,
      },
      update: {
        endedAt: input.endedAt ? new Date(input.endedAt) : undefined,
        totalTokensUsed: input.totalTokensUsed,
        estimatedCost: input.estimatedCost,
      },
    });

    reply.status(201).send({ session });
  });

  // Update session
  app.put(
    '/api/v1/sessions/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const input = updateSessionSchema.parse(request.body);
      const prisma = getPrisma();

      const existing = await prisma.interviewSession.findFirst({
        where: { id: request.params.id, userId: request.user.sub },
      });
      if (!existing) return reply.status(404).send({ error: 'Session not found' });

      const session = await prisma.interviewSession.update({
        where: { id: request.params.id },
        data: {
          ...input,
          endedAt: input.endedAt ? new Date(input.endedAt) : undefined,
        },
      });

      reply.send({ session });
    }
  );

  // Delete session
  app.delete(
    '/api/v1/sessions/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const prisma = getPrisma();
      const existing = await prisma.interviewSession.findFirst({
        where: { id: request.params.id, userId: request.user.sub },
      });
      if (!existing) return reply.status(404).send({ error: 'Session not found' });

      await prisma.interviewSession.delete({ where: { id: request.params.id } });
      reply.send({ success: true });
    }
  );
}

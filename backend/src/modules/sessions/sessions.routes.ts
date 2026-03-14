import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { withDatabaseRetry } from '../../config/database.js';
import { buildPaginatedResponse } from '../../utils/pagination.js';
import { z } from 'zod';
import { getSessionAccessGrant } from '../billing/billing.service.js';
import { SessionMode } from '@prisma/client';

const sessionTelemetrySummarySchema = z.object({
  exchangeCount: z.number().int().nonnegative(),
  cachedExchangeCount: z.number().int().nonnegative(),
  predictiveFireCount: z.number().int().nonnegative(),
  averageTotalLatencyMs: z.number().int().nonnegative(),
  averageTimeToFirstTokenMs: z.number().int().nonnegative().nullable().optional(),
  averageGenerationDurationMs: z.number().int().nonnegative().nullable().optional(),
  averageLiveTimeToFirstTokenMs: z.number().int().nonnegative().nullable().optional(),
  averageLiveGenerationDurationMs: z.number().int().nonnegative().nullable().optional(),
  p95LiveTimeToFirstTokenMs: z.number().int().nonnegative().nullable().optional(),
  p95LiveGenerationDurationMs: z.number().int().nonnegative().nullable().optional(),
  averageQuestionDurationMs: z.number().int().nonnegative().nullable().optional(),
  averageSpeechEndToFireMs: z.number().int().nonnegative().nullable().optional(),
}).strict();

const createSessionSchema = z.object({
  clientId: z.string().uuid(),
  sessionMode: z.enum(['liveInterview', 'voicePrep']).default('liveInterview'),
  startedAt: z.string().datetime(),
  endedAt: z.string().datetime().optional(),
  resumeText: z.string(),
  jobDescription: z.string(),
  interviewType: z.string(),
  responseFormat: z.string(),
  modelUsed: z.string(),
  totalTokensUsed: z.number().int().default(0),
  estimatedCost: z.number().default(0),
  telemetrySummary: sessionTelemetrySummarySchema.optional(),
});

const updateSessionSchema = z.object({
  endedAt: z.string().datetime().optional(),
  totalTokensUsed: z.number().int().optional(),
  estimatedCost: z.number().optional(),
  telemetrySummary: sessionTelemetrySummarySchema.optional(),
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
    const sessions = await withDatabaseRetry((prisma) =>
      prisma.interviewSession.findMany({
        where: { userId: request.user.sub },
        orderBy: { startedAt: 'desc' },
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        include: { _count: { select: { exchanges: true } } },
      })
    );

    reply.send(buildPaginatedResponse(sessions, limit));
  });

  // Get single session
  app.get(
    '/api/v1/sessions/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const session = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.findFirst({
          where: { id: request.params.id, userId: request.user.sub },
          include: { exchanges: { orderBy: { sequenceOrder: 'asc' } } },
        })
      );

      if (!session) return reply.status(404).send({ error: 'Session not found' });
      reply.send({ session });
    }
  );

  // Create session
  app.post('/api/v1/sessions', async (request: FastifyRequest, reply: FastifyReply) => {
    const input = createSessionSchema.parse(request.body);
    const accessGrant = await getSessionAccessGrant(
      request.user.sub,
      input.clientId,
      input.sessionMode === 'voicePrep' ? SessionMode.VOICE_PREP : SessionMode.LIVE_INTERVIEW
    );

    const session = await withDatabaseRetry((prisma) =>
      prisma.interviewSession.upsert({
        where: { clientId: input.clientId },
        create: {
          ...input,
          sessionMode:
            input.sessionMode === 'voicePrep' ? SessionMode.VOICE_PREP : SessionMode.LIVE_INTERVIEW,
          startedAt: new Date(input.startedAt),
          endedAt: input.endedAt ? new Date(input.endedAt) : undefined,
          userId: request.user.sub,
          accessSource: accessGrant.accessSource,
          accessTier: accessGrant.accessTier,
          trialInterviewNumber: accessGrant.trialInterviewNumber ?? undefined,
          telemetrySummary: input.telemetrySummary,
        },
        update: {
          endedAt: input.endedAt ? new Date(input.endedAt) : undefined,
          totalTokensUsed: input.totalTokensUsed,
          estimatedCost: input.estimatedCost,
          telemetrySummary: input.telemetrySummary,
        },
      })
    );

    reply.status(201).send({ session });
  });

  // Update session
  app.put(
    '/api/v1/sessions/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const input = updateSessionSchema.parse(request.body);
      const existing = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.findFirst({
          where: { id: request.params.id, userId: request.user.sub },
        })
      );
      if (!existing) return reply.status(404).send({ error: 'Session not found' });

      const session = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.update({
          where: { id: request.params.id },
          data: {
            ...input,
            endedAt: input.endedAt ? new Date(input.endedAt) : undefined,
          },
        })
      );

      reply.send({ session });
    }
  );

  // Delete session
  app.delete(
    '/api/v1/sessions/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const existing = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.findFirst({
          where: { id: request.params.id, userId: request.user.sub },
        })
      );
      if (!existing) return reply.status(404).send({ error: 'Session not found' });

      await withDatabaseRetry((prisma) =>
        prisma.interviewSession.deleteMany({ where: { id: request.params.id } })
      );
      reply.send({ success: true });
    }
  );
}

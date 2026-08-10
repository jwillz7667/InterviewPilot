import { SessionMode } from '@prisma/client';
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

import { withDatabaseRetry } from '../../config/database.js';
import { authenticate } from '../../middleware/authenticate.js';
import { buildPaginatedResponse } from '../../utils/pagination.js';
import { getSessionAccessGrant } from '../billing/billing.service.js';
import { getUserChatProvider } from '../settings/settings.service.js';

import { analyzeSession } from './session-analysis.service.js';

const sessionTelemetrySummarySchema = z
  .object({
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
  })
  .strict();

const createSessionSchema = z.object({
  clientId: z.string().uuid(),
  sessionMode: z.enum(['liveInterview', 'voicePrep']).default('liveInterview'),
  startedAt: z.string().datetime(),
  endedAt: z.string().datetime().optional(),
  resumeText: z.string().max(50000),
  jobDescription: z.string().max(50000),
  jobListingUrl: z.string().max(2000).optional(),
  profileId: z.string().max(200).optional(),
  interviewType: z.string().max(200),
  responseFormat: z.string().max(200),
  modelUsed: z.string().max(200),
  totalTokensUsed: z.number().int().default(0),
  estimatedCost: z.number().default(0),
  telemetrySummary: sessionTelemetrySummarySchema.optional(),
  technicalAccuracyScore: z.number().min(0).max(100).optional(),
  communicationScore: z.number().min(0).max(100).optional(),
  confidenceScore: z.number().min(0).max(100).optional(),
  aiStrengths: z.array(z.string()).optional(),
  aiImprovements: z.array(z.string()).optional(),
  overallScore: z.number().int().min(0).max(100).optional(),
});

const updateSessionSchema = z.object({
  endedAt: z.string().datetime().optional(),
  totalTokensUsed: z.number().int().optional(),
  estimatedCost: z.number().optional(),
  telemetrySummary: sessionTelemetrySummarySchema.optional(),
  technicalAccuracyScore: z.number().min(0).max(100).optional(),
  communicationScore: z.number().min(0).max(100).optional(),
  confidenceScore: z.number().min(0).max(100).optional(),
  aiStrengths: z.array(z.string()).optional(),
  aiImprovements: z.array(z.string()).optional(),
  overallScore: z.number().int().min(0).max(100).optional(),
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
  app.post(
    '/api/v1/sessions',
    { config: { idempotent: true } },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = createSessionSchema.parse(request.body);

      // Verify ownership: if a session with this clientId already exists, it must belong to the requesting user
      const existingByClientId = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.findUnique({
          where: { clientId: input.clientId },
          select: { userId: true },
        })
      );
      if (existingByClientId && existingByClientId.userId !== request.user.sub) {
        return reply
          .status(403)
          .send({ error: 'Forbidden', message: 'Session belongs to another user' });
      }

      // The grant must exist (created at quota-claim time, before the session row).
      // We read it here to seal accessTier/quality into the immutable session record so the
      // session report can render the right pricing label even if the user upgrades later.
      const accessGrant = await getSessionAccessGrant(request.user.sub, input.clientId);

      const session = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.upsert({
          where: { clientId: input.clientId },
          create: {
            ...input,
            sessionMode:
              input.sessionMode === 'voicePrep'
                ? SessionMode.VOICE_PREP
                : SessionMode.LIVE_INTERVIEW,
            startedAt: new Date(input.startedAt),
            endedAt: input.endedAt ? new Date(input.endedAt) : undefined,
            userId: request.user.sub,
            accessSource: accessGrant.accessSource,
            accessTier: accessGrant.accessTier,
            quality: accessGrant.quality,
            trialInterviewNumber: accessGrant.trialInterviewNumber ?? undefined,
            telemetrySummary: input.telemetrySummary,
          },
          update: {
            endedAt: input.endedAt ? new Date(input.endedAt) : undefined,
            totalTokensUsed: input.totalTokensUsed,
            estimatedCost: input.estimatedCost,
            telemetrySummary: input.telemetrySummary,
            technicalAccuracyScore: input.technicalAccuracyScore,
            communicationScore: input.communicationScore,
            confidenceScore: input.confidenceScore,
            aiStrengths: input.aiStrengths,
            aiImprovements: input.aiImprovements,
            overallScore: input.overallScore,
          },
        })
      );

      reply.status(201).send({ session });
    }
  );

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

  // Analyze session with AI grading. Premium-only feature: gated via the
  // `post_session_analysis` flag which is set on PREMIUM and SANDBOX tiers.
  app.post(
    '/api/v1/sessions/:id/analyze',
    { config: { rateLimit: { max: 5, timeWindow: '1 minute' } } },
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      await request.requireFeature('post_session_analysis');
      const preferredProvider = await getUserChatProvider(request.user.sub);
      const analysis = await analyzeSession(request.params.id, request.user.sub, preferredProvider);
      reply.send({ analysis });
    }
  );

  // Delete session
  app.delete(
    '/api/v1/sessions/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      // Conditional updateMany: ownership check and soft-delete in one atomic
      // statement (no lookup-then-delete TOCTOU), scoped to the caller's rows.
      const result = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.updateMany({
          where: { id: request.params.id, userId: request.user.sub, deletedAt: null },
          data: { deletedAt: new Date() },
        })
      );
      if (result.count === 0) return reply.status(404).send({ error: 'Session not found' });
      reply.send({ success: true });
    }
  );
}

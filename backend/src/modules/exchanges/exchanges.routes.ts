import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { withDatabaseRetry } from '../../config/database.js';
import { z } from 'zod';

const exchangeTelemetrySchema = z.object({
  questionDurationMs: z.number().int().nonnegative().nullable().optional(),
  speechEndToFireMs: z.number().int().nonnegative().nullable().optional(),
  timeToFirstTokenMs: z.number().int().nonnegative().nullable().optional(),
  generationDurationMs: z.number().int().nonnegative().nullable().optional(),
  questionEndToCompletionMs: z.number().int().nonnegative().nullable().optional(),
  cacheLookupMs: z.number().int().nonnegative().nullable().optional(),
  classificationMs: z.number().int().nonnegative().nullable().optional(),
  streamChunkCount: z.number().int().nonnegative(),
  usedPredictiveFire: z.boolean(),
}).strict();

const exchangeSchema = z.object({
  clientId: z.string().uuid(),
  timestamp: z.string().datetime(),
  questionTranscript: z.string(),
  questionType: z.string(),
  generatedResponse: z.string(),
  responseLatencyMs: z.number().int(),
  wasPreComputed: z.boolean().default(false),
  telemetry: exchangeTelemetrySchema.optional(),
  sequenceOrder: z.number().int(),
});

const bulkSyncSchema = z.object({
  exchanges: z.array(exchangeSchema),
});

export async function exchangesRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // List exchanges for a session
  app.get(
    '/api/v1/sessions/:sessionId/exchanges',
    async (request: FastifyRequest<{ Params: { sessionId: string } }>, reply: FastifyReply) => {
      // Verify session ownership
      const session = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.findFirst({
          where: { id: request.params.sessionId, userId: request.user.sub },
        })
      );
      if (!session) return reply.status(404).send({ error: 'Session not found' });

      const exchanges = await withDatabaseRetry((prisma) =>
        prisma.exchange.findMany({
          where: { sessionId: request.params.sessionId },
          orderBy: { sequenceOrder: 'asc' },
        })
      );

      reply.send({ exchanges });
    }
  );

  // Bulk create/sync exchanges (idempotent via clientId)
  app.post(
    '/api/v1/sessions/:sessionId/exchanges/sync',
    async (request: FastifyRequest<{ Params: { sessionId: string } }>, reply: FastifyReply) => {
      const { exchanges } = bulkSyncSchema.parse(request.body);
      // Verify session ownership
      const session = await withDatabaseRetry((prisma) =>
        prisma.interviewSession.findFirst({
          where: { id: request.params.sessionId, userId: request.user.sub },
        })
      );
      if (!session) return reply.status(404).send({ error: 'Session not found' });

      const results = await withDatabaseRetry((prisma) =>
        prisma.$transaction(
          exchanges.map((exchange) =>
            prisma.exchange.upsert({
              where: { clientId: exchange.clientId },
              create: {
                ...exchange,
                timestamp: new Date(exchange.timestamp),
                sessionId: request.params.sessionId,
                telemetry: exchange.telemetry,
              },
              update: {
                questionTranscript: exchange.questionTranscript,
                generatedResponse: exchange.generatedResponse,
                responseLatencyMs: exchange.responseLatencyMs,
                wasPreComputed: exchange.wasPreComputed,
                telemetry: exchange.telemetry,
              },
            })
          )
        )
      );

      reply.send({ exchanges: results, synced: results.length });
    }
  );
}

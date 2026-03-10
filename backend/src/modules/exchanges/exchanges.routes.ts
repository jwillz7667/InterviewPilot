import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { getPrisma } from '../../config/database.js';
import { z } from 'zod';

const exchangeSchema = z.object({
  clientId: z.string().uuid(),
  timestamp: z.string().datetime(),
  questionTranscript: z.string(),
  questionType: z.string(),
  generatedResponse: z.string(),
  responseLatencyMs: z.number().int(),
  wasPreComputed: z.boolean().default(false),
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
      const prisma = getPrisma();

      // Verify session ownership
      const session = await prisma.interviewSession.findFirst({
        where: { id: request.params.sessionId, userId: request.user.sub },
      });
      if (!session) return reply.status(404).send({ error: 'Session not found' });

      const exchanges = await prisma.exchange.findMany({
        where: { sessionId: request.params.sessionId },
        orderBy: { sequenceOrder: 'asc' },
      });

      reply.send({ exchanges });
    }
  );

  // Bulk create/sync exchanges (idempotent via clientId)
  app.post(
    '/api/v1/sessions/:sessionId/exchanges/sync',
    async (request: FastifyRequest<{ Params: { sessionId: string } }>, reply: FastifyReply) => {
      const { exchanges } = bulkSyncSchema.parse(request.body);
      const prisma = getPrisma();

      // Verify session ownership
      const session = await prisma.interviewSession.findFirst({
        where: { id: request.params.sessionId, userId: request.user.sub },
      });
      if (!session) return reply.status(404).send({ error: 'Session not found' });

      const results = [];
      for (const exchange of exchanges) {
        const result = await prisma.exchange.upsert({
          where: { clientId: exchange.clientId },
          create: {
            ...exchange,
            timestamp: new Date(exchange.timestamp),
            sessionId: request.params.sessionId,
          },
          update: {
            questionTranscript: exchange.questionTranscript,
            generatedResponse: exchange.generatedResponse,
            responseLatencyMs: exchange.responseLatencyMs,
          },
        });
        results.push(result);
      }

      reply.send({ exchanges: results, synced: results.length });
    }
  );
}

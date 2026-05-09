import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

import { authenticate } from '../../middleware/authenticate.js';
import { getLogger } from '../../utils/logger.js';
import { appAttestHook } from '../attest/attest.middleware.js';
import { getBillingSummary } from '../billing/billing.service.js';

import { parseOrAudit } from './ai.audit.js';
import {
  realtimeSessionSchema,
  transcriptionSessionSchema,
  chatSchema,
  chatStreamSchema,
} from './ai.schema.js';
import {
  createRealtimeSession,
  createTranscriptionSession,
  chatCompletion,
  chatCompletionStream,
} from './ai.service.js';

const log = getLogger().child({ module: 'ai-routes' });

// Per-tier rate limits. Resolved from the cached billing summary (30s TTL — cheap to read).
// FREE is intentionally lower: live interviews are bursty so 30/min covers a session start
// + question pre-gen + a few answer streams without burning the limit.
async function tierAwareMax(req: FastifyRequest): Promise<number> {
  const userId = req.user?.sub;
  if (!userId) return 30;
  try {
    const summary = await getBillingSummary(userId);
    if (summary.sandboxFullAccess) return 240;
    switch (summary.tier) {
      case 'premium':
        return 240;
      case 'pro':
      case 'plus':
        return 120;
      case 'free':
      case 'trial':
      default:
        return 30;
    }
  } catch (err) {
    log.warn({ err, userId }, 'tierAwareMax: defaulting to FREE limit');
    return 30;
  }
}

function userKey(req: FastifyRequest): string {
  return req.user?.sub ?? req.ip;
}

export async function aiRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);
  app.addHook('preHandler', appAttestHook);

  // Voice Prep / Realtime: gated to Premium inside the service. Strict rate cap (lower than
  // chat) because each session minted is a new outbound socket to OpenAI Realtime.
  app.post(
    '/api/v1/ai/realtime/session',
    {
      config: {
        rateLimit: {
          max: 20,
          timeWindow: '1 minute',
          keyGenerator: userKey,
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = parseOrAudit(realtimeSessionSchema, request.body, request);
      const session = await createRealtimeSession(request.user.sub, input);
      reply.send(session);
    }
  );

  app.post(
    '/api/v1/ai/transcription/session',
    {
      config: {
        rateLimit: {
          max: 30,
          timeWindow: '1 minute',
          keyGenerator: userKey,
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = parseOrAudit(transcriptionSessionSchema, request.body, request);
      const session = await createTranscriptionSession(request.user.sub, input);
      reply.send(session);
    }
  );

  app.post(
    '/api/v1/ai/chat',
    {
      config: {
        rateLimit: {
          max: tierAwareMax,
          timeWindow: '1 minute',
          keyGenerator: userKey,
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = parseOrAudit(chatSchema, request.body, request);
      const data = await chatCompletion(request.user.sub, input);
      reply.send(data);
    }
  );

  app.post(
    '/api/v1/ai/chat/stream',
    {
      config: {
        rateLimit: {
          max: tierAwareMax,
          timeWindow: '1 minute',
          keyGenerator: userKey,
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = parseOrAudit(chatStreamSchema, request.body, request);
      const { upstream, resolvedQuality, resolvedModel } = await chatCompletionStream(
        request.user.sub,
        input
      );

      reply.raw.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        Connection: 'keep-alive',
        'X-Accel-Buffering': 'no',
        // Surface the resolved quality + model for the iOS observability layer.
        'X-Resolved-Quality': resolvedQuality,
        'X-Resolved-Model': resolvedModel,
      });

      const reader = upstream.body!.getReader() as ReadableStreamDefaultReader<Uint8Array>;
      const onDisconnect = () => {
        void reader.cancel().catch(() => {});
      };
      reply.raw.on('close', onDisconnect);

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          if (!reply.raw.writableEnded) {
            reply.raw.write(value);
          } else {
            await reader.cancel().catch(() => {});
            break;
          }
        }
      } finally {
        reply.raw.off('close', onDisconnect);
        if (!reply.raw.writableEnded) reply.raw.end();
      }
    }
  );
}

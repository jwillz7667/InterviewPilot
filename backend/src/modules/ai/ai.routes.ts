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

// Resolves once the socket can accept more data, or immediately if the
// connection closes/errors first. Without this, a slow client lets the upstream
// stream outrun the kernel send buffer and balloons server memory.
function awaitDrain(stream: NodeJS.WritableStream): Promise<void> {
  return new Promise((resolve) => {
    const settle = () => {
      stream.off('drain', settle);
      stream.off('close', settle);
      stream.off('error', settle);
      resolve();
    };
    stream.once('drain', settle);
    stream.once('close', settle);
    stream.once('error', settle);
  });
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
      // Abort the upstream OpenAI request when the client disconnects — cancelling
      // only the local reader leaves OpenAI generating (and billing) the full
      // completion for an abandoned stream.
      const upstreamAbort = new AbortController();
      const { upstream, resolvedQuality, resolvedModel } = await chatCompletionStream(
        request.user.sub,
        input,
        upstreamAbort.signal
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
        upstreamAbort.abort();
        void reader.cancel().catch(() => {});
      };
      reply.raw.on('close', onDisconnect);

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          if (reply.raw.writableEnded) {
            upstreamAbort.abort();
            await reader.cancel().catch(() => {});
            break;
          }
          // Respect backpressure: if the kernel buffer is full, pause reading
          // from OpenAI until the socket drains (or the client disconnects).
          if (!reply.raw.write(value)) {
            await awaitDrain(reply.raw);
          }
        }
      } catch (err) {
        // Mid-stream upstream failure after headers are flushed: emit a terminal
        // SSE error frame so the iOS client can distinguish failure from a clean
        // end (a bare truncated 200 with no [DONE] is ambiguous).
        if (!reply.raw.writableEnded) {
          const message = err instanceof Error ? err.message : 'stream interrupted';
          reply.raw.write(`event: error\ndata: ${JSON.stringify({ message })}\n\n`);
        }
      } finally {
        reply.raw.off('close', onDisconnect);
        upstreamAbort.abort();
        if (!reply.raw.writableEnded) reply.raw.end();
      }
    }
  );
}

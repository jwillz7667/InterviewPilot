import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
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

export async function aiRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // Mint an ephemeral OpenAI Realtime client_secret for direct iOS WSS connection.
  // The returned token is short-lived (~1 minute) and bound to this session only.
  app.post(
    '/api/v1/ai/realtime/session',
    { config: { rateLimit: { max: 30, timeWindow: '1 minute' } } },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = realtimeSessionSchema.parse(request.body);
      const session = await createRealtimeSession(request.user.sub, input);
      reply.send(session);
    }
  );

  // Mint a short-lived Deepgram API key (or proxy master key when DEEPGRAM_PROJECT_ID
  // is not configured — that fallback is a temporary measure).
  app.post(
    '/api/v1/ai/transcription/session',
    { config: { rateLimit: { max: 30, timeWindow: '1 minute' } } },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = transcriptionSessionSchema.parse(request.body);
      const session = await createTranscriptionSession(request.user.sub, input);
      reply.send(session);
    }
  );

  // Non-streaming JSON pass-through to OpenAI Chat Completions.
  app.post(
    '/api/v1/ai/chat',
    { config: { rateLimit: { max: 60, timeWindow: '1 minute' } } },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = chatSchema.parse(request.body);
      const data = await chatCompletion(request.user.sub, input);
      reply.send(data);
    }
  );

  // SSE pass-through to OpenAI Chat Completions streaming.
  // Forwards the raw event stream byte-for-byte; iOS parses `data: {...}` lines.
  app.post(
    '/api/v1/ai/chat/stream',
    { config: { rateLimit: { max: 60, timeWindow: '1 minute' } } },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = chatStreamSchema.parse(request.body);
      const upstream = await chatCompletionStream(request.user.sub, input);

      reply.raw.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        Connection: 'keep-alive',
        'X-Accel-Buffering': 'no',
      });

      const reader = upstream.body!.getReader();
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

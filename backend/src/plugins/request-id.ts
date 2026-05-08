import { FastifyInstance } from 'fastify';

import { currentTraceId } from '../config/telemetry.js';

export async function requestIdPlugin(app: FastifyInstance) {
  app.addHook('onRequest', (request, reply, done) => {
    const incomingId = request.headers['x-request-id'] as string | undefined;
    if (incomingId) {
      request.id = incomingId;
    }
    reply.header('x-request-id', request.id);
    done();
  });

  // Echo the active OTel trace ID on every response. iOS surfaces this in
  // crash reports + error toasts so a TestFlight-bug bisects directly to the
  // backend trace. No-op when telemetry is disabled.
  app.addHook('onSend', (_request, reply, payload, done) => {
    const traceId = currentTraceId();
    if (traceId) reply.header('x-trace-id', traceId);
    done(null, payload);
  });
}

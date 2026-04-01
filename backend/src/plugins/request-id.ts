import { FastifyInstance } from 'fastify';

export async function requestIdPlugin(app: FastifyInstance) {
  app.addHook('onRequest', (request, reply, done) => {
    const incomingId = request.headers['x-request-id'] as string | undefined;
    if (incomingId) {
      request.id = incomingId;
    }
    reply.header('x-request-id', request.id);
    done();
  });
}

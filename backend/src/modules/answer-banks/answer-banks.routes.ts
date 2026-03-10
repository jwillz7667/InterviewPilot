import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { getPrisma } from '../../config/database.js';
import { z } from 'zod';

const answerSchema = z.object({
  question: z.string(),
  response: z.string(),
  questionType: z.string(),
});

const createBankSchema = z.object({
  name: z.string().min(1).max(200),
  resumeText: z.string(),
  jobDescription: z.string(),
  interviewType: z.string(),
  answers: z.array(answerSchema),
});

export async function answerBanksRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // List answer banks
  app.get('/api/v1/answer-banks', async (request: FastifyRequest, reply: FastifyReply) => {
    const prisma = getPrisma();
    const banks = await prisma.answerBank.findMany({
      where: { userId: request.user.sub },
      include: { _count: { select: { answers: true } } },
      orderBy: { createdAt: 'desc' },
    });
    reply.send({ banks });
  });

  // Get single bank with answers
  app.get(
    '/api/v1/answer-banks/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const prisma = getPrisma();
      const bank = await prisma.answerBank.findFirst({
        where: { id: request.params.id, userId: request.user.sub },
        include: { answers: true },
      });
      if (!bank) return reply.status(404).send({ error: 'Answer bank not found' });
      reply.send({ bank });
    }
  );

  // Create bank with answers
  app.post('/api/v1/answer-banks', async (request: FastifyRequest, reply: FastifyReply) => {
    const input = createBankSchema.parse(request.body);
    const prisma = getPrisma();

    const bank = await prisma.answerBank.create({
      data: {
        userId: request.user.sub,
        name: input.name,
        resumeText: input.resumeText,
        jobDescription: input.jobDescription,
        interviewType: input.interviewType,
        answers: {
          create: input.answers,
        },
      },
      include: { answers: true },
    });

    reply.status(201).send({ bank });
  });

  // Delete bank
  app.delete(
    '/api/v1/answer-banks/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const prisma = getPrisma();
      const bank = await prisma.answerBank.findFirst({
        where: { id: request.params.id, userId: request.user.sub },
      });
      if (!bank) return reply.status(404).send({ error: 'Answer bank not found' });

      await prisma.answerBank.delete({ where: { id: request.params.id } });
      reply.send({ success: true });
    }
  );
}

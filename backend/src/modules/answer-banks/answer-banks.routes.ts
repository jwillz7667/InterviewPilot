import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

import { getPrisma, withDatabaseRetry } from '../../config/database.js';
import { authenticate } from '../../middleware/authenticate.js';
import { PaymentRequiredError, ValidationError } from '../../utils/errors.js';
import { maxTokensField, resolveChatProvider, type ChatProvider } from '../ai/ai.provider.js';
import { getModelByQuality, selectModel } from '../billing/billing.constants.js';
import { canAccessRuntimeAiConfig, getBillingSummary } from '../billing/billing.service.js';
import { getUserChatProvider } from '../settings/settings.service.js';

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

const generatedAnswerSchema = z.object({
  question: z.string().min(1),
  answer: z.string().min(1),
  type: z.string().min(1),
});

const generateBankSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  resumeText: z.string().min(1, 'Resume text is required'),
  jobDescription: z.string().min(1, 'Job description is required'),
  interviewType: z.string().min(1, 'Interview type is required'),
  responseQualityMode: z.enum(['standard', 'premium']).default('standard'),
});

export async function answerBanksRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // List answer banks
  app.get('/api/v1/answer-banks', async (request: FastifyRequest, reply: FastifyReply) => {
    const banks = await withDatabaseRetry((prisma) =>
      prisma.answerBank.findMany({
        where: { userId: request.user.sub },
        include: { _count: { select: { answers: true } } },
        orderBy: { createdAt: 'desc' },
      })
    );
    reply.send({ banks });
  });

  app.post(
    '/api/v1/answer-banks/generate',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const input = generateBankSchema.parse(request.body);

      const canAccess = await canAccessRuntimeAiConfig(request.user.sub);
      if (!canAccess) {
        throw new PaymentRequiredError('Upgrade to generate personalized prep assets.');
      }

      if (input.responseQualityMode === 'premium') {
        const billing = await getBillingSummary(request.user.sub);
        if (!billing.featureFlags.priority_models) {
          throw new PaymentRequiredError('Top Tier mode requires an active Pro subscription.', {
            requiredFeature: 'priority_models',
          });
        }
      }

      const existingBank = await withDatabaseRetry((prisma) =>
        prisma.answerBank.findFirst({
          where: {
            userId: request.user.sub,
            resumeText: input.resumeText,
            jobDescription: input.jobDescription,
            interviewType: input.interviewType,
            ...(input.responseQualityMode === 'premium'
              ? { name: { contains: 'top-tier prep' } }
              : { NOT: { name: { contains: 'top-tier prep' } } }),
          },
          include: { answers: true },
          orderBy: { updatedAt: 'desc' },
        })
      );

      if (existingBank) {
        return reply.send({ bank: existingBank, fromCache: true });
      }

      // Question count is governed by quality, not by user setting: Standard = 25, Premium = 50.
      // We deliberately do NOT honour `userSettings.maxPreComputedQs` here so a free user cannot
      // bump it to 200 client-side and burn premium tokens at standard prices.
      const quality = input.responseQualityMode === 'premium' ? 'PREMIUM' : 'STANDARD';
      const maxQuestions = getModelByQuality()[quality].preGenAnswerBank;

      const provider = resolveChatProvider(await getUserChatProvider(request.user.sub));
      const generatedAnswers = await generatePrepAnswers({
        resumeText: input.resumeText,
        jobDescription: input.jobDescription,
        interviewType: input.interviewType,
        maxQuestions,
        responseQualityMode: input.responseQualityMode,
        provider,
      });

      if (generatedAnswers.length === 0) {
        throw new ValidationError('The AI response did not contain any usable prep questions.');
      }

      const prisma = getPrisma();
      const bank = await prisma.answerBank.create({
        data: {
          userId: request.user.sub,
          name: deriveBankName(input.name, input.interviewType, input.responseQualityMode),
          resumeText: input.resumeText,
          jobDescription: input.jobDescription,
          interviewType: input.interviewType,
          answers: {
            create: generatedAnswers.map((answer) => ({
              question: answer.question,
              response: answer.answer,
              questionType: answer.type,
            })),
          },
        },
        include: { answers: true },
      });

      reply.status(201).send({ bank, fromCache: false });
    }
  );

  // Get single bank with answers
  app.get(
    '/api/v1/answer-banks/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const bank = await withDatabaseRetry((prisma) =>
        prisma.answerBank.findFirst({
          where: { id: request.params.id, userId: request.user.sub },
          include: { answers: true },
        })
      );
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
      // Conditional updateMany: ownership check and soft-delete in one atomic
      // statement, with the userId in the write predicate (tenant isolation at
      // the query layer, not just the preceding lookup).
      const result = await withDatabaseRetry((prisma) =>
        prisma.answerBank.updateMany({
          where: { id: request.params.id, userId: request.user.sub, deletedAt: null },
          data: { deletedAt: new Date() },
        })
      );
      if (result.count === 0) return reply.status(404).send({ error: 'Answer bank not found' });
      reply.send({ success: true });
    }
  );
}

function deriveBankName(
  name: string | undefined,
  interviewType: string,
  responseQualityMode: 'standard' | 'premium'
): string {
  const trimmed = name?.trim();
  if (trimmed) {
    return trimmed;
  }

  const label = interviewType.trim() || 'general';
  const date = new Date().toISOString().slice(0, 10);
  return responseQualityMode === 'premium'
    ? `${label} top-tier prep ${date}`
    : `${label} prep ${date}`;
}

async function generatePrepAnswers(input: {
  resumeText: string;
  jobDescription: string;
  interviewType: string;
  maxQuestions: number;
  responseQualityMode: 'standard' | 'premium';
  provider: ChatProvider;
}): Promise<z.infer<typeof generatedAnswerSchema>[]> {
  const { provider } = input;

  const quality = input.responseQualityMode === 'premium' ? 'PREMIUM' : 'STANDARD';
  const modelChoice = selectModel(quality, 'default', provider.name);

  const response = await fetch(`${provider.baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${provider.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: modelChoice.model,
      [maxTokensField(provider.name)]: 4000,
      temperature: modelChoice.temperature,
      frequency_penalty: 0.15,
      messages: [
        {
          role: 'system',
          content:
            'You are an expert interview coach who writes specific, candidate-ready answers that sound natural when spoken out loud.',
        },
        {
          role: 'user',
          content: buildPreGenerationPrompt(input),
        },
      ],
    }),
  });

  const payload = (await response.json()) as {
    choices?: { message?: { content?: string | null } }[];
    error?: { message?: string };
  };

  if (!response.ok) {
    throw new ValidationError(payload.error?.message || `AI request failed (${response.status})`);
  }

  const content = payload.choices?.[0]?.message?.content?.trim();
  if (!content) {
    throw new ValidationError('AI provider returned an empty answer bank response.');
  }

  return parseGeneratedAnswers(content).map((item) => generatedAnswerSchema.parse(item));
}

function buildPreGenerationPrompt(input: {
  resumeText: string;
  jobDescription: string;
  interviewType: string;
  maxQuestions: number;
  responseQualityMode: 'standard' | 'premium';
}): string {
  return `
You are preparing a candidate for a demanding interview.
Based on the candidate's resume and the target job description, generate ${input.maxQuestions}
likely interview questions and strong candidate-ready answers.

RESUME:
${input.resumeText}

JOB DESCRIPTION:
${input.jobDescription}

INTERVIEW TYPE:
${input.interviewType}

RESPONSE QUALITY MODE:
${
  input.responseQualityMode === 'premium'
    ? 'Top-tier. Answers should be action-heavy, quantified when supported, explicit about judgment and tradeoffs, and strong enough to impress a senior interviewer without sounding scripted.'
    : 'Standard. Answers should be concise, direct, and natural out loud.'
}

Return ONLY a JSON array in this exact shape:
[
  {
    "question": "...",
    "answer": "...",
    "type": "behavioral|technical|systemDesign|coding|situational|background|curveball"
  }
]

Rules:
- Keep each answer realistic for live speech: roughly 45-85 words
- Use first person and natural spoken language
- Make answers specific with one concrete detail, tradeoff, metric, or implementation choice when relevant
- Behavioral answers should follow a compressed STAR structure
- In top-tier mode, lead with a stronger headline, spend most of the answer on the candidate's actions and decisions, and close on impact or judgment when useful
- Technical answers should mention mechanism, tradeoff, and one production concern
- Coding answers should mention approach, complexity, and one edge case
- Do not invent unsupported experience
- Output JSON only
  `.trim();
}

function parseGeneratedAnswers(content: string): Record<string, string>[] {
  let jsonString = content.trim();

  const firstBracket = jsonString.indexOf('[');
  const lastBracket = jsonString.lastIndexOf(']');
  if (firstBracket >= 0 && lastBracket > firstBracket) {
    jsonString = jsonString.slice(firstBracket, lastBracket + 1);
  }

  const parsed = JSON.parse(jsonString) as unknown;
  if (!Array.isArray(parsed)) {
    throw new ValidationError('OpenAI returned malformed answer bank JSON.');
  }

  return parsed.map((item) => {
    if (typeof item !== 'object' || item === null) {
      throw new ValidationError('OpenAI returned an invalid answer bank item.');
    }

    const record = item as Record<string, unknown>;
    return {
      question: String(record.question ?? '').trim(),
      answer: String(record.answer ?? '').trim(),
      type: String(record.type ?? 'unknown').trim(),
    };
  });
}

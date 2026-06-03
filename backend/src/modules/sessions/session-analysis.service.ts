import OpenAI from 'openai';

import { withDatabaseRetry } from '../../config/database.js';
import { resolveChatProvider, type ChatProviderName } from '../ai/ai.provider.js';
import { selectModel } from '../billing/billing.constants.js';

interface ExchangeData {
  questionTranscript: string;
  questionType: string;
  generatedResponse: string;
  responseLatencyMs: number;
  wasPreComputed: boolean;
  sequenceOrder: number;
}

interface SessionData {
  id: string;
  resumeText: string;
  jobDescription: string;
  interviewType: string;
  startedAt: Date;
  endedAt: Date | null;
  exchanges: ExchangeData[];
}

interface AnalysisResult {
  technicalAccuracyScore: number;
  communicationScore: number;
  confidenceScore: number;
  overallScore: number;
  aiStrengths: string[];
  aiImprovements: string[];
  exchangeFeedback: ExchangeFeedback[];
}

interface ExchangeFeedback {
  sequenceOrder: number;
  score: number;
  verdict: 'strong' | 'adequate' | 'weak';
  feedback: string;
}

const analysisResponseSchema = {
  type: 'json_schema' as const,
  json_schema: {
    name: 'interview_analysis',
    strict: true,
    schema: {
      type: 'object',
      required: [
        'technicalAccuracyScore',
        'communicationScore',
        'confidenceScore',
        'overallScore',
        'aiStrengths',
        'aiImprovements',
        'exchangeFeedback',
      ],
      additionalProperties: false,
      properties: {
        technicalAccuracyScore: {
          type: 'number',
          description: '0-100 score for technical accuracy and depth',
        },
        communicationScore: {
          type: 'number',
          description: '0-100 score for communication quality',
        },
        confidenceScore: { type: 'number', description: '0-100 score for confidence and delivery' },
        overallScore: { type: 'number', description: '0-100 weighted overall score' },
        aiStrengths: {
          type: 'array',
          items: { type: 'string' },
          description: '4-6 specific strengths with evidence from the transcript',
        },
        aiImprovements: {
          type: 'array',
          items: { type: 'string' },
          description: '4-6 specific, actionable improvement areas with evidence',
        },
        exchangeFeedback: {
          type: 'array',
          items: {
            type: 'object',
            required: ['sequenceOrder', 'score', 'verdict', 'feedback'],
            additionalProperties: false,
            properties: {
              sequenceOrder: { type: 'number' },
              score: { type: 'number', description: '0-100 score for this specific exchange' },
              verdict: { type: 'string', enum: ['strong', 'adequate', 'weak'] },
              feedback: {
                type: 'string',
                description: '2-3 sentence specific feedback for this exchange',
              },
            },
          },
        },
      },
    },
  },
};

// OpenAI-compatible providers (DeepSeek, Groq) support `{ type: 'json_object' }`
// but not OpenAI's strict json_schema response_format, so the exact shape must be
// pinned in the prompt instead (json_object mode also requires the word "json").
const JSON_SHAPE_INSTRUCTION = `Respond with ONLY a single valid JSON object — no markdown, no code fences — matching exactly this shape:
{
  "technicalAccuracyScore": <number 0-100>,
  "communicationScore": <number 0-100>,
  "confidenceScore": <number 0-100>,
  "overallScore": <number 0-100>,
  "aiStrengths": [<4-6 strings, each citing specific transcript evidence>],
  "aiImprovements": [<4-6 actionable strings, each citing specific transcript evidence>],
  "exchangeFeedback": [{ "sequenceOrder": <number>, "score": <number 0-100>, "verdict": "strong" | "adequate" | "weak", "feedback": <string, 2-3 sentences> }]
}`;

function buildAnalysisPrompt(session: SessionData): string {
  const durationMinutes = session.endedAt
    ? Math.round((session.endedAt.getTime() - session.startedAt.getTime()) / 60000)
    : null;

  const exchangeTranscript = session.exchanges
    .sort((a, b) => a.sequenceOrder - b.sequenceOrder)
    .map((e, i) => {
      const latencyNote = e.wasPreComputed
        ? '(pre-computed answer)'
        : `(${e.responseLatencyMs}ms latency)`;
      return [
        `--- Exchange ${i + 1} [${e.questionType}] ${latencyNote} ---`,
        `INTERVIEWER: ${e.questionTranscript}`,
        `CANDIDATE RESPONSE: ${e.generatedResponse}`,
      ].join('\n');
    })
    .join('\n\n');

  return `You are a senior interview assessment specialist used by top tech companies (Google, Meta, Amazon, Stripe) to evaluate candidate performance. You analyze interview transcripts with the same rigor as enterprise AI interview platforms like HireVue, Karat, and Interviewing.io.

EVALUATION FRAMEWORK — apply all of these criteria:

## 1. TECHNICAL ACCURACY (0-100)
- **Correctness**: Are claims factually accurate? Are technical concepts used properly?
- **Depth vs. surface-level**: Does the candidate go beyond buzzword-dropping to demonstrate real understanding?
- **Specificity**: Are concrete examples given (real numbers, architectures, tools) vs. vague generalities?
- **Trade-off awareness**: Does the candidate acknowledge limitations, alternatives, and edge cases?
- **Relevance to role**: Do responses align with the job description requirements?

## 2. COMMUNICATION QUALITY (0-100)
- **Structure**: Are responses organized (situation-action-result, or clear logical flow)?
- **Conciseness**: Answers should be thorough but not rambling. Ideal: 60-120 seconds speaking equivalent.
- **Clarity**: Simple, direct language. No jargon soup. Explains complex ideas accessibly.
- **Authenticity detection**: Does this sound like a real person speaking from experience, or like someone reading a scripted answer? Look for:
  - Natural hedging ("I think", "from my experience") vs. robotic certainty
  - Personal narrative details vs. generic template answers
  - Conversational transitions vs. essay-style structure
  - First-person ownership ("I built", "I decided") vs. passive voice
- **Filler and hedging**: Note excessive filler words, over-qualification, or lack of commitment to answers.

## 3. CONFIDENCE & DELIVERY (0-100)
- **Response speed**: How quickly did the candidate begin answering? (<1s = very confident, 1-2s = normal, >3s = hesitant)
- **Consistency**: Similar quality across different question types, or did they crumble on certain topics?
- **Adaptability**: Did they handle follow-ups and curveballs well, or only prepared questions?
- **Completeness**: Did they fully address the question or leave key parts unanswered?
- **Reading detection**: Does the pacing/structure suggest the candidate is reading from a screen rather than speaking naturally? Indicators:
  - Unnaturally perfect grammar and sentence structure
  - Responses that are too polished for extemporaneous speech
  - Lack of verbal thinking markers ("let me think...", "so basically...")
  - Every response hitting the same length/structure pattern

## 4. OVERALL SCORE (0-100)
Weighted: Technical 40% + Communication 35% + Confidence 25%.
Apply harsh but fair grading — a 70 means "would likely pass screening", 85+ means "strong hire signal".

## SCORING CALIBRATION
- 90-100: Exceptional — hire-level performance at top companies
- 80-89: Strong — would advance to next round at most companies
- 70-79: Adequate — borderline, depends on competition
- 60-69: Below average — significant gaps that would raise concerns
- Below 60: Weak — fundamental issues with preparation or fit

## STRENGTHS & IMPROVEMENTS
- Provide exactly 4-6 of each
- Each must cite specific evidence from the transcript (quote or reference specific exchanges)
- Improvements must be actionable — "do X instead of Y" format
- Strengths should highlight what would impress an interviewer specifically
- Do NOT give generic advice. Every point must be tied to something the candidate actually said or did.

## PER-EXCHANGE FEEDBACK
For each exchange, provide:
- A score (0-100) reflecting how well that specific question was answered
- A verdict: "strong" (would impress), "adequate" (acceptable), "weak" (concerning)
- 2-3 sentences of specific feedback: what worked, what didn't, what would improve it

---

INTERVIEW CONTEXT:
- Interview type: ${session.interviewType}
- Duration: ${durationMinutes ? `${durationMinutes} minutes` : 'unknown'}
- Total exchanges: ${session.exchanges.length}

CANDIDATE RESUME:
${session.resumeText.slice(0, 3000)}

JOB DESCRIPTION:
${session.jobDescription.slice(0, 2000)}

FULL INTERVIEW TRANSCRIPT:
${exchangeTranscript}

---

Analyze this interview thoroughly. Be specific, evidence-based, and calibrated to real tech interview standards. Do not inflate scores — an average interview should score around 65-75, not 85+.`;
}

export async function analyzeSession(
  sessionId: string,
  userId: string,
  preferredProvider?: ChatProviderName | null
): Promise<AnalysisResult> {
  const session = await withDatabaseRetry((prisma) =>
    prisma.interviewSession.findFirst({
      where: { id: sessionId, userId },
      include: { exchanges: { orderBy: { sequenceOrder: 'asc' } } },
    })
  );

  if (!session) {
    throw new Error('Session not found');
  }

  if (session.exchanges.length === 0) {
    throw new Error('No exchanges to analyze');
  }

  // If already analyzed, return cached result
  if (session.overallScore !== null && session.aiStrengths !== null) {
    return {
      technicalAccuracyScore: session.technicalAccuracyScore ?? 0,
      communicationScore: session.communicationScore ?? 0,
      confidenceScore: session.confidenceScore ?? 0,
      overallScore: session.overallScore,
      aiStrengths: (session.aiStrengths as string[]) ?? [],
      aiImprovements: (session.aiImprovements as string[]) ?? [],
      exchangeFeedback: [],
    };
  }

  const provider = resolveChatProvider(preferredProvider);
  const openai = new OpenAI({ apiKey: provider.apiKey, baseURL: provider.baseUrl });
  const useStrictSchema = provider.name === 'openai';

  // OpenAI uses its premium analysis model; OpenAI-compatible providers use the
  // model their PREMIUM tier resolves to (deepseek-chat or the env GROQ_MODEL).
  const model = useStrictSchema
    ? 'gpt-4.1'
    : selectModel('PREMIUM', 'default', provider.name).model;

  const prompt = useStrictSchema
    ? buildAnalysisPrompt(session)
    : `${buildAnalysisPrompt(session)}\n\n${JSON_SHAPE_INSTRUCTION}`;

  const completion = await openai.chat.completions.create({
    model,
    messages: [{ role: 'user', content: prompt }],
    response_format: useStrictSchema ? analysisResponseSchema : { type: 'json_object' },
    temperature: 0.3,
    max_tokens: 4000,
  });

  const content = completion.choices[0]?.message?.content;
  if (!content) {
    throw new Error('Empty analysis response from AI');
  }

  // OpenAI strict mode returns bare JSON; json_object mode does too, but strip
  // any stray code fences defensively before parsing.
  const jsonText = content
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '');
  const analysis = JSON.parse(jsonText) as AnalysisResult;

  // Clamp scores to 0-100
  analysis.technicalAccuracyScore = Math.max(
    0,
    Math.min(100, Math.round(analysis.technicalAccuracyScore))
  );
  analysis.communicationScore = Math.max(0, Math.min(100, Math.round(analysis.communicationScore)));
  analysis.confidenceScore = Math.max(0, Math.min(100, Math.round(analysis.confidenceScore)));
  analysis.overallScore = Math.max(0, Math.min(100, Math.round(analysis.overallScore)));

  // Persist scores to database
  await withDatabaseRetry((prisma) =>
    prisma.interviewSession.update({
      where: { id: sessionId },
      data: {
        technicalAccuracyScore: analysis.technicalAccuracyScore,
        communicationScore: analysis.communicationScore,
        confidenceScore: analysis.confidenceScore,
        overallScore: analysis.overallScore,
        aiStrengths: analysis.aiStrengths,
        aiImprovements: analysis.aiImprovements,
      },
    })
  );

  return analysis;
}

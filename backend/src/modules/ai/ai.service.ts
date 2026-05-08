import type { InterviewQuality } from '@prisma/client';

import { getEnv } from '../../config/env.js';
import { AppError, PaymentRequiredError } from '../../utils/errors.js';
import { getLogger } from '../../utils/logger.js';
import { type ModelChoice, selectModel } from '../billing/billing.constants.js';
import {
  authorizeAiCall,
  canAccessRuntimeAiConfig,
  getBillingSummary,
} from '../billing/billing.service.js';

import type {
  ChatInput,
  ChatStreamInput,
  RealtimeSessionInput,
  TranscriptionSessionInput,
} from './ai.schema.js';

const OPENAI_BASE = 'https://api.openai.com/v1';
const DEEPGRAM_BASE = 'https://api.deepgram.com/v1';

const REALTIME_DEFAULT_MODEL = 'gpt-realtime';

const log = getLogger().child({ module: 'ai' });

interface OpenAIRealtimeSessionResponse {
  id: string;
  object: string;
  model: string;
  client_secret: { value: string; expires_at: number };
}

interface DeepgramKeyResponse {
  api_key_id: string;
  key: string;
  scopes: string[];
  expiration_date: string | null;
}

export interface RealtimeSessionResult {
  sessionId: string;
  model: string;
  clientSecret: string;
  expiresAt: number;
}

export interface TranscriptionSessionResult {
  apiKey: string;
  expiresAt: number | null;
  ephemeral: boolean;
}

async function ensureBillingAccess(userId: string): Promise<void> {
  const allowed = await canAccessRuntimeAiConfig(userId);
  if (!allowed) {
    throw new PaymentRequiredError(
      'Your monthly interview quota is exhausted. Upgrade to continue.'
    );
  }
}

function requireOpenAIKey(): string {
  const env = getEnv();
  if (!env.OPENAI_API_KEY || env.OPENAI_API_KEY.length === 0) {
    throw new AppError(503, 'OpenAI API key not configured on the server', 'AI_NOT_CONFIGURED');
  }
  return env.OPENAI_API_KEY;
}

function requireDeepgramKey(): string {
  const env = getEnv();
  if (!env.DEEPGRAM_API_KEY || env.DEEPGRAM_API_KEY.length === 0) {
    throw new AppError(503, 'Deepgram API key not configured on the server', 'AI_NOT_CONFIGURED');
  }
  return env.DEEPGRAM_API_KEY;
}

export async function createRealtimeSession(
  userId: string,
  input: RealtimeSessionInput
): Promise<RealtimeSessionResult> {
  // Voice Prep is Premium-only. The grant lookup verifies ownership AND tier eligibility:
  // claimInterviewAccess(VOICE_PREP, ...) refuses to issue grants for non-Premium tiers.
  const authorized = await authorizeAiCall(userId, input.sessionClientId, 'default');
  const summary = await getBillingSummary(userId);
  if (!summary.featureFlags.voice_prep) {
    log.warn(
      { event: 'ai.feature.gated', userId, feature: 'voice_prep', tier: summary.tier },
      'Voice Prep blocked by tier'
    );
    throw new PaymentRequiredError('Voice Prep is a Premium-only feature.', {
      requiredFeature: 'voice_prep',
      currentTier: summary.tier,
    });
  }

  const apiKey = requireOpenAIKey();
  const env = getEnv();
  // Realtime model is governed by env (not yet differentiated by quality), but we still log
  // the resolved quality so downstream cost reporting can attribute usage correctly.
  const model = env.OPENAI_REALTIME_MODEL || REALTIME_DEFAULT_MODEL;

  const body: Record<string, unknown> = {
    model,
    modalities: ['audio', 'text'],
    instructions: input.instructions,
    voice: input.voice,
    input_audio_format: input.inputAudioFormat,
    output_audio_format: input.outputAudioFormat,
  };

  if (input.inputAudioTranscription) {
    body.input_audio_transcription = {
      model: input.inputAudioTranscription.model,
      language: input.inputAudioTranscription.language,
    };
  }

  if (input.turnDetection) {
    body.turn_detection = {
      type: input.turnDetection.type,
      threshold: input.turnDetection.threshold,
      prefix_padding_ms: input.turnDetection.prefixPaddingMs,
      silence_duration_ms: input.turnDetection.silenceDurationMs,
    };
  }

  const response = await fetch(`${OPENAI_BASE}/realtime/sessions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'OpenAI-Beta': 'realtime=v1',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new AppError(
      502,
      `OpenAI Realtime session creation failed (${response.status}): ${text.slice(0, 200)}`,
      'AI_UPSTREAM_ERROR'
    );
  }

  const data = (await response.json()) as OpenAIRealtimeSessionResponse;

  log.info(
    {
      event: 'ai.model.served',
      userId,
      sessionClientId: input.sessionClientId,
      surface: 'realtime',
      quality: authorized.quality,
      tier: authorized.tier,
      model: data.model,
    },
    'Realtime session minted'
  );

  return {
    sessionId: data.id,
    model: data.model,
    clientSecret: data.client_secret.value,
    expiresAt: data.client_secret.expires_at,
  };
}

export async function createTranscriptionSession(
  userId: string,
  input: TranscriptionSessionInput
): Promise<TranscriptionSessionResult> {
  await ensureBillingAccess(userId);
  const masterKey = requireDeepgramKey();
  const env = getEnv();

  const projectId = env.DEEPGRAM_PROJECT_ID;
  if (!projectId) {
    return {
      apiKey: masterKey,
      expiresAt: null,
      ephemeral: false,
    };
  }

  const response = await fetch(`${DEEPGRAM_BASE}/projects/${projectId}/keys`, {
    method: 'POST',
    headers: {
      Authorization: `Token ${masterKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      comment: `ip-user-${userId}-${Date.now()}`,
      scopes: ['usage:write'],
      time_to_live_in_seconds: input.ttlSeconds,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new AppError(
      502,
      `Deepgram key provisioning failed (${response.status}): ${text.slice(0, 200)}`,
      'AI_UPSTREAM_ERROR'
    );
  }

  const data = (await response.json()) as DeepgramKeyResponse;
  const expiresAt = data.expiration_date ? new Date(data.expiration_date).getTime() / 1000 : null;

  return {
    apiKey: data.key,
    expiresAt,
    ephemeral: true,
  };
}

function buildOpenAIBody(
  input: ChatInput | ChatStreamInput,
  model: ModelChoice,
  stream: boolean
): Record<string, unknown> {
  const body: Record<string, unknown> = {
    model: model.model,
    messages: input.messages,
    max_completion_tokens: model.maxTokens,
  };
  // Server-resolved temperature wins. Client-supplied temperature is allowed for fine control
  // but capped to the quality's ceiling so a Standard caller cannot run a Premium-temperature
  // experiment that costs more.
  body.temperature =
    typeof input.temperature === 'number'
      ? Math.min(input.temperature, model.temperature + 0.1)
      : model.temperature;

  if (typeof input.top_p === 'number') body.top_p = input.top_p;
  if (typeof input.frequency_penalty === 'number') body.frequency_penalty = input.frequency_penalty;
  if (typeof input.presence_penalty === 'number') body.presence_penalty = input.presence_penalty;
  if (input.response_format) body.response_format = input.response_format;

  if (stream) {
    body.stream = true;
    if ('stream_options' in input && input.stream_options) {
      body.stream_options = input.stream_options;
    }
  }

  return body;
}

export async function chatCompletion(userId: string, input: ChatInput): Promise<unknown> {
  const authorized = await authorizeAiCall(userId, input.sessionClientId, input.routing);
  await ensureBillingAccess(userId);
  const apiKey = requireOpenAIKey();

  const body = buildOpenAIBody(input, authorized.model, false);

  const response = await fetch(`${OPENAI_BASE}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const text = await response.text();
  if (!response.ok) {
    throw new AppError(
      response.status >= 500 ? 502 : response.status,
      `OpenAI chat completion failed (${response.status}): ${text.slice(0, 500)}`,
      'AI_UPSTREAM_ERROR'
    );
  }

  log.info(
    {
      event: 'ai.model.served',
      userId,
      sessionClientId: input.sessionClientId,
      surface: 'chat',
      quality: authorized.quality,
      tier: authorized.tier,
      routing: input.routing,
      model: authorized.model.model,
      maxTokens: authorized.model.maxTokens,
    },
    'Chat completion served'
  );

  try {
    return JSON.parse(text);
  } catch {
    throw new AppError(502, 'OpenAI returned non-JSON response', 'AI_UPSTREAM_ERROR');
  }
}

export async function chatCompletionStream(
  userId: string,
  input: ChatStreamInput
): Promise<{ upstream: Response; resolvedQuality: InterviewQuality; resolvedModel: string }> {
  const authorized = await authorizeAiCall(userId, input.sessionClientId, input.routing);
  await ensureBillingAccess(userId);
  const apiKey = requireOpenAIKey();

  const body = buildOpenAIBody(input, authorized.model, true);

  const response = await fetch(`${OPENAI_BASE}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok || !response.body) {
    const text = await response.text().catch(() => '');
    throw new AppError(
      response.status >= 500 ? 502 : response.status,
      `OpenAI chat stream failed (${response.status}): ${text.slice(0, 500)}`,
      'AI_UPSTREAM_ERROR'
    );
  }

  log.info(
    {
      event: 'ai.model.served',
      userId,
      sessionClientId: input.sessionClientId,
      surface: 'chat_stream',
      quality: authorized.quality,
      tier: authorized.tier,
      routing: input.routing,
      model: authorized.model.model,
      maxTokens: authorized.model.maxTokens,
    },
    'Chat stream opened'
  );

  return {
    upstream: response,
    resolvedQuality: authorized.quality,
    resolvedModel: authorized.model.model,
  };
}

// Re-export so other modules (e.g. session analysis) can resolve a model without the proxy.
export { selectModel };

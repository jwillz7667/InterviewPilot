import { getEnv } from '../../config/env.js';
import { AppError, PaymentRequiredError, ValidationError } from '../../utils/errors.js';
import { canAccessRuntimeAiConfig } from '../billing/billing.service.js';
import type {
  ChatInput,
  ChatStreamInput,
  RealtimeSessionInput,
  TranscriptionSessionInput,
} from './ai.schema.js';

const OPENAI_BASE = 'https://api.openai.com/v1';
const DEEPGRAM_BASE = 'https://api.deepgram.com/v1';

const REALTIME_DEFAULT_MODEL = 'gpt-realtime';
const MAX_OUTPUT_TOKENS_PER_REQUEST = 4000;

type OpenAIRealtimeSessionResponse = {
  id: string;
  object: string;
  model: string;
  client_secret: { value: string; expires_at: number };
};

type DeepgramKeyResponse = {
  api_key_id: string;
  key: string;
  scopes: string[];
  expiration_date: string | null;
};

export type RealtimeSessionResult = {
  sessionId: string;
  model: string;
  clientSecret: string;
  expiresAt: number;
};

export type TranscriptionSessionResult = {
  apiKey: string;
  expiresAt: number | null;
  ephemeral: boolean;
};

async function ensureBillingAccess(userId: string): Promise<void> {
  const allowed = await canAccessRuntimeAiConfig(userId);
  if (!allowed) {
    throw new PaymentRequiredError('Your free trial is complete. Upgrade to continue.');
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
  await ensureBillingAccess(userId);
  const apiKey = requireOpenAIKey();

  const env = getEnv();
  const model = input.model ?? env.OPENAI_REALTIME_MODEL ?? REALTIME_DEFAULT_MODEL;

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
    // Fallback: mint nothing — return master key with short cache TTL on the client.
    // This matches pre-fix behavior but should be removed once DEEPGRAM_PROJECT_ID is set.
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

function applyTokenCap(body: Record<string, unknown>): Record<string, unknown> {
  const out = { ...body };
  if (typeof out.max_tokens === 'number') {
    out.max_tokens = Math.min(out.max_tokens, MAX_OUTPUT_TOKENS_PER_REQUEST);
  } else if (typeof out.max_completion_tokens === 'number') {
    out.max_completion_tokens = Math.min(out.max_completion_tokens, MAX_OUTPUT_TOKENS_PER_REQUEST);
  } else {
    out.max_tokens = MAX_OUTPUT_TOKENS_PER_REQUEST;
  }
  return out;
}

export async function chatCompletion(userId: string, input: ChatInput): Promise<unknown> {
  await ensureBillingAccess(userId);
  const apiKey = requireOpenAIKey();

  const body = applyTokenCap({ ...(input as Record<string, unknown>) });
  if ('stream' in body) {
    throw new ValidationError('Use /api/v1/ai/chat/stream for streaming responses');
  }

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

  try {
    return JSON.parse(text);
  } catch {
    throw new AppError(502, 'OpenAI returned non-JSON response', 'AI_UPSTREAM_ERROR');
  }
}

export async function chatCompletionStream(
  userId: string,
  input: ChatStreamInput
): Promise<Response> {
  await ensureBillingAccess(userId);
  const apiKey = requireOpenAIKey();

  const body = applyTokenCap({
    ...(input as Record<string, unknown>),
    stream: true,
  });

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

  return response;
}

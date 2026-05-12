import { randomBytes } from 'node:crypto';
import https from 'node:https';

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

interface DeepgramErrorBody {
  category?: string;
  message?: string;
  details?: string;
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

// When the configured master Deepgram key lacks `keys:write`, every interview
// start would otherwise 502. We probe once, cache the verdict for 10 minutes,
// and quietly degrade to returning the master key directly — Deepgram's WSS
// accepts it for transcription as long as the key has `usage:write`. The TTL
// keeps a manual fix (rotating the master key with the right scope) from
// requiring a redeploy.
const KEY_MINT_FALLBACK_TTL_MS = 10 * 60 * 1000;
let keyMintFallbackUntil = 0;
let keyMintFallbackReason: string | null = null;

function shouldSkipKeyMint(): boolean {
  return Date.now() < keyMintFallbackUntil;
}

function activateKeyMintFallback(reason: string): void {
  keyMintFallbackUntil = Date.now() + KEY_MINT_FALLBACK_TTL_MS;
  keyMintFallbackReason = reason;
}

function clearKeyMintFallback(): void {
  keyMintFallbackUntil = 0;
  keyMintFallbackReason = null;
}

function parseDeepgramError(text: string): DeepgramErrorBody | null {
  try {
    return JSON.parse(text) as DeepgramErrorBody;
  } catch {
    return null;
  }
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
    // No project configured — master key is the intended credential.
    return {
      apiKey: masterKey,
      expiresAt: null,
      ephemeral: false,
    };
  }

  // If a recent mint attempt failed for a permissions reason, skip the round-trip
  // and serve the master key. The fallback window is short enough that an ops
  // fix (rotating the master key with `keys:write`) is honored within minutes.
  if (shouldSkipKeyMint()) {
    log.debug(
      {
        event: 'deepgram.key.mint.skipped',
        userId,
        reason: keyMintFallbackReason,
        retryAt: new Date(keyMintFallbackUntil).toISOString(),
      },
      'Skipping Deepgram key mint (fallback active)'
    );
    return masterKeyFallback(masterKey);
  }

  let response: Response;
  try {
    response = await fetch(`${DEEPGRAM_BASE}/projects/${projectId}/keys`, {
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
  } catch (err) {
    log.warn(
      { event: 'deepgram.key.mint.network', userId, err },
      'Deepgram key mint network error — serving master key'
    );
    activateKeyMintFallback('network_error');
    return masterKeyFallback(masterKey);
  }

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    const parsed = parseDeepgramError(text);
    const isPermissionDenied =
      response.status === 401 ||
      response.status === 403 ||
      parsed?.category === 'INSUFFICIENT_PERMISSIONS';

    if (isPermissionDenied) {
      // Most common cause: master key lacks `keys:write`. The key still works
      // for transcription, so degrade rather than failing the live session.
      log.warn(
        {
          event: 'deepgram.key.mint.scope_missing',
          userId,
          status: response.status,
          category: parsed?.category,
          message: parsed?.message,
          remediation:
            'Rotate DEEPGRAM_API_KEY to a key with the `keys:write` scope to restore ephemeral key minting.',
        },
        'Deepgram master key lacks keys:write — falling back to master key'
      );
      activateKeyMintFallback(`http_${response.status}_${parsed?.category ?? 'permission_denied'}`);
      return masterKeyFallback(masterKey);
    }

    if (response.status >= 500) {
      // Upstream Deepgram outage — short-circuit subsequent calls and serve
      // the master key so users can keep transcribing.
      log.warn(
        {
          event: 'deepgram.key.mint.upstream_error',
          userId,
          status: response.status,
          body: text.slice(0, 200),
        },
        'Deepgram key mint failed upstream — falling back to master key'
      );
      activateKeyMintFallback(`http_${response.status}`);
      return masterKeyFallback(masterKey);
    }

    // 4xx other than auth — likely a configuration problem worth surfacing.
    log.error(
      {
        event: 'deepgram.key.mint.failed',
        userId,
        status: response.status,
        body: text.slice(0, 200),
      },
      'Deepgram key mint failed with unexpected status'
    );
    throw new AppError(
      502,
      'Transcription credentials are temporarily unavailable. Please retry shortly.',
      'TRANSCRIPTION_UNAVAILABLE'
    );
  }

  const data = (await response.json()) as DeepgramKeyResponse;
  // Successful mint clears any prior fallback so future calls retry the
  // happy path immediately if ops fixed the scope mid-window.
  if (keyMintFallbackUntil !== 0) clearKeyMintFallback();

  const expiresAt = data.expiration_date ? new Date(data.expiration_date).getTime() / 1000 : null;

  return {
    apiKey: data.key,
    expiresAt,
    ephemeral: true,
  };
}

function masterKeyFallback(masterKey: string): TranscriptionSessionResult {
  // Master keys are long-lived; the iOS client caps cache to 5 minutes when
  // expiresAt is null, so a rotated master key takes effect on the next reload.
  return { apiKey: masterKey, expiresAt: null, ephemeral: false };
}

interface StreamingProbeResult {
  ok: boolean;
  status: number | null;
  body: string;
  error?: string;
}

// Opens a raw HTTPS Upgrade request against Deepgram's streaming endpoint and
// captures the upgrade response so callers can see WHY Deepgram refused the
// WSS (401 invalid key, 402 no credits, 403 missing scope, 400 bad params).
// Node's WebSocket API hides this; native https.request exposes it.
function probeDeepgramStreaming(apiKey: string): Promise<StreamingProbeResult> {
  return new Promise((resolve) => {
    const wsKey = randomBytes(16).toString('base64');
    // Mirror the exact iOS query params so the probe and the real client hit
    // the same accept/reject path on Deepgram's side.
    const path =
      '/v1/listen?model=nova-3&language=en&smart_format=true&interim_results=true' +
      '&utterance_end_ms=800&vad_events=true&encoding=linear16&sample_rate=16000' +
      '&channels=1&endpointing=350';

    const req = https.request({
      host: 'api.deepgram.com',
      port: 443,
      path,
      method: 'GET',
      headers: {
        Authorization: `Token ${apiKey}`,
        Upgrade: 'websocket',
        Connection: 'Upgrade',
        'Sec-WebSocket-Key': wsKey,
        'Sec-WebSocket-Version': '13',
      },
      timeout: 5000,
    });

    let settled = false;
    const settle = (result: StreamingProbeResult) => {
      if (settled) return;
      settled = true;
      resolve(result);
    };

    req.on('upgrade', (_res, socket) => {
      socket.destroy();
      settle({ ok: true, status: 101, body: '' });
    });

    req.on('response', (res) => {
      let body = '';
      res.on('data', (chunk: Buffer) => {
        if (body.length < 500) body += chunk.toString('utf8');
      });
      res.on('end', () => {
        settle({ ok: false, status: res.statusCode ?? null, body: body.slice(0, 500) });
      });
    });

    req.on('error', (err) => {
      settle({ ok: false, status: null, body: '', error: err.message });
    });

    req.on('timeout', () => {
      req.destroy();
      settle({ ok: false, status: null, body: '', error: 'timeout' });
    });

    req.end();
  });
}

// Probes the configured Deepgram master key at boot to verify it can mint
// ephemeral keys (i.e. holds `keys:write`). The only fully reliable check is
// to perform a real mint+delete — Deepgram does not expose a read-only
// "current member scopes" endpoint that works without knowing the member_id
// of the key's owner. The probe creates a tiny 30s-TTL key with `usage:write`
// and deletes it immediately. Never throws — the runtime fallback covers
// correctness; this just pre-warms operational state.
export async function probeDeepgramKeyScopes(): Promise<void> {
  const env = getEnv();
  if (!env.DEEPGRAM_API_KEY || !env.DEEPGRAM_PROJECT_ID) return;

  const projectId = env.DEEPGRAM_PROJECT_ID;
  const authHeader = `Token ${env.DEEPGRAM_API_KEY}`;

  let response: Response;
  try {
    response = await fetch(`${DEEPGRAM_BASE}/projects/${projectId}/keys`, {
      method: 'POST',
      headers: {
        Authorization: authHeader,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        comment: `ip-probe-${Date.now()}`,
        scopes: ['usage:write'],
        time_to_live_in_seconds: 30,
      }),
    });
  } catch (err) {
    // Network-level failure — not a permission problem. Leave fallback alone
    // so the first user request decides the truth.
    log.warn(
      { event: 'deepgram.key.probe.network', err },
      'Deepgram key probe network error; runtime fallback will handle it'
    );
    return;
  }

  if (response.ok) {
    const data = (await response.json().catch(() => null)) as DeepgramKeyResponse | null;
    if (!data?.api_key_id) {
      log.warn(
        { event: 'deepgram.key.probe.malformed', status: response.status },
        'Deepgram key probe returned a 2xx without api_key_id; runtime fallback will handle it'
      );
      return;
    }

    // A successful mint also clears any stale fallback window left by a
    // previous boot — ops fix is honored immediately.
    if (keyMintFallbackUntil !== 0) clearKeyMintFallback();
    log.info(
      { event: 'deepgram.key.probe.ok', scopes: data.scopes },
      'Deepgram master key has keys:write scope'
    );

    // Mint succeeded — now verify the minted key can actually open a streaming
    // WSS. This catches the failure mode where the project is otherwise valid
    // but streaming itself is rejected (no credits, model unavailable, etc.).
    const streamResult = await probeDeepgramStreaming(data.key);
    if (streamResult.ok) {
      log.info(
        { event: 'deepgram.streaming.probe.ok' },
        'Deepgram streaming upgrade accepted with minted key'
      );
    } else {
      log.warn(
        {
          event: 'deepgram.streaming.probe.failed',
          status: streamResult.status,
          body: streamResult.body,
          err: streamResult.error,
          remediation:
            'Deepgram refused the WSS upgrade for our streaming params. Likely causes: 401 invalid key, 402 no streaming credits, 403 missing usage:write or no streaming plan, 400 bad model/encoding/sample_rate.',
        },
        'Deepgram streaming upgrade rejected — live transcription will fail for users'
      );
    }

    // Fire-and-forget cleanup. A 30s-TTL key would auto-expire anyway, but
    // deleting keeps the project keyring tidy and short-circuits any rate
    // accounting on Deepgram's side.
    void fetch(`${DEEPGRAM_BASE}/projects/${projectId}/keys/${data.api_key_id}`, {
      method: 'DELETE',
      headers: { Authorization: authHeader },
    }).catch((err: unknown) => {
      log.debug(
        { event: 'deepgram.key.probe.cleanup_failed', err, apiKeyId: data.api_key_id },
        'Deepgram probe cleanup delete failed (key will auto-expire)'
      );
    });

    return;
  }

  const text = await response.text().catch(() => '');
  const parsed = parseDeepgramError(text);
  const isPermissionDenied =
    response.status === 401 ||
    response.status === 403 ||
    parsed?.category === 'INSUFFICIENT_PERMISSIONS';

  if (isPermissionDenied) {
    log.warn(
      {
        event: 'deepgram.key.probe.scope_missing',
        status: response.status,
        category: parsed?.category,
        message: parsed?.message,
        remediation:
          'The configured DEEPGRAM_API_KEY lacks `keys:write`. Per-user ephemeral key minting will fall back to the master key. Rotate to a Member-or-higher key with `keys:write` (or use an admin key) to restore ephemeral minting.',
      },
      'Deepgram master key missing keys:write scope'
    );
    activateKeyMintFallback(`probe_scope_missing_${response.status}`);
    return;
  }

  // Any other non-2xx (404, 405, 429, 5xx) is treated as a probe failure, not
  // a definitive permission verdict. Log it but leave the runtime path to make
  // the real call on the first user request — that way a transient Deepgram
  // hiccup at boot doesn't lock the backend into master-key mode for 10 min.
  log.warn(
    {
      event: 'deepgram.key.probe.failed',
      status: response.status,
      category: parsed?.category,
      body: text.slice(0, 200),
    },
    'Deepgram key probe failed with a non-permission status; runtime fallback will handle it'
  );
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

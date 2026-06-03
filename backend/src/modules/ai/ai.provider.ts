import { getEnv } from '../../config/env.js';
import { AppError } from '../../utils/errors.js';

// Chat-completion provider resolution. DeepSeek and Groq both expose an
// OpenAI-compatible API (same /chat/completions contract, Bearer auth, and SSE
// delta shape), so every chat surface — live stream, answer-bank pre-gen,
// post-session analysis — shares this single resolver. Deepgram (transcription)
// and the OpenAI realtime voice path are deliberately NOT routed through here.

export type ChatProviderName = 'openai' | 'deepseek' | 'groq';

export interface ChatProvider {
  name: ChatProviderName;
  // Base URL without a trailing slash and without `/chat/completions`; callers
  // append the path themselves (raw fetch) or hand it to the OpenAI SDK as baseURL.
  baseUrl: string;
  apiKey: string;
}

const OPENAI_CHAT_BASE = 'https://api.openai.com/v1';
const DEEPSEEK_DEFAULT_BASE = 'https://api.deepseek.com';
const GROQ_DEFAULT_BASE = 'https://api.groq.com/openai/v1';

type ResolvedEnv = ReturnType<typeof getEnv>;

// A provider is selectable only if the server actually holds a key for it. The
// iOS provider menu reads this list so a user can never pick a dead provider.
export function chatProviderHasKey(name: ChatProviderName, env: ResolvedEnv = getEnv()): boolean {
  switch (name) {
    case 'openai':
      return Boolean(env.OPENAI_API_KEY);
    case 'deepseek':
      return Boolean(env.DEEPSEEK_API_KEY);
    case 'groq':
      return Boolean(env.GROQ_API_KEY);
  }
}

export function availableChatProviders(env: ResolvedEnv = getEnv()): ChatProviderName[] {
  return (['openai', 'deepseek', 'groq'] as const).filter((name) => chatProviderHasKey(name, env));
}

function buildProvider(name: ChatProviderName, env: ResolvedEnv): ChatProvider {
  switch (name) {
    case 'deepseek':
      if (!env.DEEPSEEK_API_KEY) {
        throw new AppError(
          503,
          'DeepSeek API key not configured on the server',
          'AI_NOT_CONFIGURED'
        );
      }
      return {
        name: 'deepseek',
        baseUrl: (env.DEEPSEEK_BASE_URL || DEEPSEEK_DEFAULT_BASE).replace(/\/+$/, ''),
        apiKey: env.DEEPSEEK_API_KEY,
      };
    case 'groq':
      if (!env.GROQ_API_KEY) {
        throw new AppError(503, 'Groq API key not configured on the server', 'AI_NOT_CONFIGURED');
      }
      return {
        name: 'groq',
        baseUrl: (env.GROQ_BASE_URL || GROQ_DEFAULT_BASE).replace(/\/+$/, ''),
        apiKey: env.GROQ_API_KEY,
      };
    case 'openai':
      if (!env.OPENAI_API_KEY) {
        throw new AppError(503, 'OpenAI API key not configured on the server', 'AI_NOT_CONFIGURED');
      }
      return { name: 'openai', baseUrl: OPENAI_CHAT_BASE, apiKey: env.OPENAI_API_KEY };
  }
}

// `preferred` is a per-user override (from the iOS provider menu). It wins only
// when the server actually has a key for it; otherwise we fall back to the
// server-wide AI_CHAT_PROVIDER default so a stale preference can never wedge a
// live interview onto a dead provider.
export function resolveChatProvider(preferred?: ChatProviderName | null): ChatProvider {
  const env = getEnv();
  const choice = preferred && chatProviderHasKey(preferred, env) ? preferred : env.AI_CHAT_PROVIDER;
  return buildProvider(choice, env);
}

// DeepSeek and Groq's OpenAI-compatible endpoints honor only `max_tokens`;
// OpenAI's newer API expects `max_completion_tokens`. Returning the field name
// keeps the token cap from being silently dropped after a provider swap.
export function maxTokensField(provider: ChatProviderName): 'max_tokens' | 'max_completion_tokens' {
  return provider === 'openai' ? 'max_completion_tokens' : 'max_tokens';
}

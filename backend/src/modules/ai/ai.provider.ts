import { getEnv } from '../../config/env.js';
import { AppError } from '../../utils/errors.js';

// Chat-completion provider resolution. DeepSeek exposes an OpenAI-compatible API
// (same /chat/completions contract, Bearer auth, and SSE delta shape), so every
// chat surface — live stream, answer-bank pre-gen, post-session analysis —
// shares this single resolver. Deepgram (transcription) and the OpenAI realtime
// voice path are deliberately NOT routed through here.

export type ChatProviderName = 'openai' | 'deepseek';

export interface ChatProvider {
  name: ChatProviderName;
  // Base URL without a trailing slash and without `/chat/completions`; callers
  // append the path themselves (raw fetch) or hand it to the OpenAI SDK as baseURL.
  baseUrl: string;
  apiKey: string;
}

const OPENAI_CHAT_BASE = 'https://api.openai.com/v1';
const DEEPSEEK_DEFAULT_BASE = 'https://api.deepseek.com';

export function resolveChatProvider(): ChatProvider {
  const env = getEnv();

  if (env.AI_CHAT_PROVIDER === 'deepseek') {
    if (!env.DEEPSEEK_API_KEY) {
      throw new AppError(503, 'DeepSeek API key not configured on the server', 'AI_NOT_CONFIGURED');
    }
    return {
      name: 'deepseek',
      baseUrl: (env.DEEPSEEK_BASE_URL || DEEPSEEK_DEFAULT_BASE).replace(/\/+$/, ''),
      apiKey: env.DEEPSEEK_API_KEY,
    };
  }

  if (!env.OPENAI_API_KEY) {
    throw new AppError(503, 'OpenAI API key not configured on the server', 'AI_NOT_CONFIGURED');
  }
  return { name: 'openai', baseUrl: OPENAI_CHAT_BASE, apiKey: env.OPENAI_API_KEY };
}

// DeepSeek's OpenAI-compatible endpoint honors only `max_tokens`; OpenAI's newer
// API expects `max_completion_tokens`. Returning the field name keeps the token
// cap from being silently dropped after a provider swap.
export function maxTokensField(provider: ChatProviderName): 'max_tokens' | 'max_completion_tokens' {
  return provider === 'deepseek' ? 'max_tokens' : 'max_completion_tokens';
}

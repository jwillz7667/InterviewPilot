import { withDatabaseRetry } from '../../config/database.js';
import { type ChatProviderName } from '../ai/ai.provider.js';

const CHAT_PROVIDERS: readonly ChatProviderName[] = ['openai', 'deepseek', 'groq'];

function asChatProvider(value: string | null | undefined): ChatProviderName | null {
  return value && (CHAT_PROVIDERS as readonly string[]).includes(value)
    ? (value as ChatProviderName)
    : null;
}

// A user's persisted chat-provider override, or null when they have no
// preference (follow the server-wide AI_CHAT_PROVIDER default). The column is a
// free-form String in Prisma, so validate it back into the union defensively —
// a stale/unknown value resolves to "no preference" rather than a bad provider.
export async function getUserChatProvider(userId: string): Promise<ChatProviderName | null> {
  const row = await withDatabaseRetry((prisma) =>
    prisma.userSettings.findUnique({
      where: { userId },
      select: { chatProvider: true },
    })
  );

  return asChatProvider(row?.chatProvider);
}

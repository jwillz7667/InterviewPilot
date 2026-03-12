import { SessionMode } from '@prisma/client';
import { z } from 'zod';

export const sessionModeSchema = z.enum(['liveInterview', 'voicePrep']);

export const accessClaimSchema = z.object({
  sessionClientId: z.string().uuid(),
  sessionMode: sessionModeSchema,
});

export const appStoreSyncSchema = z.object({
  signedTransactions: z.array(z.string().min(1)).min(1).max(20),
});

export const appStoreNotificationSchema = z.object({
  signedPayload: z.string().min(1),
});

export type SessionModeInput = z.infer<typeof sessionModeSchema>;
export type AccessClaimInput = z.infer<typeof accessClaimSchema>;
export type AppStoreSyncInput = z.infer<typeof appStoreSyncSchema>;

export function toPrismaSessionMode(input: SessionModeInput): SessionMode {
  return input === 'voicePrep' ? SessionMode.VOICE_PREP : SessionMode.LIVE_INTERVIEW;
}

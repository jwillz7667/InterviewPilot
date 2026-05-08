import { InterviewQuality, SessionMode } from '@prisma/client';
import { z } from 'zod';

export const sessionModeSchema = z.enum(['liveInterview', 'voicePrep']);

export const interviewQualitySchema = z.enum(['STANDARD', 'PREMIUM']).default('STANDARD');

export const accessClaimSchema = z
  .object({
    sessionClientId: z.string().uuid(),
    sessionMode: sessionModeSchema,
    quality: interviewQualitySchema,
  })
  .strict();

export const appStoreSyncSchema = z
  .object({
    signedTransactions: z.array(z.string().min(1)).min(1).max(20),
  })
  .strict();

export const appStoreNotificationSchema = z
  .object({
    signedPayload: z.string().min(1),
  })
  .strict();

export type SessionModeInput = z.infer<typeof sessionModeSchema>;
export type AccessClaimInput = z.infer<typeof accessClaimSchema>;
export type AppStoreSyncInput = z.infer<typeof appStoreSyncSchema>;
export type InterviewQualityInput = z.infer<typeof interviewQualitySchema>;

export function toPrismaSessionMode(input: SessionModeInput): SessionMode {
  return input === 'voicePrep' ? SessionMode.VOICE_PREP : SessionMode.LIVE_INTERVIEW;
}

export function toPrismaQuality(input: InterviewQualityInput): InterviewQuality {
  return input === 'PREMIUM' ? InterviewQuality.PREMIUM : InterviewQuality.STANDARD;
}

import { z } from 'zod';

export const realtimeSessionSchema = z
  .object({
    instructions: z.string().min(1).max(20000),
    voice: z.string().min(1).max(64).default('alloy'),
    model: z.string().min(1).max(128).optional(),
    inputAudioFormat: z.enum(['pcm16', 'g711_ulaw', 'g711_alaw']).default('pcm16'),
    outputAudioFormat: z.enum(['pcm16', 'g711_ulaw', 'g711_alaw']).default('pcm16'),
    inputAudioTranscription: z
      .object({
        model: z.string().min(1).max(64).default('whisper-1'),
        language: z.string().min(2).max(8).default('en'),
      })
      .strict()
      .optional(),
    turnDetection: z
      .object({
        type: z.literal('server_vad').default('server_vad'),
        threshold: z.number().min(0).max(1).default(0.5),
        prefixPaddingMs: z.number().int().min(0).max(5000).default(300),
        silenceDurationMs: z.number().int().min(0).max(10000).default(700),
      })
      .strict()
      .optional(),
  })
  .strict();

export type RealtimeSessionInput = z.infer<typeof realtimeSessionSchema>;

export const transcriptionSessionSchema = z
  .object({
    keywords: z.array(z.string().min(1).max(100)).max(50).optional(),
    ttlSeconds: z.number().int().min(60).max(3600).default(900),
  })
  .strict();

export type TranscriptionSessionInput = z.infer<typeof transcriptionSessionSchema>;

const messageContentSchema = z.union([
  z.string().max(50000),
  z.array(
    z
      .object({
        type: z.enum(['text', 'image_url']),
        text: z.string().max(50000).optional(),
      })
      .passthrough()
  ),
]);

export const chatMessageSchema = z
  .object({
    role: z.enum(['system', 'user', 'assistant', 'tool', 'developer']),
    content: messageContentSchema,
    name: z.string().max(64).optional(),
  })
  .strict();

const baseChatSchema = z
  .object({
    model: z.string().min(1).max(128),
    messages: z.array(chatMessageSchema).min(1).max(64),
    max_tokens: z.number().int().min(1).max(8000).optional(),
    max_completion_tokens: z.number().int().min(1).max(8000).optional(),
    temperature: z.number().min(0).max(2).optional(),
    top_p: z.number().min(0).max(1).optional(),
    frequency_penalty: z.number().min(-2).max(2).optional(),
    presence_penalty: z.number().min(-2).max(2).optional(),
    response_format: z
      .object({ type: z.enum(['text', 'json_object']) })
      .strict()
      .optional(),
  })
  .strict();

export const chatSchema = baseChatSchema;
export type ChatInput = z.infer<typeof chatSchema>;

export const chatStreamSchema = baseChatSchema.extend({
  stream_options: z
    .object({ include_usage: z.boolean().optional() })
    .strict()
    .optional(),
});
export type ChatStreamInput = z.infer<typeof chatStreamSchema>;

import { describe, expect, it } from 'vitest';
import { ZodError } from 'zod';

import {
  chatSchema,
  chatStreamSchema,
  realtimeSessionSchema,
} from '../src/modules/ai/ai.schema.js';

const validChatBody = {
  sessionClientId: '550e8400-e29b-41d4-a716-446655440000',
  routing: 'default',
  messages: [{ role: 'user' as const, content: 'Tell me about yourself.' }],
};

describe('chatSchema — server-authoritative model gate', () => {
  it('accepts a clean payload that omits model/max_tokens', () => {
    const result = chatSchema.safeParse(validChatBody);
    expect(result.success).toBe(true);
  });

  it('rejects a client-supplied `model` field with unrecognized_keys', () => {
    const result = chatSchema.safeParse({ ...validChatBody, model: 'o4-mini' });
    expect(result.success).toBe(false);
    if (!result.success) {
      const issue = result.error.errors.find((e) => e.code === 'unrecognized_keys');
      expect(issue).toBeDefined();
      expect((issue as { keys?: string[] }).keys).toContain('model');
    }
  });

  it('rejects a client-supplied `max_tokens` field (token-cap is server-authoritative)', () => {
    const result = chatSchema.safeParse({ ...validChatBody, max_tokens: 4000 });
    expect(result.success).toBe(false);
  });

  it('rejects a client-supplied `max_output_tokens` alias', () => {
    const result = chatSchema.safeParse({ ...validChatBody, max_output_tokens: 4000 });
    expect(result.success).toBe(false);
  });

  it('rejects a sessionClientId that is not a UUID', () => {
    const result = chatSchema.safeParse({ ...validChatBody, sessionClientId: 'not-a-uuid' });
    expect(result.success).toBe(false);
  });

  it('rejects an unknown routing value (only default/technical/coding allowed)', () => {
    const result = chatSchema.safeParse({ ...validChatBody, routing: 'premium' });
    expect(result.success).toBe(false);
  });

  it('caps message count at 64', () => {
    const tooMany = Array.from({ length: 65 }, () => ({ role: 'user' as const, content: 'x' }));
    const result = chatSchema.safeParse({ ...validChatBody, messages: tooMany });
    expect(result.success).toBe(false);
  });
});

describe('chatStreamSchema — same security posture as chatSchema', () => {
  it('rejects a client-supplied model on the streaming endpoint', () => {
    const result = chatStreamSchema.safeParse({ ...validChatBody, model: 'gpt-4.1' });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.errors.some((e) => e.code === 'unrecognized_keys')).toBe(true);
    }
  });

  it('accepts the documented stream_options.include_usage flag', () => {
    const result = chatStreamSchema.safeParse({
      ...validChatBody,
      stream_options: { include_usage: true },
    });
    expect(result.success).toBe(true);
  });
});

describe('realtimeSessionSchema — voice prep gating starts at the schema layer', () => {
  it('accepts a clean realtime payload', () => {
    const result = realtimeSessionSchema.safeParse({
      sessionClientId: '550e8400-e29b-41d4-a716-446655440000',
      instructions: 'You are an interviewer.',
      voice: 'alloy',
    });
    expect(result.success).toBe(true);
  });

  it('rejects a client-supplied model on realtime sessions', () => {
    const result = realtimeSessionSchema.safeParse({
      sessionClientId: '550e8400-e29b-41d4-a716-446655440000',
      instructions: 'You are an interviewer.',
      voice: 'alloy',
      model: 'gpt-4o-realtime-preview-2024-10-01',
    });
    expect(result.success).toBe(false);
  });

  it('rejects an instructions string that exceeds 20k chars (input cap)', () => {
    const result = realtimeSessionSchema.safeParse({
      sessionClientId: '550e8400-e29b-41d4-a716-446655440000',
      instructions: 'x'.repeat(20_001),
      voice: 'alloy',
    });
    expect(result.success).toBe(false);
  });
});

describe('regression: prove ZodError surfaces unrecognized_keys for model field', () => {
  it('produces an error with the exact `keys: ["model"]` shape the audit logger relies on', () => {
    try {
      chatSchema.parse({ ...validChatBody, model: 'o4-mini' });
      throw new Error('should have thrown');
    } catch (err) {
      expect(err).toBeInstanceOf(ZodError);
      const zodErr = err as ZodError;
      const unrecognizedIssue = zodErr.errors.find((e) => e.code === 'unrecognized_keys') as
        | { code: 'unrecognized_keys'; keys: string[] }
        | undefined;
      expect(unrecognizedIssue).toBeDefined();
      expect(unrecognizedIssue!.keys).toEqual(['model']);
    }
  });
});

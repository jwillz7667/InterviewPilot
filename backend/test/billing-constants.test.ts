import { describe, expect, it, vi } from 'vitest';

// selectModel/getModelByQuality now read AI_CHAT_PROVIDER via getEnv(); mock it
// so this unit test never needs the full (DB/JWT) env to be present, and so we
// can flip the provider to assert the DeepSeek / Groq mappings.
const { envState } = vi.hoisted(() => {
  const envState: { AI_CHAT_PROVIDER: 'openai' | 'deepseek' | 'groq'; GROQ_MODEL: string } = {
    AI_CHAT_PROVIDER: 'openai',
    GROQ_MODEL: '',
  };
  return { envState };
});

vi.mock('../src/config/env.js', () => ({
  getEnv: () => envState,
}));

import {
  TIER_QUOTA,
  getModelByQuality,
  selectModel,
  isUnlimitedQuota,
  TIER_FEATURES,
  TIER_PROFILE_LIMITS,
} from '../src/modules/billing/billing.constants.js';

describe('TIER_QUOTA', () => {
  it('FREE tier: 3 standard + 1 premium per month', () => {
    expect(TIER_QUOTA.FREE).toEqual({ standardMonthly: 3, premiumMonthly: 1 });
  });

  it('PRO tier: 25 standard + 10 premium per month', () => {
    expect(TIER_QUOTA.PRO).toEqual({ standardMonthly: 25, premiumMonthly: 10 });
  });

  it('PREMIUM tier: unlimited standard + unlimited premium', () => {
    expect(isUnlimitedQuota(TIER_QUOTA.PREMIUM.standardMonthly)).toBe(true);
    expect(isUnlimitedQuota(TIER_QUOTA.PREMIUM.premiumMonthly)).toBe(true);
  });

  it('legacy PLUS tier maps to Pro quota for safe migration', () => {
    expect(TIER_QUOTA.PLUS).toEqual(TIER_QUOTA.PRO);
  });

  it('legacy TRIAL tier maps to Free quota', () => {
    expect(TIER_QUOTA.TRIAL).toEqual(TIER_QUOTA.FREE);
  });

  it('SANDBOX tier: unlimited so App Store reviewers never hit a paywall', () => {
    expect(isUnlimitedQuota(TIER_QUOTA.SANDBOX.standardMonthly)).toBe(true);
    expect(isUnlimitedQuota(TIER_QUOTA.SANDBOX.premiumMonthly)).toBe(true);
  });
});

describe('getModelByQuality() — OpenAI provider (default)', () => {
  it('STANDARD uses gpt-4.1-mini for all routings', () => {
    const models = getModelByQuality();
    expect(models.STANDARD.primary).toBe('gpt-4.1-mini');
    expect(models.STANDARD.technical).toBe('gpt-4.1-mini');
    expect(models.STANDARD.coding).toBe('gpt-4.1-mini');
  });

  it('PREMIUM uses gpt-4.1 for default/technical and o4-mini for coding', () => {
    const models = getModelByQuality();
    expect(models.PREMIUM.primary).toBe('gpt-4.1');
    expect(models.PREMIUM.technical).toBe('gpt-4.1');
    expect(models.PREMIUM.coding).toBe('o4-mini');
  });

  it('STANDARD is capped at 320 tokens, PREMIUM at 600 tokens', () => {
    const models = getModelByQuality();
    expect(models.STANDARD.maxTokens).toBe(320);
    expect(models.PREMIUM.maxTokens).toBe(600);
  });

  it('PREMIUM pre-gen answer banks have 50 questions vs 25 for STANDARD', () => {
    const models = getModelByQuality();
    expect(models.STANDARD.preGenAnswerBank).toBe(25);
    expect(models.PREMIUM.preGenAnswerBank).toBe(50);
  });

  it('PREMIUM uses lower temperature (0.55) than STANDARD (0.7) for tighter answers', () => {
    const models = getModelByQuality();
    expect(models.STANDARD.temperature).toBe(0.7);
    expect(models.PREMIUM.temperature).toBe(0.55);
  });
});

describe('getModelByQuality() — DeepSeek provider', () => {
  it('routes every quality/routing to deepseek-chat while keeping token budgets', () => {
    envState.AI_CHAT_PROVIDER = 'deepseek';
    try {
      const models = getModelByQuality();
      expect(models.STANDARD.primary).toBe('deepseek-chat');
      expect(models.STANDARD.coding).toBe('deepseek-chat');
      expect(models.PREMIUM.primary).toBe('deepseek-chat');
      // No deepseek-reasoner on the coding route — latency would break a live interview.
      expect(models.PREMIUM.coding).toBe('deepseek-chat');
      // Token/temperature budgets are product decisions, identical across providers.
      expect(models.STANDARD.maxTokens).toBe(320);
      expect(models.PREMIUM.maxTokens).toBe(600);
      expect(selectModel('PREMIUM', 'coding').model).toBe('deepseek-chat');
    } finally {
      envState.AI_CHAT_PROVIDER = 'openai';
    }
  });
});

describe('getModelByQuality() — Groq provider', () => {
  it('routes every quality/routing to the env GROQ_MODEL (default when unset)', () => {
    envState.AI_CHAT_PROVIDER = 'groq';
    try {
      const models = getModelByQuality();
      expect(models.STANDARD.primary).toBe('llama-3.3-70b-versatile');
      expect(models.STANDARD.coding).toBe('llama-3.3-70b-versatile');
      expect(models.PREMIUM.primary).toBe('llama-3.3-70b-versatile');
      expect(models.PREMIUM.coding).toBe('llama-3.3-70b-versatile');
      expect(models.STANDARD.maxTokens).toBe(320);
      expect(models.PREMIUM.maxTokens).toBe(600);
    } finally {
      envState.AI_CHAT_PROVIDER = 'openai';
    }
  });

  it('honors a GROQ_MODEL override without a code change', () => {
    envState.AI_CHAT_PROVIDER = 'groq';
    envState.GROQ_MODEL = 'openai/gpt-oss-120b';
    try {
      expect(getModelByQuality().PREMIUM.primary).toBe('openai/gpt-oss-120b');
      expect(selectModel('STANDARD', 'coding').model).toBe('openai/gpt-oss-120b');
    } finally {
      envState.AI_CHAT_PROVIDER = 'openai';
      envState.GROQ_MODEL = '';
    }
  });

  it('an explicit provider arg overrides the env default', () => {
    // env says openai, but a per-user override asks for groq
    expect(getModelByQuality('groq').STANDARD.primary).toBe('llama-3.3-70b-versatile');
    expect(selectModel('PREMIUM', 'default', 'deepseek').model).toBe('deepseek-chat');
  });
});

describe('selectModel(quality, routing)', () => {
  it('STANDARD + default → gpt-4.1-mini', () => {
    const choice = selectModel('STANDARD', 'default');
    expect(choice.model).toBe('gpt-4.1-mini');
    expect(choice.maxTokens).toBe(320);
  });

  it('STANDARD + coding → still gpt-4.1-mini (no privilege escalation)', () => {
    const choice = selectModel('STANDARD', 'coding');
    expect(choice.model).toBe('gpt-4.1-mini');
  });

  it('PREMIUM + coding → o4-mini', () => {
    const choice = selectModel('PREMIUM', 'coding');
    expect(choice.model).toBe('o4-mini');
    expect(choice.maxTokens).toBe(600);
  });

  it('PREMIUM + default → gpt-4.1', () => {
    expect(selectModel('PREMIUM', 'default').model).toBe('gpt-4.1');
  });

  it('PREMIUM + technical → gpt-4.1', () => {
    expect(selectModel('PREMIUM', 'technical').model).toBe('gpt-4.1');
  });

  it('routing defaults to "default" when omitted', () => {
    expect(selectModel('PREMIUM').model).toBe(getModelByQuality().PREMIUM.primary);
  });
});

describe('TIER_FEATURES', () => {
  it('voice_prep is Premium-only (not on Pro/Plus/Free)', () => {
    expect(TIER_FEATURES.PREMIUM).toContain('voice_prep');
    expect(TIER_FEATURES.SANDBOX).toContain('voice_prep');
    expect(TIER_FEATURES.PRO).not.toContain('voice_prep');
    expect(TIER_FEATURES.PLUS).not.toContain('voice_prep');
    expect(TIER_FEATURES.FREE).not.toContain('voice_prep');
    expect(TIER_FEATURES.TRIAL).not.toContain('voice_prep');
  });

  it('post_session_analysis is Premium-only', () => {
    expect(TIER_FEATURES.PREMIUM).toContain('post_session_analysis');
    expect(TIER_FEATURES.SANDBOX).toContain('post_session_analysis');
    expect(TIER_FEATURES.PRO).not.toContain('post_session_analysis');
    expect(TIER_FEATURES.FREE).not.toContain('post_session_analysis');
  });

  it('priority_models is Pro+ (not Free)', () => {
    expect(TIER_FEATURES.PRO).toContain('priority_models');
    expect(TIER_FEATURES.PREMIUM).toContain('priority_models');
    expect(TIER_FEATURES.FREE).not.toContain('priority_models');
  });

  it('FREE keeps live_interview + session_history', () => {
    expect(TIER_FEATURES.FREE).toContain('live_interview');
    expect(TIER_FEATURES.FREE).toContain('session_history');
  });
});

describe('TIER_PROFILE_LIMITS', () => {
  it('FREE: 1 profile, PRO: 3, PREMIUM: 5', () => {
    expect(TIER_PROFILE_LIMITS.FREE).toBe(1);
    expect(TIER_PROFILE_LIMITS.PRO).toBe(3);
    expect(TIER_PROFILE_LIMITS.PREMIUM).toBe(5);
    expect(TIER_PROFILE_LIMITS.SANDBOX).toBe(5);
  });
});

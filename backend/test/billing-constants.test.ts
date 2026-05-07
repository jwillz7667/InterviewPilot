import { describe, expect, it } from 'vitest';
import {
  TIER_QUOTA,
  MODEL_BY_QUALITY,
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

describe('MODEL_BY_QUALITY', () => {
  it('STANDARD uses gpt-4.1-mini for all routings', () => {
    expect(MODEL_BY_QUALITY.STANDARD.primary).toBe('gpt-4.1-mini');
    expect(MODEL_BY_QUALITY.STANDARD.technical).toBe('gpt-4.1-mini');
    expect(MODEL_BY_QUALITY.STANDARD.coding).toBe('gpt-4.1-mini');
  });

  it('PREMIUM uses gpt-4.1 for default/technical and o4-mini for coding', () => {
    expect(MODEL_BY_QUALITY.PREMIUM.primary).toBe('gpt-4.1');
    expect(MODEL_BY_QUALITY.PREMIUM.technical).toBe('gpt-4.1');
    expect(MODEL_BY_QUALITY.PREMIUM.coding).toBe('o4-mini');
  });

  it('STANDARD is capped at 320 tokens, PREMIUM at 600 tokens', () => {
    expect(MODEL_BY_QUALITY.STANDARD.maxTokens).toBe(320);
    expect(MODEL_BY_QUALITY.PREMIUM.maxTokens).toBe(600);
  });

  it('PREMIUM pre-gen answer banks have 50 questions vs 25 for STANDARD', () => {
    expect(MODEL_BY_QUALITY.STANDARD.preGenAnswerBank).toBe(25);
    expect(MODEL_BY_QUALITY.PREMIUM.preGenAnswerBank).toBe(50);
  });

  it('PREMIUM uses lower temperature (0.55) than STANDARD (0.7) for tighter answers', () => {
    expect(MODEL_BY_QUALITY.STANDARD.temperature).toBe(0.7);
    expect(MODEL_BY_QUALITY.PREMIUM.temperature).toBe(0.55);
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
    expect(selectModel('PREMIUM').model).toBe(MODEL_BY_QUALITY.PREMIUM.primary);
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

import { z } from 'zod';

/**
 * Password policy applied to all user-supplied passwords (registration + reset).
 * Centralized so the policy can be tightened in one place.
 *
 * Policy: ≥12 chars, at least one uppercase, lowercase, digit, and symbol.
 * NIST SP 800-63B allows long passphrases with no character-class rules; we keep
 * the classes here as defense-in-depth alongside the length floor.
 */
export const passwordSchema = z
  .string()
  .min(12, 'Password must be at least 12 characters')
  .max(256, 'Password must be at most 256 characters')
  .regex(/[A-Z]/, 'Password must contain an uppercase letter')
  .regex(/[a-z]/, 'Password must contain a lowercase letter')
  .regex(/[0-9]/, 'Password must contain a digit')
  .regex(/[^A-Za-z0-9]/, 'Password must contain a symbol');

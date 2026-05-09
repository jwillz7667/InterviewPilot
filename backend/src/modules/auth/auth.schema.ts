import { z } from 'zod';

import { passwordSchema } from '../../shared/validation/password.js';

export const registerSchema = z
  .object({
    email: z.string().email('Invalid email address'),
    password: passwordSchema,
    displayName: z.string().min(1).max(100).optional(),
  })
  .strict();

export const loginSchema = z
  .object({
    email: z.string().email('Invalid email address'),
    password: z.string().min(1, 'Password is required'),
    deviceId: z.string().optional(),
  })
  .strict();

export const appleLoginSchema = z
  .object({
    identityToken: z.string().min(1, 'Identity token is required'),
    nonce: z.string().min(1, 'Nonce is required'),
    displayName: z.string().min(1).max(100).optional(),
    authorizationCode: z.string().min(1).optional(),
  })
  .strict();

export const linkedinLoginSchema = z
  .object({
    code: z.string().min(1, 'Authorization code is required'),
    redirectUri: z.string().url().min(1, 'redirectUri is required'),
    deviceId: z.string().min(1).max(128).optional(),
  })
  .strict();

export const refreshSchema = z
  .object({
    refreshToken: z.string().min(1, 'Refresh token is required'),
  })
  .strict();

export const logoutSchema = z
  .object({
    refreshToken: z.string().min(1, 'Refresh token is required'),
  })
  .strict();

export const listSessionsSchema = z
  .object({
    refreshToken: z.string().min(1).optional(),
  })
  .strict();

export const revokeSessionsSchema = z
  .object({
    refreshToken: z.string().min(1).optional(),
    deviceId: z.string().min(1).optional(),
    allOthers: z.boolean().optional(),
  })
  .strict()
  .refine((data) => Boolean(data.deviceId) || data.allOthers === true, {
    message: 'Either deviceId or allOthers=true is required',
  });

export const forgotPasswordSchema = z
  .object({
    email: z.string().email(),
  })
  .strict();

export const resetPasswordSchema = z
  .object({
    token: z.string().min(1),
    password: passwordSchema,
  })
  .strict();

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type AppleLoginInput = z.infer<typeof appleLoginSchema>;
export type LinkedInLoginInput = z.infer<typeof linkedinLoginSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;

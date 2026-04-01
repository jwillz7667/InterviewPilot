import { z } from 'zod';

export const registerSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string()
    .min(10, 'Password must be at least 10 characters')
    .regex(/[A-Z]/, 'Must contain an uppercase letter')
    .regex(/[a-z]/, 'Must contain a lowercase letter')
    .regex(/[0-9]/, 'Must contain a number'),
  displayName: z.string().min(1).max(100).optional(),
}).strict();

export const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
  deviceId: z.string().optional(),
}).strict();

export const appleLoginSchema = z.object({
  identityToken: z.string().min(1, 'Identity token is required'),
  nonce: z.string().min(1, 'Nonce is required'),
  displayName: z.string().min(1).max(100).optional(),
  authorizationCode: z.string().min(1).optional(),
}).strict();

export const refreshSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
}).strict();

export const logoutSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
}).strict();

export const forgotPasswordSchema = z.object({
  email: z.string().email(),
}).strict();

export const resetPasswordSchema = z.object({
  token: z.string().min(1),
  password: z.string().min(10),
}).strict();

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type AppleLoginInput = z.infer<typeof appleLoginSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;

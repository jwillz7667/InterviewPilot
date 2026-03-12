import { z } from 'zod';

const booleanish = z
  .union([z.boolean(), z.string()])
  .transform((value) => {
    if (typeof value === 'boolean') return value;
    return ['1', 'true', 'yes', 'on'].includes(value.toLowerCase());
  });

const envSchema = z.object({
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(32),
  API_KEY_ENCRYPTION_SECRET: z.string().min(32),
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  CORS_ORIGIN: z.string().default('*'),
  DEEPGRAM_API_KEY: z.string().default(''),
  OPENAI_API_KEY: z.string().default(''),
  APPLE_SIGN_IN_AUDIENCES: z.string().default('Res.InterviewPilot'),
  APP_STORE_BUNDLE_ID: z.string().default('Res.InterviewPilot'),
  APP_STORE_APPLE_ID: z.string().optional(),
  APP_STORE_ENABLE_ONLINE_CHECKS: booleanish.default(false),
  APP_STORE_PLUS_MONTHLY_PRODUCT_ID: z.string().default('Res.InterviewPilot.plus.monthly'),
  APP_STORE_PLUS_YEARLY_PRODUCT_ID: z.string().default('Res.InterviewPilot.plus.yearly'),
  APP_STORE_PRO_MONTHLY_PRODUCT_ID: z.string().default('Res.InterviewPilot.pro.monthly'),
  APP_STORE_PRO_YEARLY_PRODUCT_ID: z.string().default('Res.InterviewPilot.pro.yearly'),
  TRIAL_INTERVIEW_LIMIT: z.coerce.number().int().min(1).max(100).default(5),
});

export type Env = z.infer<typeof envSchema>;

let _env: Env;

export function loadEnv(): Env {
  if (_env) return _env;
  _env = envSchema.parse(process.env);
  return _env;
}

export function getEnv(): Env {
  if (!_env) return loadEnv();
  return _env;
}

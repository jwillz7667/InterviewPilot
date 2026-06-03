import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import dotenv from 'dotenv';
import { z } from 'zod';

const booleanish = z.union([z.boolean(), z.string()]).transform((value) => {
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
  JWT_AUDIENCE: z.string().default('interviewpilot-ios'),
  JWT_ISSUER: z.string().default('interviewpilot-api'),
  REDIS_URL: z.string().optional(),
  DEEPGRAM_API_KEY: z.string().default(''),
  DEEPGRAM_PROJECT_ID: z.string().optional(),
  OPENAI_API_KEY: z.string().default(''),
  OPENAI_REALTIME_MODEL: z.string().default('gpt-realtime'),
  // Chat-completion provider for live answers, answer-bank pre-gen, and
  // post-session analysis. DeepSeek is OpenAI-compatible, so switching is a
  // base-URL + key + model-name change only (see ai.provider.ts and the
  // provider-aware maps in billing.constants.ts). Transcription stays on
  // Deepgram and the realtime voice path stays on OpenAI regardless.
  AI_CHAT_PROVIDER: z.enum(['openai', 'deepseek']).default('openai'),
  DEEPSEEK_API_KEY: z.string().default(''),
  DEEPSEEK_BASE_URL: z.string().default('https://api.deepseek.com'),
  APPLE_SIGN_IN_TEAM_ID: z.string().default('487LC4H9U4'),
  APPLE_SIGN_IN_KEY_ID: z.string().default('H539ZPGG3B'),
  APPLE_SIGN_IN_PRIVATE_KEY: z.string().optional(),
  APPLE_SIGN_IN_AUDIENCES: z.string().default('com.res.jobhopperAI'),
  APP_STORE_BUNDLE_ID: z.string().default('com.res.jobhopperAI'),
  APP_STORE_APPLE_ID: z.string().optional(),
  APP_STORE_ENABLE_ONLINE_CHECKS: booleanish.default(false),
  APP_STORE_PLUS_MONTHLY_PRODUCT_ID: z.string().default('com.res.jobhopperAI.plus.monthly'),
  APP_STORE_PLUS_YEARLY_PRODUCT_ID: z.string().default('com.res.jobhopperAI.plus.yearly'),
  APP_STORE_PRO_MONTHLY_PRODUCT_ID: z.string().default('com.res.jobhopperAI.pro.monthly'),
  APP_STORE_PRO_YEARLY_PRODUCT_ID: z.string().default('com.res.jobhopperAI.pro.yearly'),
  APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID: z.string().default('com.res.jobhopperAI.premium.monthly'),
  APP_STORE_PREMIUM_YEARLY_PRODUCT_ID: z.string().default('com.res.jobhopperAI.premium.yearly'),
  TRIAL_INTERVIEW_LIMIT: z.coerce.number().int().min(1).max(100).default(5),
  TRIAL_DURATION_DAYS: z.coerce.number().int().min(1).max(90).default(7),
  FREE_MONTHLY_INTERVIEW_LIMIT: z.coerce.number().int().min(0).max(100).default(3),
  SANDBOX_TESTER_EMAILS: z.string().default(''),
  DEVELOPER_FULL_ACCESS_EMAILS: z.string().default(''),
  DATABASE_POOL_SIZE: z.coerce.number().int().min(1).max(50).default(15),
  SENDGRID_API_KEY: z.string().optional(),
  SENDGRID_FROM_EMAIL: z.string().email().default('noreply@interviewpilot.app'),
  APP_URL: z.string().url().default('https://interviewpilot.app'),
  R2_ACCOUNT_ID: z.string().optional(),
  R2_ACCESS_KEY_ID: z.string().optional(),
  R2_SECRET_ACCESS_KEY: z.string().optional(),
  R2_BUCKET_NAME: z.string().default('interviewpilot-uploads'),
  R2_PUBLIC_URL: z.string().optional(),
  SENTRY_DSN: z.string().optional(),
  // OpenTelemetry. When OTEL_EXPORTER_OTLP_ENDPOINT is set, the SDK auto-loads
  // and exports traces. Sentry ingests OTLP natively, so the same DSN's OTLP
  // endpoint is the simplest target.
  OTEL_EXPORTER_OTLP_ENDPOINT: z.string().optional(),
  OTEL_EXPORTER_OTLP_HEADERS: z.string().optional(),
  OTEL_SERVICE_NAME: z.string().default('interviewpilot-backend'),
  OTEL_TRACES_SAMPLER_ARG: z.coerce.number().min(0).max(1).default(0.1),
  // App Attest. APP_ATTEST_REQUIRED gates whether protected routes reject
  // requests without a valid assertion header. Ship false for one release so
  // existing clients can register their key before enforcement turns on.
  APP_ATTEST_REQUIRED: booleanish.default(false),
  APP_ATTEST_TEAM_ID: z.string().default('487LC4H9U4'),
  APP_ATTEST_BUNDLE_ID: z.string().default('com.res.jobhopperAI'),
  APP_ATTEST_ENVIRONMENT: z.enum(['appattest', 'appattestdevelop']).default('appattest'),
  // Sentry DSN delivered to iOS clients post-auth via /config; can be a
  // separate DSN from the backend's, but reusing the same project is fine.
  SENTRY_DSN_IOS: z.string().optional(),
  // Sign In with LinkedIn (OpenID Connect). LinkedIn rejects custom URL
  // schemes in OAuth redirect URIs, so iOS uses an HTTPS bridge URL on the
  // backend; the bridge then 302s to LINKEDIN_NATIVE_CALLBACK_URI which
  // ASWebAuthenticationSession captures via its registered scheme.
  LINKEDIN_CLIENT_ID: z.string().optional(),
  LINKEDIN_CLIENT_SECRET: z.string().optional(),
  LINKEDIN_REDIRECT_URI: z
    .string()
    .default('https://interviewpilot-production.up.railway.app/auth/linkedin/callback'),
  LINKEDIN_NATIVE_CALLBACK_URI: z
    .string()
    .default('com.res.jobhopperAI://oauth/linkedin/callback'),
});

export type Env = z.infer<typeof envSchema>;

let _env: Env;
let envFilesLoaded = false;

function loadEnvFiles(): void {
  if (envFilesLoaded) return;

  const configDir = path.dirname(fileURLToPath(import.meta.url));
  const projectRoot = path.resolve(configDir, '../..');
  const stage = process.env.NODE_ENV ?? 'development';
  const fileNames = ['.env', stage === 'production' ? '.env.production' : '.env.local'];

  for (const fileName of fileNames) {
    const filePath = path.join(projectRoot, fileName);
    if (!fs.existsSync(filePath)) continue;
    dotenv.config({ path: filePath, override: false });
  }

  envFilesLoaded = true;
}

export function loadEnv(): Env {
  if (_env) return _env;
  loadEnvFiles();
  _env = envSchema.parse(process.env);
  return _env;
}

export function getEnv(): Env {
  if (!_env) return loadEnv();
  return _env;
}

import { z } from 'zod';

const envSchema = z.object({
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(32),
  API_KEY_ENCRYPTION_SECRET: z.string().min(32),
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  CORS_ORIGIN: z.string().default('*'),
  DEEPGRAM_API_KEY: z.string().default(''),
  OPENAI_API_KEY: z.string().default(''),
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

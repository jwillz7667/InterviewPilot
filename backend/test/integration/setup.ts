import { execSync } from 'node:child_process';

import { PrismaClient } from '@prisma/client';
import { createClient, type RedisClientType } from 'redis';
import { afterAll, beforeAll } from 'vitest';

// Test fixtures shared across integration tests. Imported via:
//   import { getTestPrisma, getTestRedis } from './setup.js';
let prisma: PrismaClient | null = null;
let redis: RedisClientType | null = null;

export function getTestPrisma(): PrismaClient {
  if (!prisma) throw new Error('Prisma test client not initialized — setup.ts not loaded');
  return prisma;
}

export function getTestRedis(): RedisClientType {
  if (!redis) throw new Error('Redis test client not initialized — setup.ts not loaded');
  return redis;
}

beforeAll(async () => {
  const databaseUrl = process.env.DATABASE_URL;
  const redisUrl = process.env.REDIS_URL;
  if (!databaseUrl) {
    throw new Error(
      'DATABASE_URL is required for integration tests. ' +
        'In CI it is set by the postgres service. Locally use docker compose.'
    );
  }
  if (!redisUrl) {
    throw new Error('REDIS_URL is required for integration tests.');
  }

  // Apply migrations against the disposable test DB. `migrate deploy` is the
  // CI-safe variant — it never prompts and never resets data.
  execSync('npx prisma migrate deploy', {
    stdio: 'inherit',
    env: { ...process.env, DATABASE_URL: databaseUrl },
  });

  prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
  await prisma.$connect();

  redis = createClient({ url: redisUrl });
  await redis.connect();
});

afterAll(async () => {
  await prisma?.$disconnect();
  await redis?.quit();
});

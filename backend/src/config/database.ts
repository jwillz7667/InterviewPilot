import { Prisma, PrismaClient } from '@prisma/client';
import { getEnv } from './env.js';
import { softDeleteExtension } from '../middleware/soft-delete.js';

function createPrismaClient() {
  const env = getEnv();
  const url = new URL(env.DATABASE_URL);
  url.searchParams.set('connection_limit', String(env.DATABASE_POOL_SIZE));

  return new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
    datasourceUrl: url.toString(),
  });
}

export type DatabaseClient = ReturnType<typeof createPrismaClient>;

let prisma: DatabaseClient | undefined;
let reconnectInFlight: Promise<DatabaseClient> | undefined;

const TRANSIENT_PRISMA_ERROR_CODES = new Set(['P1001', 'P1002', 'P1017']);
const TRANSIENT_PRISMA_MESSAGE_PATTERNS = [
  'Error in PostgreSQL connection: Error { kind: Closed',
  'Connection reset by peer',
  "Can't reach database server",
  'server closed the connection unexpectedly',
  'terminating connection due to administrator command',
  'Server has closed the connection',
];

export function getPrisma(): DatabaseClient {
  if (!prisma) {
    prisma = createPrismaClient().$extends(softDeleteExtension) as unknown as DatabaseClient;
  }
  return prisma;
}

export function isTransientPrismaError(error: unknown): boolean {
  const code = getPrismaErrorCode(error);
  if (code && TRANSIENT_PRISMA_ERROR_CODES.has(code)) {
    return true;
  }

  const message = error instanceof Error ? error.message : String(error);
  return TRANSIENT_PRISMA_MESSAGE_PATTERNS.some((pattern) => message.includes(pattern));
}

export async function reconnectPrisma(): Promise<DatabaseClient> {
  if (reconnectInFlight) {
    return reconnectInFlight;
  }

  reconnectInFlight = (async () => {
    const previousClient = prisma;
    const nextClient = createPrismaClient().$extends(softDeleteExtension) as unknown as DatabaseClient;
    prisma = nextClient;

    if (previousClient) {
      await previousClient.$disconnect().catch(() => undefined);
    }

    try {
      await nextClient.$connect();
      return nextClient;
    } catch (error) {
      if (prisma === nextClient) {
        prisma = undefined;
      }
      await nextClient.$disconnect().catch(() => undefined);
      throw error;
    }
  })();

  try {
    return await reconnectInFlight;
  } finally {
    reconnectInFlight = undefined;
  }
}

export async function withDatabaseRetry<T>(
  operation: (prismaClient: DatabaseClient) => Promise<T>
): Promise<T> {
  try {
    return await operation(getPrisma());
  } catch (error) {
    if (!isTransientPrismaError(error)) {
      throw error;
    }

    const prismaClient = await reconnectPrisma();
    return operation(prismaClient);
  }
}

export async function disconnectPrisma(): Promise<void> {
  if (prisma) {
    await prisma.$disconnect();
    prisma = undefined;
  }
}

function getPrismaErrorCode(error: unknown): string | undefined {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    return error.code;
  }

  if (error instanceof Prisma.PrismaClientInitializationError) {
    return error.errorCode ?? undefined;
  }

  if (typeof error === 'object' && error && 'code' in error) {
    const code = (error as { code?: unknown }).code;
    return typeof code === 'string' ? code : undefined;
  }

  return undefined;
}

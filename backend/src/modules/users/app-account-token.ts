import { randomUUID } from 'crypto';
import { Prisma } from '@prisma/client';
import type { DatabaseClient } from '../../config/database.js';

type UserClient = Pick<DatabaseClient | Prisma.TransactionClient, 'user'>;

export async function ensureAppAccountToken(
  prisma: UserClient,
  user: { id: string; appAccountToken: string | null }
): Promise<string> {
  if (user.appAccountToken) {
    return user.appAccountToken;
  }

  try {
    const updated = await prisma.user.update({
      where: { id: user.id },
      data: { appAccountToken: randomUUID() },
      select: { appAccountToken: true },
    });

    if (!updated.appAccountToken) {
      throw new Error(`User ${user.id} is still missing appAccountToken after update`);
    }

    return updated.appAccountToken;
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      const existing = await prisma.user.findUniqueOrThrow({
        where: { id: user.id },
        select: { appAccountToken: true },
      });

      if (existing.appAccountToken) {
        return existing.appAccountToken;
      }
    }

    throw error;
  }
}

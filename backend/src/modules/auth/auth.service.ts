import { randomBytes } from 'crypto';
import * as argon2 from 'argon2';
import { getPrisma } from '../../config/database.js';
import { ConflictError, UnauthorizedError } from '../../utils/errors.js';
import type { RegisterInput, LoginInput } from './auth.schema.js';

const REFRESH_TOKEN_EXPIRY_DAYS = 30;

export async function registerUser(input: RegisterInput) {
  const prisma = getPrisma();

  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing) {
    throw new ConflictError('An account with this email already exists');
  }

  const passwordHash = await argon2.hash(input.password, {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 4,
  });

  const user = await prisma.user.create({
    data: {
      email: input.email,
      passwordHash,
      displayName: input.displayName,
      lastLoginAt: new Date(),
      settings: { create: {} }, // Create default settings
    },
    select: { id: true, email: true, displayName: true, createdAt: true },
  });

  return user;
}

export async function loginUser(input: LoginInput) {
  const prisma = getPrisma();

  const user = await prisma.user.findUnique({ where: { email: input.email } });
  if (!user) {
    throw new UnauthorizedError('Invalid email or password');
  }

  const validPassword = await argon2.verify(user.passwordHash, input.password);
  if (!validPassword) {
    throw new UnauthorizedError('Invalid email or password');
  }

  // Update last login
  await prisma.user.update({
    where: { id: user.id },
    data: { lastLoginAt: new Date() },
  });

  return { id: user.id, email: user.email, displayName: user.displayName };
}

export async function createRefreshToken(userId: string, deviceId?: string): Promise<string> {
  const prisma = getPrisma();
  const token = randomBytes(64).toString('hex');
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

  await prisma.refreshToken.create({
    data: { token, userId, deviceId, expiresAt },
  });

  return token;
}

export async function rotateRefreshToken(oldToken: string): Promise<{ userId: string; newToken: string }> {
  const prisma = getPrisma();

  const existing = await prisma.refreshToken.findUnique({ where: { token: oldToken } });
  if (!existing || existing.revokedAt || existing.expiresAt < new Date()) {
    throw new UnauthorizedError('Invalid or expired refresh token');
  }

  // Revoke old token
  await prisma.refreshToken.update({
    where: { id: existing.id },
    data: { revokedAt: new Date() },
  });

  // Create new token
  const newToken = await createRefreshToken(existing.userId, existing.deviceId ?? undefined);

  return { userId: existing.userId, newToken };
}

export async function revokeRefreshToken(token: string): Promise<void> {
  const prisma = getPrisma();
  await prisma.refreshToken.updateMany({
    where: { token, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

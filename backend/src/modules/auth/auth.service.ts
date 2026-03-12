import { createHash, randomBytes } from 'crypto';
import * as argon2 from 'argon2';
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';
import { getPrisma, withDatabaseRetry } from '../../config/database.js';
import { getEnv } from '../../config/env.js';
import {
  ConflictError,
  UnauthorizedError,
  ValidationError,
} from '../../utils/errors.js';
import type { AppleLoginInput, LoginInput, RegisterInput } from './auth.schema.js';

const REFRESH_TOKEN_EXPIRY_DAYS = 30;
const APPLE_ISSUER = 'https://appleid.apple.com';
const appleJwks = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

const authUserSelect = {
  id: true,
  email: true,
  displayName: true,
  appAccountToken: true,
  createdAt: true,
} as const;

type AppleIdentityTokenClaims = JWTPayload & {
  sub: string;
  email?: string;
  email_verified?: boolean | string;
  nonce?: string;
};

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function hashAppleNonce(nonce: string): string {
  return createHash('sha256').update(nonce).digest('hex');
}

function isEmailVerified(value: AppleIdentityTokenClaims['email_verified']): boolean {
  return value === true || value === 'true';
}

async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 4,
  });
}

export async function registerUser(input: RegisterInput) {
  const email = normalizeEmail(input.email);
  const existing = await withDatabaseRetry((prisma) =>
    prisma.user.findUnique({ where: { email } })
  );

  if (existing) {
    throw new ConflictError('An account with this email already exists');
  }

  const passwordHash = await hashPassword(input.password);
  const prisma = getPrisma();

  return prisma.user.create({
    data: {
      email,
      passwordHash,
      displayName: input.displayName,
      lastLoginAt: new Date(),
      settings: { create: {} },
      entitlement: {
        create: {
          trialInterviewLimit: getEnv().TRIAL_INTERVIEW_LIMIT,
        },
      },
    },
    select: authUserSelect,
  });
}

export async function loginUser(input: LoginInput) {
  const email = normalizeEmail(input.email);
  const user = await withDatabaseRetry((prisma) =>
    prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        email: true,
        displayName: true,
        appAccountToken: true,
        passwordHash: true,
      },
    })
  );

  if (!user || !user.passwordHash) {
    throw new UnauthorizedError('Invalid email or password');
  }

  const validPassword = await argon2.verify(user.passwordHash, input.password);
  if (!validPassword) {
    throw new UnauthorizedError('Invalid email or password');
  }

  await withDatabaseRetry((prisma) =>
    prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    })
  );

  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    appAccountToken: user.appAccountToken,
  };
}

async function verifyAppleIdentityToken(
  identityToken: string,
  nonce: string
): Promise<AppleIdentityTokenClaims> {
  const env = getEnv();
  const audiences = env.APPLE_SIGN_IN_AUDIENCES
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  if (audiences.length === 0) {
    throw new ValidationError('APPLE_SIGN_IN_AUDIENCES must include at least one bundle or service id');
  }

  const verified = await jwtVerify(identityToken, appleJwks, {
    issuer: APPLE_ISSUER,
    audience: audiences,
  });

  const payload = verified.payload as AppleIdentityTokenClaims;
  if (!payload.sub) {
    throw new ValidationError('Apple identity token is missing a subject claim');
  }

  const expectedNonce = hashAppleNonce(nonce);
  if (payload.nonce !== expectedNonce) {
    throw new UnauthorizedError('Apple nonce verification failed');
  }

  return payload;
}

export async function authenticateWithApple(input: AppleLoginInput) {
  const claims = await verifyAppleIdentityToken(input.identityToken, input.nonce);
  const email = claims.email ? normalizeEmail(claims.email) : null;
  const displayName = input.displayName?.trim() || null;

  const prisma = getPrisma();

  const user = await prisma.$transaction(async (tx) => {
    const existingByAppleId = await tx.user.findUnique({
      where: { appleId: claims.sub },
      select: {
        id: true,
        email: true,
        displayName: true,
        appAccountToken: true,
      },
    });

    if (existingByAppleId) {
      return tx.user.update({
        where: { id: existingByAppleId.id },
        data: {
          lastLoginAt: new Date(),
          ...(displayName && !existingByAppleId.displayName ? { displayName } : {}),
        },
        select: authUserSelect,
      });
    }

    if (!email) {
      throw new ValidationError('Apple did not provide an email for this account');
    }

    const existingByEmail = await tx.user.findUnique({
      where: { email },
      select: {
        id: true,
        appleId: true,
        displayName: true,
      },
    });

    if (existingByEmail?.appleId && existingByEmail.appleId !== claims.sub) {
      throw new ConflictError('This email is already linked to another Apple account');
    }

    if (existingByEmail) {
      return tx.user.update({
        where: { id: existingByEmail.id },
        data: {
          appleId: claims.sub,
          emailVerified: isEmailVerified(claims.email_verified),
          lastLoginAt: new Date(),
          ...(displayName && !existingByEmail.displayName ? { displayName } : {}),
        },
        select: authUserSelect,
      });
    }

    return tx.user.create({
      data: {
        email,
        passwordHash: null,
        appleId: claims.sub,
        displayName,
        emailVerified: isEmailVerified(claims.email_verified),
        lastLoginAt: new Date(),
        settings: { create: {} },
        entitlement: {
          create: {
            trialInterviewLimit: getEnv().TRIAL_INTERVIEW_LIMIT,
          },
        },
      },
      select: authUserSelect,
    });
  });

  return user;
}

export async function createRefreshToken(userId: string, deviceId?: string): Promise<string> {
  const token = randomBytes(64).toString('hex');
  const tokenHash = hashRefreshToken(token);
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

  await withDatabaseRetry((prisma) =>
    prisma.refreshToken.create({
      data: { tokenHash, userId, deviceId, expiresAt },
    })
  );

  return token;
}

export async function rotateRefreshToken(
  oldToken: string
): Promise<{ userId: string; newToken: string }> {
  const oldTokenHash = hashRefreshToken(oldToken);
  const existing = await withDatabaseRetry((prisma) =>
    prisma.refreshToken.findUnique({ where: { tokenHash: oldTokenHash } })
  );

  if (!existing || existing.revokedAt || existing.expiresAt < new Date()) {
    throw new UnauthorizedError('Invalid or expired refresh token');
  }

  await withDatabaseRetry((prisma) =>
    prisma.refreshToken.update({
      where: { id: existing.id },
      data: { revokedAt: new Date() },
    })
  );

  const newToken = await createRefreshToken(existing.userId, existing.deviceId ?? undefined);

  return { userId: existing.userId, newToken };
}

export async function revokeRefreshToken(token: string): Promise<void> {
  const tokenHash = hashRefreshToken(token);

  await withDatabaseRetry((prisma) =>
    prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    })
  );
}

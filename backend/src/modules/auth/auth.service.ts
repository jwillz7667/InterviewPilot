import { createHash, randomBytes, randomUUID } from 'crypto';
import * as argon2 from 'argon2';
import {
  createRemoteJWKSet,
  importPKCS8,
  jwtVerify,
  SignJWT,
  type JWTPayload,
} from 'jose';
import { getPrisma, withDatabaseRetry } from '../../config/database.js';
import { getEnv } from '../../config/env.js';
import {
  ConflictError,
  UnauthorizedError,
  ValidationError,
} from '../../utils/errors.js';
import type { AppleLoginInput, LoginInput, RegisterInput } from './auth.schema.js';

const REFRESH_TOKEN_EXPIRY_DAYS = 30;
const MAX_FAILED_LOGIN_ATTEMPTS = 5;
const LOGIN_LOCKOUT_DURATION_MS = 15 * 60 * 1000;
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

type AppleTokenResponse = {
  access_token?: string;
  expires_in?: number;
  id_token?: string;
  refresh_token?: string;
  token_type?: string;
  error?: string;
  error_description?: string;
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

function normalizeApplePrivateKey(privateKey: string): string {
  return privateKey.replace(/\\n/g, '\n').trim();
}

function canUseAppleCodeExchange(): boolean {
  const env = getEnv();
  return Boolean(
    env.APPLE_SIGN_IN_TEAM_ID &&
      env.APPLE_SIGN_IN_KEY_ID &&
      env.APPLE_SIGN_IN_PRIVATE_KEY &&
      env.APP_STORE_BUNDLE_ID
  );
}

async function buildAppleClientSecret(): Promise<string> {
  const env = getEnv();

  if (!canUseAppleCodeExchange()) {
    throw new ValidationError('Apple Sign In code exchange is not fully configured');
  }

  const privateKey = normalizeApplePrivateKey(env.APPLE_SIGN_IN_PRIVATE_KEY!);
  const signingKey = await importPKCS8(privateKey, 'ES256');
  const issuedAt = Math.floor(Date.now() / 1000);

  return new SignJWT({})
    .setProtectedHeader({
      alg: 'ES256',
      kid: env.APPLE_SIGN_IN_KEY_ID!,
    })
    .setIssuer(env.APPLE_SIGN_IN_TEAM_ID!)
    .setSubject(env.APP_STORE_BUNDLE_ID)
    .setAudience('https://appleid.apple.com')
    .setIssuedAt(issuedAt)
    .setExpirationTime(issuedAt + 60 * 5)
    .sign(signingKey);
}

async function exchangeAppleAuthorizationCode(
  authorizationCode: string
): Promise<AppleTokenResponse> {
  const env = getEnv();
  const clientSecret = await buildAppleClientSecret();

  const response = await fetch('https://appleid.apple.com/auth/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      client_id: env.APP_STORE_BUNDLE_ID,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: 'authorization_code',
    }),
  });

  const payload = (await response.json()) as AppleTokenResponse;
  if (!response.ok || payload.error) {
    throw new UnauthorizedError(
      payload.error_description || payload.error || 'Apple authorization code exchange failed'
    );
  }

  if (!payload.id_token) {
    throw new ValidationError('Apple token response did not include an identity token');
  }

  return payload;
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
    throw new ConflictError('Unable to create account. Please try again or sign in.');
  }

  const passwordHash = await hashPassword(input.password);
  const prisma = getPrisma();
  const appAccountToken = randomUUID();

  const env = getEnv();
  const now = new Date();
  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      displayName: input.displayName,
      appAccountToken,
      lastLoginAt: now,
      settings: { create: {} },
      entitlement: {
        create: {
          tier: 'TRIAL',
          status: 'TRIALING',
          trialInterviewLimit: env.TRIAL_INTERVIEW_LIMIT,
          trialStartedAt: now,
          trialEndsAt: new Date(now.getTime() + env.TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000),
        },
      },
    },
    select: authUserSelect,
  });

  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    appAccountToken,
    createdAt: user.createdAt,
  };
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
        failedLoginAttempts: true,
        lockedUntil: true,
      },
    })
  );

  if (!user || !user.passwordHash) {
    throw new UnauthorizedError('Invalid email or password');
  }

  if (user.lockedUntil && user.lockedUntil > new Date()) {
    throw new UnauthorizedError('Account temporarily locked. Try again later.');
  }

  const validPassword = await argon2.verify(user.passwordHash, input.password);
  if (!validPassword) {
    // Atomic increment + conditional lock — prevents two concurrent failed
    // attempts from each reading the same count and only incrementing once.
    const incremented = await withDatabaseRetry((prisma) =>
      prisma.user.update({
        where: { id: user.id },
        data: { failedLoginAttempts: { increment: 1 } },
        select: { failedLoginAttempts: true },
      })
    );
    if (incremented.failedLoginAttempts >= MAX_FAILED_LOGIN_ATTEMPTS) {
      await withDatabaseRetry((prisma) =>
        prisma.user.update({
          where: { id: user.id },
          data: { lockedUntil: new Date(Date.now() + LOGIN_LOCKOUT_DURATION_MS) },
        })
      );
    }
    throw new UnauthorizedError('Invalid email or password');
  }

  // Single update on success: stamp last login, clear lockout state if any,
  // and lazily mint an appAccountToken for legacy rows that never got one.
  const appAccountToken = user.appAccountToken ?? randomUUID();
  const successData: {
    lastLoginAt: Date;
    failedLoginAttempts?: number;
    lockedUntil?: null;
    appAccountToken?: string;
  } = { lastLoginAt: new Date() };
  if (user.failedLoginAttempts > 0 || user.lockedUntil) {
    successData.failedLoginAttempts = 0;
    successData.lockedUntil = null;
  }
  if (!user.appAccountToken) {
    successData.appAccountToken = appAccountToken;
  }

  const updated = await withDatabaseRetry((prisma) =>
    prisma.user.update({
      where: { id: user.id },
      data: successData,
      select: { id: true, email: true, displayName: true },
    })
  );

  return {
    id: updated.id,
    email: updated.email,
    displayName: updated.displayName,
    appAccountToken,
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

async function resolveAppleClaims(input: AppleLoginInput): Promise<AppleIdentityTokenClaims> {
  if (input.authorizationCode && canUseAppleCodeExchange()) {
    const tokenResponse = await exchangeAppleAuthorizationCode(input.authorizationCode);
    return verifyAppleIdentityToken(tokenResponse.id_token!, input.nonce);
  }

  return verifyAppleIdentityToken(input.identityToken, input.nonce);
}

export async function authenticateWithApple(input: AppleLoginInput) {
  const claims = await resolveAppleClaims(input);
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
      const appAccountToken = existingByAppleId.appAccountToken ?? randomUUID();
      const user = await tx.user.update({
        where: { id: existingByAppleId.id },
        data: {
          lastLoginAt: new Date(),
          ...(existingByAppleId.appAccountToken ? {} : { appAccountToken }),
          ...(displayName && !existingByAppleId.displayName ? { displayName } : {}),
        },
        select: authUserSelect,
      });

      return {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        appAccountToken,
        createdAt: user.createdAt,
      };
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
        appAccountToken: true,
      },
    });

    if (existingByEmail?.appleId && existingByEmail.appleId !== claims.sub) {
      throw new ConflictError('This email is already linked to another Apple account');
    }

    if (existingByEmail && !existingByEmail.appleId) {
      // Linking existing email account to Apple ID — require verified email
      if (!isEmailVerified(claims.email_verified)) {
        throw new ValidationError('Cannot link account: email not verified by Apple');
      }
    }

    if (existingByEmail) {
      const appAccountToken = existingByEmail.appAccountToken ?? randomUUID();
      const user = await tx.user.update({
        where: { id: existingByEmail.id },
        data: {
          appleId: claims.sub,
          ...(existingByEmail.appAccountToken ? {} : { appAccountToken }),
          emailVerified: isEmailVerified(claims.email_verified),
          lastLoginAt: new Date(),
          ...(displayName && !existingByEmail.displayName ? { displayName } : {}),
        },
        select: authUserSelect,
      });

      return {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        appAccountToken,
        createdAt: user.createdAt,
      };
    }

    const appAccountToken = randomUUID();
    const appleEnv = getEnv();
    const appleNow = new Date();
    const user = await tx.user.create({
      data: {
        email,
        passwordHash: null,
        appleId: claims.sub,
        displayName,
        appAccountToken,
        emailVerified: isEmailVerified(claims.email_verified),
        lastLoginAt: appleNow,
        settings: { create: {} },
        entitlement: {
          create: {
            tier: 'TRIAL',
            status: 'TRIALING',
            trialInterviewLimit: appleEnv.TRIAL_INTERVIEW_LIMIT,
            trialStartedAt: appleNow,
            trialEndsAt: new Date(appleNow.getTime() + appleEnv.TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000),
          },
        },
      },
      select: authUserSelect,
    });

    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      appAccountToken,
      createdAt: user.createdAt,
    };
  });

  return user;
}

export async function createRefreshToken(
  userId: string,
  deviceId?: string,
  userAgent?: string
): Promise<string> {
  const token = randomBytes(64).toString('hex');
  const tokenHash = hashRefreshToken(token);
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

  await withDatabaseRetry((prisma) =>
    prisma.refreshToken.create({
      data: { tokenHash, userId, deviceId, userAgent, expiresAt },
    })
  );

  return token;
}

export async function rotateRefreshToken(
  oldToken: string,
  userAgent?: string
): Promise<{ userId: string; newToken: string }> {
  const oldTokenHash = hashRefreshToken(oldToken);
  const prisma = getPrisma();

  const result = await prisma.$transaction(async (tx) => {
    const existing = await tx.refreshToken.findUnique({
      where: { tokenHash: oldTokenHash },
    });

    if (!existing || existing.revokedAt || existing.expiresAt < new Date()) {
      throw new UnauthorizedError('Invalid or expired refresh token');
    }

    await tx.refreshToken.update({
      where: { id: existing.id },
      data: { revokedAt: new Date() },
    });

    const newTokenValue = randomBytes(64).toString('hex');
    const newTokenHash = hashRefreshToken(newTokenValue);
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

    await tx.refreshToken.create({
      data: {
        tokenHash: newTokenHash,
        userId: existing.userId,
        deviceId: existing.deviceId,
        userAgent: userAgent ?? existing.userAgent,
        expiresAt,
      },
    });

    return { userId: existing.userId, newToken: newTokenValue };
  });

  return result;
}

export async function revokeRefreshToken(token: string): Promise<void> {
  const tokenHash = hashRefreshToken(token);

  await withDatabaseRetry((prisma) =>
    prisma.refreshToken.updateMany({
      where: {
        revokedAt: null,
        tokenHash,
      },
      data: { revokedAt: new Date() },
    })
  );
}

export type SessionSummary = {
  deviceId: string | null;
  userAgent: string | null;
  createdAt: Date;
  lastUsedAt: Date;
  current: boolean;
};

export async function listUserSessions(
  userId: string,
  currentToken?: string
): Promise<SessionSummary[]> {
  const currentHash = currentToken ? hashRefreshToken(currentToken) : null;

  const rows = await withDatabaseRetry((prisma) =>
    prisma.refreshToken.findMany({
      where: {
        userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { lastUsedAt: 'desc' },
      select: {
        tokenHash: true,
        deviceId: true,
        userAgent: true,
        createdAt: true,
        lastUsedAt: true,
      },
    })
  );

  return rows.map((row) => ({
    deviceId: row.deviceId,
    userAgent: row.userAgent,
    createdAt: row.createdAt,
    lastUsedAt: row.lastUsedAt,
    current: currentHash != null && row.tokenHash === currentHash,
  }));
}

export async function revokeUserSessions(
  userId: string,
  options: { deviceId?: string; exceptToken?: string } = {}
): Promise<{ revokedCount: number }> {
  const exceptHash = options.exceptToken ? hashRefreshToken(options.exceptToken) : null;

  const result = await withDatabaseRetry((prisma) =>
    prisma.refreshToken.updateMany({
      where: {
        userId,
        revokedAt: null,
        ...(options.deviceId ? { deviceId: options.deviceId } : {}),
        ...(exceptHash ? { tokenHash: { not: exceptHash } } : {}),
      },
      data: { revokedAt: new Date() },
    })
  );

  return { revokedCount: result.count };
}

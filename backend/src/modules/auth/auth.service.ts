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

  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      displayName: input.displayName,
      appAccountToken,
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
    const attempts = (user.failedLoginAttempts ?? 0) + 1;
    const lockData: { failedLoginAttempts: number; lockedUntil?: Date } = { failedLoginAttempts: attempts };
    if (attempts >= 5) {
      lockData.lockedUntil = new Date(Date.now() + 15 * 60 * 1000); // 15 min
    }
    await withDatabaseRetry((prisma) =>
      prisma.user.update({ where: { id: user.id }, data: lockData })
    );
    throw new UnauthorizedError('Invalid email or password');
  }

  if (user.failedLoginAttempts > 0) {
    await withDatabaseRetry((prisma) =>
      prisma.user.update({ where: { id: user.id }, data: { failedLoginAttempts: 0, lockedUntil: null } })
    );
  }

  const appAccountToken = user.appAccountToken ?? randomUUID();
  const updated = await withDatabaseRetry((prisma) =>
    prisma.user.update({
      where: { id: user.id },
      data: {
        lastLoginAt: new Date(),
        ...(user.appAccountToken ? {} : { appAccountToken }),
      },
      select: {
        id: true,
        email: true,
        displayName: true,
      },
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
    const user = await tx.user.create({
      data: {
        email,
        passwordHash: null,
        appleId: claims.sub,
        displayName,
        appAccountToken,
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
      where: {
        revokedAt: null,
        tokenHash,
      },
      data: { revokedAt: new Date() },
    })
  );
}

import { randomUUID } from 'node:crypto';

import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';

import { getPrisma, withDatabaseRetry } from '../../config/database.js';
import { getEnv } from '../../config/env.js';
import { ConflictError, UnauthorizedError, ValidationError } from '../../utils/errors.js';

import type { LinkedInLoginInput } from './auth.schema.js';

const LINKEDIN_ISSUER = 'https://www.linkedin.com';
const LINKEDIN_TOKEN_ENDPOINT = 'https://www.linkedin.com/oauth/v2/accessToken';
const LINKEDIN_USERINFO_ENDPOINT = 'https://api.linkedin.com/v2/userinfo';
const linkedinJwks = createRemoteJWKSet(new URL('https://www.linkedin.com/oauth/openid/jwks'));

const authUserSelect = {
  id: true,
  email: true,
  displayName: true,
  appAccountToken: true,
  createdAt: true,
} as const;

type LinkedInIdTokenClaims = JWTPayload & {
  sub: string;
  name?: string;
  given_name?: string;
  family_name?: string;
  picture?: string;
  email?: string;
  email_verified?: boolean | string;
  locale?: string;
};

interface LinkedInTokenResponse {
  access_token?: string;
  expires_in?: number;
  scope?: string;
  token_type?: string;
  id_token?: string;
  error?: string;
  error_description?: string;
}

interface LinkedInUserInfo {
  sub: string;
  name?: string;
  given_name?: string;
  family_name?: string;
  picture?: string;
  email?: string;
  email_verified?: boolean;
  locale?: string;
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function isEmailVerified(value: LinkedInIdTokenClaims['email_verified']): boolean {
  return value === true || value === 'true';
}

function ensureLinkedInConfigured(): {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
} {
  const env = getEnv();
  if (!env.LINKEDIN_CLIENT_ID || !env.LINKEDIN_CLIENT_SECRET) {
    throw new ValidationError('Sign in with LinkedIn is not configured on this server');
  }
  return {
    clientId: env.LINKEDIN_CLIENT_ID,
    clientSecret: env.LINKEDIN_CLIENT_SECRET,
    redirectUri: env.LINKEDIN_REDIRECT_URI,
  };
}

async function exchangeAuthorizationCode(
  code: string,
  redirectUri: string
): Promise<LinkedInTokenResponse> {
  const { clientId, clientSecret, redirectUri: registered } = ensureLinkedInConfigured();

  // Reject mismatched redirectUri to neuter open-redirector forwarding from a
  // malicious client. The token exchange would fail at LinkedIn's end anyway,
  // but failing fast here keeps the error message specific.
  if (redirectUri !== registered) {
    throw new ValidationError('redirectUri does not match the configured LinkedIn redirect URI');
  }

  const response = await fetch(LINKEDIN_TOKEN_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri,
      client_id: clientId,
      client_secret: clientSecret,
    }),
  });

  const payload = (await response.json()) as LinkedInTokenResponse;

  if (!response.ok || payload.error) {
    throw new UnauthorizedError(
      payload.error_description ?? payload.error ?? 'LinkedIn authorization code exchange failed'
    );
  }

  if (!payload.id_token) {
    throw new ValidationError('LinkedIn token response did not include an ID token');
  }

  return payload;
}

async function verifyLinkedInIdToken(
  idToken: string,
  expectedAudience: string
): Promise<LinkedInIdTokenClaims> {
  const verified = await jwtVerify(idToken, linkedinJwks, {
    issuer: LINKEDIN_ISSUER,
    audience: expectedAudience,
    algorithms: ['RS256'],
  });

  const claims = verified.payload as LinkedInIdTokenClaims;
  if (!claims.sub) {
    throw new ValidationError('LinkedIn ID token is missing a subject claim');
  }

  return claims;
}

async function fetchUserInfo(accessToken: string): Promise<LinkedInUserInfo | null> {
  // Best-effort enrichment. LinkedIn's userinfo can fail transiently; the ID
  // token already carries the canonical claims we need.
  try {
    const response = await fetch(LINKEDIN_USERINFO_ENDPOINT, {
      headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' },
    });
    if (!response.ok) return null;
    return (await response.json()) as LinkedInUserInfo;
  } catch {
    return null;
  }
}

function pickName(claims: LinkedInIdTokenClaims, info: LinkedInUserInfo | null): string | null {
  const candidates = [
    info?.name,
    claims.name,
    [info?.given_name ?? claims.given_name, info?.family_name ?? claims.family_name]
      .filter(Boolean)
      .join(' '),
  ];
  for (const candidate of candidates) {
    if (!candidate) continue;
    const trimmed = candidate.trim();
    if (trimmed) return trimmed.slice(0, 100);
  }
  return null;
}

function pickAvatar(claims: LinkedInIdTokenClaims, info: LinkedInUserInfo | null): string | null {
  const url = info?.picture ?? claims.picture;
  if (!url) return null;
  if (!/^https:\/\//i.test(url)) return null;
  return url.slice(0, 2048);
}

export async function authenticateWithLinkedIn(input: LinkedInLoginInput) {
  const { clientId } = ensureLinkedInConfigured();

  const tokenResponse = await exchangeAuthorizationCode(input.code, input.redirectUri);
  // exchangeAuthorizationCode guarantees id_token is present, but the type is
  // optional on the wire shape — re-check so TS narrows without a `!`.
  const idToken = tokenResponse.id_token;
  if (!idToken) {
    throw new ValidationError('LinkedIn token response did not include an ID token');
  }
  const claims = await verifyLinkedInIdToken(idToken, clientId);
  const accessToken = tokenResponse.access_token ?? null;
  const userInfo = accessToken ? await fetchUserInfo(accessToken) : null;

  const emailFromClaims = claims.email ?? userInfo?.email ?? null;
  const email = emailFromClaims ? normalizeEmail(emailFromClaims) : null;
  const emailVerified = isEmailVerified(claims.email_verified) || userInfo?.email_verified === true;
  const displayName = pickName(claims, userInfo);
  const avatarUrl = pickAvatar(claims, userInfo);

  const prisma = getPrisma();

  const user = await prisma.$transaction(async (tx) => {
    const existingByLinkedIn = await tx.user.findUnique({
      where: { linkedinSub: claims.sub },
      select: {
        id: true,
        email: true,
        displayName: true,
        appAccountToken: true,
        avatarUrl: true,
      },
    });

    if (existingByLinkedIn) {
      const appAccountToken = existingByLinkedIn.appAccountToken ?? randomUUID();
      const updated = await tx.user.update({
        where: { id: existingByLinkedIn.id },
        data: {
          lastLoginAt: new Date(),
          ...(existingByLinkedIn.appAccountToken ? {} : { appAccountToken }),
          ...(displayName && !existingByLinkedIn.displayName ? { displayName } : {}),
          ...(avatarUrl && !existingByLinkedIn.avatarUrl ? { avatarUrl } : {}),
        },
        select: authUserSelect,
      });

      return {
        id: updated.id,
        email: updated.email,
        displayName: updated.displayName,
        appAccountToken,
        createdAt: updated.createdAt,
      };
    }

    if (!email) {
      throw new ValidationError(
        'LinkedIn did not return an email. Grant the email permission and retry.'
      );
    }

    const existingByEmail = await tx.user.findUnique({
      where: { email },
      select: {
        id: true,
        linkedinSub: true,
        displayName: true,
        appAccountToken: true,
        avatarUrl: true,
      },
    });

    if (existingByEmail?.linkedinSub && existingByEmail.linkedinSub !== claims.sub) {
      throw new ConflictError('This email is already linked to a different LinkedIn account');
    }

    if (existingByEmail && !existingByEmail.linkedinSub && !emailVerified) {
      throw new ValidationError('Cannot link account: LinkedIn has not verified this email');
    }

    if (existingByEmail) {
      const appAccountToken = existingByEmail.appAccountToken ?? randomUUID();
      const updated = await tx.user.update({
        where: { id: existingByEmail.id },
        data: {
          linkedinSub: claims.sub,
          ...(existingByEmail.appAccountToken ? {} : { appAccountToken }),
          emailVerified: emailVerified || undefined,
          lastLoginAt: new Date(),
          ...(displayName && !existingByEmail.displayName ? { displayName } : {}),
          ...(avatarUrl && !existingByEmail.avatarUrl ? { avatarUrl } : {}),
        },
        select: authUserSelect,
      });

      return {
        id: updated.id,
        email: updated.email,
        displayName: updated.displayName,
        appAccountToken,
        createdAt: updated.createdAt,
      };
    }

    const appAccountToken = randomUUID();
    const env = getEnv();
    const now = new Date();
    const created = await tx.user.create({
      data: {
        email,
        passwordHash: null,
        linkedinSub: claims.sub,
        displayName,
        avatarUrl,
        appAccountToken,
        emailVerified,
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
      id: created.id,
      email: created.email,
      displayName: created.displayName,
      appAccountToken,
      createdAt: created.createdAt,
    };
  });

  return user;
}

export async function linkLinkedInAccountToUser(
  userId: string,
  input: LinkedInLoginInput
): Promise<{ linkedinSub: string }> {
  const { clientId } = ensureLinkedInConfigured();
  const tokenResponse = await exchangeAuthorizationCode(input.code, input.redirectUri);
  const idToken = tokenResponse.id_token;
  if (!idToken) {
    throw new ValidationError('LinkedIn token response did not include an ID token');
  }
  const claims = await verifyLinkedInIdToken(idToken, clientId);

  const conflict = await withDatabaseRetry((prisma) =>
    prisma.user.findUnique({
      where: { linkedinSub: claims.sub },
      select: { id: true },
    })
  );

  if (conflict && conflict.id !== userId) {
    throw new ConflictError('This LinkedIn account is already linked to another user');
  }

  await withDatabaseRetry((prisma) =>
    prisma.user.update({
      where: { id: userId },
      data: { linkedinSub: claims.sub },
    })
  );

  return { linkedinSub: claims.sub };
}

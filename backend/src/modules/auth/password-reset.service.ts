import { createHash, randomBytes } from 'crypto';
import * as argon2 from 'argon2';
import { getPrisma, withDatabaseRetry } from '../../config/database.js';
import { sendPasswordResetEmail } from '../../services/email.js';
import { UnauthorizedError, ValidationError } from '../../utils/errors.js';

const TOKEN_EXPIRY_HOURS = 1;

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * Request a password reset. Always returns void (never reveals whether email exists).
 */
export async function requestPasswordReset(email: string): Promise<void> {
  const normalizedEmail = email.trim().toLowerCase();

  const user = await withDatabaseRetry((prisma) =>
    prisma.user.findUnique({
      where: { email: normalizedEmail },
      select: { id: true, email: true, passwordHash: true },
    })
  );

  // Silently return if user doesn't exist or has no password (Apple-only accounts)
  if (!user || !user.passwordHash) return;

  const rawToken = randomBytes(32).toString('hex');
  const tokenHash = hashToken(rawToken);
  const expiresAt = new Date(Date.now() + TOKEN_EXPIRY_HOURS * 60 * 60 * 1000);

  await withDatabaseRetry((prisma) =>
    prisma.passwordResetToken.create({
      data: { userId: user.id, tokenHash, expiresAt },
    })
  );

  await sendPasswordResetEmail(user.email, rawToken);
}

/**
 * Reset password using a valid token. Revokes all refresh tokens for security.
 */
export async function resetPassword(token: string, newPassword: string): Promise<void> {
  if (newPassword.length < 10) {
    throw new ValidationError('Password must be at least 10 characters');
  }

  const tokenHash = hashToken(token);

  const resetToken = await withDatabaseRetry((prisma) =>
    prisma.passwordResetToken.findUnique({
      where: { tokenHash },
      select: { id: true, userId: true, expiresAt: true, usedAt: true },
    })
  );

  if (!resetToken || resetToken.usedAt || resetToken.expiresAt < new Date()) {
    throw new UnauthorizedError('Invalid or expired reset token');
  }

  const passwordHash = await argon2.hash(newPassword, {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 4,
  });

  const prisma = getPrisma();
  await prisma.$transaction([
    // Mark token as used
    prisma.passwordResetToken.update({
      where: { id: resetToken.id },
      data: { usedAt: new Date() },
    }),
    // Update password and reset lockout
    prisma.user.update({
      where: { id: resetToken.userId },
      data: { passwordHash, failedLoginAttempts: 0, lockedUntil: null },
    }),
    // Revoke all refresh tokens for security
    prisma.refreshToken.updateMany({
      where: { userId: resetToken.userId, revokedAt: null },
      data: { revokedAt: new Date() },
    }),
  ]);
}

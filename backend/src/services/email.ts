import sgMail from '@sendgrid/mail';
import { getEnv } from '../config/env.js';

let initialized = false;

function ensureInitialized(): boolean {
  if (initialized) return true;
  const key = getEnv().SENDGRID_API_KEY;
  if (!key) return false;
  sgMail.setApiKey(key);
  initialized = true;
  return true;
}

export async function sendPasswordResetEmail(email: string, token: string): Promise<void> {
  if (!ensureInitialized()) {
    console.warn('[Email] SendGrid not configured — password reset email not sent');
    return;
  }

  const env = getEnv();
  const resetUrl = `${env.APP_URL}/reset-password?token=${encodeURIComponent(token)}`;

  await sgMail.send({
    to: email,
    from: env.SENDGRID_FROM_EMAIL,
    subject: 'Reset your InterviewPilot password',
    text: `You requested a password reset. Use this link to set a new password:\n\n${resetUrl}\n\nThis link expires in 1 hour. If you didn't request this, you can safely ignore this email.`,
    html: `
      <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto;">
        <h2>Reset your password</h2>
        <p>You requested a password reset for your InterviewPilot account.</p>
        <p><a href="${resetUrl}" style="display: inline-block; padding: 12px 24px; background: #2563eb; color: #fff; text-decoration: none; border-radius: 8px;">Reset Password</a></p>
        <p style="color: #666; font-size: 14px;">This link expires in 1 hour. If you didn't request this, you can safely ignore this email.</p>
      </div>
    `,
  });
}

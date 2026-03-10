import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';
import { getEnv } from '../config/env.js';

const ALGORITHM = 'aes-256-gcm';

export function encryptApiKey(plaintext: string): {
  encrypted: string;
  iv: string;
  tag: string;
} {
  const key = Buffer.from(getEnv().API_KEY_ENCRYPTION_SECRET, 'hex');
  const iv = randomBytes(16);
  const cipher = createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const tag = cipher.getAuthTag().toString('hex');

  return {
    encrypted,
    iv: iv.toString('hex'),
    tag,
  };
}

export function decryptApiKey(encrypted: string, iv: string, tag: string): string {
  const key = Buffer.from(getEnv().API_KEY_ENCRYPTION_SECRET, 'hex');
  const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(iv, 'hex'));
  decipher.setAuthTag(Buffer.from(tag, 'hex'));

  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

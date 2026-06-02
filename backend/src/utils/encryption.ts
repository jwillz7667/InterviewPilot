import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

import { getEnv } from '../config/env.js';

const ALGORITHM = 'aes-256-gcm';
const KEY_BYTES = 32; // AES-256

// Decode and validate the secret once per call. A hex secret that doesn't
// resolve to exactly 32 bytes silently truncates under Buffer.from(..,'hex')
// and createCipheriv throws an opaque "Invalid key length". Fail with an
// actionable message instead. This validates length only — IV generation and
// key derivation are unchanged, so existing ciphertext stays decryptable.
function getEncryptionKey(): Buffer {
  const key = Buffer.from(getEnv().API_KEY_ENCRYPTION_SECRET, 'hex');
  if (key.length !== KEY_BYTES) {
    throw new Error(
      'API_KEY_ENCRYPTION_SECRET must be 64 hex characters (32 bytes) for AES-256-GCM. ' +
        'Generate one with: openssl rand -hex 32'
    );
  }
  return key;
}

export function encryptApiKey(plaintext: string): {
  encrypted: string;
  iv: string;
  tag: string;
} {
  const key = getEncryptionKey();
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
  const key = getEncryptionKey();
  const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(iv, 'hex'));
  decipher.setAuthTag(Buffer.from(tag, 'hex'));

  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

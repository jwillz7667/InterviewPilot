import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

import { getEnv } from '../config/env.js';

const UPLOAD_KEY_PREFIX = 'resumes';
const UPLOAD_URL_TTL_SECONDS = 600;
const DOWNLOAD_URL_TTL_SECONDS = 300;

let _client: S3Client | undefined;

function getS3Client(): S3Client | undefined {
  const env = getEnv();
  if (!env.R2_ACCOUNT_ID || !env.R2_ACCESS_KEY_ID || !env.R2_SECRET_ACCESS_KEY) {
    return undefined;
  }

  if (_client) return _client;

  _client = new S3Client({
    region: 'auto',
    endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: env.R2_ACCESS_KEY_ID,
      secretAccessKey: env.R2_SECRET_ACCESS_KEY,
    },
  });

  return _client;
}

export function buildUploadKey(userId: string, filename: string): string {
  const sanitized = filename.replaceAll(/[^a-zA-Z0-9._-]/g, '_');
  return `${UPLOAD_KEY_PREFIX}/${userId}/${Date.now()}-${sanitized}`;
}

export function isKeyOwnedBy(key: string, userId: string): boolean {
  // Reject path traversal and cross-user access. Key must literally start with
  // `resumes/<userId>/` and contain no `..` segments.
  if (key.includes('..')) return false;
  return key.startsWith(`${UPLOAD_KEY_PREFIX}/${userId}/`);
}

export async function generateUploadPresignedUrl(
  userId: string,
  filename: string,
  contentType: string
): Promise<{ url: string; key: string } | null> {
  const client = getS3Client();
  if (!client) return null;

  const env = getEnv();
  const key = buildUploadKey(userId, filename);

  const command = new PutObjectCommand({
    Bucket: env.R2_BUCKET_NAME,
    Key: key,
    ContentType: contentType,
  });

  const url = await getSignedUrl(client, command, { expiresIn: UPLOAD_URL_TTL_SECONDS });
  return { url, key };
}

export async function generateDownloadPresignedUrl(key: string): Promise<string | null> {
  const client = getS3Client();
  if (!client) return null;

  const env = getEnv();
  // Force a download disposition so a stored object can never be rendered inline
  // in a browser context (defense-in-depth against a malicious upload slipping
  // past the upload-time content-type allowlist).
  const command = new GetObjectCommand({
    Bucket: env.R2_BUCKET_NAME,
    Key: key,
    ResponseContentDisposition: 'attachment',
  });

  return getSignedUrl(client, command, { expiresIn: DOWNLOAD_URL_TTL_SECONDS });
}

export async function deleteObject(key: string): Promise<void> {
  const client = getS3Client();
  if (!client) return;

  const env = getEnv();
  await client.send(
    new DeleteObjectCommand({
      Bucket: env.R2_BUCKET_NAME,
      Key: key,
    })
  );
}

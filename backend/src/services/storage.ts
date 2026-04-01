import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { getEnv } from '../config/env.js';

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

export async function generateUploadPresignedUrl(
  userId: string,
  filename: string,
  contentType: string
): Promise<{ url: string; key: string } | null> {
  const client = getS3Client();
  if (!client) return null;

  const env = getEnv();
  const sanitized = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
  const key = `resumes/${userId}/${Date.now()}-${sanitized}`;

  const command = new PutObjectCommand({
    Bucket: env.R2_BUCKET_NAME,
    Key: key,
    ContentType: contentType,
  });

  const url = await getSignedUrl(client, command, { expiresIn: 3600 });
  return { url, key };
}

export async function generateDownloadPresignedUrl(key: string): Promise<string | null> {
  const client = getS3Client();
  if (!client) return null;

  const env = getEnv();
  const command = new GetObjectCommand({
    Bucket: env.R2_BUCKET_NAME,
    Key: key,
  });

  return getSignedUrl(client, command, { expiresIn: 3600 });
}

export async function deleteObject(key: string): Promise<void> {
  const client = getS3Client();
  if (!client) return;

  const env = getEnv();
  await client.send(new DeleteObjectCommand({
    Bucket: env.R2_BUCKET_NAME,
    Key: key,
  }));
}

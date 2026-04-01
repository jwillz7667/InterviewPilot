import { createClient, type RedisClientType } from 'redis';
import { getEnv } from './env.js';

let _client: RedisClientType | undefined;

export async function getRedis(): Promise<RedisClientType | undefined> {
  const url = getEnv().REDIS_URL;
  if (!url) return undefined;
  if (_client?.isReady) return _client;

  _client = createClient({ url });
  _client.on('error', (err) => console.error('[Redis] Connection error:', err));
  await _client.connect();
  return _client;
}

export async function disconnectRedis(): Promise<void> {
  if (_client) {
    await _client.quit();
    _client = undefined;
  }
}

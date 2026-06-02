import { createClient, type RedisClientType } from 'redis';

import { getLogger } from '../utils/logger.js';

import { getEnv } from './env.js';

const log = getLogger().child({ module: 'redis' });

// One shared client, reconnected manually on a cooldown. We deliberately disable
// node-redis's internal reconnect loop and never create a second client while one
// exists: otherwise each down-period leaks a zombie client (its own socket timer
// and 'error' listener). Under per-request callers like the rate-limit store that
// leak becomes unbounded client growth — memory climb plus a flood of connection
// timeouts in the logs — which is enough to make a platform health check fail.
//
// getRedis() is non-blocking and never throws: it returns the live client only
// when ready, otherwise it kicks off a throttled background (re)connect and
// returns undefined so every caller degrades open (cache miss / rate-limit
// fail-open / attest in-memory fallback).
let client: RedisClientType | undefined;
let connectInFlight: Promise<void> | undefined;
let lastAttemptAt = 0;
let errorLogged = false;

const CONNECT_TIMEOUT_MS = 5_000;
const RECONNECT_COOLDOWN_MS = 30_000;

function logUnavailableOnce(message: string): void {
  if (errorLogged) return;
  errorLogged = true;
  // One line per down-period (reset on a successful connect) — never the full
  // stack on every retry, which is what previously flooded the logs.
  log.warn({ reason: message }, 'Redis unavailable, degrading open');
}

function buildClient(url: string): RedisClientType {
  const instance: RedisClientType = createClient({
    url,
    // Fail commands fast when not connected instead of queueing them: callers are
    // best-effort and degrade open, so a queued command waiting on a reconnect
    // would only add latency to the request path.
    disableOfflineQueue: true,
    socket: {
      connectTimeout: CONNECT_TIMEOUT_MS,
      // Reconnection is handled manually (see triggerReconnect) so there is never
      // both an internal loop and a manual one racing to recreate the socket.
      reconnectStrategy: false,
    },
  });
  // A connected client can still emit 'error' on an unexpected drop; swallow it
  // (throttled) so an async socket error never becomes an unhandled exception.
  instance.on('error', (err: Error) => logUnavailableOnce(err.message));
  return instance;
}

async function teardown(instance: RedisClientType): Promise<void> {
  instance.removeAllListeners();
  try {
    await instance.quit();
  } catch {
    try {
      instance.destroy();
    } catch {
      // already closed / never connected
    }
  }
}

function triggerReconnect(url: string): void {
  if (connectInFlight) return;
  if (Date.now() - lastAttemptAt < RECONNECT_COOLDOWN_MS) return;
  lastAttemptAt = Date.now();

  connectInFlight = (async () => {
    if (client) {
      const stale = client;
      client = undefined;
      await teardown(stale);
    }

    const instance = buildClient(url);
    try {
      await instance.connect();
      client = instance;
      errorLogged = false;
      log.info('Redis connected');
    } catch (err) {
      logUnavailableOnce(err instanceof Error ? err.message : String(err));
      await teardown(instance);
    }
  })().finally(() => {
    connectInFlight = undefined;
  });
}

// eslint-disable-next-line @typescript-eslint/require-await -- async only to keep the awaited Promise contract; the body is intentionally non-blocking
export async function getRedis(): Promise<RedisClientType | undefined> {
  const url = getEnv().REDIS_URL;
  if (!url) return undefined;
  if (client?.isReady) return client;
  // Non-blocking: kick off a throttled background (re)connect and degrade open.
  triggerReconnect(url);
  return undefined;
}

export async function disconnectRedis(): Promise<void> {
  const instance = client;
  client = undefined;
  connectInFlight = undefined;
  if (instance) await teardown(instance);
}

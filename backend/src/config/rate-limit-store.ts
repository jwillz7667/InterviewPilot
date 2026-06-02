import { getRedis } from './redis.js';

// Mirror of @fastify/rate-limit's bundled Lua so a Redis-backed limiter behaves
// identically to the in-memory LocalStore (INCR + PEXPIRE fixed window, with the
// same continueExceeding / exponentialBackoff semantics and PTTL reporting).
const RATE_LIMIT_LUA = `
  local key = KEYS[1]
  local timeWindow = tonumber(ARGV[1])
  local max = tonumber(ARGV[2])
  local continueExceeding = ARGV[3] == 'true'
  local exponentialBackoff = ARGV[4] == 'true'
  local MAX_SAFE_INTEGER = (2^53) - 1
  local current = redis.call('INCR', key)
  if current == 1 or (continueExceeding and current > max) then
    redis.call('PEXPIRE', key, timeWindow)
  elseif exponentialBackoff and current > max then
    local backoffExponent = current - max - 1
    timeWindow = math.min(timeWindow * (2 ^ backoffExponent), MAX_SAFE_INTEGER)
    redis.call('PEXPIRE', key, timeWindow)
  else
    timeWindow = redis.call('PTTL', key)
  end
  return {current, timeWindow}
`;

interface RateLimitStoreOptions {
  continueExceeding?: boolean;
  exponentialBackoff?: boolean;
  prefix?: string;
}

interface IncrResult {
  current: number;
  ttl: number;
}

type IncrCallback = (error: Error | null, result?: IncrResult) => void;

interface ChildRouteOptions {
  routeInfo?: { method?: string; url?: string };
  // The plugin passes the merged route params (which include path/prefix). Declaring
  // them keeps this structurally assignable to the published store interface, whose
  // child() parameter is `RouteOptions & { path; prefix }`.
  path?: string;
  prefix?: string;
}

/**
 * `@fastify/rate-limit` custom store backed by node-redis, so rate-limit counters
 * are shared across horizontally-scaled instances instead of living per-process.
 *
 * Construction: the plugin calls `new RedisRateLimitStore(globalParams)` once,
 * then `child()` per route to namespace counters by method+url. `incr` receives
 * `(key, cb, timeWindow, max)` at call time (the published `.d.ts` understates the
 * arity; the runtime passes all four — `timeWindow`/`max` are optional here only
 * to stay structurally assignable to the declared interface).
 *
 * Fails open: any Redis error is surfaced to the plugin, which — with
 * `skipOnError: true` — lets the request through. Rate limiting is best-effort
 * and must never take the API down when the cache is unavailable.
 */
export class RedisRateLimitStore {
  private readonly continueExceeding: boolean;
  private readonly exponentialBackoff: boolean;
  private readonly prefix: string;

  constructor(options: RateLimitStoreOptions = {}) {
    this.continueExceeding = options.continueExceeding ?? false;
    this.exponentialBackoff = options.exponentialBackoff ?? false;
    this.prefix = options.prefix ?? 'fastify-rate-limit-';
  }

  incr(key: string, callback: IncrCallback, timeWindow?: number, max?: number): void {
    this.run(key, timeWindow ?? 60_000, max ?? 0).then(
      (result) => callback(null, result),
      (error: unknown) => callback(error instanceof Error ? error : new Error(String(error)))
    );
  }

  child(routeOptions: ChildRouteOptions): RedisRateLimitStore {
    const method = routeOptions.routeInfo?.method ?? '';
    const url = routeOptions.routeInfo?.url ?? '';
    return new RedisRateLimitStore({
      continueExceeding: this.continueExceeding,
      exponentialBackoff: this.exponentialBackoff,
      prefix: `${this.prefix}${method}${url}-`,
    });
  }

  private async run(key: string, timeWindow: number, max: number): Promise<IncrResult> {
    const redis = await getRedis();
    if (!redis) {
      throw new Error('Redis client unavailable for rate limiting');
    }
    const result = (await redis.eval(RATE_LIMIT_LUA, {
      keys: [this.prefix + key],
      arguments: [
        String(timeWindow),
        String(max),
        String(this.continueExceeding),
        String(this.exponentialBackoff),
      ],
    })) as [number, number];
    return { current: Number(result[0]), ttl: Number(result[1]) };
  }
}

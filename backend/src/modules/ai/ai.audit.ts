import type { FastifyRequest } from 'fastify';
import type { z, ZodError, ZodSchema } from 'zod';

import { getLogger } from '../../utils/logger.js';

/// Forbidden client-supplied fields. The proxy is server-authoritative on
/// model selection — any client that tries to inject `model` (or other
/// engine-control fields) is logged as a security event so we can spot
/// attempted bypasses in production.
export const FORBIDDEN_CLIENT_FIELDS = new Set(['model', 'max_tokens', 'max_output_tokens']);

const log = getLogger().child({ module: 'ai-routes' });

interface AuditContext {
  userId?: string;
  ip?: string;
  path?: string;
}

/// Inspects a ZodError for `unrecognized_keys` issues and emits an
/// `ai.client.model.rejected` warning when a client supplied any of the
/// security-sensitive fields. The error is intended to be re-thrown after
/// auditing — Fastify will then convert it to a 400 response.
export function auditUnknownKeys(ctx: AuditContext, error: ZodError): void {
  const offendingKeys = error.errors
    .filter((issue) => issue.code === 'unrecognized_keys')
    .flatMap((issue) => (issue as { keys?: string[] }).keys ?? []);
  const securityKeys = offendingKeys.filter((key) => FORBIDDEN_CLIENT_FIELDS.has(key));
  if (securityKeys.length > 0) {
    log.warn(
      {
        event: 'ai.client.model.rejected',
        userId: ctx.userId,
        ip: ctx.ip,
        keys: securityKeys,
        path: ctx.path,
      },
      'Client attempted to override server-authoritative AI fields'
    );
  }
}

export function parseOrAudit<T extends ZodSchema>(
  schema: T,
  body: unknown,
  req: FastifyRequest
): z.infer<T> {
  const result = schema.safeParse(body);
  if (result.success) return result.data as z.infer<T>;
  auditUnknownKeys({ userId: req.user?.sub, ip: req.ip, path: req.url }, result.error);
  throw result.error;
}

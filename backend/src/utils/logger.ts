import pino from 'pino';
import { getEnv } from '../config/env.js';

let _logger: pino.Logger | undefined;

function buildLogger(): pino.Logger {
  const env = getEnv();
  return pino({
    level: env.NODE_ENV === 'production' ? 'info' : 'debug',
    base: { service: 'interviewpilot-backend' },
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        '*.password',
        '*.token',
        '*.apiKey',
      ],
      censor: '[REDACTED]',
    },
  });
}

// Module-level pino instance for code that runs outside a request context
// (services, jobs, startup hooks). Inside Fastify handlers prefer `request.log`
// so log lines are correlated with the request id.
export function getLogger(): pino.Logger {
  if (!_logger) {
    _logger = buildLogger();
  }
  return _logger;
}

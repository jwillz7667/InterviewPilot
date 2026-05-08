import * as Sentry from '@sentry/node';

import { getEnv } from './env.js';

let initialized = false;

export function initSentry(): void {
  const dsn = getEnv().SENTRY_DSN;
  if (!dsn) return;

  Sentry.init({
    dsn,
    environment: getEnv().NODE_ENV,
    tracesSampleRate: getEnv().NODE_ENV === 'production' ? 0.1 : 1.0,
  });

  initialized = true;
}

export function captureException(error: unknown, context?: Record<string, unknown>): void {
  if (!initialized) return;

  if (context) {
    Sentry.withScope((scope) => {
      for (const [key, value] of Object.entries(context)) {
        scope.setExtra(key, value);
      }
      Sentry.captureException(error);
    });
  } else {
    Sentry.captureException(error);
  }
}

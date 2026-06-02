import { diag, DiagConsoleLogger, DiagLogLevel, trace, SpanStatusCode } from '@opentelemetry/api';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { TraceIdRatioBasedSampler } from '@opentelemetry/sdk-trace-base';
import {
  SEMRESATTRS_SERVICE_NAME,
  SEMRESATTRS_SERVICE_VERSION,
} from '@opentelemetry/semantic-conventions';

import { getEnv } from './env.js';

let started = false;
let sdk: NodeSDK | null = null;

// Boots the OTel SDK if OTEL_EXPORTER_OTLP_ENDPOINT is configured. Safe to call
// multiple times — only the first call wires up instrumentation. Must run
// before any HTTP/Prisma/Fetch import so auto-instrumentation can patch them.
export function initTelemetry(): void {
  if (started) return;
  const env = getEnv();
  if (!env.OTEL_EXPORTER_OTLP_ENDPOINT) return;

  // OTel diagnostics: ERROR-level only in prod, INFO in dev. Helps spot
  // misconfigured exporters without flooding logs.
  diag.setLogger(
    new DiagConsoleLogger(),
    env.NODE_ENV === 'production' ? DiagLogLevel.ERROR : DiagLogLevel.INFO
  );

  const headers = parseOtlpHeaders(env.OTEL_EXPORTER_OTLP_HEADERS);

  sdk = new NodeSDK({
    resource: new Resource({
      [SEMRESATTRS_SERVICE_NAME]: env.OTEL_SERVICE_NAME,
      [SEMRESATTRS_SERVICE_VERSION]: process.env.RAILWAY_GIT_COMMIT_SHA ?? 'dev',
      'deployment.environment': env.NODE_ENV,
    }),
    sampler: new TraceIdRatioBasedSampler(env.OTEL_TRACES_SAMPLER_ARG),
    traceExporter: new OTLPTraceExporter({
      url: env.OTEL_EXPORTER_OTLP_ENDPOINT,
      headers,
    }),
    instrumentations: [
      getNodeAutoInstrumentations({
        // fs is too noisy and not useful for our app.
        '@opentelemetry/instrumentation-fs': { enabled: false },
        // We use our own pino logger setup; auto-instr would double-wrap.
        '@opentelemetry/instrumentation-pino': { enabled: false },
      }),
    ],
  });

  sdk.start();
  started = true;
}

// Flush + stop the OTel SDK. Called from the single graceful-shutdown path in
// index.ts so the last batch of spans is exported before the process exits.
// Telemetry must NOT register its own process-exit handlers: a stray
// process.exit() there races (and can win against) the real shutdown that drains
// in-flight SSE streams and disconnects Prisma/Redis.
export async function shutdownTelemetry(): Promise<void> {
  if (!sdk) return;
  try {
    await sdk.shutdown();
  } catch {
    // Best-effort flush; never block or fail shutdown on telemetry.
  }
}

function parseOtlpHeaders(raw: string | undefined): Record<string, string> {
  if (!raw) return {};
  const out: Record<string, string> = {};
  for (const pair of raw.split(',')) {
    const [k, v] = pair.split('=').map((s) => s.trim());
    if (k && v) out[k] = v;
  }
  return out;
}

// Wraps an async fn in a span. Use at boundaries we care about (claim-access,
// model-select, OpenAI fetches) so traces have meaningful breakdowns even
// where auto-instrumentation can't see method names.
export async function withSpan<T>(
  name: string,
  fn: () => Promise<T>,
  attributes: Record<string, string | number | boolean> = {}
): Promise<T> {
  const tracer = trace.getTracer('interviewpilot');
  return tracer.startActiveSpan(name, async (span) => {
    try {
      for (const [k, v] of Object.entries(attributes)) span.setAttribute(k, v);
      const result = await fn();
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (err) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: err instanceof Error ? err.message : String(err),
      });
      if (err instanceof Error) span.recordException(err);
      throw err;
    } finally {
      span.end();
    }
  });
}

// Returns the current trace ID (for echoing in response headers / iOS logs).
export function currentTraceId(): string | undefined {
  const span = trace.getActiveSpan();
  if (!span) return undefined;
  const ctx = span.spanContext();
  // valid traceId is 32 hex chars; "00000…" means no real trace.
  if (!ctx.traceId || /^0+$/.test(ctx.traceId)) return undefined;
  return ctx.traceId;
}

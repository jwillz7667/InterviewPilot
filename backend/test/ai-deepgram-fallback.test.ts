import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const { warnSpy, infoSpy, debugSpy, errorSpy, envState } = vi.hoisted(() => ({
  warnSpy: vi.fn(),
  infoSpy: vi.fn(),
  debugSpy: vi.fn(),
  errorSpy: vi.fn(),
  envState: {
    DEEPGRAM_API_KEY: 'master-key-abc',
    DEEPGRAM_PROJECT_ID: 'project-xyz' as string | undefined,
  },
}));

vi.mock('../src/utils/logger.js', () => ({
  getLogger: () => ({
    child: () => ({ warn: warnSpy, info: infoSpy, debug: debugSpy, error: errorSpy }),
  }),
}));

vi.mock('../src/config/env.js', () => ({
  getEnv: () => envState,
}));

vi.mock('../src/modules/billing/billing.service.js', () => ({
  authorizeAiCall: vi.fn(),
  // Plain async function, not vi.fn — clearAllMocks would otherwise wipe the
  // `mockResolvedValue(true)` shorthand and trip the quota guard mid-suite.
  canAccessRuntimeAiConfig: async () => true,
  getBillingSummary: vi.fn(),
}));

vi.mock('../src/modules/billing/billing.constants.js', () => ({
  selectModel: vi.fn(),
}));

const SUCCESS_BODY = {
  api_key_id: 'key-123',
  key: 'ephemeral-secret',
  scopes: ['usage:write'],
  expiration_date: new Date(Date.now() + 60_000).toISOString(),
};

const PERMISSION_DENIED_BODY = JSON.stringify({
  category: 'INSUFFICIENT_PERMISSIONS',
  message: "Your account does not have the required scope to perform that action for this project.",
  details: "Check that your account has the 'keys:write' scope",
});

function fetchResponse(opts: { ok: boolean; status: number; bodyText: string }): Response {
  return {
    ok: opts.ok,
    status: opts.status,
    json: async () => JSON.parse(opts.bodyText),
    text: async () => opts.bodyText,
  } as unknown as Response;
}

function mockFetchOnce(opts: { ok: boolean; status: number; bodyText: string }) {
  global.fetch = vi.fn().mockResolvedValueOnce(fetchResponse(opts)) as unknown as typeof fetch;
}

beforeEach(async () => {
  vi.clearAllMocks();
  envState.DEEPGRAM_API_KEY = 'master-key-abc';
  envState.DEEPGRAM_PROJECT_ID = 'project-xyz';
  // Each test gets a fresh module instance so the in-memory fallback state
  // does not leak. The vi.mock() registrations above persist across resets.
  vi.resetModules();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('createTranscriptionSession', () => {
  it('returns ephemeral key on happy-path mint', async () => {
    const { createTranscriptionSession } = await import('../src/modules/ai/ai.service.js');
    mockFetchOnce({ ok: true, status: 201, bodyText: JSON.stringify(SUCCESS_BODY) });

    const result = await createTranscriptionSession('user-1', { ttlSeconds: 60 });

    expect(result.apiKey).toBe('ephemeral-secret');
    expect(result.ephemeral).toBe(true);
    expect(result.expiresAt).not.toBeNull();
  });

  it('falls back to master key on 403 INSUFFICIENT_PERMISSIONS', async () => {
    const { createTranscriptionSession } = await import('../src/modules/ai/ai.service.js');
    mockFetchOnce({ ok: false, status: 403, bodyText: PERMISSION_DENIED_BODY });

    const result = await createTranscriptionSession('user-1', { ttlSeconds: 60 });

    expect(result.apiKey).toBe('master-key-abc');
    expect(result.ephemeral).toBe(false);
    expect(result.expiresAt).toBeNull();
    expect(warnSpy).toHaveBeenCalledWith(
      expect.objectContaining({ event: 'deepgram.key.mint.scope_missing' }),
      expect.stringContaining('falling back to master key')
    );
  });

  it('falls back on 401 even without category', async () => {
    const { createTranscriptionSession } = await import('../src/modules/ai/ai.service.js');
    mockFetchOnce({ ok: false, status: 401, bodyText: 'Unauthorized' });

    const result = await createTranscriptionSession('user-1', { ttlSeconds: 60 });

    expect(result.apiKey).toBe('master-key-abc');
    expect(result.ephemeral).toBe(false);
  });

  it('falls back on Deepgram 5xx', async () => {
    const { createTranscriptionSession } = await import('../src/modules/ai/ai.service.js');
    mockFetchOnce({ ok: false, status: 502, bodyText: 'Bad Gateway' });

    const result = await createTranscriptionSession('user-1', { ttlSeconds: 60 });

    expect(result.apiKey).toBe('master-key-abc');
    expect(result.ephemeral).toBe(false);
    expect(warnSpy).toHaveBeenCalledWith(
      expect.objectContaining({ event: 'deepgram.key.mint.upstream_error' }),
      expect.stringContaining('falling back to master key')
    );
  });

  it('throws TRANSCRIPTION_UNAVAILABLE on unexpected 4xx (not auth)', async () => {
    const { createTranscriptionSession } = await import('../src/modules/ai/ai.service.js');
    mockFetchOnce({ ok: false, status: 422, bodyText: '{"category":"INVALID_BODY"}' });

    await expect(
      createTranscriptionSession('user-1', { ttlSeconds: 60 })
    ).rejects.toMatchObject({
      statusCode: 502,
      code: 'TRANSCRIPTION_UNAVAILABLE',
    });
  });

  it('skips network round-trip while fallback is active', async () => {
    const { createTranscriptionSession } = await import('../src/modules/ai/ai.service.js');
    const fetchSpy = vi
      .fn()
      .mockResolvedValueOnce(
        fetchResponse({ ok: false, status: 403, bodyText: PERMISSION_DENIED_BODY })
      );
    global.fetch = fetchSpy as unknown as typeof fetch;

    await createTranscriptionSession('user-1', { ttlSeconds: 60 });
    expect(fetchSpy).toHaveBeenCalledTimes(1);

    // Subsequent calls should not invoke fetch at all.
    const result = await createTranscriptionSession('user-2', { ttlSeconds: 60 });

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(result.apiKey).toBe('master-key-abc');
    expect(result.ephemeral).toBe(false);
  });

  it('returns master key when DEEPGRAM_PROJECT_ID is unset', async () => {
    envState.DEEPGRAM_PROJECT_ID = undefined;
    const { createTranscriptionSession } = await import('../src/modules/ai/ai.service.js');
    const fetchSpy = vi.fn();
    global.fetch = fetchSpy as unknown as typeof fetch;

    const result = await createTranscriptionSession('user-1', { ttlSeconds: 60 });

    expect(result.apiKey).toBe('master-key-abc');
    expect(result.ephemeral).toBe(false);
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});

describe('probeDeepgramKeyScopes', () => {
  it('warns and pre-warms fallback when scope is missing', async () => {
    const { probeDeepgramKeyScopes } = await import('../src/modules/ai/ai.service.js');
    mockFetchOnce({
      ok: true,
      status: 200,
      bodyText: JSON.stringify({ scopes: ['usage:write'] }),
    });

    await probeDeepgramKeyScopes();

    expect(warnSpy).toHaveBeenCalledWith(
      expect.objectContaining({ event: 'deepgram.key.probe.scope_missing' }),
      expect.any(String)
    );
  });

  it('logs ok when keys:write is present', async () => {
    const { probeDeepgramKeyScopes } = await import('../src/modules/ai/ai.service.js');
    mockFetchOnce({
      ok: true,
      status: 200,
      bodyText: JSON.stringify({ scopes: ['usage:write', 'keys:write'] }),
    });

    await probeDeepgramKeyScopes();

    expect(infoSpy).toHaveBeenCalledWith(
      expect.objectContaining({ event: 'deepgram.key.probe.ok' }),
      expect.any(String)
    );
  });

  it('does not throw when probe fails', async () => {
    const { probeDeepgramKeyScopes } = await import('../src/modules/ai/ai.service.js');
    global.fetch = vi.fn().mockRejectedValueOnce(new Error('network down')) as unknown as typeof fetch;

    await expect(probeDeepgramKeyScopes()).resolves.toBeUndefined();
    expect(warnSpy).toHaveBeenCalledWith(
      expect.objectContaining({ event: 'deepgram.key.probe.error' }),
      expect.any(String)
    );
  });

  it('no-ops when DEEPGRAM_PROJECT_ID is unset', async () => {
    envState.DEEPGRAM_PROJECT_ID = undefined;
    const { probeDeepgramKeyScopes } = await import('../src/modules/ai/ai.service.js');
    const fetchSpy = vi.fn();
    global.fetch = fetchSpy as unknown as typeof fetch;

    await probeDeepgramKeyScopes();

    expect(fetchSpy).not.toHaveBeenCalled();
  });
});

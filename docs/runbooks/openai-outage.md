# Runbook: OpenAI outage

## Symptoms

- Sentry: spike in `AI_UPSTREAM_ERROR` from `ai.service.ts`.
- iOS: users report "AI is busy" or empty answers in live sessions.
- OpenAI status page (https://status.openai.com) shows degraded chat-completions or realtime.

## Triage

1. Check OpenAI status page first — fastest signal.
2. Sentry → `ai.client.model.served` event count vs. `AI_UPSTREAM_ERROR` count over the last 30 min. If error rate >5%, treat as outage.
3. Confirm it's not us — `curl -sS -o /dev/null -w "%{http_code}\n" https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY"`. 5xx from OpenAI = outage; 401/403 = our key got rotated.
4. Check `OPENAI_API_KEY` in Railway env hasn't been removed/expired.

## Resolution

### Short outage (<10 min)

OpenAI usually recovers fast. The backend already returns 502 with a typed error and the iOS client retries once. No action needed unless duration >10 min.

### Sustained outage (>10 min)

1. **Communicate** — post a status banner on the marketing site (`website/app/page.tsx` has a `StatusBanner` slot — set `STATUS_MESSAGE` env var and redeploy website).
2. **Ship a degrade flag** — set Railway env `AI_DEGRADED_MODE=1` and redeploy backend. This:
   - Disables `/api/v1/ai/chat/stream` (returns 503 with retry-after).
   - Forces iOS clients to fall back to Answer Bank pre-baked responses (already implemented in `ResponseGeneratorService.swift` when receiving 503).
3. Monitor Sentry for resolution. When OpenAI status page returns to "all systems normal", remove `AI_DEGRADED_MODE` and redeploy.

### Realtime-specific outage

Voice Prep uses `gpt-realtime`. If realtime is down but chat-completions is up:

1. Set `OPENAI_REALTIME_MODEL=gpt-4o-realtime-preview` (older but more stable).
2. Redeploy. iOS picks up the new model on next session start.
3. If realtime is fully out, gate Voice Prep behind a feature flag — set `VOICE_PREP_DISABLED=1` and redeploy. iOS shows "Voice Prep temporarily unavailable" copy.

## Postmortem checklist

- Outage start/end timestamps from OpenAI status RSS.
- Number of failed sessions, bucketed by tier (PREMIUM users get priority refunds via `billing.refund` admin tool).
- Did the iOS fallback to Answer Bank actually trigger? (Sentry: `ai.fallback.used` event count.)
- Should we add a second AI provider for redundancy? (Anthropic / Google) — track in long-term roadmap.

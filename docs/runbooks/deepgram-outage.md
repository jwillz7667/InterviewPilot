# Runbook: Deepgram outage

## Symptoms

- iOS: live transcript stops updating mid-session; users see frozen transcript.
- Sentry-Cocoa: spike in `deepgram.ws.disconnect` breadcrumbs without successful reconnect.
- Deepgram status page (https://status.deepgram.com) shows degraded streaming.

## Triage

1. Deepgram status page — fastest signal.
2. Test from a dev machine:
   ```sh
   curl -sS https://api.deepgram.com/v1/projects -H "Authorization: Token $DEEPGRAM_API_KEY" | jq '.projects | length'
   ```
   - 200 + project count = REST is fine, streaming may still be down.
   - 5xx = full outage.
3. Check Railway env: `DEEPGRAM_API_KEY` and `DEEPGRAM_PROJECT_ID` set. Ephemeral key minting via `createTranscriptionSession` requires both.

## Resolution

### REST + WS both up but high latency

The iOS client (`DeepgramService.swift`) already does exponential backoff with jitter. Acceptable up to ~5s reconnect time. No action.

### Deepgram WS streaming down (REST up)

1. iOS clients can't transcribe live audio. The backend cannot fix this.
2. Communicate via marketing site banner. Set `STATUS_MESSAGE` env var.
3. **Fallback path**: iOS supports Apple `SFSpeechRecognizer` as a backup. Ship a remote config flag:
   - Set Railway env `TRANSCRIPTION_FALLBACK=apple` and redeploy.
   - Backend exposes this via `GET /api/v1/config/runtime`; iOS reads on app launch + every 5 min.
   - Apple's recognizer is on-device, slower, less accurate, but works offline.

### Full Deepgram outage

Same as above — fallback to Apple. Voice Prep (OpenAI Realtime) is unaffected because it does its own transcription.

### Key rotation needed

If Deepgram support indicates our keys were leaked:

1. Generate new master key in Deepgram console.
2. Update Railway env `DEEPGRAM_API_KEY`. Redeploy.
3. Old ephemeral keys minted before the rotation will keep working until their TTL expires (~5 min). New sessions get new keys.

## Postmortem checklist

- Outage timestamps.
- Did the Apple fallback actually work? (iOS Sentry `transcription.fallback.used` count.)
- Average user-visible delay during fallback (Apple recognizer adds ~800ms vs Deepgram's ~250ms).
- Long-term: should we keep paying for two transcription vendors instead of using Apple as cold fallback?

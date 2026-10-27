# Reliability review and acceptance checks

## Scope

The personal app connects directly to Deepgram's Voice Agent API. Profiles and saved sessions are local. There is no application backend, account authentication, StoreKit entitlement check, PostgreSQL, Redis or remote profile synchronization in the runtime path.

A passing build and deterministic tests verify code behavior under the tested conditions. They do not establish account access, microphone correctness, real-world latency or factual accuracy.

## Original failure points

Reviewed baseline: `823be749e288ae27b064efb32f77610483074ae9`.

| Baseline location | Problem removed by the direct connection |
| --- | --- |
| `backend/src/modules/ai/ai.service.ts:782` | Streaming upstream fetch had no deadline. The route attached its disconnect handler only after upstream headers arrived, so early disconnects could leave work running. |
| `backend/src/modules/ai/ai.service.ts:787` | Each answer waited for billing access, a user provider lookup and a database-backed session grant before inference. |
| `backend/src/modules/ai/ai.service.ts:createTranscriptionSession` | Startup key minting used a network request without a timeout before opening the transcription socket. |
| `backend/src/config/env.ts:14` and `backend/src/index.ts:141` | Database/authentication configuration and database health were required even for an otherwise healthy AI provider. |
| `InterviewPilot/ContentView.swift` | Login, subscription refresh and trial/paywall state gated access to core functionality. |
| `.github/workflows/testflight.yml` | Distribution selected Xcode 16 even though the app requires iOS 26.1. |

The new direct path removes these dependencies rather than deploying them to another free hosting service. No existing hosted service or database is shut down by a code refactor.

## Protocol expectations

- Endpoint: `wss://agent.deepgram.com/v1/agent/converse`.
- Authenticate using the personal Deepgram key. Never log the key or authorization header.
- Receive `Welcome`, send `Settings`, then wait for `SettingsApplied` before sending microphone audio or a typed message.
- Encode mono PCM audio consistently with the declared encoding and sample rate.
- Use a Deepgram-managed model without a custom `think.endpoint`. A separate OpenAI key is not needed.
- Render `ConversationText` promptly. It is statement-based; do not assume token deltas or Nova-style interim transcripts.
- Keep the connection alive during audio silence and handle provider errors, closed sockets, cancellations and interruptions visibly.
- Bound captured audio and restored context. Old queued audio must not replay as if it were current after a long outage.
- Preserve the most recent useful answer during an interruption. Never silently present a stale answer as a response to a different question.
- Restore canonical candidate context and appropriate recent history when opening a replacement connection.
- The service synthesizes speech even if the client ignores the binary audio. Silent presentation is not a text-only billing guarantee.

References: [message flow](https://developers.deepgram.com/docs/voice-agent-message-flow), [models](https://developers.deepgram.com/docs/voice-agent-llm-models), [context](https://developers.deepgram.com/docs/voice-agent-conversation-context), [ConversationText](https://developers.deepgram.com/docs/voice-agent-conversation-text), [keepalive](https://developers.deepgram.com/docs/agent-keep-alive).

## Automated checks

Run `swift test` and the unsigned simulator build documented in [README.md](../README.md). Tests should exercise protocol ordering, malformed or unknown messages, prompt/context bounds, cancellation and queue overflow with deterministic fixtures. Do not put provider keys in fixtures or make ordinary CI spend account credit.

CI is deliberately credential-free. A failed or unavailable live smoke test must be reported as unverified rather than treated as a pass.

## Physical-device acceptance

Record device, iOS version, app commit, Deepgram model, network type, date and outcome. Use the actual microphone/headphone setup intended for the interview.

| Check | Expected outcome |
| --- | --- |
| Fresh launch | No login, account creation, subscription or server-health gate. |
| Key entry and relaunch | Key persists in Keychain; it is absent from logs, exports and visible history. |
| Missing/invalid key or exhausted credit | Clear actionable error, no endless connection spinner, and a working way to edit settings or retry. |
| Microphone permission denied | Permission guidance; typed question entry remains usable where supported. |
| Resume import | Import a text PDF and a UTF-8 text resume; preview/edit the text. An image-only or unreadable file produces useful guidance without losing existing profile content. |
| Job URL import | Import a public job page, review extracted structured/text content, and confirm edited text reaches session context. |
| Unavailable job page | A blocked, invalid, private-network or oversized URL fails safely; direct text entry remains available. |
| Candidate context | Questions about experience use the supplied resume/profile; missing facts are not invented. |
| Role and follow-up context | Suggestions address the selected role and refer correctly to recent interview questions. |
| Live audio | Spoken questions are recognized with the intended speaker and microphone routing. |
| Practice mode | Start a practice session with the chosen candidate and job context; responses match the selected mode. |
| Typed question | A manual question generates a relevant answer without requiring microphone capture. |
| Long question and natural pauses | The app does not repeatedly answer unfinished fragments or overwrite useful text with an unrelated partial response. |
| Network loss and recovery | A visible connection state, bounded retry behavior, no duplicate answer or stale audio flood, and an explicit recovery path. |
| Phone/audio interruption and route change | Capture stops or recovers safely without a crash; the status accurately reflects what is happening. |
| Stop/restart repeatedly | No abandoned microphone session, ghost response, duplicated callback or continuously billed idle connection. |
| Longer session | Run at least 30 minutes, checking memory behavior, transcript/history growth, and session retention. |
| Local history/export | Save, reopen, export and delete a session; profile and history operations do not require the retired backend. |
| App restart | Local data remains available. A interrupted live connection is not falsely shown as active. |

iOS microphone capture does not provide arbitrary access to another app's call audio. Verify that the microphone can hear the interviewer. A simulator cannot establish real-device audio reliability.

## Measuring latency and answer quality

Use at least 20 representative spoken questions, including a long question, a short follow-up, a behavioral prompt and a role-specific technical prompt. Record the interval from the audible end of the question to the first useful text displayed. Report the sample count, median, p95, failures and network conditions; do not substitute total provider audio latency for this display metric.

Also check whether each suggestion answers the actual question, reflects the candidate's facts, uses a conversational form and avoids unsupported claims. Lower latency with incorrect or premature answers is not a successful result.

No live latency percentile or universal reliability guarantee is asserted by this document. Device and live-provider checks remain required even when CI passes.


## Verification on 2026-10-26

- All 35 core tests passed together: protocol framing and queue limits, job HTML/JSON-LD extraction and rejection cases, resume/job prompt grounding and Unicode limits, serialized persistence, checkpoint upserts and backup recovery.
- All app Swift sources passed native iOS 26.1 typechecking together with Swift 6 and MainActor default isolation.
- The supplied Deepgram credential authenticated successfully without storing it in this repository.
- A live managed-model typed-input smoke test returned first text in 767 ms. A synthetic spoken-question test streamed mono PCM16 at 16 kHz in 20 ms frames, transcribed the question exactly, and returned first text 957 ms after the last spoken frame was sent. These are two single samples, not percentile benchmarks, latency guarantees, or tests of the physical device microphone.
- Local full simulator packaging was blocked by unavailable CoreSimulator runtimes. GitHub CI performs the complete simulator build. Physical-device microphone, interruptions, route changes, adverse networks and long-session acceptance checks above remain necessary.

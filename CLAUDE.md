# InterviewPilot

Real-time AI interview assistant: Audio → Deepgram Nova-3 transcription → OpenAI response generation.

## Build

```bash
# iOS (Xcode 17+, iOS 26 SDK, deployment target 26.1+)
xcodebuild -project InterviewPilot.xcodeproj -scheme InterviewPilot -configuration Debug -destination 'generic/platform=iOS Simulator' build

# Backend (Node 22, Fastify 5, Prisma 6 + PostgreSQL)
cd backend && npm ci && npm run build    # Install + compile
npm run dev                               # Dev server (tsx watch)
npm run db:migrate                        # Create/run migrations
npm run db:generate                       # Regenerate Prisma client
```

Bundle ID: `com.res.jobhopperAI` | Team: `487LC4H9U4` | Deploy: Railway (Dockerfile, `/health`)

## Swift Patterns (MUST follow)

- **`PBXFileSystemSynchronizedRootGroup`** — new .swift files auto-discover. **Never edit pbxproj.**
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** — all types are `@MainActor` by default. Do NOT add `@MainActor` annotations manually.
- **`@Observable` classes** — use `@ObservationIgnored` on all stored closure properties.
- **No third-party dependencies** — all networking (WebSocket, SSE, REST) uses native `URLSession`.
- **SwiftData persistence** — `InterviewSession` stores exchanges as JSON-encoded `Data`. Follow the existing `encode()`/`decode()` pattern.
- **API keys** — stored in iOS Keychain via `KeychainService`, fetched from backend post-auth. Never hardcode.
- **SourceKit false positives** — cross-file errors in the editor are lies. Trust `xcodebuild`, not IDE diagnostics.

## Architecture

### iOS (105 Swift files, MVVM + @Observable)

```
InterviewPilotApp.swift          Entry point, SwiftData ModelContainer
ContentView.swift                Tab router
Configuration/
  AppEnvironment.swift           Backend URL, feature flags, dev access
  Constants.swift                APIConfig: models, thresholds, limits
  DependencyContainer.swift      LiveSessionViewModel factory
Features/                        9 modules: Auth, Dashboard, History, Insights,
                                 LiveSession, Onboarding, SessionReview, SessionSetup, Settings
Services/
  Audio/                         AVAudioEngine capture + playback
  Transcription/                 Deepgram WebSocket (nova-3, 16kHz, linear16)
  AI/                            PromptBuilder, ResponseGenerator (SSE), QuestionClassifier,
                                 AnswerBank, JobDescriptionAnalyzer, SimilarityMatch
  Auth/                          AuthService, SubscriptionService (StoreKit 2)
  Storage/                       KeychainService, SessionStorage, RemoteSync
  Document/                      Resume parser, job listing analyzer
  Network/                       AuthenticatedAPIClient
Models/                          InterviewSession (SwiftData), Exchange, InterviewType,
                                 ResponseFormat/Behavior/Tone/Emphasis/QualityMode, etc.
DesignSystem/
  Theme.swift                    IATheme — Material 3 blue palette, spacing, radii
  Typography.swift               IATypography — Public Sans / Source Sans 3 / Plus Jakarta Sans
  Components                     GlassCard, TypewriterText, ShimmerModifier, StepIndicator, etc.
```

**Core pipeline:** `LiveSessionViewModel` orchestrates: AudioCaptureService → DeepgramService (WebSocket) → QuestionClassifier → PromptBuilder → ResponseGeneratorService (SSE streaming).

**OpenAI models (from APIConfig):**
| Context | Model |
|---------|-------|
| Default | `gpt-4.1-mini` |
| Technical / Premium | `gpt-4.1` |
| Coding | `o4-mini` |
| Prep | `gpt-4.1` |

### Backend (Fastify + Prisma)

`backend/src/modules/`: auth, users, settings, api-keys, sessions, exchanges, answer-banks, billing, config. JWT auth, rate limiting (100 req/min), CORS, Argon2 passwords. Schema: `backend/prisma/schema.prisma`.

Subscription tiers: TRIAL, PLUS, PRO, SANDBOX — gated via `SubscriptionService` / `BillingEntitlement`.

## Workflow

For any task beyond trivial one-line fixes, spawn multiple sub-agents in parallel to explore, analyze, and resolve the problem. Use agents to read related files, trace call chains, check both iOS and backend sides simultaneously, and review changes — don't do everything sequentially in the main context.

## Critical Rules

1. **PromptBuilder is high-stakes** — contains 13+ expert prompt engineering rules. Changes directly impact interview response quality. Read it fully before modifying.
2. **Design system** — use `IATheme` for colors/spacing/radii, `IATypography` for text styles. Not IPTheme/IPTypography.
3. **Subscription checks** — verify `BillingEntitlement` feature flags before adding premium-gated features.
4. **Token limits** — standard: 320 tokens, premium: 380 tokens. Respect these in prompt/response logic.
5. **Predictive buffering** — utteranceEndMs=2200, endpointingMs=700, minWords=10, confidence=0.75. These are tuned values; don't change without testing.

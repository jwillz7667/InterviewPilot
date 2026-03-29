# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

### iOS App
```bash
# Build for simulator (CI configuration)
xcodebuild -project InterviewPilot.xcodeproj -scheme InterviewPilot -configuration Debug -destination 'generic/platform=iOS Simulator' build

# Build for device (requires signing)
xcodebuild -project InterviewPilot.xcodeproj -scheme InterviewPilot -configuration Release -destination 'generic/platform=iOS'
```
- Xcode 17+ / iOS 26 SDK required, deployment target iOS 26.1+
- Bundle ID: `com.res.jobhopperAI`, Team: `487LC4H9U4`
- Uses `PBXFileSystemSynchronizedRootGroup` — new Swift files auto-discover, **no pbxproj edits needed**

### Backend (Fastify + Prisma)
```bash
cd backend
npm ci                    # Install dependencies
npm run dev               # Dev server with hot reload (tsx watch)
npm run build             # TypeScript compile to dist/
npm start                 # Production (node dist/index.js)
npm run db:generate       # Regenerate Prisma client
npm run db:migrate        # Create/run migrations (dev)
npm run db:deploy         # Apply migrations (prod)
npm run db:seed           # Seed database
npm run db:studio         # Prisma Studio GUI
```
- Node 22, TypeScript 5.7, Fastify 5, Prisma 6 + PostgreSQL
- Deployed to Railway via Dockerfile (healthcheck at `/health`)

### CI
GitHub Actions runs on PR + push to main: backend `npm ci && npm run build`, iOS `xcodebuild` simulator build.

## Architecture

### iOS App (SwiftUI, zero external dependencies)

**Pattern:** MVVM with `@Observable` (Swift 6 concurrency). All types are `@MainActor` by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` build setting). Use `@ObservationIgnored` on callback closures in `@Observable` classes.

**Core pipeline:** Audio (AVAudioEngine) → Deepgram Nova-3 WebSocket transcription → OpenAI SSE response generation. Orchestrated by `LiveSessionViewModel`.

**Key layers:**
- `InterviewPilotApp.swift` — Entry point, SwiftData ModelContainer setup
- `ContentView.swift` — Tab router (Prepare, History, Settings)
- `Configuration/` — `AppEnvironment` (backend URL, feature flags), `Constants` (APIConfig: models, thresholds, limits), `DependencyContainer` (LiveSessionViewModel factory, loads API keys from Keychain)
- `Features/` — 10 feature modules: Auth, Onboarding, SessionSetup, LiveSession, SessionReview, History, Settings, PrepSession, Shared
- `Services/` — Audio capture/playback, Deepgram WebSocket, ResponseGenerator (SSE), PromptBuilder, QuestionClassifier, AnswerBank, Auth, Subscription (StoreKit 2), Keychain, SessionStorage, RemoteSync
- `Models/` — InterviewSession (SwiftData), Exchange, InterviewType, ResponseFormat/Behavior/Tone/Emphasis/QualityMode, PreComputedAnswer, LatencyTelemetry
- `DesignSystem/` — `IPTheme` (colors, spacing, radii, gradients), `IPTypography` (semantic type scale), `IPAnimations`, component library (GlassCard, TypewriterText, ShimmerModifier, etc.)

**API keys** are stored in iOS Keychain via `KeychainService` and fetched from the backend post-authentication. Never hardcode keys.

**OpenAI models by context:** `gpt-4.1-nano` (default), `gpt-4.1-mini` (technical/premium), `o4-mini` (coding), `gpt-4.1` (prep), `gpt-realtime-1.5` (voice prep).

### Backend (Fastify)

Modular structure under `backend/src/modules/`: auth, users, settings, api-keys, sessions, exchanges, answer-banks, billing, config. JWT auth, rate limiting (100 req/min), CORS, Argon2 password hashing. Schema at `backend/prisma/schema.prisma`.

## Critical Implementation Notes

- SourceKit frequently shows false cross-file errors in the editor; the actual `xcodebuild` succeeds. Trust the build, not the IDE diagnostics.
- WebSocket (Deepgram) and SSE (OpenAI) are implemented with native `URLSession` — no third-party networking libraries.
- The `PromptBuilder` contains expert-level prompt engineering with 13+ critical rules. Changes to prompts directly impact response quality; review `FINAL-SPEC.md` for the full specification before modifying.
- SwiftData model (`InterviewSession`) stores exchanges as JSON-encoded `Data`. Use the existing encode/decode pattern when modifying exchange persistence.
- Subscription tiers (sandbox, pro, plus, trial) gate features via `SubscriptionService`. Check `BillingEntitlement` feature flags before adding premium-gated features.

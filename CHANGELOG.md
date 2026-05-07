# Changelog

All notable changes to InterviewPilot are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `/health` now probes Redis with `PING` in addition to PostgreSQL, surfacing `redis: connected | unconfigured | disconnected` for readiness checks.
- `PrivacyInfo.xcprivacy` declaring required-reason API use (`UserDefaults` CA92.1) and collected data types — required for App Store submission.
- `gitleaks` pre-commit hook (opt-in via `.githooks/install.sh`) to block accidentally-committed secrets.
- Centralized password policy schema (≥12 chars, complexity classes) in `backend/src/shared/validation/password.ts`, shared by registration and password-reset flows.
- Atomic password-reset token consumption inside a database transaction, preventing replay across concurrent requests.
- Atomic failed-login increment with automatic 15-minute lockout after 5 failures.
- Soft-delete extension now intercepts `deleteMany` (in addition to `delete`) and covers `interviewProfile`.

### Changed
- `AuthenticatedAPIClient` (iOS) uses a dedicated `URLSession` with 15s request and 30s resource timeouts, isolated from `URLSession.shared` (which handles long-running SSE streams).
- `KeychainService.save` is now atomic — `SecItemUpdate` first, falling through to `SecItemAdd` only on `errSecItemNotFound`.
- Replaced `nonisolated(unsafe) Timer` in live + practice interview view models with cancellable `Task<Void, Never>` loops aligned with Swift 6 structured concurrency.
- `DELETE /users/me` now uses `prisma.user.delete` so the soft-delete extension intercepts it.
- Tightened `bodyLimit` to 4 KB on auth and profile-update routes.
- Tightened rate limit on `GET /api-keys/:provider/decrypt` to 5 requests per hour with a structured audit log.

### Removed
- Force-unwrapped `URL(string:)` constructors in `AuthService` (now throws a typed `AuthError.invalidConfiguration`).
- Redundant `@@index([tokenHash])` on `RefreshToken` — the existing `@unique` constraint already provides an equivalent B-tree index.
- Cached AI master keys from local Keychain — the AI proxy now mints ephemeral credentials server-side.

### Security
- Closed C-01 (AI key exposure on client), C-02 (upload IDOR), C-03 (Apple PEM in `.env.example`), and quick-win findings QW-02 through QW-20 from the internal audit.

## [1.0.0] — 2026-04-05

### Added
- Initial production release.
- iOS client with real-time interview assistance: live transcription via Deepgram Nova-3, classified routing to OpenAI GPT-4.1 / GPT-4.1-mini / o4-mini, streamed responses.
- Practice interview mode with bi-directional voice AI via the OpenAI Realtime API.
- Session history with SwiftData local storage and authenticated remote sync.
- Subscription tiers (`TRIAL`, `PLUS`, `PRO`, `SANDBOX`) gated through StoreKit 2 and `BillingEntitlement` feature flags.
- Resume + job-listing parsing for context-aware prompts.
- Sign in with Apple (server-side Apple ID token verification) and email/password authentication with Argon2id hashes.
- Backend deployed to Railway (Fastify 5, Prisma 6, PostgreSQL, optional Redis cache).

[Unreleased]: https://github.com/jwillz7667/InterviewPilot/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jwillz7667/InterviewPilot/releases/tag/v1.0.0

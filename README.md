# InterviewPilot

Real-time AI interview assistant for iOS. Captures the interviewer's voice, transcribes it with sub-second latency, and streams a tailored response back to the candidate based on their resume, the job description, and the question's intent.

[![CI](https://github.com/jwillz7667/InterviewPilot/actions/workflows/ci.yml/badge.svg)](https://github.com/jwillz7667/InterviewPilot/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](./LICENSE)
[![iOS](https://img.shields.io/badge/iOS-26.1%2B-blue.svg)](https://developer.apple.com/ios/)
[![Node](https://img.shields.io/badge/Node-22-green.svg)](https://nodejs.org/)

> Proprietary software © Viral Ventures LLC. All rights reserved. See [LICENSE](./LICENSE).

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
  - [Backend](#backend)
  - [iOS](#ios)
- [Development Workflow](#development-workflow)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Security](#security)
- [Contributing](#contributing)
- [Support](#support)

---

## Overview

InterviewPilot helps candidates pass real interviews by listening in real time and surfacing high-signal, role-tailored answers. It is built around three pipelines:

1. **Capture** — `AVAudioEngine` records the interviewer's voice from the device microphone.
2. **Transcribe** — A persistent WebSocket to **Deepgram Nova-3** returns interim and final transcripts at ~16 kHz with predictive endpointing.
3. **Respond** — A classifier routes each question to the correct **OpenAI** model (GPT-4.1, GPT-4.1-mini, or o4-mini), and a streamed response is rendered as a typewriter on screen.

The product is iOS-first. The backend is a stateless Fastify API that authenticates users, mints short-lived AI proxy credentials, persists session history, and gates premium features through StoreKit-driven subscriptions.

### Subscription Tiers

| Tier      | Use case                                       |
|-----------|------------------------------------------------|
| `TRIAL`   | Time-limited evaluation                        |
| `PLUS`    | Standard tier                                  |
| `PRO`     | Premium models, unlimited sessions             |
| `SANDBOX` | Internal testing / App Store sandbox accounts  |

---

## Architecture

```
┌──────────────────────────────────────────────┐
│                 iOS Client                   │
│ SwiftUI · SwiftData · @Observable VMs        │
│                                              │
│ AudioCapture ─► Deepgram WS ─► Classifier    │
│                                  │            │
│                                  ▼            │
│                          PromptBuilder        │
│                                  │            │
│                                  ▼            │
│                       Backend AI Proxy (SSE)  │
└──────────────────┬───────────────────────────┘
                   │ HTTPS · JWT (RS256)
                   ▼
┌──────────────────────────────────────────────┐
│              Backend (Fastify 5)             │
│ Auth · Sessions · Billing · AI Proxy · Files │
│ Prisma ORM ──► PostgreSQL                    │
│ redis client ──► Redis (billing cache)       │
│ StoreKit Server API ──► Apple                │
│ Sentry · Pino structured logs                │
└──────────────────────────────────────────────┘
```

The backend is the **only** code path that holds long-lived AI provider credentials. Clients call `/api/v1/ai/*` proxy routes; the backend authenticates the user, attaches its own keys, and streams the upstream response back over Server-Sent Events.

---

## Repository Layout

```
.
├── InterviewPilot/                # iOS app sources (SwiftUI)
│   ├── App/                       # @main entrypoint, SwiftData container
│   ├── Configuration/             # AppEnvironment, Constants, DI
│   ├── Features/                  # Feature modules (Auth, LiveSession, ...)
│   ├── Services/                  # Audio, Transcription, AI, Auth, Storage
│   ├── Models/                    # Domain types + SwiftData models
│   ├── DesignSystem/              # IATheme, IATypography, components
│   └── PrivacyInfo.xcprivacy      # Apple privacy manifest
├── InterviewPilot.xcodeproj/
├── backend/                       # Fastify + Prisma server
│   ├── src/
│   │   ├── modules/               # Feature modules (auth, ai, billing, ...)
│   │   ├── middleware/            # Authenticate, soft-delete, ...
│   │   ├── plugins/               # Fastify plugins
│   │   ├── shared/                # Cross-cutting (validation, errors)
│   │   ├── config/                # env, database, redis, sentry
│   │   └── index.ts               # Server entrypoint
│   ├── prisma/
│   │   ├── schema.prisma
│   │   └── migrations/
│   ├── Dockerfile
│   └── docker-entrypoint.sh
├── .githooks/                     # gitleaks pre-commit (opt-in via install.sh)
├── .github/                       # CI, issue + PR templates, CODEOWNERS
├── docker-compose.yml             # Local backend stack
└── railway.json                   # Railway deployment config
```

A more detailed map of agent-internal conventions lives in `CLAUDE.md` (not committed; ignored by `.gitignore`).

---

## Prerequisites

| Tool                     | Version                | Notes                                    |
|--------------------------|------------------------|------------------------------------------|
| **Xcode**                | 17 (iOS 26 SDK)        | iOS deployment target 26.1+              |
| **Node.js**              | 22 LTS                 | Pinned via `backend/.nvmrc`              |
| **PostgreSQL**           | 15+                    | Local dev or hosted                      |
| **Redis**                | 7+                     | Optional — disables billing cache if absent |
| **Docker**               | 24+                    | For `docker-compose` local backend       |
| **Apple Developer Acct** | Team `487LC4H9U4`      | Required for device runs + StoreKit      |

---

## Quick Start

### Backend

```bash
cd backend
nvm use                          # honors .nvmrc → Node 22
cp .env.example .env             # fill in DATABASE_URL, JWT_SECRET, etc.
npm ci
npm run db:generate              # generate Prisma client
npm run db:migrate               # apply migrations to local DB
npm run dev                      # tsx watch mode on http://localhost:3000
```

Smoke test:

```bash
curl -s http://localhost:3000/health | jq
# → { "status": "ok", "database": "connected", "redis": "connected" | "unconfigured" }
```

#### Docker (alternative)

```bash
docker-compose up --build
```

### iOS

1. Open `InterviewPilot.xcodeproj` in Xcode 17.
2. Select the `InterviewPilot` scheme and an iOS 26 simulator (or a registered device).
3. Update `BACKEND_BASE_URL` in `Info.plist` if you are pointing at a non-default backend.
4. Build & run (`⌘R`).

> **Important**: New `.swift` files are auto-discovered by `PBXFileSystemSynchronizedRootGroup`. Do not edit `project.pbxproj` manually.

CLI build (matches CI):

```bash
xcodebuild -project InterviewPilot.xcodeproj \
  -scheme InterviewPilot \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

---

## Development Workflow

### Branching

- `main` is always deployable.
- Feature branches: `feat/<short-slug>`
- Fix branches: `fix/<ticket-or-slug>`
- Refactors: `refactor/<slug>`

### Commits

Conventional Commits (`feat:`, `fix:`, `refactor:`, `perf:`, `test:`, `docs:`, `chore:`, `build:`, `ci:`). Imperative subject ≤ 72 chars. Body explains *why*. One logical change per commit.

### Pull Requests

Every PR must:

1. Pass CI (`backend-build`, `ios-build`).
2. Include a **Test plan** in the description.
3. Link the originating issue / ticket.
4. Be reviewed by at least one CODEOWNER.

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the full process.

### Pre-commit secret scanning

Activate the bundled gitleaks hook once per clone:

```bash
./.githooks/install.sh
```

This sets `core.hooksPath = .githooks` so every `git commit` runs `gitleaks protect --staged --redact`. Bypass with `git commit --no-verify` only when justified.

### Backend scripts

```bash
npm run dev          # tsx watch
npm run build        # tsc to dist/
npm start            # node dist/index.js
npm run db:migrate   # prisma migrate dev
npm run db:deploy    # prisma migrate deploy (production)
npm run db:generate  # regenerate Prisma client
npm run db:studio    # interactive DB browser
```

---

## Configuration

The backend validates all environment variables at boot via `zod`. Required variables in production:

| Variable                       | Purpose                                          |
|--------------------------------|--------------------------------------------------|
| `DATABASE_URL`                 | PostgreSQL connection string                     |
| `REDIS_URL`                    | Redis connection (optional; disables cache if unset) |
| `JWT_SECRET`                   | RS256 / HS256 secret for access tokens           |
| `JWT_ISSUER` / `JWT_AUDIENCE`  | Token claim guards                               |
| `OPENAI_API_KEY`               | Server-side OpenAI key (proxied to clients)      |
| `DEEPGRAM_API_KEY`             | Server-side Deepgram key (proxied to clients)    |
| `APPLE_SIGN_IN_PRIVATE_KEY`    | Sign In with Apple verification                  |
| `APP_KEY_ENCRYPTION_KEY`       | At-rest encryption for user-stored API keys      |
| `CORS_ORIGIN`                  | Comma-separated origins; **must not be `*`** in production |
| `SENTRY_DSN`                   | Error reporting                                  |
| `SENDGRID_API_KEY`             | Transactional email (password reset, etc.)       |

The full list with example values lives in `backend/.env.example`.

---

## Deployment

The backend is deployed to **Railway** from `main` on every push:

- Build configuration: `backend/Dockerfile` (multi-stage Node 22 Alpine).
- Start: `backend/docker-entrypoint.sh` → `node dist/index.js`.
- Migrations: run `npx prisma migrate deploy` against the production database before promoting a build that includes a new migration.
- Health check: `GET /health` returns `200` only when the database connection is healthy.
- Rollbacks: re-deploy a prior commit via `railway redeploy`.

The iOS app ships through the App Store. Build numbers are managed in Xcode; production releases are tagged `v<semver>` on `main`.

---

## Security

We take security seriously. To report a vulnerability, see [`SECURITY.md`](./SECURITY.md). Do not open public issues for security reports.

Highlights:

- All AI provider credentials are server-only — clients never see them.
- All passwords hashed with **Argon2id** (64 MiB memory cost, 3 iterations).
- All transit secured with TLS; tokens redacted from logs via Pino redaction.
- All staging changes scanned by `gitleaks` (pre-commit + CI).
- All required-reason API usage declared in `InterviewPilot/PrivacyInfo.xcprivacy`.

---

## Contributing

This is a private repository. Internal contributors should read [`CONTRIBUTING.md`](./CONTRIBUTING.md) before opening a PR.

---

## Support

| Topic                | Where                                    |
|----------------------|------------------------------------------|
| Bug reports          | GitHub Issues (Bug Report template)      |
| Feature requests     | GitHub Issues (Feature Request template) |
| Security disclosures | See [`SECURITY.md`](./SECURITY.md)       |
| Internal questions   | `#interviewpilot` (Slack)                |

---

© 2026 [Viral Ventures LLC](https://viral-ventures-llc.com). All rights reserved.

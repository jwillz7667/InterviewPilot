# InterviewPilot Backend

Fastify 5 + Prisma 6 + PostgreSQL service that authenticates users, persists interview sessions, mints short-lived AI provider credentials, and gates premium features through StoreKit 2.

> Part of the InterviewPilot project. See the [root README](../README.md) for the iOS client and product overview.

## Stack

- **Runtime**: Node.js 22 (Alpine in production)
- **Framework**: Fastify 5
- **Database**: PostgreSQL (Prisma 6 ORM)
- **Cache**: Redis 7 (optional — disables billing cache when absent)
- **Auth**: JWT (access + refresh), Argon2id password hashes
- **Mail**: SendGrid
- **Object storage**: AWS S3 (via `@aws-sdk/client-s3`)
- **Telemetry**: Sentry, Pino structured logs
- **Deployment**: Railway (Dockerfile multi-stage build)

## Quick Start

```bash
nvm use                        # honors .nvmrc → Node 22
cp .env.example .env           # fill in secrets locally
npm ci                         # reproducible install
npm run db:generate            # Prisma client
npm run db:migrate             # apply local migrations
npm run dev                    # tsx watch on http://localhost:3000
```

Smoke test:

```bash
curl -s http://localhost:3000/health | jq
```

A healthy response:

```json
{
  "status": "ok",
  "timestamp": "2026-05-07T17:08:30.069Z",
  "environment": "development",
  "database": "connected",
  "redis": "connected"
}
```

## Scripts

| Command                | Effect                                                  |
|------------------------|---------------------------------------------------------|
| `npm run dev`          | tsx watch with hot reload                               |
| `npm run build`        | TypeScript compile to `dist/`                           |
| `npm start`            | Run the compiled server (`node dist/index.js`)          |
| `npm run db:migrate`   | Create + apply a development migration                  |
| `npm run db:deploy`    | Apply pending migrations (use in production)            |
| `npm run db:generate`  | Regenerate the Prisma client                            |
| `npm run db:seed`      | Seed local data (`prisma/seed.ts`)                      |
| `npm run db:studio`    | Open Prisma Studio                                      |

## Project Layout

```
src/
├── index.ts                # Server entrypoint, plugin registration, /health
├── config/                 # env, database, redis, sentry
├── middleware/             # authenticate, soft-delete, error wrappers
├── plugins/                # Fastify plugins (request-id, …)
├── shared/                 # Cross-cutting utilities (validation, errors)
├── modules/                # Feature modules — one per domain
│   ├── auth/               # Register, login, refresh, Apple sign-in, password reset
│   ├── users/              # /users/me CRUD
│   ├── settings/           # User-scoped settings
│   ├── api-keys/           # User-stored AI provider keys (encrypted at rest)
│   ├── sessions/           # Interview session persistence + analysis
│   ├── exchanges/          # Per-question Q/A turns
│   ├── answer-banks/       # User-curated reusable answers
│   ├── interview-profiles/ # Per-role configurations
│   ├── billing/            # StoreKit 2 entitlements + Apple verification
│   ├── ai/                 # Server-side proxy for OpenAI + Deepgram
│   ├── uploads/            # S3 pre-signed URL minting
│   └── config/             # Public client configuration
└── utils/                  # Encryption, errors, helpers
prisma/
├── schema.prisma           # Single source of truth for models + indexes
└── migrations/             # Each PR adds one migration directory
```

The dependency direction is **inward**: `modules → shared → config`. Modules never reach into each other's internals; cross-cutting types live in `shared/`.

## Environment Variables

Production validates all required variables at boot via `zod`. The full list with example values is in [`.env.example`](./.env.example). Highlights:

| Variable                   | Required in production | Notes                                   |
|----------------------------|-----------------------|-----------------------------------------|
| `DATABASE_URL`             | yes                   | PostgreSQL connection string            |
| `REDIS_URL`                | recommended           | Disables billing cache when unset       |
| `JWT_SECRET`               | yes                   | Asymmetric or shared key                |
| `JWT_ISSUER`, `JWT_AUDIENCE` | yes                 | Claim guards on verification            |
| `OPENAI_API_KEY`           | yes                   | Server-side; never exposed to clients   |
| `DEEPGRAM_API_KEY`         | yes                   | Server-side; never exposed to clients   |
| `APPLE_SIGN_IN_PRIVATE_KEY` | yes                  | PEM string, multi-line                  |
| `APP_KEY_ENCRYPTION_KEY`   | yes                   | AES-256 key for user-stored API keys    |
| `CORS_ORIGIN`              | yes                   | Must NOT be `*` in production           |
| `SENTRY_DSN`               | yes                   | Error reporting                         |
| `SENDGRID_API_KEY`         | yes                   | Transactional email                     |

## Health Check

`GET /health` probes both PostgreSQL and Redis in parallel:

- `database`: `connected` | `disconnected`
- `redis`: `connected` | `unconfigured` | `disconnected`
- `status`: `ok` only when the database is connected (Redis is non-critical).

Railway's deployment health check uses the same endpoint.

## Database Migrations

Migrations are committed as `prisma/migrations/<timestamp>_<slug>/migration.sql`. Workflow:

```bash
# 1. Edit schema.prisma
# 2. Generate a migration (also applies it locally)
npm run db:migrate -- --name <slug>

# 3. Commit both schema.prisma and the new migration directory
# 4. Production applies pending migrations on the next deploy via:
#    npx prisma migrate deploy
```

Never edit a committed migration. If you need to revert, write a new compensating migration.

## Soft Deletes

Models with a `deletedAt` column (`User`, `InterviewSession`, `AnswerBank`, `InterviewProfile`) participate in the soft-delete extension wired in `src/middleware/soft-delete.ts`:

- `delete` and `deleteMany` are translated to `update`/`updateMany` setting `deletedAt = now()`.
- `findMany` and `findFirst` automatically filter out rows where `deletedAt IS NOT NULL`.
- `findUnique` is **not** rewritten (Prisma cannot mix unique-by + arbitrary `where`); callers requiring the exclusion must filter explicitly.

Hard deletes still happen for `User` cascades (e.g. account deletion is irreversible by policy).

## Rate Limiting & Body Limits

| Surface                                  | Limit                                  |
|------------------------------------------|----------------------------------------|
| Global                                   | 100 requests / minute / client         |
| `/api/v1/auth/*` (except logout)         | 10 requests / minute / client          |
| `/api/v1/api-keys/:provider/decrypt`     | 5 requests / hour / client             |
| Auth + profile mutation request bodies   | 4 KB                                   |

Rate-limit decisions are recorded in Pino logs with `event: rate_limit.exceeded`.

## Logging & Audit Events

Pino emits structured JSON in production. Sensitive paths are auto-redacted (`req.body.password`, `*.token`, `req.headers.authorization`, …). Routes that act on credentials emit explicit audit events:

- `event: api_key.decrypt` — every successful decrypt of a user-stored AI provider key.
- `event: auth.failed_login` — every wrong-password attempt.
- `event: auth.lockout` — every triggered 15-minute lockout.

## Deployment

Production is deployed to **Railway** from `main` on every push.

- **Service**: `InterviewPilot`
- **Environment**: `production`
- **Build**: multi-stage `Dockerfile` (Node 22 Alpine, ~150 MB final image)
- **Entrypoint**: `docker-entrypoint.sh` → `node dist/index.js`
- **Health check**: `GET /health` (5 minute window, retries every 10–60 s)

Setting an environment variable triggers an auto-redeploy. Use `railway variables --set KEY=VALUE` to update.

## License

Proprietary — © 2026 Viral Ventures LLC. All rights reserved. See the [root LICENSE](../LICENSE).

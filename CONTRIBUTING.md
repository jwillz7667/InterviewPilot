# Contributing to InterviewPilot

Thank you for working on InterviewPilot. This document is for **internal contributors** at Viral Ventures LLC and approved external collaborators. The project is proprietary; please review the [LICENSE](./LICENSE) before contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Set Up](#getting-set-up)
- [Branching Strategy](#branching-strategy)
- [Commit Messages](#commit-messages)
- [Pull Requests](#pull-requests)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pre-commit Hooks](#pre-commit-hooks)
- [Releases](#releases)

## Code of Conduct

Treat every contributor with respect. Disagreements happen — keep them about the work, not the person. Harassment of any kind is grounds for revoking repository access.

## Getting Set Up

See the **Quick Start** section of [`README.md`](./README.md) for environment setup. Ensure both `xcodebuild` (iOS) and `npm run build` (backend) succeed locally before opening a PR.

Activate the bundled gitleaks hook once per clone:

```bash
./.githooks/install.sh
```

## Branching Strategy

| Prefix       | Use case                                  | Example                                |
|--------------|-------------------------------------------|----------------------------------------|
| `feat/`      | New user-facing or developer-facing feature | `feat/practice-interview-bookmarks`  |
| `fix/`       | Bug fix                                   | `fix/sse-reconnect-loop`               |
| `refactor/`  | Internal restructuring, no behavior change | `refactor/promptbuilder-extract-rules` |
| `perf/`      | Performance improvement                   | `perf/billing-cache-warmup`            |
| `docs/`      | Documentation only                        | `docs/security-policy`                 |
| `chore/`     | Tooling, CI, dependency bumps             | `chore/bump-prisma-6.20`               |
| `test/`      | Test-only changes                         | `test/auth-rate-limit`                 |

Branches are short-lived. Rebase onto `main` before opening a PR.

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<optional scope>): <subject>

<optional body — explain WHY, not WHAT>

<optional footer — refs, breaking changes, co-authors>
```

Rules:

- **Subject** is imperative mood, ≤ 72 characters, no trailing period.
- **One logical change per commit.** Refactors and behavior changes never share a commit.
- **Body** wraps at 72 characters and explains motivation, constraints, and trade-offs.
- **Type** is one of: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `build`, `ci`, `revert`.

Example:

```
fix(auth): block password-reset replay across concurrent requests

`updateMany` with `usedAt: null AND expiresAt > now` is the only
predicate that lets exactly one caller win. Inside `$transaction`
with the user update + refresh-token revocation, this turns a
read-then-write race into a single atomic claim.
```

## Pull Requests

A good PR is small, reviewable, and reversible. Before opening one:

1. **Rebase** onto the latest `main`.
2. **Run the full local check**:
   ```bash
   cd backend && npm run build && npx tsc --noEmit
   xcodebuild -project ../InterviewPilot.xcodeproj -scheme InterviewPilot \
     -configuration Debug -destination 'generic/platform=iOS Simulator' build
   ```
3. **Confirm CI passes** (`backend-build`, `ios-build`).
4. **Fill in the PR template** — summary, test plan, screenshots for UI work.

PRs require at least one [CODEOWNER](./.github/CODEOWNERS) approval before merging. Force-pushes to a PR branch are fine; force-pushes to `main` are not.

### Merging

- Default merge strategy: **squash**. The squash subject must follow Conventional Commits.
- Reviewers should leave the squash body to the PR author or copy the most useful commit messages.

## Code Style

The repository follows the conventions captured in `CLAUDE.md` (agent-internal guidance, not committed). High-level rules:

### Architecture

- Feature-first directory layout (`features/auth/`), not type-first (`controllers/`, `models/`).
- Dependencies flow inward: UI → application → domain → infrastructure. Domain code is framework-free.
- Every feature exposes a single barrel (`index.ts`) as its public API; deep cross-feature imports are forbidden.

### TypeScript / Backend

- `strict: true`. No `any`, no unjustified `as` casts.
- Validate all external input with `zod` at the boundary; trust internal types.
- Errors are typed (`AppError`, discriminated unions). No `catch (e: any)` swallowing.
- Pure functions where possible; isolate side effects at the edges.

### Swift / iOS

- Swift 6 concurrency (`async/await`, `@Observable`, structured concurrency).
- All types are `@MainActor` by default via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — do not annotate manually.
- Use value types (`struct`, `enum`) unless reference semantics are required.
- New `.swift` files are auto-discovered via `PBXFileSystemSynchronizedRootGroup` — never edit `project.pbxproj` directly.
- All `@Observable` classes mark stored closure properties `@ObservationIgnored`.

### Comments

Default to writing **no comments**. Add one only when the *why* is non-obvious — a hidden constraint, a workaround for a specific bug, or behavior that would surprise a reader. Don't explain *what* the code does; well-named identifiers do that.

## Testing

We follow the [test pyramid](https://martinfowler.com/articles/practical-test-pyramid.html): many fast unit tests, fewer integration tests, fewest end-to-end.

| Tier         | Hits                                  | Where                                   |
|--------------|---------------------------------------|-----------------------------------------|
| Unit         | Pure logic, no I/O                    | `*.test.ts` next to source              |
| Integration  | Real DB, real Fastify, real Prisma    | `backend/test/integration/*.test.ts`    |
| End-to-end   | Real device or simulator              | iOS `UITests/` target                   |

Coverage target: **80%+** on `backend/src/domain/` and `backend/src/modules/*/service.ts`. Coverage is a smell-detector, not a goal — one meaningful test beats five trivial ones.

## Pre-commit Hooks

The repository ships a `gitleaks`-based pre-commit hook in `.githooks/`. After cloning, run:

```bash
./.githooks/install.sh
```

The hook scans only staged content (`gitleaks protect --staged --redact`) and is fast enough for routine commits. It warns and skips if `gitleaks` is not installed locally.

## Releases

1. Update `CHANGELOG.md`: move `[Unreleased]` entries under a new dated `[x.y.z]` section.
2. Tag the release commit: `git tag -s v<x.y.z> -m "release: v<x.y.z>"`.
3. Push tags: `git push origin v<x.y.z>`.
4. The Railway production environment auto-deploys on `main`. Verify `/health` returns `{ "status": "ok" }` before announcing.
5. iOS releases are submitted via App Store Connect; production builds use the App Store distribution scheme.

If a release introduces a database migration, run `npx prisma migrate deploy` against production **before** the deploying build is promoted to traffic.

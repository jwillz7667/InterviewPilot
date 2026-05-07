<!--
Thanks for opening a PR. Keep the title in Conventional Commits format
(e.g. `feat(billing): add proration on plan downgrade`). Small,
single-purpose PRs ship faster and review more cleanly.
-->

## Summary

<!-- 1–3 bullets describing what this change does and why. -->

-

## Type of Change

<!-- Tick whichever apply. -->

- [ ] Feature (`feat`)
- [ ] Bug fix (`fix`)
- [ ] Refactor (`refactor`)
- [ ] Performance (`perf`)
- [ ] Tests (`test`)
- [ ] Documentation (`docs`)
- [ ] Build / CI / chore (`build`, `ci`, `chore`)
- [ ] Breaking change

## Test Plan

<!-- How did you verify the change? Reviewers should be able to follow these steps to reproduce. Include relevant commands, fixtures, and observations. -->

- [ ]
- [ ]

## Screenshots / Recordings

<!-- For UI work only. Drag-and-drop screenshots or a short screen recording. -->

## Risk & Rollout

<!-- Anything reviewers should know about deploy ordering, feature flags, schema migrations, or rollback plans. -->

## Checklist

- [ ] My commits follow [Conventional Commits](../CONTRIBUTING.md#commit-messages).
- [ ] I rebased onto `main` and resolved conflicts.
- [ ] I ran `npm run build` (backend) and `xcodebuild ... build` (iOS) locally and both pass.
- [ ] I added or updated tests where appropriate.
- [ ] I updated `CHANGELOG.md` under `[Unreleased]` if this change is user- or operator-visible.
- [ ] I confirmed no secrets are present in the diff (`gitleaks` pre-commit ran).

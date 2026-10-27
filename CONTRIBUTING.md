# Contributing to InterviewPilot

This is proprietary software for authorized contributors. See [LICENSE](LICENSE).

## Development

Use Xcode 26.1 or later. Follow [README.md](README.md) to build the iOS app and run `swift test`. No backend services or provider credentials are required for the automated checks.

Use short-lived `feat/`, `fix/`, `refactor/`, `perf/`, `test/` or `docs/` branches and Conventional Commit messages. Explain the user-visible problem, the resulting behavior and the verification in each pull request. Do not force-push `main`.

## Design constraints

- The app is personal and operates without accounts, subscription checks or a hosted application backend.
- Keep candidate profiles and session history local. Do not add analytics or upload user data outside the explicit Deepgram request path.
- Keep provider credentials in Keychain. No real secrets in fixtures, shared schemes, screenshots, logs or exported sessions.
- Keep transport and audio work bounded and cancellable. A failed connection must produce a useful state, not an indefinite spinner.
- Render received text immediately. Do not add a cosmetic typing delay to the interview flow.
- Pure protocol, prompt and buffering logic belongs in code that can be exercised by `swift test`.
- Use structured concurrency; isolate UI state on the main actor and keep audio callbacks light.
- Xcode discovers new Swift files automatically. Edit project settings only when a real configuration change requires it.

## Verification

Before submitting:

```bash
swift test
xcodebuild -project InterviewPilot.xcodeproj \
  -scheme InterviewPilot \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Test failure behavior as well as successful answers: malformed protocol messages, connection loss, cancellation, invalid credentials, and bounded history or audio queues. Use deterministic test doubles; do not make ordinary unit tests spend provider credit.

Changes to microphone capture, interruption handling or session lifetime also require the relevant physical-device checks in [docs/RELIABILITY.md](docs/RELIABILITY.md). Record which checks were actually run and leave unperformed checks explicitly unverified.

## Secret scanning

The opt-in pre-commit hook runs a staged, redacted `gitleaks` scan when the tool is installed:

```bash
./.githooks/install.sh
```

Never bypass a real credential finding. Remove the secret from the staged change and rotate it if it was committed.

## Distribution

CI builds unsigned simulator code. Physical-device and distribution signing remain local Apple tooling concerns. The optional TestFlight workflow runs only when explicitly dispatched and requires the repository owner's signing setup. Neither merging a branch nor creating a tag should automatically publish this personal app.

There are no database migrations, entitlement jobs or backend deployment steps.

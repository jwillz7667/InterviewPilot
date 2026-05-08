# InterviewPilot — Fastlane

Lanes for TestFlight uploads, App Store submission, and screenshot capture.

## Lanes

```sh
bundle exec fastlane beta         # build + upload to TestFlight
bundle exec fastlane release      # build + submit metadata to App Store Connect
bundle exec fastlane screenshots  # capture screenshots (needs UI test target)
bundle exec fastlane tests        # run iOS unit tests (needs XCTest target — Phase C2)
```

## First-time setup

See `docs/runbooks/testflight.md` for the full walkthrough. TL;DR:

1. **App Store Connect API key** — Apple Developer → Users and Access → Keys → "+", role "App Manager". Download the `.p8`.
2. **Match repo** — create a private GitHub repo (e.g. `interviewpilot-certs`) for encrypted certs.
3. **GitHub secrets** — set `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT` (base64'd `.p8`), `MATCH_GIT_URL`, `MATCH_PASSWORD`.
4. Run `bundle exec fastlane match appstore` once locally to generate certs into the match repo.
5. Tag a release: `git tag v1.0.0 && git push origin v1.0.0` — `.github/workflows/testflight.yml` picks it up.

## Local install

```sh
brew install rbenv ruby-build
rbenv install 3.3.0
rbenv local 3.3.0
gem install bundler
bundle install
```

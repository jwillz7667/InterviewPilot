# Optional TestFlight distribution

The native app runs directly from Xcode without Fastlane. These lanes are only for the repository owner's manual Apple distribution workflow. They do not deploy an application backend or supply AI credentials.

Use Xcode 26.1 or later. Configure your own Apple signing identity and App Store Connect API access before distribution. The bundle identifier remains `com.res.jobhopperAI`.

```bash
bundle install
bundle exec fastlane tests
bundle exec fastlane beta
```

- `tests` runs the provider-free `swift test` suite.
- `beta` builds and uploads to TestFlight. It increments the build number locally; review that change before committing.
- `release` uploads an archive to App Store Connect without submitting it for review or enabling automatic release.

For CI, dispatch **TestFlight (manual)** from GitHub Actions only when you intend to upload a build. Pushes and tags do not trigger publication.

The workflow uses existing repository signing secrets:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT` (base64-encoded signing key)
- Optional Match configuration: `MATCH_GIT_URL`, `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION`

Do not add a Deepgram key to this workflow. The resulting app must ask for the personal installation's key and store it in Keychain.

Complete the physical-device checklist in [docs/RELIABILITY.md](../docs/RELIABILITY.md) before relying on a distributed build.

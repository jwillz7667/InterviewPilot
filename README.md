# InterviewPilot

A personal iOS interview assistant. Keep a candidate profile, resume and target role on your device, then listen to questions and receive contextual answer suggestions through Deepgram.

The app has no account sign-in, subscription tiers, usage quotas, hosted application backend, database server or remote profile sync. It uses Apple's native frameworks and connects directly to Deepgram's Voice Agent API. A funded Deepgram API key is required; a separate OpenAI account or API key is not.

Proprietary software © Viral Ventures LLC. See [LICENSE](LICENSE).

## How it works

1. Enter your own Deepgram key in the app. It is stored in the device Keychain, not committed or embedded in the app bundle.
2. Create or choose a local candidate profile. Import a PDF or text resume, or paste the resume text. Paste a job-posting URL to retrieve a description, then review and edit the extracted text before using it. You can also paste a job description directly.
3. Choose interview assistance or practice mode and your response preferences.
4. Start a live session or submit a typed question. Microphone audio goes directly to Deepgram over a secure WebSocket.
5. Deepgram transcribes and generates a suggestion using its managed `gpt-4.1-mini` integration. That model's usage is billed through Deepgram.
6. Read incoming suggestions immediately, review the local session history, and export a session when needed.

Profiles and saved history live on the device. Audio and the context used to answer questions leave the device for Deepgram processing. There is no application server storing your data, and there is no automatic cloud backup or cross-device synchronization provided by this app.

## Build and run

- macOS with **Xcode 26.1 or later** and an installed iOS SDK.
- An iPhone or simulator running **iOS 26.1 or later**.
- A Deepgram key with Voice Agent access and available credit.
- An Apple development signing identity for physical-device installation.

Open `InterviewPilot.xcodeproj`, select the `InterviewPilot` scheme, and run. The existing bundle identifier `com.res.jobhopperAI` is preserved.

Run the core tests and a simulator build from the repository root:

```bash
swift test
xcodebuild -project InterviewPilot.xcodeproj \
  -scheme InterviewPilot \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

No Node.js installation, package server, PostgreSQL, Redis, Docker or Railway deployment is needed. New Swift files inside `InterviewPilot/` are discovered automatically by the Xcode project. The project contains no third-party Swift package dependencies.

## Resume and job context

PDF and plain-text resume imports are processed on the device. Review the extracted text before starting; scanned image-only PDFs may require you to paste selectable text. Only the context used for an AI session is sent to Deepgram.

Job URL import supports public pages and structured job-posting data. Fetching has limits and a timeout; authenticated, blocked or heavily JavaScript-rendered pages may not expose a usable description. If extraction fails or includes unrelated page content, paste and edit the job description manually. Imported page text is reference material, not trusted instructions for the assistant.

## Audio and response behavior

The input is the **device microphone**. iOS does not make another app's call audio available through this capture path. For a remote interview, the microphone must actually hear the other speaker, for example from a separate computer's speakers. Test the intended microphone and headphone setup before use.

The app requests answer suggestions as text and does not play the agent's voice. Deepgram's Voice Agent service still synthesizes audio internally; discarding that output does not make the service free or establish a lower price.

Deepgram sends `ConversationText` statements rather than a documented token-by-token text stream. Suggestions are displayed when they arrive without an artificial typewriter delay. Response time depends on speech endpointing, network conditions, model load and answer length. This repository does not claim a measured sub-second response time or guaranteed answer accuracy.

Candidate facts and interview context guide the answer. Review suggestions and use only examples that accurately represent your experience.

## Cost and credentials

Deepgram bills its managed Voice Agent service through the Deepgram account. Existing Deepgram credit can cover this usage subject to the account's terms. See [Deepgram pricing](https://deepgram.com/pricing) and [managed LLM documentation](https://developers.deepgram.com/docs/voice-agent-llm-models).

Do not place a personal API key in source code, `Info.plist`, an Xcode shared scheme, build logs or an exported session. Each personal installation supplies its own key through the app. An App Store distribution must not contain a shared developer key.

## Reliability and verification

[docs/RELIABILITY.md](docs/RELIABILITY.md) records the original failure points, the test strategy and physical-device acceptance checks. CI runs the core tests and simulator build without real provider credentials. Passing those checks does not verify microphone hardware, Deepgram account access or live latency; those need the device checks.

The old backend, commercial website, billing jobs and deployment configuration have been removed from this repository. This code change does **not** shut down any previously deployed Railway service, delete hosted data, or cancel hosting charges.

## Project layout

| Path | Purpose |
| --- | --- |
| `InterviewPilot/` | Native app, local data, audio capture and Deepgram connection |
| `InterviewPilot.xcodeproj/` | iOS build and signing configuration |
| `Package.swift` | Core logic test package |
| `.github/workflows/ci.yml` | Credential-free automated verification |
| `docs/RELIABILITY.md` | Review findings and device acceptance checks |
| `fastlane/` | Optional manual TestFlight distribution |

See [CONTRIBUTING.md](CONTRIBUTING.md) for development conventions and [SECURITY.md](SECURITY.md) for credential and disclosure guidance.

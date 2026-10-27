# Security Policy

InterviewPilot is a personal iOS application. The current source has no hosted application backend, user account system, subscription service or analytics SDK.

## Credentials and data

- Supply a personal Deepgram API key through the app's secure settings. Store it in Keychain; never hardcode it in a distributable build.
- Send credentials only to the intended Deepgram HTTPS/WebSocket endpoint. Do not log authorization headers or include them in diagnostics, session exports or crash reports.
- Profiles, resumes and session history are stored locally. Audio and the context submitted for inference are sent to Deepgram and its managed model processing path.
- Candidate resumes may include names, email addresses and other personal information. Only provide material you intend to use for the interview.
- This app does not provide automatic cross-device synchronization or a server-side recovery copy.
- Keeping the existing bundle identifier does not migrate data that existed only in the retired backend. Do not delete an old hosted database before independently preserving any needed records.

## Reporting a vulnerability

Do not include credentials or personal interview content in a public GitHub issue. Use the repository's private vulnerability reporting feature when enabled, or the existing project security contact: **security@viralventures.io**.

Include the affected commit or version, a concise reproduction and the likely impact. Remove real keys and personal data from examples.

The relevant scope is the native application and its repository build configuration. Report vulnerabilities in Deepgram, Apple or other third-party services directly to their maintainers. Do not attack provider infrastructure or access someone else's credentials or data.

## Verification before distribution

Review the app's privacy manifest and App Store privacy answers against the actual data flow and current Deepgram processing terms. A local-only profile database does not mean live AI requests stay on the device.

Run secret scanning against the proposed commit and inspect shared Xcode schemes, plist files, fixtures and exported diagnostics. The repository must contain no real provider keys.

Removing old deployment files does not revoke deployed credentials, stop an existing service or erase hosted data. Those are separate operational changes and are not performed by this refactor.

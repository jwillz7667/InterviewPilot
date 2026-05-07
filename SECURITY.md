# Security Policy

[Viral Ventures LLC](https://viral-ventures-llc.com) takes the security of InterviewPilot — both the iOS application and its backend services — seriously. Thank you for taking the time to disclose vulnerabilities responsibly.

## Supported Versions

We support security updates for the following:

| Component        | Supported Versions                       |
|------------------|------------------------------------------|
| iOS application  | The latest App Store release             |
| Backend service  | The currently deployed `main` branch     |

Older versions, internal forks, and unreleased branches are out of scope.

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security reports.**

Instead, email us at **security@viralventures.io** with:

- A clear description of the vulnerability and its potential impact.
- Steps to reproduce, including any required configuration, sample inputs, or proof-of-concept code.
- The affected component (iOS, backend, infrastructure) and version, commit, or environment.
- Your name and contact information (a pseudonym is fine).
- Whether you would like to be credited publicly once a fix ships.

If your finding involves sensitive data (PII, credentials, exfiltrated content), encrypt the report with our PGP key — request the key by sending an empty email to `security@viralventures.io` with the subject line `pgp request` and we will reply with the current public key.

## What to Expect

| Stage                              | Target                          |
|------------------------------------|---------------------------------|
| Acknowledgement of receipt          | Within 2 business days          |
| Initial triage and severity rating  | Within 5 business days          |
| Patched release for high/critical   | Within 14 calendar days         |
| Public disclosure (coordinated)     | Negotiated with the reporter    |

We will keep you informed of our progress and ask for clarifying details as needed. Once a fix is deployed, we will, with your permission, acknowledge your contribution in the release notes.

## Scope

In scope:

- The InterviewPilot iOS application (`com.res.jobhopperAI`).
- The backend API at `interviewpilot-production.up.railway.app` and any other production hosts owned by Viral Ventures LLC.
- Infrastructure-as-code, build pipelines, and configuration files in this repository.

Out of scope:

- Third-party services we depend on (Deepgram, OpenAI, Apple, Railway, Sentry, SendGrid, etc.). Please report directly to those providers.
- Vulnerabilities requiring physical access to an unlocked device.
- Reports based on outdated dependencies without a working exploit path.
- Social-engineering attacks against our staff or contractors.
- Denial-of-service attacks, including brute-force, volumetric, or resource-exhaustion attacks.
- Reports generated solely from automated scanning tools, without manual validation.

## Safe Harbor

We will not pursue legal action against researchers who:

1. Make a good-faith effort to comply with this policy.
2. Avoid privacy violations, destruction of data, and disruption of service.
3. Use only the accounts they own (or have explicit permission to test).
4. Do not exfiltrate, retain, or share confidential data beyond what is necessary to demonstrate the vulnerability.
5. Give us reasonable time to investigate and remediate before public disclosure.

If in doubt about whether a particular activity is authorized, contact us before proceeding.

## Hall of Fame

We publicly thank researchers who help us improve InterviewPilot's security in the [`CHANGELOG.md`](./CHANGELOG.md) under the `Security` heading of each release.

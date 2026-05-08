# Runbooks

Operational playbooks for InterviewPilot. Each runbook follows the same shape:

1. **Symptoms** — how the incident surfaces (alert, user report, dashboard).
2. **Triage** — what to check first, in order of cheapest-to-confirm.
3. **Resolution** — concrete steps to recover.
4. **Postmortem** — what to capture once resolved.

| Runbook | Use when |
| --- | --- |
| [deploy.md](deploy.md) | Shipping or rolling back a backend release |
| [database-restore.md](database-restore.md) | DB corruption, accidental delete, point-in-time recovery |
| [openai-outage.md](openai-outage.md) | OpenAI 5xx rate elevated or full outage |
| [deepgram-outage.md](deepgram-outage.md) | Live transcription failing across users |
| [storekit-notification-failure.md](storekit-notification-failure.md) | Apple webhook not arriving, entitlement drift |
| [incident-response.md](incident-response.md) | Severity scoring, comms templates, on-call rotation |

## Severity quick reference

- **SEV-1** — App unusable for >5% of paying users. Page on-call immediately.
- **SEV-2** — Major feature broken (live session, billing) but workaround exists.
- **SEV-3** — Minor degradation, single-user reports.

See `incident-response.md` for full criteria and comms templates.

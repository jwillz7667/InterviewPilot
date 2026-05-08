# Runbook: Incident response

How to triage, communicate, and resolve production incidents.

## Severity levels

| Level | Criteria | Page on-call? | Comms |
| --- | --- | --- | --- |
| **SEV-1** | Service down OR >5% of paying users blocked OR data loss / leak | Yes, immediately | Status page + email blast within 30 min |
| **SEV-2** | Major feature broken (live session, billing, auth) but workaround exists OR <5% paying users affected | Yes, business hours | Status page within 60 min |
| **SEV-3** | Single-user reports, minor degradation, no revenue impact | No, file ticket | None unless user-initiated |

When in doubt, **upgrade the severity**. Easier to downgrade later than to under-respond.

## On-call rotation

Currently a one-person rotation (founder). Once the team scales:

- Weekly rotation, Mon 09:00 → Mon 09:00 PT.
- Primary + backup. Backup pages if primary doesn't ack within 5 min.
- Configure via PagerDuty (TODO when team grows past 1 engineer).

## Incident playbook (SEV-1 / SEV-2)

### 0–5 min: triage

1. Acknowledge the page. Set Slack status to "🔥 incident".
2. Identify symptoms — Sentry, Railway logs, status pages.
3. Decide severity. Spin up an incident channel if SEV-1: `#inc-YYYYMMDD-<slug>`.

### 5–30 min: stabilize

1. Look up the relevant runbook ([deploy](deploy.md), [database-restore](database-restore.md), [openai](openai-outage.md), [deepgram](deepgram-outage.md), [storekit](storekit-notification-failure.md)).
2. Apply the cheapest stabilizing action first (e.g. redeploy known-good build, set degrade flag) before investigating root cause.
3. Update the incident channel every 15 minutes minimum.

### 30 min+: resolve

1. Once the bleeding stops, investigate root cause.
2. Ship the fix on `main` with a fast-tracked review.
3. Verify with smoke test on TestFlight build.

### Post-resolution

1. Mark incident closed in Slack.
2. File a postmortem within 48 hours: `docs/postmortems/YYYY-MM-DD-<slug>.md`.
3. Track action items in GitHub Issues with `incident` label.

## Communication templates

### Status page (SEV-1)

> **Investigating** — We are aware of an issue affecting [feature]. Some users may experience [symptom]. We are actively investigating.
>
> _Posted: [timestamp]_

### Update

> **Identified** — We've identified the issue ([brief description]) and are deploying a fix. ETA to resolution: [estimate].

### Resolution

> **Resolved** — The issue affecting [feature] has been resolved as of [timestamp]. Affected users may need to [restart app / sign out and back in / wait N minutes]. We apologize for the disruption and will share a postmortem within 48 hours.

### Email blast (SEV-1, paying users)

> Subject: Service interruption on [date] — what happened
>
> Hi [name],
>
> Between [start] and [end] on [date], InterviewPilot experienced [issue]. As a paying customer, you may have experienced [specific impact].
>
> What we did: [actions taken].
> What we're doing next: [followups, including any refund / credit if revenue was lost].
>
> Full postmortem will be published at https://interviewace.app/incidents/[slug].
>
> Apologies again,
> The InterviewPilot team

## Postmortem template

```markdown
# Postmortem: <Title>
**Date:** YYYY-MM-DD
**Severity:** SEV-N
**Author:** <name>
**Status:** Draft / Final

## Summary
One paragraph: what broke, who was affected, how long, how we fixed it.

## Timeline (all times PT)
- HH:MM — First signal (Sentry alert, user report, etc.)
- HH:MM — On-call ack'd
- HH:MM — Mitigation deployed
- HH:MM — Resolved

## Impact
- Users affected: <count>
- Revenue at risk: $<amount>
- Data loss: <yes/no, scope>

## Root cause
What actually broke, in technical detail.

## Detection
How we noticed. Was monitoring adequate?

## Resolution
Step-by-step what we did. Reference the runbook used.

## What went well
- ...

## What didn't go well
- ...

## Action items
- [ ] OWNER — Description (#issue)
```

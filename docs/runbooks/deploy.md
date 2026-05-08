# Runbook: Deploying the backend

## Symptoms / triggers

- A merged PR on `main` you want to ship.
- A bad release that needs rolling back.

## Normal deploy flow

Railway is wired to auto-deploy from `main` via the Dockerfile. Checks run on the merge commit.

1. **Pre-flight** — verify CI is green on the merge commit:
   ```sh
   gh run list --branch main --limit 5
   ```
2. **Watch the deploy** — Railway dashboard → InterviewPilot service → Deployments. The build takes ~3 minutes; container start ~30 seconds.
3. **Verify health** — `curl https://api.interviewace.app/health` returns `{"status":"ok","database":"connected","redis":"connected"}`. Anything else means roll back.
4. **Smoke test** — drive a fresh sign-in + interview start on TestFlight. iOS pulls a fresh entitlement; if `getBillingSummary` is broken nobody starts a session.

## Rollback

Railway does not support `git revert`-style auto rollback. Two options:

**Option A — revert the commit (preferred when bad commit is identifiable):**
```sh
git checkout main
git pull
git revert <bad-sha>
git push origin main
```
Railway auto-deploys the revert. Time-to-recovery: ~4 minutes.

**Option B — redeploy a known-good build (faster):**
1. Railway → Deployments → find the last green deploy.
2. "Redeploy" from that deployment.
3. Time-to-recovery: ~30 seconds (no rebuild).

Use Option B for SEV-1 incidents, then revert in git afterward so the bad commit doesn't ship again on the next deploy.

## Postmortem checklist

- Capture Railway deployment ID + commit SHA of the bad build.
- Capture Sentry error spike + Grafana request error rate during incident window.
- File a `postmortem-YYYY-MM-DD-<slug>.md` under `docs/postmortems/` (create dir on first incident).
- Add a regression test if the failure mode is reproducible.

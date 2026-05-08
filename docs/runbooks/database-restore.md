# Runbook: Database restore

## Symptoms

- Data corruption reports across users.
- Bad migration ran against prod (truncated column, dropped table, etc.).
- Accidental destructive operation (`UPDATE` without `WHERE`, `DELETE FROM users`).

## Triage

Before restoring, decide whether you actually need a restore. Restores are irreversible — anything written between the backup point and now is gone.

1. **Scope the damage** — how many rows / which tables / which users. If it's <10 rows of one user, hand-fix is cheaper than a restore.
2. **Halt writes if needed** — set Railway env `DB_READONLY=1` and redeploy (the app respects this flag for write-path routes; reads still work).
3. **Identify a clean backup point** — Railway Postgres takes daily snapshots. For finer granularity, Postgres point-in-time recovery (PITR) needs a `pg_basebackup` + WAL archive — Railway exposes these via the support team only.

## Resolution

### Daily snapshot restore (Railway)

1. Railway dashboard → Postgres service → Backups.
2. Pick the latest snapshot before the incident.
3. Click "Restore" → Railway creates a **new** database. Do NOT overwrite the live one — instead, dump from the new DB and re-import selectively.
4. Get the new DB connection string. Run:
   ```sh
   pg_dump "<new-db-url>" -t affected_table_name --data-only > /tmp/restore.sql
   ```
5. Inspect `/tmp/restore.sql`, compare with prod, and apply targeted `INSERT`/`UPDATE` statements.

### Full restore (last resort)

Only if the entire DB is unrecoverable:

1. Take a defensive dump of the current (broken) DB first:
   ```sh
   pg_dump "<live-db-url>" > /tmp/broken-$(date +%s).sql
   ```
2. Update Railway env `DATABASE_URL` to point at the restored snapshot DB.
3. Redeploy backend (Railway → Redeploy current image).
4. Verify `/health` reports `database: connected` and run a sanity query for a known user.

## Drill cadence

`backend/scripts/backup-restore-drill.sh` runs monthly via `.github/workflows/db-drill.yml`. It restores the latest snapshot into a disposable DB, runs `audit-entitlements.ts`, and Slacks on failure. If a drill fails, treat as SEV-2 and investigate before the next prod incident forces a real restore.

## Postmortem checklist

- Timeline: incident detected → halt → restore start → restore done → writes resumed.
- Root cause: was this a bad migration, app bug, or operator error?
- Backup window lost: how many minutes/hours of data could not be recovered?
- Followups: did the bad migration have a code review? Was there a `--force-reset` flag that shouldn't exist?

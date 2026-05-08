#!/usr/bin/env bash
# backup-restore-drill.sh
#
# Monthly DR drill: dump the live DB, restore it into a disposable
# postgres docker container, run the entitlement audit against the
# restored copy. Exits 0 on green, non-zero on failure.
#
# Required env:
#   DATABASE_URL  — production (or staging) DB to drill against
#
# Optional env:
#   DRILL_PORT    — local port to expose the disposable container (default 55432)
#
# Local usage:
#   DATABASE_URL=postgres://... ./backend/scripts/backup-restore-drill.sh
#
# CI usage: invoked by .github/workflows/db-drill.yml on a monthly cron.

set -euo pipefail

if [ -z "${DATABASE_URL:-}" ]; then
  echo "✗ DATABASE_URL is required" >&2
  exit 1
fi

DRILL_PORT="${DRILL_PORT:-55432}"
CONTAINER_NAME="ip-drill-$$"
DUMP_FILE="$(mktemp -t ip-dump.XXXXXX.sql)"
RESTORED_URL="postgres://postgres:postgres@127.0.0.1:${DRILL_PORT}/drill"

cleanup() {
  echo "» cleaning up"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  rm -f "$DUMP_FILE"
}
trap cleanup EXIT

echo "» 1/4 dumping live DB"
pg_dump --no-owner --no-acl "$DATABASE_URL" > "$DUMP_FILE"
echo "  dump size: $(wc -c < "$DUMP_FILE") bytes"

echo "» 2/4 starting disposable postgres on :${DRILL_PORT}"
docker run -d --name "$CONTAINER_NAME" \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=drill \
  -p "${DRILL_PORT}:5432" \
  postgres:16 >/dev/null

# Wait for postgres readiness
for i in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "» 3/4 restoring dump"
psql "$RESTORED_URL" < "$DUMP_FILE" >/dev/null

echo "» 4/4 running entitlement audit against restored copy"
DATABASE_URL="$RESTORED_URL" npx tsx backend/scripts/audit-entitlements.ts

echo "✓ drill passed"

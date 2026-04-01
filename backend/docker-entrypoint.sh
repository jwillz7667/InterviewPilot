#!/bin/sh

echo "=== InterviewPilot Backend Starting ==="
echo "NODE_ENV: $NODE_ENV"
echo "PORT: $PORT"
echo "DATABASE_URL set: $([ -n "$DATABASE_URL" ] && echo 'yes' || echo 'NO')"

echo "Running database migrations..."
npx prisma migrate deploy || echo "WARNING: Migration failed (may already be applied)"

echo "Starting server..."
exec node dist/index.js

#!/bin/sh

echo "=== InterviewPilot Backend Starting ==="
echo "NODE_ENV: $NODE_ENV"
echo "PORT: $PORT"
echo "DATABASE_URL set: $([ -n "$DATABASE_URL" ] && echo 'yes' || echo 'NO')"

if [ -n "$DATABASE_URL" ]; then
  echo "Pushing database schema..."
  npx prisma db push --skip-generate 2>&1 || echo "WARNING: Schema push failed, continuing anyway..."
else
  echo "WARNING: DATABASE_URL not set, skipping schema push"
fi

echo "Starting server..."
exec node dist/index.js

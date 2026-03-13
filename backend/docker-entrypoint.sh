#!/bin/sh

echo "=== Job Hopper Backend Starting ==="
echo "NODE_ENV: $NODE_ENV"
echo "PORT: $PORT"
echo "DATABASE_URL set: $([ -n "$DATABASE_URL" ] && echo 'yes' || echo 'NO')"

if [ -n "$DATABASE_URL" ]; then
  echo "Pushing database schema..."
  attempts=0
  until npx prisma db push --skip-generate --accept-data-loss 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 5 ]; then
      echo "ERROR: Schema push failed after $attempts attempts"
      exit 1
    fi

    echo "Schema push failed, retrying in 3 seconds..."
    sleep 3
  done
else
  echo "WARNING: DATABASE_URL not set, skipping schema push"
fi

echo "Starting server..."
exec node dist/index.js

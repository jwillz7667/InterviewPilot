#!/bin/sh

echo "=== Job Hopper Backend Starting ==="
echo "NODE_ENV: $NODE_ENV"
echo "PORT: $PORT"
echo "DATABASE_URL set: $([ -n "$DATABASE_URL" ] && echo 'yes' || echo 'NO')"

echo "Starting server..."
exec node dist/index.js

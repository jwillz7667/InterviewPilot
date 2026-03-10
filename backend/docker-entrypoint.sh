#!/bin/sh
set -e

echo "Pushing database schema..."
npx prisma db push --skip-generate

echo "Starting server..."
exec node dist/index.js

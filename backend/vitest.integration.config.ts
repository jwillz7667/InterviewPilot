import { defineConfig } from 'vitest/config';

// Integration test config — separate from the unit suite so unit tests stay
// fast and don't require docker. Integration tests expect DATABASE_URL +
// REDIS_URL to be set (CI provides both via the postgres/redis service
// containers). Locally, run via:
//   docker compose up -d postgres redis
//   DATABASE_URL=... REDIS_URL=... npm run test:integration
export default defineConfig({
  test: {
    globals: false,
    include: ['test/integration/**/*.test.ts'],
    environment: 'node',
    setupFiles: ['test/integration/setup.ts'],
    // Migrations + container boot can be slow on cold start.
    testTimeout: 30_000,
    hookTimeout: 60_000,
    // Run integration files serially so they don't fight over the shared DB.
    fileParallelism: false,
  },
  resolve: {
    alias: {},
  },
});

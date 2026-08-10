import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: false,
    // Unit tests only. Integration tests live under test/integration/** and
    // run via `npm run test:integration` (separate config + testcontainers).
    include: ['test/**/*.test.ts', 'src/**/*.test.ts'],
    exclude: ['node_modules/**', 'dist/**', 'test/integration/**'],
    environment: 'node',
    setupFiles: ['test/setup-env.ts'],
    testTimeout: 10_000,
  },
  resolve: {
    // The repo uses NodeNext-style `.js` import suffixes for TS files. Vitest
    // honours these when running through esbuild without extra config.
    alias: {},
  },
});

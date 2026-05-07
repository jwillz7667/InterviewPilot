import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: false,
    include: ['test/**/*.test.ts', 'src/**/*.test.ts'],
    environment: 'node',
    testTimeout: 10_000,
  },
  resolve: {
    // The repo uses NodeNext-style `.js` import suffixes for TS files. Vitest
    // honours these when running through esbuild without extra config.
    alias: {},
  },
});

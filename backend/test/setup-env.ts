import 'reflect-metadata';

// Unit and integration suites import production modules whose shared env schema
// validates these values at module load. Keep deterministic, test-only defaults
// here so every Vitest entry point has the same safe harness. CI-provided
// service URLs win because nullish assignment never overwrites real values.
process.env.DATABASE_URL ??= 'postgresql://postgres:postgres@127.0.0.1:5432/interviewpilot_test';
process.env.JWT_SECRET ??= 'test-only-jwt-secret-never-use-in-production';
process.env.API_KEY_ENCRYPTION_SECRET ??=
  '0000000000000000000000000000000000000000000000000000000000000001';
process.env.NODE_ENV ??= 'test';

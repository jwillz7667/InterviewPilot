-- Drop redundant index on refresh_tokens.tokenHash. The unique constraint
-- (refresh_tokens_tokenHash_key) already provides an index that satisfies
-- equality lookups, so refresh_tokens_tokenHash_idx is purely overhead on
-- writes.
DROP INDEX IF EXISTS "refresh_tokens_tokenHash_idx";

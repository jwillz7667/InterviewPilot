import { Prisma } from '@prisma/client';

/**
 * Soft-delete extension. For models with a `deletedAt` column:
 *   findMany / findFirst   → auto-filter `deletedAt: null`
 *   delete / deleteMany    → REJECTED with a descriptive error. Query-extension
 *                            handlers cannot re-route an operation to `update`
 *                            (there is no usable client/transaction handle in
 *                            the handler, and reaching for the base client
 *                            would escape the caller's transaction). Call sites
 *                            must write `update({ data: { deletedAt: new Date() } })`
 *                            explicitly — see users/sessions/answer-banks routes.
 *   findUnique             → passes through (Prisma cannot mix unique-by + arbitrary where);
 *                            callers that need to exclude soft-deletes must filter explicitly.
 *
 * Hard deletes remain possible via `$executeRaw` in code that genuinely needs
 * to wipe rows (e.g. integration-test cleanup).
 */

type SoftDeletableModel = 'user' | 'interviewSession' | 'answerBank' | 'interviewProfile';

function makeHandlers(model: SoftDeletableModel) {
  const rejectHardDelete = (operation: string): never => {
    throw new Error(
      `${model}.${operation} is disabled: "${model}" soft-deletes. ` +
        `Use update/updateMany({ data: { deletedAt: new Date() } }) so the write stays ` +
        `inside the caller's transaction, or $executeRaw for a genuine hard delete.`
    );
  };

  return {
    async findMany({
      args,
      query,
    }: {
      args: { where?: Record<string, unknown> };
      query: (a: unknown) => unknown;
    }) {
      args.where = { ...args.where, deletedAt: null };
      return query(args);
    },
    async findFirst({
      args,
      query,
    }: {
      args: { where?: Record<string, unknown> };
      query: (a: unknown) => unknown;
    }) {
      args.where = { ...args.where, deletedAt: null };
      return query(args);
    },
    async delete() {
      return rejectHardDelete('delete');
    },
    async deleteMany() {
      return rejectHardDelete('deleteMany');
    },
  };
}

export const softDeleteExtension = Prisma.defineExtension({
  name: 'soft-delete',
  query: {
    user: makeHandlers('user'),
    interviewSession: makeHandlers('interviewSession'),
    answerBank: makeHandlers('answerBank'),
    interviewProfile: makeHandlers('interviewProfile'),
  },
});

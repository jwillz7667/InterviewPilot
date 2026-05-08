import { Prisma } from '@prisma/client';

/**
 * Soft-delete extension. For models with a `deletedAt` column:
 *   findMany / findFirst   → auto-filter `deletedAt: null`
 *   delete / deleteMany    → translated to update setting `deletedAt = now`
 *   findUnique             → passes through (Prisma cannot mix unique-by + arbitrary where);
 *                            callers that need to exclude soft-deletes must filter explicitly.
 *
 * Hard deletes still possible via `$queryRaw` or by calling the underlying client through
 * `Prisma.getExtensionContext(this).$parent` in a service that genuinely needs to wipe rows.
 */

type SoftDeletableModel = 'user' | 'interviewSession' | 'answerBank' | 'interviewProfile';

type ParentClient = Record<
  SoftDeletableModel,
  {
    update: (args: { where: unknown; data: unknown }) => unknown;
    updateMany: (args: { where?: unknown; data: unknown }) => unknown;
  }
>;

function parent(thisArg: unknown): ParentClient {
  return (Prisma.getExtensionContext(thisArg) as unknown as { $parent: ParentClient }).$parent;
}

function makeHandlers(model: SoftDeletableModel) {
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
    async delete(this: unknown, { args }: { args: { where: unknown } }) {
      return parent(this)[model].update({ where: args.where, data: { deletedAt: new Date() } });
    },
    async deleteMany(this: unknown, { args }: { args: { where?: unknown } }) {
      return parent(this)[model].updateMany({ where: args.where, data: { deletedAt: new Date() } });
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

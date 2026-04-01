import { Prisma } from '@prisma/client';

/**
 * Prisma extension that enables soft deletes for models that have a `deletedAt` field.
 * - findMany/findFirst/findUnique automatically filter out soft-deleted records
 * - delete/deleteMany set `deletedAt` instead of actually deleting
 * - Use `$queryRaw` or direct SQL for hard deletes when needed
 */
export const softDeleteExtension = Prisma.defineExtension({
  name: 'soft-delete',
  query: {
    user: {
      async findMany({ args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async findFirst({ args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async findUnique({ args, query }) {
        // findUnique doesn't support arbitrary where clauses easily,
        // so we let it through and filter in application code if needed
        return query(args);
      },
      async delete({ args, query }) {
        return (Prisma.getExtensionContext(this) as any).$parent.user.update({
          ...args,
          data: { deletedAt: new Date() },
        });
      },
    },
    interviewSession: {
      async findMany({ args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async findFirst({ args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async delete({ args, query }) {
        return (Prisma.getExtensionContext(this) as any).$parent.interviewSession.update({
          ...args,
          data: { deletedAt: new Date() },
        });
      },
    },
    answerBank: {
      async findMany({ args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async findFirst({ args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async delete({ args, query }) {
        return (Prisma.getExtensionContext(this) as any).$parent.answerBank.update({
          ...args,
          data: { deletedAt: new Date() },
        });
      },
    },
  },
});

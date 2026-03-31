import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { withDatabaseRetry } from '../../config/database.js';
import { z } from 'zod';

const updateProfileSchema = z.object({
  linkedinUrl: z.string().url().nullable().optional(),
  primaryGoal: z.string().max(500).nullable().optional(),
  resumeFileUrl: z.string().url().nullable().optional(),
  currentRole: z.string().max(200).nullable().optional(),
  currentCompany: z.string().max(200).nullable().optional(),
  yearsInRole: z.number().int().min(0).max(50).nullable().optional(),
  onboardingCompleted: z.boolean().optional(),
});

const workExperienceItemSchema = z.object({
  title: z.string().min(1).max(200),
  company: z.string().min(1).max(200),
  startYear: z.number().int().min(1950).max(2100),
  endYear: z.number().int().min(1950).max(2100).nullable().optional(),
});

const bulkWorkExperienceSchema = z.object({
  items: z.array(workExperienceItemSchema).max(50),
});

const bulkSkillsSchema = z.object({
  items: z.array(z.string().min(1).max(100)).max(100),
});

export async function profileRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // GET /api/v1/users/me/profile — Full profile with work experience + skills
  app.get('/api/v1/users/me/profile', async (request: FastifyRequest, reply: FastifyReply) => {
    const profile = await withDatabaseRetry((prisma) =>
      prisma.user.findUniqueOrThrow({
        where: { id: request.user.sub },
        select: {
          id: true,
          email: true,
          displayName: true,
          avatarUrl: true,
          linkedinUrl: true,
          primaryGoal: true,
          resumeFileUrl: true,
          currentRole: true,
          currentCompany: true,
          yearsInRole: true,
          onboardingCompleted: true,
          createdAt: true,
          workExperiences: {
            orderBy: { startYear: 'desc' },
            select: {
              id: true,
              title: true,
              company: true,
              startYear: true,
              endYear: true,
            },
          },
          skills: {
            orderBy: { name: 'asc' },
            select: {
              id: true,
              name: true,
            },
          },
        },
      })
    );

    reply.send({ profile });
  });

  // PATCH /api/v1/users/me/profile — Update profile fields
  app.patch('/api/v1/users/me/profile', async (request: FastifyRequest, reply: FastifyReply) => {
    const input = updateProfileSchema.parse(request.body);

    const profile = await withDatabaseRetry((prisma) =>
      prisma.user.update({
        where: { id: request.user.sub },
        data: input,
        select: {
          id: true,
          email: true,
          displayName: true,
          avatarUrl: true,
          linkedinUrl: true,
          primaryGoal: true,
          resumeFileUrl: true,
          currentRole: true,
          currentCompany: true,
          yearsInRole: true,
          onboardingCompleted: true,
        },
      })
    );

    reply.send({ profile });
  });

  // PUT /api/v1/users/me/work-experience — Bulk update work experience
  app.put(
    '/api/v1/users/me/work-experience',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const { items } = bulkWorkExperienceSchema.parse(request.body);

      const workExperiences = await withDatabaseRetry((prisma) =>
        prisma.$transaction(async (tx) => {
          // Delete all existing work experiences for the user
          await tx.workExperience.deleteMany({
            where: { userId: request.user.sub },
          });

          // Create new ones
          if (items.length > 0) {
            await tx.workExperience.createMany({
              data: items.map((item) => ({
                ...item,
                endYear: item.endYear ?? null,
                userId: request.user.sub,
              })),
            });
          }

          // Return the newly created records
          return tx.workExperience.findMany({
            where: { userId: request.user.sub },
            orderBy: { startYear: 'desc' },
            select: {
              id: true,
              title: true,
              company: true,
              startYear: true,
              endYear: true,
            },
          });
        })
      );

      reply.send({ workExperiences });
    }
  );

  // PUT /api/v1/users/me/skills — Bulk update skills
  app.put('/api/v1/users/me/skills', async (request: FastifyRequest, reply: FastifyReply) => {
    const { items } = bulkSkillsSchema.parse(request.body);

    const skills = await withDatabaseRetry((prisma) =>
      prisma.$transaction(async (tx) => {
        // Delete all existing skills for the user
        await tx.userSkill.deleteMany({
          where: { userId: request.user.sub },
        });

        // Create new ones
        if (items.length > 0) {
          await tx.userSkill.createMany({
            data: items.map((name) => ({
              name,
              userId: request.user.sub,
            })),
          });
        }

        // Return the newly created records
        return tx.userSkill.findMany({
          where: { userId: request.user.sub },
          orderBy: { name: 'asc' },
          select: {
            id: true,
            name: true,
          },
        });
      })
    );

    reply.send({ skills });
  });
}

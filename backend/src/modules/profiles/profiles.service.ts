import { getPrisma, withDatabaseRetry } from '../../config/database.js';
import { getBillingSummary } from '../billing/billing.service.js';
import { invalidateBillingCache } from '../billing/billing.cache.js';
import {
  ForbiddenError,
  NotFoundError,
  PaymentRequiredError,
  ValidationError,
} from '../../utils/errors.js';

type CreateProfileInput = {
  name: string;
  resumeText?: string | null;
  currentRole?: string | null;
  currentCompany?: string | null;
  yearsInRole?: number | null;
  linkedinUrl?: string | null;
  summary?: string | null;
  communicationStyle?: string | null;
};

type UpdateProfileInput = Partial<CreateProfileInput>;

type WorkExperienceItem = {
  title: string;
  company: string;
  startYear: number;
  endYear?: number | null;
  description?: string | null;
};

type SkillItem = {
  name: string;
  category?: string | null;
};

type EducationItem = {
  institution: string;
  degree: string;
  field?: string | null;
  startYear?: number | null;
  endYear?: number | null;
};

type CertificationItem = {
  name: string;
  issuer?: string | null;
  year?: number | null;
};

type ProjectItem = {
  name: string;
  description?: string | null;
  techStack?: string | null;
  url?: string | null;
  year?: number | null;
};

type AchievementItem = {
  description: string;
  metric?: string | null;
  year?: number | null;
};

async function verifyProfileOwnership(userId: string, profileId: string) {
  const profile = await withDatabaseRetry((prisma) =>
    prisma.interviewProfile.findFirst({
      where: { id: profileId, userId, deletedAt: null },
      select: { id: true, isDefault: true },
    })
  );

  if (!profile) {
    throw new NotFoundError('Profile');
  }

  return profile;
}

export async function listProfiles(userId: string) {
  return withDatabaseRetry((prisma) =>
    prisma.interviewProfile.findMany({
      where: { userId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
      include: {
        _count: {
          select: {
            workExperiences: true,
            skills: true,
            education: true,
            certifications: true,
            projects: true,
            achievements: true,
          },
        },
      },
    })
  );
}

export async function getProfile(userId: string, profileId: string) {
  const profile = await withDatabaseRetry((prisma) =>
    prisma.interviewProfile.findFirst({
      where: { id: profileId, userId, deletedAt: null },
      include: {
        workExperiences: { orderBy: { startYear: 'desc' } },
        skills: { orderBy: { name: 'asc' } },
        education: { orderBy: { endYear: 'desc' } },
        certifications: { orderBy: { year: 'desc' } },
        projects: { orderBy: { year: 'desc' } },
        achievements: { orderBy: { year: 'desc' } },
      },
    })
  );

  if (!profile) {
    throw new NotFoundError('Profile');
  }

  return profile;
}

export async function createProfile(userId: string, data: CreateProfileInput) {
  const billing = await getBillingSummary(userId);

  if (!billing.featureFlags.resume_personalization) {
    throw new PaymentRequiredError(
      'Resume personalization requires an active subscription.',
      { requiredFeature: 'resume_personalization' }
    );
  }

  if (billing.profilesUsed >= billing.profileLimit) {
    throw new PaymentRequiredError(
      `You have reached the maximum of ${billing.profileLimit} interview profile(s) for your plan. Upgrade for more.`,
      { requiredTier: 'pro' }
    );
  }

  const isFirst = billing.profilesUsed === 0;

  const profile = await withDatabaseRetry((prisma) =>
    prisma.interviewProfile.create({
      data: {
        userId,
        name: data.name,
        isDefault: isFirst,
        resumeText: data.resumeText ?? null,
        currentRole: data.currentRole ?? null,
        currentCompany: data.currentCompany ?? null,
        yearsInRole: data.yearsInRole ?? null,
        linkedinUrl: data.linkedinUrl ?? null,
        summary: data.summary ?? null,
        communicationStyle: data.communicationStyle ?? null,
      },
      include: {
        workExperiences: true,
        skills: true,
        education: true,
        certifications: true,
        projects: true,
        achievements: true,
      },
    })
  );

  await invalidateBillingCache(userId).catch(() => {});

  return profile;
}

export async function updateProfile(userId: string, profileId: string, data: UpdateProfileInput) {
  await verifyProfileOwnership(userId, profileId);

  return withDatabaseRetry((prisma) =>
    prisma.interviewProfile.update({
      where: { id: profileId },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.resumeText !== undefined && { resumeText: data.resumeText }),
        ...(data.currentRole !== undefined && { currentRole: data.currentRole }),
        ...(data.currentCompany !== undefined && { currentCompany: data.currentCompany }),
        ...(data.yearsInRole !== undefined && { yearsInRole: data.yearsInRole }),
        ...(data.linkedinUrl !== undefined && { linkedinUrl: data.linkedinUrl }),
        ...(data.summary !== undefined && { summary: data.summary }),
        ...(data.communicationStyle !== undefined && { communicationStyle: data.communicationStyle }),
      },
      include: {
        workExperiences: { orderBy: { startYear: 'desc' } },
        skills: { orderBy: { name: 'asc' } },
        education: { orderBy: { endYear: 'desc' } },
        certifications: { orderBy: { year: 'desc' } },
        projects: { orderBy: { year: 'desc' } },
        achievements: { orderBy: { year: 'desc' } },
      },
    })
  );
}

export async function deleteProfile(userId: string, profileId: string) {
  const profile = await verifyProfileOwnership(userId, profileId);

  if (profile.isDefault) {
    const otherCount = await withDatabaseRetry((prisma) =>
      prisma.interviewProfile.count({
        where: { userId, deletedAt: null, id: { not: profileId } },
      })
    );

    if (otherCount === 0) {
      throw new ValidationError('Cannot delete the only default profile. Create another profile first.');
    }
  }

  await withDatabaseRetry((prisma) =>
    prisma.interviewProfile.update({
      where: { id: profileId },
      data: { deletedAt: new Date() },
    })
  );

  // If we deleted the default profile, promote another one
  if (profile.isDefault) {
    await withDatabaseRetry((prisma) =>
      prisma.$transaction(async (tx) => {
        const nextDefault = await tx.interviewProfile.findFirst({
          where: { userId, deletedAt: null },
          orderBy: { createdAt: 'asc' },
          select: { id: true },
        });

        if (nextDefault) {
          await tx.interviewProfile.update({
            where: { id: nextDefault.id },
            data: { isDefault: true },
          });
        }
      })
    );
  }

  await invalidateBillingCache(userId).catch(() => {});
}

export async function setDefaultProfile(userId: string, profileId: string) {
  await verifyProfileOwnership(userId, profileId);

  return withDatabaseRetry((prisma) =>
    prisma.$transaction(async (tx) => {
      await tx.interviewProfile.updateMany({
        where: { userId, isDefault: true },
        data: { isDefault: false },
      });

      return tx.interviewProfile.update({
        where: { id: profileId },
        data: { isDefault: true },
        include: {
          workExperiences: { orderBy: { startYear: 'desc' } },
          skills: { orderBy: { name: 'asc' } },
          education: { orderBy: { endYear: 'desc' } },
          certifications: { orderBy: { year: 'desc' } },
          projects: { orderBy: { year: 'desc' } },
          achievements: { orderBy: { year: 'desc' } },
        },
      });
    })
  );
}

export async function bulkReplaceWorkExperiences(userId: string, profileId: string, items: WorkExperienceItem[]) {
  await verifyProfileOwnership(userId, profileId);

  return withDatabaseRetry((prisma) =>
    prisma.$transaction(async (tx) => {
      await tx.profileWorkExperience.deleteMany({ where: { profileId } });

      if (items.length > 0) {
        await tx.profileWorkExperience.createMany({
          data: items.map((item) => ({
            profileId,
            title: item.title,
            company: item.company,
            startYear: item.startYear,
            endYear: item.endYear ?? null,
            description: item.description ?? null,
          })),
        });
      }

      return tx.profileWorkExperience.findMany({
        where: { profileId },
        orderBy: { startYear: 'desc' },
      });
    })
  );
}

export async function bulkReplaceSkills(userId: string, profileId: string, items: SkillItem[]) {
  await verifyProfileOwnership(userId, profileId);

  return withDatabaseRetry((prisma) =>
    prisma.$transaction(async (tx) => {
      await tx.profileSkill.deleteMany({ where: { profileId } });

      if (items.length > 0) {
        await tx.profileSkill.createMany({
          data: items.map((item) => ({
            profileId,
            name: item.name,
            category: item.category ?? null,
          })),
        });
      }

      return tx.profileSkill.findMany({
        where: { profileId },
        orderBy: { name: 'asc' },
      });
    })
  );
}

export async function bulkReplaceEducation(userId: string, profileId: string, items: EducationItem[]) {
  await verifyProfileOwnership(userId, profileId);

  return withDatabaseRetry((prisma) =>
    prisma.$transaction(async (tx) => {
      await tx.profileEducation.deleteMany({ where: { profileId } });

      if (items.length > 0) {
        await tx.profileEducation.createMany({
          data: items.map((item) => ({
            profileId,
            institution: item.institution,
            degree: item.degree,
            field: item.field ?? null,
            startYear: item.startYear ?? null,
            endYear: item.endYear ?? null,
          })),
        });
      }

      return tx.profileEducation.findMany({
        where: { profileId },
        orderBy: { endYear: 'desc' },
      });
    })
  );
}

export async function bulkReplaceCertifications(userId: string, profileId: string, items: CertificationItem[]) {
  await verifyProfileOwnership(userId, profileId);

  return withDatabaseRetry((prisma) =>
    prisma.$transaction(async (tx) => {
      await tx.profileCertification.deleteMany({ where: { profileId } });

      if (items.length > 0) {
        await tx.profileCertification.createMany({
          data: items.map((item) => ({
            profileId,
            name: item.name,
            issuer: item.issuer ?? null,
            year: item.year ?? null,
          })),
        });
      }

      return tx.profileCertification.findMany({
        where: { profileId },
        orderBy: { year: 'desc' },
      });
    })
  );
}

export async function bulkReplaceProjects(userId: string, profileId: string, items: ProjectItem[]) {
  await verifyProfileOwnership(userId, profileId);

  return withDatabaseRetry((prisma) =>
    prisma.$transaction(async (tx) => {
      await tx.profileProject.deleteMany({ where: { profileId } });

      if (items.length > 0) {
        await tx.profileProject.createMany({
          data: items.map((item) => ({
            profileId,
            name: item.name,
            description: item.description ?? null,
            techStack: item.techStack ?? null,
            url: item.url ?? null,
            year: item.year ?? null,
          })),
        });
      }

      return tx.profileProject.findMany({
        where: { profileId },
        orderBy: { year: 'desc' },
      });
    })
  );
}

export async function bulkReplaceAchievements(userId: string, profileId: string, items: AchievementItem[]) {
  await verifyProfileOwnership(userId, profileId);

  return withDatabaseRetry((prisma) =>
    prisma.$transaction(async (tx) => {
      await tx.profileAchievement.deleteMany({ where: { profileId } });

      if (items.length > 0) {
        await tx.profileAchievement.createMany({
          data: items.map((item) => ({
            profileId,
            description: item.description,
            metric: item.metric ?? null,
            year: item.year ?? null,
          })),
        });
      }

      return tx.profileAchievement.findMany({
        where: { profileId },
        orderBy: { year: 'desc' },
      });
    })
  );
}

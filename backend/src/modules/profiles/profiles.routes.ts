import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../../middleware/authenticate.js';
import { z } from 'zod';
import {
  listProfiles,
  getProfile,
  createProfile,
  updateProfile,
  deleteProfile,
  setDefaultProfile,
  bulkReplaceWorkExperiences,
  bulkReplaceSkills,
  bulkReplaceEducation,
  bulkReplaceCertifications,
  bulkReplaceProjects,
  bulkReplaceAchievements,
} from './profiles.service.js';

const createProfileSchema = z.object({
  name: z.string().min(1).max(200),
  resumeText: z.string().max(50000).nullable().optional(),
  currentRole: z.string().max(200).nullable().optional(),
  currentCompany: z.string().max(200).nullable().optional(),
  yearsInRole: z.number().int().min(0).max(50).nullable().optional(),
  linkedinUrl: z.string().max(500).nullable().optional(),
  summary: z.string().max(5000).nullable().optional(),
  communicationStyle: z.string().max(200).nullable().optional(),
});

const updateProfileSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  resumeText: z.string().max(50000).nullable().optional(),
  currentRole: z.string().max(200).nullable().optional(),
  currentCompany: z.string().max(200).nullable().optional(),
  yearsInRole: z.number().int().min(0).max(50).nullable().optional(),
  linkedinUrl: z.string().max(500).nullable().optional(),
  summary: z.string().max(5000).nullable().optional(),
  communicationStyle: z.string().max(200).nullable().optional(),
});

const workExperienceItemSchema = z.object({
  title: z.string().min(1).max(200),
  company: z.string().min(1).max(200),
  startYear: z.number().int().min(1950).max(2100),
  endYear: z.number().int().min(1950).max(2100).nullable().optional(),
  description: z.string().max(5000).nullable().optional(),
});

const skillItemSchema = z.object({
  name: z.string().min(1).max(200),
  category: z.string().max(200).nullable().optional(),
});

const educationItemSchema = z.object({
  institution: z.string().min(1).max(200),
  degree: z.string().min(1).max(200),
  field: z.string().max(200).nullable().optional(),
  startYear: z.number().int().min(1950).max(2100).nullable().optional(),
  endYear: z.number().int().min(1950).max(2100).nullable().optional(),
});

const certificationItemSchema = z.object({
  name: z.string().min(1).max(200),
  issuer: z.string().max(200).nullable().optional(),
  year: z.number().int().min(1950).max(2100).nullable().optional(),
});

const projectItemSchema = z.object({
  name: z.string().min(1).max(200),
  description: z.string().max(5000).nullable().optional(),
  techStack: z.string().max(500).nullable().optional(),
  url: z.string().max(500).nullable().optional(),
  year: z.number().int().min(1950).max(2100).nullable().optional(),
});

const achievementItemSchema = z.object({
  description: z.string().min(1).max(5000),
  metric: z.string().max(500).nullable().optional(),
  year: z.number().int().min(1950).max(2100).nullable().optional(),
});

const bulkWorkExperiencesSchema = z.object({
  items: z.array(workExperienceItemSchema).max(50),
});

const bulkSkillsSchema = z.object({
  items: z.array(skillItemSchema).max(50),
});

const bulkEducationSchema = z.object({
  items: z.array(educationItemSchema).max(50),
});

const bulkCertificationsSchema = z.object({
  items: z.array(certificationItemSchema).max(50),
});

const bulkProjectsSchema = z.object({
  items: z.array(projectItemSchema).max(50),
});

const bulkAchievementsSchema = z.object({
  items: z.array(achievementItemSchema).max(50),
});

export async function interviewProfilesRoutes(app: FastifyInstance) {
  app.addHook('onRequest', authenticate);

  // List profiles
  app.get('/api/v1/profiles', async (request: FastifyRequest, reply: FastifyReply) => {
    const profiles = await listProfiles(request.user.sub);
    reply.send({ profiles });
  });

  // Create profile
  app.post('/api/v1/profiles', async (request: FastifyRequest, reply: FastifyReply) => {
    const input = createProfileSchema.parse(request.body);
    const profile = await createProfile(request.user.sub, input);
    reply.status(201).send({ profile });
  });

  // Get single profile
  app.get(
    '/api/v1/profiles/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const profile = await getProfile(request.user.sub, request.params.id);
      reply.send({ profile });
    }
  );

  // Update profile
  app.patch(
    '/api/v1/profiles/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const input = updateProfileSchema.parse(request.body);
      const profile = await updateProfile(request.user.sub, request.params.id, input);
      reply.send({ profile });
    }
  );

  // Soft delete profile
  app.delete(
    '/api/v1/profiles/:id',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      await deleteProfile(request.user.sub, request.params.id);
      reply.send({ success: true });
    }
  );

  // Set default profile
  app.post(
    '/api/v1/profiles/:id/set-default',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const profile = await setDefaultProfile(request.user.sub, request.params.id);
      reply.send({ profile });
    }
  );

  // Bulk replace work experiences
  app.put(
    '/api/v1/profiles/:id/work-experiences',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const { items } = bulkWorkExperiencesSchema.parse(request.body);
      const workExperiences = await bulkReplaceWorkExperiences(request.user.sub, request.params.id, items);
      reply.send({ workExperiences });
    }
  );

  // Bulk replace skills
  app.put(
    '/api/v1/profiles/:id/skills',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const { items } = bulkSkillsSchema.parse(request.body);
      const skills = await bulkReplaceSkills(request.user.sub, request.params.id, items);
      reply.send({ skills });
    }
  );

  // Bulk replace education
  app.put(
    '/api/v1/profiles/:id/education',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const { items } = bulkEducationSchema.parse(request.body);
      const education = await bulkReplaceEducation(request.user.sub, request.params.id, items);
      reply.send({ education });
    }
  );

  // Bulk replace certifications
  app.put(
    '/api/v1/profiles/:id/certifications',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const { items } = bulkCertificationsSchema.parse(request.body);
      const certifications = await bulkReplaceCertifications(request.user.sub, request.params.id, items);
      reply.send({ certifications });
    }
  );

  // Bulk replace projects
  app.put(
    '/api/v1/profiles/:id/projects',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const { items } = bulkProjectsSchema.parse(request.body);
      const projects = await bulkReplaceProjects(request.user.sub, request.params.id, items);
      reply.send({ projects });
    }
  );

  // Bulk replace achievements
  app.put(
    '/api/v1/profiles/:id/achievements',
    async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
      const { items } = bulkAchievementsSchema.parse(request.body);
      const achievements = await bulkReplaceAchievements(request.user.sub, request.params.id, items);
      reply.send({ achievements });
    }
  );
}

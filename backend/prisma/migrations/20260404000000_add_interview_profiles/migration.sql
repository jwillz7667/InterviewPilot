-- CreateTable
CREATE TABLE "interview_profiles" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "resumeText" TEXT,
    "currentRole" TEXT,
    "currentCompany" TEXT,
    "yearsInRole" INTEGER,
    "linkedinUrl" TEXT,
    "summary" TEXT,
    "communicationStyle" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "interview_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profile_work_experiences" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "company" TEXT NOT NULL,
    "startYear" INTEGER NOT NULL,
    "endYear" INTEGER,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profile_work_experiences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profile_skills" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profile_skills_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profile_education" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "institution" TEXT NOT NULL,
    "degree" TEXT NOT NULL,
    "field" TEXT,
    "startYear" INTEGER,
    "endYear" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profile_education_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profile_certifications" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "issuer" TEXT,
    "year" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profile_certifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profile_projects" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "techStack" TEXT,
    "url" TEXT,
    "year" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profile_projects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profile_achievements" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "metric" TEXT,
    "year" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profile_achievements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "interview_profiles_userId_idx" ON "interview_profiles"("userId");

-- CreateIndex
CREATE INDEX "profile_work_experiences_profileId_idx" ON "profile_work_experiences"("profileId");

-- CreateIndex
CREATE UNIQUE INDEX "profile_skills_profileId_name_key" ON "profile_skills"("profileId", "name");

-- CreateIndex
CREATE INDEX "profile_skills_profileId_idx" ON "profile_skills"("profileId");

-- CreateIndex
CREATE INDEX "profile_education_profileId_idx" ON "profile_education"("profileId");

-- CreateIndex
CREATE INDEX "profile_certifications_profileId_idx" ON "profile_certifications"("profileId");

-- CreateIndex
CREATE INDEX "profile_projects_profileId_idx" ON "profile_projects"("profileId");

-- CreateIndex
CREATE INDEX "profile_achievements_profileId_idx" ON "profile_achievements"("profileId");

-- AddForeignKey
ALTER TABLE "interview_profiles" ADD CONSTRAINT "interview_profiles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profile_work_experiences" ADD CONSTRAINT "profile_work_experiences_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "interview_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profile_skills" ADD CONSTRAINT "profile_skills_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "interview_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profile_education" ADD CONSTRAINT "profile_education_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "interview_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profile_certifications" ADD CONSTRAINT "profile_certifications_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "interview_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profile_projects" ADD CONSTRAINT "profile_projects_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "interview_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profile_achievements" ADD CONSTRAINT "profile_achievements_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "interview_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Migrate existing user profile data into default InterviewProfile
INSERT INTO "interview_profiles" ("id", "userId", "name", "isDefault", "resumeText", "currentRole", "currentCompany", "yearsInRole", "linkedinUrl", "createdAt", "updatedAt")
SELECT
    gen_random_uuid()::text,
    u."id",
    'Default',
    true,
    u."resumeText",
    u."currentRole",
    u."currentCompany",
    u."yearsInRole",
    u."linkedinUrl",
    NOW(),
    NOW()
FROM "users" u
WHERE u."resumeText" IS NOT NULL
   OR u."currentRole" IS NOT NULL
   OR u."currentCompany" IS NOT NULL;

-- Copy existing work experiences to profile work experiences
INSERT INTO "profile_work_experiences" ("id", "profileId", "title", "company", "startYear", "endYear", "createdAt")
SELECT
    gen_random_uuid()::text,
    ip."id",
    we."title",
    we."company",
    we."startYear",
    we."endYear",
    we."createdAt"
FROM "work_experiences" we
JOIN "interview_profiles" ip ON ip."userId" = we."userId" AND ip."isDefault" = true;

-- Copy existing user skills to profile skills
INSERT INTO "profile_skills" ("id", "profileId", "name", "createdAt")
SELECT
    gen_random_uuid()::text,
    ip."id",
    us."name",
    us."createdAt"
FROM "user_skills" us
JOIN "interview_profiles" ip ON ip."userId" = us."userId" AND ip."isDefault" = true;

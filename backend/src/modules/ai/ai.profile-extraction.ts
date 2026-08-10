import { z } from 'zod';

// Resume → structured profile extraction. The prompt and the output contract
// live server-side so the model choice, token budget, and schema are
// authoritative — the iOS client only ships raw resume text. The sanitizer
// validates every array element independently and drops malformed rows, so one
// bad entry can never void an entire collection on the client (the iOS decoder
// requires, e.g., workExperiences[].startYear to be a present integer).

export const EXTRACTION_SYSTEM_PROMPT = `Extract a complete professional profile from the following resume. Return ONLY valid JSON with this exact schema:
{
  "displayName": "candidate's full name from the resume header (e.g., \\"Jane Doe\\") or null",
  "linkedinUrl": "candidate's LinkedIn URL exactly as it appears in the resume (e.g., \\"linkedin.com/in/janedoe\\") or null",
  "currentRole": "most recent job title or null",
  "currentCompany": "most recent company or null",
  "yearsInRole": approximate years in most recent role as integer or null,
  "summary": "2-3 sentence professional summary capturing the candidate's key strengths and focus areas",
  "skills": [
    {"name": "Swift", "category": "language"},
    {"name": "SwiftUI", "category": "framework"},
    {"name": "Docker", "category": "tool"},
    {"name": "Team Leadership", "category": "soft"}
  ],
  "workExperiences": [
    {
      "title": "Job Title",
      "company": "Company Name",
      "startYear": 2020,
      "endYear": 2024,
      "description": "Led team of 8 engineers to migrate 200k LOC UIKit app to SwiftUI, reducing UI crashes by 73%. Built real-time data pipeline processing 50k events/sec."
    }
  ],
  "education": [
    {
      "institution": "Stanford University",
      "degree": "B.S.",
      "field": "Computer Science",
      "startYear": 2012,
      "endYear": 2016
    }
  ],
  "certifications": [
    {"name": "AWS Solutions Architect", "issuer": "Amazon", "year": 2023}
  ],
  "projects": [
    {
      "name": "Project Name",
      "description": "What it does and the impact it had",
      "techStack": "Swift, Python, PostgreSQL",
      "year": 2024
    }
  ],
  "achievements": [
    {
      "description": "Reduced app cold start time from 3.2s to 0.8s through lazy loading and prewarming",
      "metric": "75% faster launch",
      "year": 2023
    }
  ]
}

CRITICAL RULES:
- displayName must be ONLY the candidate's full personal name as it appears at the top of the resume — never a job title, company, or URL.
- linkedinUrl must be COPIED VERBATIM from the resume text. Never invent a URL. If no LinkedIn URL is present, return null.
- Extract ALL work experiences with DETAILED descriptions of key accomplishments, quantified impact, and technologies used for each role
- For work experience descriptions: combine ALL bullet points from that role into a dense paragraph with specific numbers, metrics, and outcomes
- Every work experience MUST include a numeric startYear (4-digit). Omit any role for which no start year can be determined.
- Categorize EVERY skill: "language" for programming languages, "framework" for frameworks/libraries, "tool" for devops/tools/platforms, "soft" for leadership/communication
- Extract ALL education entries including degrees in progress
- Extract certifications, professional courses, and relevant training
- Extract standalone projects (side projects, open source, hackathons) separately from work experience
- For achievements: extract specific quantified accomplishments that stand out (promotions, awards, performance records, metrics improvements)
- The summary should read like an elevator pitch, not a resume objective
- endYear is null if the position/degree is current
- If a field cannot be determined, use null
- Return ONLY the JSON object, no markdown, no explanation`;

export function buildExtractionMessages(
  resumeText: string
): { role: 'system' | 'user'; content: string }[] {
  return [
    { role: 'system', content: EXTRACTION_SYSTEM_PROMPT },
    { role: 'user', content: resumeText },
  ];
}

// Strips a Markdown code fence if the model wrapped its JSON in one despite the
// instruction not to. Returns the inner payload, or the trimmed input unchanged.
export function stripJsonFences(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed.startsWith('```')) return trimmed;
  const withoutOpen = trimmed.replace(/^```(?:json)?\s*/i, '');
  const closeIndex = withoutOpen.lastIndexOf('```');
  return (closeIndex >= 0 ? withoutOpen.slice(0, closeIndex) : withoutOpen).trim();
}

const YEAR = z.number().int().min(1900).max(2100);

const skillSchema = z.object({
  name: z.string().trim().min(1).max(200),
  category: z.string().trim().max(60).nullish(),
});

const workExperienceSchema = z.object({
  title: z.string().trim().min(1).max(200),
  company: z.string().trim().min(1).max(200),
  startYear: YEAR,
  endYear: YEAR.nullish(),
  description: z.string().trim().max(5000).nullish(),
});

const educationSchema = z.object({
  institution: z.string().trim().min(1).max(200),
  degree: z.string().trim().min(1).max(200),
  field: z.string().trim().max(200).nullish(),
  startYear: YEAR.nullish(),
  endYear: YEAR.nullish(),
});

const certificationSchema = z.object({
  name: z.string().trim().min(1).max(200),
  issuer: z.string().trim().max(200).nullish(),
  year: YEAR.nullish(),
});

const projectSchema = z.object({
  name: z.string().trim().min(1).max(200),
  description: z.string().trim().max(5000).nullish(),
  techStack: z.string().trim().max(500).nullish(),
  year: YEAR.nullish(),
});

const achievementSchema = z.object({
  description: z.string().trim().min(1).max(5000),
  metric: z.string().trim().max(500).nullish(),
  year: YEAR.nullish(),
});

export interface ExtractedProfileDTO {
  displayName: string | null;
  linkedinUrl: string | null;
  currentRole: string | null;
  currentCompany: string | null;
  yearsInRole: number | null;
  summary: string | null;
  skills: z.infer<typeof skillSchema>[];
  workExperiences: z.infer<typeof workExperienceSchema>[];
  education: z.infer<typeof educationSchema>[];
  certifications: z.infer<typeof certificationSchema>[];
  projects: z.infer<typeof projectSchema>[];
  achievements: z.infer<typeof achievementSchema>[];
}

function asObject(raw: unknown): Record<string, unknown> {
  return raw && typeof raw === 'object' && !Array.isArray(raw)
    ? (raw as Record<string, unknown>)
    : {};
}

function cleanString(raw: unknown, maxLength: number): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  return trimmed.length > maxLength ? trimmed.slice(0, maxLength) : trimmed;
}

function cleanYearsInRole(raw: unknown): number | null {
  const value = typeof raw === 'string' ? Number.parseInt(raw, 10) : raw;
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  const rounded = Math.trunc(value);
  // 50 matches every profile write schema (create/update/full) and the iOS
  // editor's Stepper ceiling, so an extracted value can never exceed what the
  // save path will accept.
  return rounded > 0 && rounded <= 50 ? rounded : null;
}

// Validates each element independently; invalid rows are dropped rather than
// failing the whole array. Keeps the client contract intact even when the model
// emits a partially malformed row.
function sanitizeArray<T>(raw: unknown, schema: z.ZodType<T>): T[] {
  if (!Array.isArray(raw)) return [];
  const result: T[] = [];
  for (const element of raw) {
    const parsed = schema.safeParse(element);
    if (parsed.success) result.push(parsed.data);
  }
  return result;
}

export function sanitizeExtractedProfile(raw: unknown): ExtractedProfileDTO {
  const obj = asObject(raw);
  return {
    displayName: cleanString(obj.displayName, 120),
    linkedinUrl: cleanString(obj.linkedinUrl, 500),
    currentRole: cleanString(obj.currentRole, 200),
    currentCompany: cleanString(obj.currentCompany, 200),
    yearsInRole: cleanYearsInRole(obj.yearsInRole),
    summary: cleanString(obj.summary, 5000),
    skills: sanitizeArray(obj.skills, skillSchema),
    workExperiences: sanitizeArray(obj.workExperiences, workExperienceSchema),
    education: sanitizeArray(obj.education, educationSchema),
    certifications: sanitizeArray(obj.certifications, certificationSchema),
    projects: sanitizeArray(obj.projects, projectSchema),
    achievements: sanitizeArray(obj.achievements, achievementSchema),
  };
}

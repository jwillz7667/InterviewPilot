import { describe, expect, it } from 'vitest';

import {
  sanitizeExtractedProfile,
  stripJsonFences,
} from '../src/modules/ai/ai.profile-extraction.js';

describe('stripJsonFences', () => {
  it('passes plain JSON through unchanged (apart from trimming)', () => {
    const raw = '  {"displayName":"Jane Doe"}  ';
    expect(stripJsonFences(raw)).toBe('{"displayName":"Jane Doe"}');
  });

  it('unwraps a ```json fenced block', () => {
    const raw = '```json\n{"displayName":"Jane Doe"}\n```';
    expect(stripJsonFences(raw)).toBe('{"displayName":"Jane Doe"}');
  });

  it('unwraps a bare ``` fenced block (no language tag)', () => {
    const raw = '```\n{"a":1}\n```';
    expect(stripJsonFences(raw)).toBe('{"a":1}');
  });

  it('tolerates a missing closing fence', () => {
    const raw = '```json\n{"a":1}';
    expect(stripJsonFences(raw)).toBe('{"a":1}');
  });

  it('keeps inner braces while stripping only the outer fence', () => {
    const raw = '```json\n{"nested":{"x":1}}\n```';
    expect(stripJsonFences(raw)).toBe('{"nested":{"x":1}}');
  });
});

describe('sanitizeExtractedProfile — scalars', () => {
  it('null-fills every scalar when given a non-object', () => {
    const dto = sanitizeExtractedProfile('not an object');
    expect(dto.displayName).toBeNull();
    expect(dto.linkedinUrl).toBeNull();
    expect(dto.currentRole).toBeNull();
    expect(dto.currentCompany).toBeNull();
    expect(dto.yearsInRole).toBeNull();
    expect(dto.summary).toBeNull();
  });

  it('returns empty arrays for every collection when given a non-object', () => {
    const dto = sanitizeExtractedProfile(null);
    expect(dto.skills).toEqual([]);
    expect(dto.workExperiences).toEqual([]);
    expect(dto.education).toEqual([]);
    expect(dto.certifications).toEqual([]);
    expect(dto.projects).toEqual([]);
    expect(dto.achievements).toEqual([]);
  });

  it('trims string scalars and nulls out empty/whitespace strings', () => {
    const dto = sanitizeExtractedProfile({
      displayName: '  Jane Doe  ',
      currentRole: '   ',
      currentCompany: '',
    });
    expect(dto.displayName).toBe('Jane Doe');
    expect(dto.currentRole).toBeNull();
    expect(dto.currentCompany).toBeNull();
  });

  it('coerces and bounds yearsInRole to 1–50 (the shared write-schema ceiling)', () => {
    expect(sanitizeExtractedProfile({ yearsInRole: '7' }).yearsInRole).toBe(7);
    expect(sanitizeExtractedProfile({ yearsInRole: 5.9 }).yearsInRole).toBe(5);
    expect(sanitizeExtractedProfile({ yearsInRole: 50 }).yearsInRole).toBe(50);
    expect(sanitizeExtractedProfile({ yearsInRole: 0 }).yearsInRole).toBeNull();
    expect(sanitizeExtractedProfile({ yearsInRole: 51 }).yearsInRole).toBeNull();
    expect(sanitizeExtractedProfile({ yearsInRole: 'lots' }).yearsInRole).toBeNull();
  });
});

describe('sanitizeExtractedProfile — work experiences (startYear gate)', () => {
  it('drops a row missing startYear while keeping the valid row', () => {
    const dto = sanitizeExtractedProfile({
      workExperiences: [
        { title: 'Senior Engineer', company: 'Acme', startYear: 2020, endYear: 2024 },
        { title: 'No Start Year', company: 'Bad Co' },
      ],
    });
    expect(dto.workExperiences).toHaveLength(1);
    expect(dto.workExperiences[0]).toMatchObject({
      title: 'Senior Engineer',
      company: 'Acme',
      startYear: 2020,
    });
  });

  it('drops a row whose startYear is out of the 1900–2100 range', () => {
    const dto = sanitizeExtractedProfile({
      workExperiences: [{ title: 'X', company: 'Y', startYear: 1850 }],
    });
    expect(dto.workExperiences).toEqual([]);
  });

  it('drops a row missing a required string field (company)', () => {
    const dto = sanitizeExtractedProfile({
      workExperiences: [{ title: 'X', startYear: 2021 }],
    });
    expect(dto.workExperiences).toEqual([]);
  });
});

describe('sanitizeExtractedProfile — other collections', () => {
  it('keeps valid skills and drops nameless ones', () => {
    const dto = sanitizeExtractedProfile({
      skills: [
        { name: 'Swift', category: 'language' },
        { name: '', category: 'language' },
        { category: 'language' },
        { name: 'Docker' },
      ],
    });
    expect(dto.skills.map((s) => s.name)).toEqual(['Swift', 'Docker']);
  });

  it('drops a non-array collection entirely', () => {
    const dto = sanitizeExtractedProfile({ skills: 'React, Swift' });
    expect(dto.skills).toEqual([]);
  });

  it('keeps a valid education row and preserves nullable years', () => {
    const dto = sanitizeExtractedProfile({
      education: [{ institution: 'Stanford', degree: 'B.S.', field: 'CS', startYear: 2012 }],
    });
    expect(dto.education).toHaveLength(1);
    expect(dto.education[0]).toMatchObject({ institution: 'Stanford', degree: 'B.S.' });
  });

  it('keeps a valid achievement and drops one with an empty description', () => {
    const dto = sanitizeExtractedProfile({
      achievements: [
        { description: 'Cut cold start 75%', metric: '75% faster', year: 2023 },
        { description: '   ', metric: 'x' },
      ],
    });
    expect(dto.achievements).toHaveLength(1);
    expect(dto.achievements[0].description).toBe('Cut cold start 75%');
  });

  it('ignores a project url field that the client DTO does not carry', () => {
    const dto = sanitizeExtractedProfile({
      projects: [
        {
          name: 'Pilot',
          description: 'Does things',
          techStack: 'Swift',
          url: 'https://x',
          year: 2024,
        },
      ],
    });
    expect(dto.projects).toHaveLength(1);
    expect(dto.projects[0]).not.toHaveProperty('url');
    expect(dto.projects[0]).toMatchObject({ name: 'Pilot', techStack: 'Swift' });
  });
});

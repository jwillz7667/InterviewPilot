import { describe, expect, it } from 'vitest';

import { dedupeSkills } from '../src/modules/profiles/profiles.service.js';

// profileSkill has a unique (profileId, name) constraint, and a single P2002
// inside createMany rolls back the whole batch — so dedupeSkills must collapse
// case-variant and whitespace-variant duplicates before the write.
describe('dedupeSkills', () => {
  it('collapses case-insensitive duplicates, first spelling wins', () => {
    const result = dedupeSkills([
      { name: 'React' },
      { name: 'react' },
      { name: 'REACT' },
    ]);
    expect(result).toEqual([{ name: 'React', category: null }]);
  });

  it('trims surrounding whitespace and treats trimmed values as equal', () => {
    const result = dedupeSkills([{ name: '  Swift  ' }, { name: 'Swift' }]);
    expect(result).toEqual([{ name: 'Swift', category: null }]);
  });

  it('drops entries that are empty or whitespace-only after trimming', () => {
    const result = dedupeSkills([{ name: '' }, { name: '   ' }, { name: 'Go' }]);
    expect(result).toEqual([{ name: 'Go', category: null }]);
  });

  it('preserves the category of the first occurrence and normalizes missing to null', () => {
    const result = dedupeSkills([
      { name: 'Docker', category: 'tool' },
      { name: 'docker', category: 'platform' },
      { name: 'Kubernetes' },
    ]);
    expect(result).toEqual([
      { name: 'Docker', category: 'tool' },
      { name: 'Kubernetes', category: null },
    ]);
  });

  it('keeps distinct skills and preserves their order', () => {
    const result = dedupeSkills([
      { name: 'Swift' },
      { name: 'SwiftUI' },
      { name: 'Combine' },
    ]);
    expect(result.map((s) => s.name)).toEqual(['Swift', 'SwiftUI', 'Combine']);
  });

  it('returns an empty array for an empty input', () => {
    expect(dedupeSkills([])).toEqual([]);
  });
});

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { hash, languages } from './translate.mjs';
import { check, limits, playCodes, problem, stale } from './translate_listing.mjs';

test('every app language has a Play listing code', () => {
  assert.deepEqual(Object.keys(playCodes).sort(), [...languages].sort());
  assert.equal(playCodes.de, 'de-DE');
  assert.equal(playCodes.ro, 'ro');
});

test('a listing text must fit Play and keep the app name and digits', () => {
  assert.deepEqual(limits, { title: 30, shortDescription: 80, fullDescription: 4000 });
  assert.equal(problem('title', 'Simple Math Tester', 'Simple Math Tester'), null);
  assert.equal(problem('title', 'Simple Math Tester', 'Einfacher Mathe-Tester'), '"Simple Math Tester" missing');
  assert.equal(problem('title', 'x', 'y'.repeat(31)), '31 characters, Play allows 30');
  // Characters, not bytes: 80 Devanagari letters fit.
  assert.equal(problem('shortDescription', 'x', 'क'.repeat(80)), null);
  assert.equal(problem('shortDescription', '60 seconds', '६० सेकंद'), 'non-Western digits');
  assert.equal(problem('fullDescription', 'x', ' '), 'empty');
  assert.equal(problem('fullDescription', 'x', undefined), 'empty');
});

test('missing fields and fields whose English changed are stale', () => {
  const english = { title: 'A', shortDescription: 'B', fullDescription: 'C' };
  const listing = { title: 'a', shortDescription: 'b' };
  const sources = { title: hash('A'), shortDescription: hash('old B') };
  assert.deepEqual(stale(english, listing, sources), ['shortDescription', 'fullDescription']);
});

test('the English listing fits Play', () => {
  const english = JSON.parse(readFileSync(new URL('../play/listing/en-US.json', import.meta.url)));
  assert.deepEqual(check('en-US.json', english, english), []);
});

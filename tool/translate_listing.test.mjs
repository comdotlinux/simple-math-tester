import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { hash, languageName, languages, westernDigits } from './translate.mjs';
import {
  check,
  limits,
  playCodes,
  problem,
  retryNote,
  stale,
} from './translate_listing.mjs';

test('digits of any script become Western digits', () => {
  assert.equal(westernDigits('६०-सेकंद'), '60-सेकंद'); // Devanagari
  assert.equal(westernDigits('௧௨ ٣٤ ൯'), '12 34 9'); // Tamil, Arabic-Indic, Malayalam
  assert.equal(westernDigits('𝟎𝟗 𝟘𝟡'), '09 09'); // two runs of mathematical digits in a row
  assert.equal(westernDigits('60 seconds'), '60 seconds');
  assert.equal(westernDigits('੬੦'), '60'); // Gurmukhi
  assert.equal(westernDigits(undefined), undefined);
});

test('a retry is told why the last answer was rejected', () => {
  assert.equal(
    retryNote('shortDescription', '100 characters, Play allows 80'),
    'Your shortDescription had 100 characters; Play allows at most 80. Write a shorter one.',
  );
  assert.equal(
    retryNote('title', '"Simple Math Tester" missing'),
    'Your title lost "Simple Math Tester": keep it exactly, in Latin letters.',
  );
  assert.equal(
    retryNote('fullDescription', 'non-Western digits'),
    'Your fullDescription had non-Western digits: use only Western digits 0-9.',
  );
  assert.equal(retryNote('title', 'empty'), 'Your title was empty: write the whole translation.');
});

test('every app language has a Play listing code', () => {
  assert.deepEqual(Object.keys(playCodes).sort(), [...languages].sort());
  assert.equal(playCodes.de, 'de-DE');
  assert.equal(playCodes.ro, 'ro');
  assert.equal(playCodes.uk, 'uk');
  assert.equal(playCodes.pt, 'pt-BR');
  assert.equal(playCodes.pt_PT, 'pt-PT');
  assert.equal(playCodes.pa, 'pa');
});

test('DeepSeek is told the Portuguese variant and the Punjabi script', () => {
  assert.equal(languageName('de'), 'German');
  assert.equal(languageName('pt'), 'Brazilian Portuguese (Brazil)');
  assert.equal(languageName('pt_PT'), 'European Portuguese (Portugal)');
  assert.equal(languageName('pa'), 'Punjabi in Gurmukhi script');
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

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { hash, placeholders, problem, stale } from './translate.mjs';

test('placeholders are argument names, not words in plural branches', () => {
  assert.deepEqual(
    placeholders('{count, plural, =1{Noch {count} Sekunde} other{Noch {count} Sekunden}}'),
    ['count'],
  );
  assert.deepEqual(placeholders('So {left} {op} {right} = {result}.'), [
    'left',
    'op',
    'result',
    'right',
  ]);
});

test('a translation must keep placeholders, braces, plurals and digits', () => {
  const source = '{count, plural, =1{1 second} other{{count} seconds}}';
  assert.equal(problem(source, '{count, plural, =1{1 Sekunde} other{{count} Sekunden}}'), null);
  assert.equal(problem(source, '{count, plural, =1{1 Sekunde}}'), 'plural without other');
  assert.equal(problem('Score: {score}', 'Punkte: {punkte}'), 'placeholders punkte instead of score');
  assert.equal(problem('Score: {score}', 'Punkte: {score'), 'unbalanced braces');
  assert.equal(problem('Level 1', 'स्तर १'), 'non-Western digits');
  assert.equal(problem('Level 1', 'स्तर 1'), null);
  assert.equal(problem('Hint', ''), 'empty');
});

test('missing keys and keys whose English changed are stale', () => {
  const template = { '@@locale': 'en', a: 'One', '@a': {}, b: 'Two', c: 'Three' };
  const arb = { a: 'Eins', b: 'Zwei' };
  const sources = { a: hash('One'), b: hash('Old two') };
  assert.deepEqual(stale(template, arb, sources), ['b', 'c']);
});

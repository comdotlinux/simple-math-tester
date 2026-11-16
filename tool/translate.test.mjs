import assert from 'node:assert/strict';
import { test } from 'node:test';

import { batches, hash, parseAnswer, placeholders, problem, stale } from './translate.mjs';

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

test('stale keys are sent in batches bounded by key count and characters', () => {
  const template = { a: 'x'.repeat(10), b: 'x'.repeat(10), c: 'x'.repeat(10), d: 'x'.repeat(25), e: 'x' };
  assert.deepEqual(batches(template, ['a', 'b', 'c', 'd', 'e'], 2, 30), [['a', 'b'], ['c'], ['d', 'e']]);
  // A single string longer than the budget still gets its own batch.
  assert.deepEqual(batches(template, ['d', 'a'], 40, 5), [['d'], ['a']]);
  assert.deepEqual(batches(template, []), []);
});

test('a cut-off, unparseable or empty answer is a failed attempt', () => {
  const reply = (content, finish_reason = 'stop') => ({ choices: [{ finish_reason, message: { content } }] });
  assert.deepEqual(parseAnswer(reply('{"a":"Eins","b":"Zwei"}'), ['a', 'b']), { a: 'Eins', b: 'Zwei' });
  assert.equal(parseAnswer(reply('{"a":"Ei', 'length'), ['a']).message, 'cut off (finish_reason length)');
  assert.equal(parseAnswer(reply('{"a":"Ei'), ['a']).message, 'unparseable JSON (finish_reason stop)');
  assert.equal(parseAnswer(reply('   '), ['a']).message, 'unparseable JSON (finish_reason stop)');
  assert.equal(parseAnswer({}, ['a']).message, 'unparseable JSON (finish_reason undefined)');
  assert.equal(
    parseAnswer(reply('{"x":"y","z":1}'), ['a']).message,
    'none of the requested keys in the answer (got: x, z)',
  );
  // A wrapped answer is unwrapped.
  assert.deepEqual(parseAnswer(reply('{"translate":{"a":"Eins"}}'), ['a']), { a: 'Eins' });
});

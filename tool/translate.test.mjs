import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  batches,
  hash,
  ordered,
  parseAnswer,
  placeholders,
  problem,
  stale,
  translateBatch,
} from './translate.mjs';

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

test('a written ARB has every key, with English for keys never translated, which stay stale', () => {
  const template = { '@@locale': 'en', a: 'One', '@a': {}, b: 'Two' };
  const arb = { a: 'Eins', gone: 'Weg' };
  const written = ordered(template, arb, 'de');
  assert.deepEqual(written, { '@@locale': 'de', a: 'Eins', b: 'Two' });
  assert.deepEqual(stale(template, written, { a: hash('One') }), ['b']);
});

test('stale keys are sent in batches bounded by key count and characters', () => {
  const template = { a: 'x'.repeat(10), b: 'x'.repeat(10), c: 'x'.repeat(10), d: 'x'.repeat(25), e: 'x' };
  assert.deepEqual(batches(template, ['a', 'b', 'c', 'd', 'e'], 2, 30), [['a', 'b'], ['c'], ['d', 'e']]);
  // A single string longer than the budget still gets its own batch.
  assert.deepEqual(batches(template, ['d', 'a'], 40, 5), [['d'], ['a']]);
  assert.deepEqual(batches(template, []), []);
});

test('a cut-off answer is split in half down to single keys; failures get one retry', async () => {
  const template = { a: 'A', b: 'B', c: 'C', d: 'D', e: 'E', f: 'F' };
  const requests = [];
  // A fake DeepSeek: more than two keys are cut off, "d" always comes back
  // empty, and the first request for "f" alone fails with HTTP 500.
  const request = async (keys) => {
    requests.push(keys.join(''));
    if (keys.join('') === 'f' && !requests.slice(0, -1).includes('f')) {
      throw new Error('DeepSeek answered 500: busy');
    }
    const cut = keys.length > 2;
    const content = cut ? '{"a":"x' : JSON.stringify(Object.fromEntries(keys.map((k) => [k, k === 'd' ? '' : `${k}!`])));
    const answer = parseAnswer({ choices: [{ finish_reason: cut ? 'length' : 'stop', message: { content } }] }, keys);
    if (answer instanceof Error) throw answer;
    return answer;
  };
  const log = [];
  const result = await translateBatch('uk: batch 1/1', template, Object.keys(template), request, (l) => log.push(l));
  assert.deepEqual(result, { accepted: { a: 'a!', b: 'b!', c: 'c!', e: 'e!', f: 'f!' }, failed: ['d'] });
  assert.deepEqual(requests, ['abcdef', 'abc', 'ab', 'c', 'def', 'de', 'd', 'f', 'f']);
  assert.equal(log[0], 'uk: batch 1/1 failed (attempt 1, 6 keys): cut off (finish_reason length)');
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

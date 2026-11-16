import assert from 'node:assert/strict';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import {
  batches,
  hash,
  ordered,
  parseAnswer,
  placeholders,
  problem,
  reportFailures,
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

// A fake DeepSeek reply for [keys], through parseAnswer like the real one.
const reply = (keys, content, finish_reason = 'stop') => {
  const answer = parseAnswer({ choices: [{ finish_reason, message: { content } }] }, keys);
  if (answer instanceof Error) throw answer;
  return answer;
};
const keyNames = (n) => Array.from({ length: n }, (_, i) => `k${i}`);

test('first batches hold up to 60 keys; fallback batches 20', () => {
  const template = Object.fromEntries(keyNames(130).map((k) => [k, 'x']));
  assert.deepEqual(batches(template, keyNames(130)).map((b) => b.length), [60, 60, 10]);
  assert.deepEqual(batches(template, keyNames(45), 20, 1500).map((b) => b.length), [20, 20, 5]);
});

test('a cut-off batch of 60 is retried as batches of 20 with up to 3 attempts each', async () => {
  const keys = keyNames(60);
  const template = Object.fromEntries(keys.map((k) => [k, k.toUpperCase()]));
  const requests = [];
  let failsOfSecond = 0;
  const request = async (ks) => {
    requests.push(ks.length);
    if (ks.length > 20) return reply(ks, '{"k0":"x', 'length');
    // The second batch of 20 fails twice (HTTP 500, then unparseable), then works.
    if (ks[0] === 'k20' && failsOfSecond++ < 2) {
      if (failsOfSecond === 1) throw new Error('DeepSeek answered 500: busy');
      return reply(ks, '   ');
    }
    return reply(ks, JSON.stringify(Object.fromEntries(ks.map((k) => [k, `${k}!`]))));
  };
  const log = [];
  const result = await translateBatch('uk: batch 1/1', template, keys, request, (l) => log.push(l));
  assert.deepEqual(result.failed, []);
  assert.equal(Object.keys(result.accepted).length, 60);
  assert.deepEqual(requests, [60, 20, 20, 20, 20, 20]);
  assert.deepEqual(log, [
    'uk: batch 1/1 failed (attempt 1/1, 60 keys): cut off (finish_reason length)',
    'uk: batch 1/1 fallback 2/3 failed (attempt 1/3, 20 keys): DeepSeek answered 500: busy',
    'uk: batch 1/1 fallback 2/3 failed (attempt 2/3, 20 keys): unparseable JSON (finish_reason stop)',
  ]);
});

test('only rejected or missing keys fall back; after 3 attempts they are failed', async () => {
  const template = { a: 'A', b: 'B {n}', c: 'C', d: 'D' };
  const requests = [];
  // "b" always loses its placeholder, "c" is missing from the first answer, and
  // "d" is never answered.
  const request = async (ks) => {
    requests.push(ks.join(''));
    const answer = Object.fromEntries(ks.filter((k) => k !== 'd').map((k) => [k, `${k}!`]));
    if (requests.length === 1) delete answer.c;
    return reply(ks, JSON.stringify(answer));
  };
  const log = [];
  const result = await translateBatch('de: batch 1/1', template, Object.keys(template), request, (l) => log.push(l));
  assert.deepEqual(result, { accepted: { a: 'a!', c: 'c!' }, failed: ['b', 'd'] });
  assert.deepEqual(requests, ['abcd', 'bcd', 'bd', 'bd']);
  assert.ok(log.includes('de: batch 1/1: c rejected (attempt 1/1): missing'));
  assert.ok(log.includes('de: batch 1/1 fallback 1/1: b rejected (attempt 3/3): placeholders none instead of n'));
});

test('failed keys are listed per language and give exit code 2', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'translate-test-'));
  const file = join(dir, 'failed-keys.txt');
  const log = [];
  assert.equal(await reportFailures({}, 5, file, (l) => log.push(l)), 0);
  assert.deepEqual(log, []);
  assert.equal(await reportFailures({ de: ['a', 'b'], uk: ['c'] }, 5, file, (l) => log.push(l)), 2);
  assert.equal(await readFile(file, 'utf8'), '- de: a, b\n- uk: c\n');
  assert.equal(log[0], 'Not translated after every retry, retried on the next run:\n- de: a, b\n- uk: c');
  // Nothing translated at all: a plain error (exit 1).
  await assert.rejects(reportFailures({ de: ['a'] }, 0, undefined, () => {}), /No string could be translated/);
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

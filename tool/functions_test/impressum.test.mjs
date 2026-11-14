// Tests for functions/api/impressum.js with Node's built-in runner:
//   node --test tool/functions_test/
// Kept outside functions/, where every file would become a route.
import assert from 'node:assert/strict';
import { afterEach, describe, test } from 'node:test';

import { onRequest, onRequestPost } from '../../functions/api/impressum.js';

const TEXT = 'Made-up Name\nExample Street 1\n12345 Sample Town';
const SECRET = 'test-secret';
const realFetch = globalThis.fetch;

function post(body = JSON.stringify({ token: 'a-token' })) {
  return new Request('https://example.test/api/impressum', { method: 'POST', body });
}

const env = (extra = {}) => ({ TURNSTILE_SECRET_KEY: SECRET, IMPRESSUM_TEXT: TEXT, ...extra });

// Replaces fetch; records each verification request's parsed body.
function verifier(respond) {
  const calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push({ url, body: JSON.parse(init.body) });
    return respond();
  };
  return calls;
}

const json = (value, status = 200) =>
  new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json' } });

async function expectAnswer(response, status) {
  assert.equal(response.status, status);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  const body = await response.text();
  if (status === 200) assert.equal(body, TEXT);
  else assert.ok(!body.includes('Example Street'), `body leaks the text: ${body}`);
  return body;
}

afterEach(() => {
  globalThis.fetch = realFetch;
});

describe('POST /api/impressum', () => {
  test('a passed check returns the text', async () => {
    const calls = verifier(() => json({ success: true }));
    await expectAnswer(await onRequestPost({ request: post(), env: env() }), 200);
    assert.deepEqual(calls, [
      {
        url: 'https://challenges.cloudflare.com/turnstile/v0/siteverify',
        body: { secret: SECRET, response: 'a-token' },
      },
    ]);
  });

  test('a failed check gives 403', async () => {
    verifier(() => json({ success: false, 'error-codes': ['invalid-input-response'] }));
    await expectAnswer(await onRequestPost({ request: post(), env: env() }), 403);
  });

  test('an answer without success: true gives 403', async () => {
    verifier(() => json({}));
    await expectAnswer(await onRequestPost({ request: post(), env: env() }), 403);
  });

  for (const [name, body] of [
    ['a missing token', JSON.stringify({})],
    ['an empty token', JSON.stringify({ token: '' })],
    ['a token that is not a string', JSON.stringify({ token: 7 })],
    ['an unreadable body', 'not json'],
    ['a JSON null body', 'null'],
  ]) {
    test(`${name} gives 403 without verification`, async () => {
      const calls = verifier(() => json({ success: true }));
      await expectAnswer(await onRequestPost({ request: post(body), env: env() }), 403);
      assert.equal(calls.length, 0);
    });
  }

  test('an unreachable verification gives 502', async () => {
    globalThis.fetch = async () => {
      throw new TypeError('fetch failed');
    };
    await expectAnswer(await onRequestPost({ request: post(), env: env() }), 502);
  });

  for (const status of [500, 429, 201]) {
    test(`verification answering status ${status} gives 502`, async () => {
      verifier(() => json({ success: true }, status));
      await expectAnswer(await onRequestPost({ request: post(), env: env() }), 502);
    });
  }

  test('an unreadable verification answer gives 502', async () => {
    verifier(() => new Response('<html>', { status: 200 }));
    await expectAnswer(await onRequestPost({ request: post(), env: env() }), 502);
  });

  test('a missing TURNSTILE_SECRET_KEY gives 500 before verification', async () => {
    const calls = verifier(() => json({ success: true }));
    const response = await onRequestPost({
      request: post(),
      env: env({ TURNSTILE_SECRET_KEY: undefined }),
    });
    await expectAnswer(response, 500);
    assert.equal(calls.length, 0);
  });

  test('a missing IMPRESSUM_TEXT gives 500 after verification', async () => {
    const calls = verifier(() => json({ success: true }));
    const response = await onRequestPost({
      request: post(),
      env: env({ IMPRESSUM_TEXT: undefined }),
    });
    await expectAnswer(response, 500);
    assert.equal(calls.length, 1);
  });

  test('a failed check with no text configured still gives 403', async () => {
    verifier(() => json({ success: false }));
    const response = await onRequestPost({
      request: post(),
      env: env({ IMPRESSUM_TEXT: undefined }),
    });
    await expectAnswer(response, 403);
  });
});

describe('other methods', () => {
  for (const method of ['GET', 'HEAD', 'PUT', 'DELETE']) {
    test(`${method} gives 405 without verification`, async () => {
      const calls = verifier(() => json({ success: true }));
      const request = new Request('https://example.test/api/impressum', { method });
      const response = await onRequest({ request, env: env() });
      await expectAnswer(response, 405);
      assert.equal(response.headers.get('Allow'), 'POST');
      assert.equal(calls.length, 0);
    });
  }

  test('POST through onRequest still returns the text', async () => {
    verifier(() => json({ success: true }));
    await expectAnswer(await onRequest({ request: post(), env: env() }), 200);
  });
});

// Criterion 63: Cloudflare's published test secret keys against the real
// verification address. Skipped, not failed, when it cannot be reached.
describe('real verification with Cloudflare test keys', () => {
  const ALWAYS_PASSES = '1x0000000000000000000000000000000AA';
  const ALWAYS_FAILS = '2x0000000000000000000000000000000AA';

  async function reachable() {
    try {
      const response = await realFetch(
        'https://challenges.cloudflare.com/turnstile/v0/siteverify',
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ secret: ALWAYS_PASSES, response: 'XXXX.DUMMY.TOKEN.XXXX' }),
          signal: AbortSignal.timeout(10_000),
        },
      );
      return response.status === 200;
    } catch {
      return false;
    }
  }

  for (const [secret, status] of [
    [ALWAYS_PASSES, 200],
    [ALWAYS_FAILS, 403],
  ]) {
    test(`secret ${secret.slice(0, 2)}... gives ${status}`, async (t) => {
      if (!(await reachable())) {
        t.skip('challenges.cloudflare.com is unreachable');
        return;
      }
      const response = await onRequestPost({
        request: post(JSON.stringify({ token: 'XXXX.DUMMY.TOKEN.XXXX' })),
        env: env({ TURNSTILE_SECRET_KEY: secret }),
      });
      await expectAnswer(response, status);
    });
  }
});

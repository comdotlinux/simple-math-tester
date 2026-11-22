// Tests for functions/api/report.js with Node's built-in runner:
//   node --test tool/functions_test/
// GitHub is replaced by a fake fetch; nothing here reaches the network.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { afterEach, describe, test } from 'node:test';

import { onRequest, onRequestPost } from '../../functions/api/report.js';

const TOKEN = 'test-token-not-real';
const API = 'https://api.github.com/repos/comdotlinux/simple-math-tester';
const realFetch = globalThis.fetch;
const env = (extra = {}) => ({ GITHUB_REPORT_TOKEN: TOKEN, ...extra });

const QUESTION = {
  type: 'question',
  kind: 'geometry',
  variant: 'rectangleArea',
  params: [3, 4],
  level: 2,
  reason: 'wrongAnswer',
  version: '1.3.0',
  platform: 'android',
  locale: 'pt_PT',
};
const PROBLEM = { type: 'problem', category: 'sound', version: '1.3.0', platform: 'web', locale: 'de' };
const QUESTION_TITLE = 'Suspect question: geometry rectangleArea [3,4] L2';
const PROBLEM_TITLE = 'Reported problem: sound 1.3.0 web';

function post(body, headers = { 'Content-Type': 'application/json' }) {
  return new Request('https://example.test/api/report', {
    method: 'POST',
    headers,
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

const json = (value, status = 200) =>
  new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json' } });

const issue = (number, title, label) => ({ number, title, labels: [{ name: label }] });

// A fake GitHub: open issues per label, and what POSTs answer. Records calls.
function fakeGitHub({ open = {}, create, react } = {}) {
  const calls = [];
  globalThis.fetch = async (url, init = {}) => {
    calls.push({
      url,
      method: init.method ?? 'GET',
      headers: init.headers,
      signal: init.signal,
      body: init.body && JSON.parse(init.body),
    });
    const { pathname, searchParams } = new URL(url);
    if ((init.method ?? 'GET') === 'GET' && pathname.endsWith('/issues')) {
      return json(open[searchParams.get('labels')] ?? []);
    }
    if (pathname.endsWith('/reactions')) return react ? react() : json({ content: '+1' }, 201);
    if (init.method === 'PATCH') return json({ state: 'closed' });
    if (pathname.endsWith('/issues')) {
      if (create) return create();
      const sent = JSON.parse(init.body);
      return json({ number: 900, title: sent.title, labels: sent.labels.map((name) => ({ name })) }, 201);
    }
    throw new Error(`unexpected ${url}`);
  };
  return calls;
}

async function expectAnswer(response, status) {
  assert.equal(response.status, status);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), null);
  assert.match(response.headers.get('Content-Type'), /^text\/plain/);
  const body = await response.text();
  assert.ok(body.length < 40, body);
  assert.ok(!body.includes(TOKEN));
  return body;
}

afterEach(() => {
  globalThis.fetch = realFetch;
});

describe('new reports', () => {
  test('a suspect question creates one labelled issue from the template: 201', async () => {
    const calls = fakeGitHub();
    assert.equal(await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 201), 'Reported.');
    const create = calls.find((c) => c.method === 'POST');
    assert.equal(create.url, `${API}/issues`);
    assert.deepEqual(create.body, {
      title: QUESTION_TITLE,
      labels: ['suspect-question'],
      body: [
        '- Kind: `geometry`',
        '- Variant: `rectangleArea`',
        '- Params: `[3,4]`',
        '- Level: `2`',
        '- Reason: `wrongAnswer`',
        '- Version: `1.3.0`',
        '- Platform: `android`',
        '- Language: `pt_PT`',
        '',
        'Sent from the app as a fixed report code: no free text, no personal data. ' +
          'Later reports of the same thing add a +1 reaction to this issue.',
      ].join('\n'),
    });
    for (const call of calls) {
      assert.ok(call.url.startsWith(`${API}/`), call.url);
      assert.equal(call.headers.Authorization, `Bearer ${TOKEN}`);
      assert.equal(call.headers['User-Agent'], 'simple-math-tester-report');
      assert.ok(call.signal instanceof AbortSignal && !call.signal.aborted);
    }
    assert.deepEqual(
      calls
        .filter((c) => c.method === 'GET')
        .map((c) => c.url)
        .sort(),
      [
        `${API}/issues?state=open&labels=reported-problem&per_page=100`,
        `${API}/issues?state=open&labels=suspect-question&per_page=100`,
      ],
    );
  });

  test('a problem report creates one issue per category, version and platform: 201', async () => {
    const calls = fakeGitHub({ open: { 'suspect-question': [issue(5, PROBLEM_TITLE, 'suspect-question')] } });
    await expectAnswer(await onRequestPost({ request: post(PROBLEM), env: env() }), 201);
    const create = calls.find((c) => c.method === 'POST');
    assert.equal(create.body.title, PROBLEM_TITLE);
    assert.deepEqual(create.body.labels, ['reported-problem']);
    assert.match(create.body.body, /^- Category: `sound`\n- Version: `1.3.0`\n- Platform: `web`\n- Language: `de`\n/);
  });

  test('a negative param and a JSON charset are accepted', async () => {
    const calls = fakeGitHub();
    const body = { ...QUESTION, kind: 'algebra', variant: 'anTenths', params: [-1000, 1000], level: 5 };
    const request = post(body, { 'Content-Type': 'application/json; charset=utf-8' });
    await expectAnswer(await onRequestPost({ request, env: env() }), 201);
    assert.equal(
      calls.find((c) => c.method === 'POST').body.title,
      'Suspect question: algebra anTenths [-1000,1000] L5',
    );
  });

  test('an issue GitHub created without the label is closed and gives 500', async () => {
    const calls = fakeGitHub({ create: () => json({ number: 9, labels: [] }, 201) });
    assert.equal(
      await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 500),
      'Not configured.',
    );
    const close = calls.find((c) => c.method === 'PATCH');
    assert.equal(close.url, `${API}/issues/9`);
    assert.deepEqual(close.body, { state: 'closed', state_reason: 'not_planned' });
  });
});

describe('repeats', () => {
  test('a question already open gets a +1 reaction and no new issue: 200', async () => {
    const calls = fakeGitHub({
      open: {
        'suspect-question': [issue(1, 'Other', 'suspect-question'), issue(42, QUESTION_TITLE, 'suspect-question')],
      },
    });
    assert.equal(
      await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 200),
      'Already reported.',
    );
    const posts = calls.filter((c) => c.method === 'POST');
    assert.deepEqual(
      posts.map((c) => [c.url, c.body]),
      [[`${API}/issues/42/reactions`, { content: '+1' }]],
    );
  });

  test('a reaction that already exists (GitHub 200) still gives 200', async () => {
    fakeGitHub({
      open: { 'reported-problem': [issue(7, PROBLEM_TITLE, 'reported-problem')] },
      react: () => json({}, 200),
    });
    await expectAnswer(await onRequestPost({ request: post(PROBLEM), env: env() }), 200);
  });

  test('a repeat is counted even at the limit, as it creates nothing', async () => {
    const full = Array.from({ length: 100 }, (_, i) =>
      issue(i + 1, i === 50 ? QUESTION_TITLE : `Q${i}`, 'suspect-question'),
    );
    const calls = fakeGitHub({ open: { 'suspect-question': full } });
    await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 200);
    assert.equal(calls.filter((c) => c.url.endsWith('/issues') && c.method === 'POST').length, 0);
  });

  test('a pull request with the same title is not taken for the issue', async () => {
    const calls = fakeGitHub({
      open: { 'suspect-question': [{ ...issue(3, QUESTION_TITLE, 'suspect-question'), pull_request: {} }] },
    });
    await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 201);
    assert.equal(calls.filter((c) => c.url.endsWith('/reactions')).length, 0);
  });
});

describe('the limit on open reports', () => {
  for (const [questions, problems] of [
    [100, 0],
    [60, 40],
    [0, 100],
  ]) {
    test(`${questions} questions and ${problems} problems open gives 429 and creates nothing`, async () => {
      const calls = fakeGitHub({
        open: {
          'suspect-question': Array.from({ length: questions }, (_, i) => issue(i, `Q${i}`, 'suspect-question')),
          'reported-problem': Array.from({ length: problems }, (_, i) => issue(i, `P${i}`, 'reported-problem')),
        },
      });
      assert.equal(
        await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 429),
        'Too many reports.',
      );
      assert.equal(calls.filter((c) => c.method === 'POST').length, 0);
    });
  }

  test('99 open still creates the issue', async () => {
    fakeGitHub({
      open: { 'reported-problem': Array.from({ length: 99 }, (_, i) => issue(i, `P${i}`, 'reported-problem')) },
    });
    await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 201);
  });
});

describe('configuration and GitHub failures', () => {
  test('a missing GITHUB_REPORT_TOKEN gives 500 without a GitHub call', async () => {
    const calls = fakeGitHub();
    for (const token of [undefined, '']) {
      const response = await onRequestPost({ request: post(QUESTION), env: env({ GITHUB_REPORT_TOKEN: token }) });
      assert.equal(await expectAnswer(response, 500), 'Not configured.');
    }
    assert.equal(calls.length, 0);
  });

  test('an invalid report without a token is still 400', async () => {
    const response = await onRequestPost({ request: post({}), env: {} });
    await expectAnswer(response, 400);
  });

  const failures = {
    'the list call fails': { open: null },
    'the list answers 500': { listStatus: 500 },
    'the list answers 401 with a message': { listStatus: 401 },
    'the list is not an array': { listBody: { message: 'x' } },
    'the list is not JSON': { listRaw: '<html>' },
    'issue creation answers 422': { create: () => json({ message: `Validation Failed ${TOKEN}` }, 422) },
    'issue creation is unreachable': {
      create: () => {
        throw new TypeError('fetch failed');
      },
    },
    'the reaction answers 403': { repeat: true, react: () => json({ message: 'Forbidden' }, 403) },
  };
  for (const [name, f] of Object.entries(failures)) {
    test(`${name}: 502 with a fixed body`, async () => {
      fakeGitHub({
        open: f.repeat ? { 'suspect-question': [issue(4, QUESTION_TITLE, 'suspect-question')] } : {},
        create: f.create,
        react: f.react,
      });
      const fake = globalThis.fetch;
      globalThis.fetch = async (url, init = {}) => {
        if ((init.method ?? 'GET') === 'GET') {
          if (f.open === null) throw new TypeError('fetch failed');
          if (f.listStatus) return json({ message: `Bad credentials ${TOKEN}` }, f.listStatus);
          if (f.listBody) return json(f.listBody);
          if (f.listRaw) return new Response(f.listRaw, { status: 200 });
        }
        return fake(url, init);
      };
      assert.equal(
        await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 502),
        'Unavailable.',
      );
    });
  }

  test('a GitHub call that times out gives 502', async () => {
    globalThis.fetch = async (_url, init) => {
      assert.ok(init.signal instanceof AbortSignal);
      throw new DOMException('The operation was aborted due to timeout', 'TimeoutError');
    };
    await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 502);
  });

  test('GitHub that never answers is cut off by the deadline: 502', async (t) => {
    // The real deadline is 8 seconds; this one is 20 ms, through the same AbortSignal.timeout.
    const timeout = AbortSignal.timeout;
    t.after(() => {
      AbortSignal.timeout = timeout;
    });
    const asked = [];
    AbortSignal.timeout = (ms) => {
      asked.push(ms);
      return timeout.call(AbortSignal, 20);
    };
    globalThis.fetch = (_url, init) =>
      new Promise((_, reject) => init.signal.addEventListener('abort', () => reject(init.signal.reason)));
    // AbortSignal.timeout does not keep Node's event loop alive; this timer does.
    const alive = setTimeout(() => {}, 5000);
    t.after(() => clearTimeout(alive));
    await expectAnswer(await onRequestPost({ request: post(QUESTION), env: env() }), 502);
    assert.deepEqual(asked, [8000]);
  });
});

describe('invalid requests give 400 and never call GitHub', () => {
  const cases = [];
  const add = (name, body, headers) => cases.push([name, body, headers]);

  add('not JSON', '{"type":');
  add('empty body', '');
  add('JSON null', 'null');
  add('a JSON array', '[]');
  add('a JSON string', '"question"');
  add('an unknown type', { ...PROBLEM, type: 'feedback' });
  add('no type', (({ type, ...rest }) => rest)(PROBLEM));
  add('arithmetic kind', { ...QUESTION, kind: 'add', variant: 'rectangleArea' });
  add('variant of the other kind', { ...QUESTION, kind: 'algebra' });
  add('a problem with question fields', { ...PROBLEM, level: 1 });
  add('a question with a category', { ...QUESTION, category: 'sound' });
  add('a question as a problem', { ...QUESTION, type: 'problem' });
  for (const field of Object.keys(QUESTION)) {
    const { [field]: _, ...rest } = QUESTION;
    add(`question without ${field}`, rest);
  }
  for (const field of Object.keys(PROBLEM)) {
    const { [field]: _, ...rest } = PROBLEM;
    add(`problem without ${field}`, rest);
  }
  add('an unknown extra key', { ...QUESTION, note: 'hi' });
  add('a __proto__ key', `${JSON.stringify(PROBLEM).slice(0, -1)},"__proto__":{"polluted":1}}`);
  add('a constructor key', { ...PROBLEM, constructor: { prototype: { polluted: 1 } } });
  add('level 0', { ...QUESTION, level: 0 });
  add('level 6', { ...QUESTION, level: 6 });
  add('level 2.5', { ...QUESTION, level: 2.5 });
  add('level as a string', { ...QUESTION, level: '2' });
  add('no params', { ...QUESTION, params: [] });
  add('five params', { ...QUESTION, params: [1, 2, 3, 4, 5] });
  add('a param above 1000', { ...QUESTION, params: [1001] });
  add('a param below -1000', { ...QUESTION, params: [-1001] });
  add('a fractional param', { ...QUESTION, params: [1.5] });
  add('a string param', { ...QUESTION, params: ['3'] });
  add('a null param', { ...QUESTION, params: [null] });
  add('a nested param', { ...QUESTION, params: [[3]] });
  add('params as an object', { ...QUESTION, params: { 0: 3, length: 1 } });
  add(
    'a huge param',
    '{"type":"question","kind":"geometry","variant":"rectangleArea","params":[1e400],"level":2,"reason":"wrongAnswer","version":"1.3.0","platform":"android","locale":"de"}',
  );
  add('version unknown', { ...QUESTION, version: 'unknown' });
  add('version with a suffix', { ...QUESTION, version: '1.3.0+12' });
  add('version with a newline', { ...QUESTION, version: '1.3.0\n' });
  add('version as a number', { ...QUESTION, version: 1.3 });
  add('platform fuchsia', { ...QUESTION, platform: 'fuchsia' });
  add('platform in capitals', { ...QUESTION, platform: 'Android' });
  add('locale pt-PT', { ...QUESTION, locale: 'pt-PT' });
  add('locale es', { ...QUESTION, locale: 'es' });
  add('reason unknown', { ...QUESTION, reason: 'tooHard' });
  add('category unknown', { ...PROBLEM, category: 'billing' });
  add('wrong Content-Type', QUESTION, { 'Content-Type': 'text/plain' });
  add('form Content-Type', QUESTION, { 'Content-Type': 'application/x-www-form-urlencoded' });
  add('JSON-like Content-Type', QUESTION, { 'Content-Type': 'application/jsonx' });
  add('no Content-Type', new Blob([JSON.stringify(QUESTION)]), {});

  // Hostile strings in every field of both shapes.
  const hostile = [
    '**bold** [link](https://evil.example) <img src=x onerror=alert(1)>',
    '<script>alert(1)</script>',
    '@comdotlinux please look',
    'https://evil.example/phish',
    '`code` | table | ```fence',
    '# Heading\n- [ ] task',
    'rectangleArea\u0000',
    'rectangleArea ',
    ' rectangleArea',
    'x'.repeat(900),
    '__proto__',
    'constructor',
    'toString',
  ];
  const values = [...hostile, { nested: { a: 1 } }, ['geometry'], null, true, 7];
  for (const [shapeName, shape] of [
    ['question', QUESTION],
    ['problem', PROBLEM],
  ]) {
    for (const field of Object.keys(shape)) {
      values.forEach((value, i) => {
        add(`${shapeName} ${field} hostile #${i}`, { ...shape, [field]: value });
      });
    }
  }

  for (const [name, body, headers] of cases) {
    test(name, async () => {
      const calls = fakeGitHub();
      const response = await onRequestPost({ request: post(body, headers), env: env() });
      assert.equal(await expectAnswer(response, 400), 'Invalid report.');
      assert.equal(calls.length, 0);
    });
  }

  test('a body over 1 KB gives 400, with or without Content-Length', async () => {
    const calls = fakeGitHub();
    const big = JSON.stringify({ ...QUESTION, pad: 'x'.repeat(1100) });
    await expectAnswer(await onRequestPost({ request: post(big), env: env() }), 400);
    const streamed = new Request('https://example.test/api/report', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: new ReadableStream({
        pull(controller) {
          controller.enqueue(new TextEncoder().encode(' '.repeat(600)));
        },
      }),
      duplex: 'half',
    });
    assert.equal(streamed.headers.get('Content-Length'), null);
    await expectAnswer(await onRequestPost({ request: streamed, env: env() }), 400);
    assert.equal(calls.length, 0);
  });

  test('a body of exactly 1024 bytes is read', async () => {
    fakeGitHub();
    const text = JSON.stringify(QUESTION);
    const padded = text + ' '.repeat(1024 - new TextEncoder().encode(text).length);
    await expectAnswer(await onRequestPost({ request: post(padded), env: env() }), 201);
  });

  test('a prototype key leaves Object.prototype alone', () => {
    assert.equal({}.polluted, undefined);
  });
});

describe('other methods', () => {
  for (const method of ['GET', 'HEAD', 'PUT', 'DELETE', 'OPTIONS', 'PATCH']) {
    test(`${method} gives 405 without a GitHub call`, async () => {
      const calls = fakeGitHub();
      const request = new Request('https://example.test/api/report', { method });
      const response = await onRequest({ request, env: env() });
      await expectAnswer(response, 405);
      assert.equal(response.headers.get('Allow'), 'POST');
      assert.equal(calls.length, 0);
    });
  }

  test('POST through onRequest creates the issue', async () => {
    fakeGitHub();
    await expectAnswer(await onRequest({ request: post(QUESTION), env: env() }), 201);
  });
});

describe('the allow-list', () => {
  const allow = JSON.parse(readFileSync(new URL('../../functions/report-allowlist.json', import.meta.url)));

  test('every name is a plain identifier, so no name can carry Markdown', () => {
    for (const name of [...allow.algebra, ...allow.geometry, ...allow.locales]) {
      assert.match(name, /^[A-Za-z]+(_[A-Z]+)?$/);
    }
  });

  test('every family of both kinds is accepted', async () => {
    for (const kind of ['algebra', 'geometry']) {
      for (const variant of allow[kind]) {
        fakeGitHub();
        const response = await onRequestPost({ request: post({ ...QUESTION, kind, variant }), env: env() });
        assert.equal(response.status, 201, variant);
      }
    }
  });

  test('every locale, platform, reason and category is accepted', async () => {
    const accepted = [
      ...allow.locales.map((locale) => ({ ...PROBLEM, locale })),
      ...['android', 'ios', 'web', 'linux', 'macos', 'windows'].map((platform) => ({ ...PROBLEM, platform })),
      ...['crash', 'display', 'sound', 'translation', 'other'].map((category) => ({ ...PROBLEM, category })),
      ...['wrongAnswer', 'unclearQuestion', 'wrongHint', 'wrongDrawing'].map((reason) => ({ ...QUESTION, reason })),
    ];
    for (const body of accepted) {
      fakeGitHub();
      const response = await onRequestPost({ request: post(body), env: env() });
      assert.equal(response.status, 201, JSON.stringify(body));
    }
  });
});

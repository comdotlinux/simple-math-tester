import assert from 'node:assert/strict';
import { createHash, generateKeyPairSync, verify } from 'node:crypto';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import {
  appName,
  appStoreLocales,
  appStoreTexts,
  connect,
  devices,
  listing,
  pickEditable,
  replaceScreenshots,
  review,
  token,
  upload,
  urls,
  whatsNewFor,
} from './app_store.mjs';
import { playCodes } from './translate_listing.mjs';

const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pem = privateKey.export({ type: 'pkcs8', format: 'pem' });
const env = { APPSTORE_API_KEY: pem, APPSTORE_KEY_ID: 'KEY123', APPSTORE_ISSUER_ID: 'issuer-1' };

test('the token is an ES256 JWT that App Store Connect accepts', () => {
  const jwt = token({ keyId: 'KEY123', issuerId: 'issuer-1', key: pem }, 1_700_000_000_000);
  const [header, payload, signature] = jwt.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(header, 'base64url')), { alg: 'ES256', kid: 'KEY123', typ: 'JWT' });
  assert.deepEqual(JSON.parse(Buffer.from(payload, 'base64url')), {
    iss: 'issuer-1',
    iat: 1_700_000_000,
    exp: 1_700_000_600,
    aud: 'appstoreconnect-v1',
  });
  // JOSE wants the raw 64-byte r||s signature, not DER.
  assert.equal(Buffer.from(signature, 'base64url').length, 64);
  assert.ok(
    verify(
      'sha256',
      Buffer.from(`${header}.${payload}`),
      { key: publicKey, dsaEncoding: 'ieee-p1363' },
      Buffer.from(signature, 'base64url'),
    ),
  );
});

test('every Play listing has an App Store locale', () => {
  assert.deepEqual(Object.keys(appStoreLocales).sort(), ['en-US', ...Object.values(playCodes)].sort());
  assert.equal(appStoreLocales['pl-PL'], 'pl');
  assert.equal(appStoreLocales['hi-IN'], 'hi');
  assert.equal(appStoreLocales.pa, 'pa-IN');
  assert.equal(appStoreLocales['ta-IN'], 'ta-IN');
});

test('Play texts map to App Store fields', () => {
  const texts = appStoreTexts({
    title: 'Simple Math Tester',
    shortDescription: 'Short',
    fullDescription: 'Full',
    subtitle: 'Sub',
    keywords: 'maths, times tables ,,kids',
  });
  assert.deepEqual(texts.info, { name: appName, subtitle: 'Sub', privacyPolicyUrl: urls.privacyPolicyUrl });
  assert.deepEqual(texts.version, {
    description: 'Full',
    keywords: 'maths,times tables,kids',
    promotionalText: 'Short',
    marketingUrl: urls.marketingUrl,
    supportUrl: urls.supportUrl,
  });
});

test('only an editable version or app info is picked', () => {
  const item = (id, attributes) => ({ id, attributes });
  assert.equal(
    pickEditable([
      item('1', { appVersionState: 'READY_FOR_DISTRIBUTION' }),
      item('2', { appVersionState: 'PREPARE_FOR_SUBMISSION' }),
    ]).id,
    '2',
  );
  assert.equal(
    pickEditable([item('1', { state: 'READY_FOR_DISTRIBUTION' }), item('2', { state: 'REJECTED' })]).id,
    '2',
  );
  assert.equal(pickEditable([item('1', { appStoreState: 'METADATA_REJECTED' })]).id, '1');
  assert.equal(pickEditable([item('1', { appStoreState: 'WAITING_FOR_REVIEW' })]), undefined);
});

test('API calls carry a token and fail with Apple’s error details', async () => {
  assert.throws(() => connect({}), /Missing APPSTORE_API_KEY, APPSTORE_KEY_ID, APPSTORE_ISSUER_ID/);
  const calls = [];
  const api = connect(env, async (url, init) => {
    calls.push({ url, init });
    return url.endsWith('/bad')
      ? new Response(JSON.stringify({ errors: [{ title: 'Conflict', detail: 'locale not supported' }] }), {
          status: 409,
        })
      : new Response(JSON.stringify({ data: [] }), { status: 200 });
  });
  assert.deepEqual(await api('GET', '/v1/apps'), { data: [] });
  assert.equal(calls[0].url, 'https://api.appstoreconnect.apple.com/v1/apps');
  assert.match(calls[0].init.headers.Authorization, /^Bearer [\w-]+\.[\w-]+\.[\w-]+$/);
  await assert.rejects(api('POST', '/bad', { type: 'x' }), (error) => {
    assert.equal(error.status, 409);
    assert.equal(error.message, 'POST /bad: 409 locale not supported');
    return true;
  });
  assert.equal(calls[1].init.body, JSON.stringify({ data: { type: 'x' } }));
});

test('a screenshot is uploaded in the parts Apple names and committed with its MD5', async () => {
  const file = join(mkdtempSync(join(tmpdir(), 'app-store-test-')), '1-practice.png');
  const bytes = Buffer.from('0123456789');
  writeFileSync(file, bytes);
  const calls = [];
  const api = async (method, path, data) => {
    calls.push({ method, path, data });
    if (method !== 'POST') return null;
    const op = (offset, length) => ({
      method: 'PUT',
      url: `https://up/${offset}`,
      offset,
      length,
      requestHeaders: [{ name: 'Content-Type', value: 'image/png' }],
    });
    return { data: { id: 'shot-1', attributes: { uploadOperations: [op(0, 6), op(6, 4)] } } };
  };
  const puts = [];
  const put = async (url, init) => {
    puts.push({ url, headers: init.headers, body: Buffer.from(init.body).toString() });
    return { ok: true };
  };
  assert.equal(await upload(api, 'set-1', file, put), 'shot-1');
  assert.deepEqual(calls[0].data, {
    type: 'appScreenshots',
    attributes: { fileName: '1-practice.png', fileSize: 10 },
    relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: 'set-1' } } },
  });
  assert.deepEqual(puts, [
    { url: 'https://up/0', headers: { 'Content-Type': 'image/png' }, body: '012345' },
    { url: 'https://up/6', headers: { 'Content-Type': 'image/png' }, body: '6789' },
  ]);
  assert.deepEqual(calls[1], {
    method: 'PATCH',
    path: '/v1/appScreenshots/shot-1',
    data: {
      type: 'appScreenshots',
      id: 'shot-1',
      attributes: { uploaded: true, sourceFileChecksum: createHash('md5').update(bytes).digest('hex') },
    },
  });
});

test('the listing updates existing locales, creates new ones and skips a locale Apple refuses', async () => {
  const calls = [];
  const api = async (method, path, data) => {
    calls.push(`${method} ${path}${data?.attributes?.locale ? ` ${data.attributes.locale}` : ''}`);
    if (path.startsWith('/v1/apps?')) return { data: [{ id: 'app' }] };
    if (path === '/v1/apps/app/appInfos')
      return { data: [{ id: 'info', attributes: { state: 'PREPARE_FOR_SUBMISSION' } }] };
    if (path.startsWith('/v1/apps/app/appStoreVersions')) {
      return {
        data: [{ id: 'ver', attributes: { versionString: '1.4.1', appVersionState: 'PREPARE_FOR_SUBMISSION' } }],
      };
    }
    if (path.startsWith('/v1/appInfos/info/')) return { data: [{ id: 'info-en', attributes: { locale: 'en-US' } }] };
    if (path.startsWith('/v1/appStoreVersions/ver/'))
      return { data: [{ id: 'ver-en', attributes: { locale: 'en-US' } }] };
    if (method === 'POST' && data.attributes.locale === 'pa-IN') {
      throw Object.assign(new Error('409 not supported'), { status: 409 });
    }
    return { data: { id: `${data.type}-${data.attributes.locale ?? 'patched'}` } };
  };
  const log = console.log;
  const lines = [];
  console.log = (line) => lines.push(line);
  try {
    await listing(api);
  } finally {
    console.log = log;
  }
  assert.ok(calls.includes('PATCH /v1/appInfoLocalizations/info-en'));
  assert.ok(calls.includes('PATCH /v1/appStoreVersionLocalizations/ver-en'));
  assert.ok(calls.includes('POST /v1/appInfoLocalizations de-DE'));
  assert.ok(calls.includes('POST /v1/appStoreVersionLocalizations de-DE'));
  assert.ok(calls.includes('POST /v1/appInfoLocalizations pa-IN'));
  assert.ok(!calls.includes('POST /v1/appStoreVersionLocalizations pa-IN'));
  assert.ok(lines.some((l) => l.startsWith('::notice::App Store Connect did not take pa-IN (pa)')));
  assert.equal(lines.filter((l) => l.startsWith('Updated ')).length, Object.keys(appStoreLocales).length - 1);
});

test('the listing updates a version localization that appeared after it was read', async () => {
  const calls = [];
  let versionReads = 0;
  const api = async (method, path, data) => {
    calls.push(`${method} ${path}${data?.attributes?.locale ? ` ${data.attributes.locale}` : ''}`);
    if (path.startsWith('/v1/apps?')) return { data: [{ id: 'app' }] };
    if (path === '/v1/apps/app/appInfos')
      return { data: [{ id: 'info', attributes: { state: 'PREPARE_FOR_SUBMISSION' } }] };
    if (path.startsWith('/v1/apps/app/appStoreVersions')) {
      return {
        data: [{ id: 'ver', attributes: { versionString: '1.4.2', appVersionState: 'PREPARE_FOR_SUBMISSION' } }],
      };
    }
    if (path.startsWith('/v1/appInfos/info/')) return { data: [] };
    if (path.startsWith('/v1/appStoreVersions/ver/')) {
      versionReads += 1;
      // The first read is before any app info localization exists.
      return versionReads === 1 ? { data: [] } : { data: [{ id: 'ver-de', attributes: { locale: 'de-DE' } }] };
    }
    if (method === 'POST' && data.type === 'appStoreVersionLocalizations' && data.attributes.locale === 'de-DE') {
      throw Object.assign(new Error('409 Entity with locale: de-DE already exists'), { status: 409 });
    }
    return { data: { id: `${data.type}-${data.attributes.locale ?? 'patched'}` } };
  };
  const log = console.log;
  console.log = () => {};
  try {
    await listing(api);
  } finally {
    console.log = log;
  }
  assert.ok(calls.includes('POST /v1/appStoreVersionLocalizations de-DE'));
  assert.ok(calls.includes('PATCH /v1/appStoreVersionLocalizations/ver-de'));
});

test('the screenshot sets are the required iPhone medium size, iPhone large and iPad 13"', () => {
  assert.deepEqual(Object.fromEntries(Object.entries(devices).map(([device, d]) => [device, d.displayType])), {
    iphone: 'APP_IPHONE_61',
    'iphone-large': 'APP_IPHONE_67',
    ipad: 'APP_IPAD_PRO_3GEN_129',
  });
  for (const { size, ratio, pixels } of Object.values(devices)) {
    const [w, h] = size.split('x').map(Number);
    assert.equal(`${w * ratio}x${h * ratio}`, pixels);
  }
});

/** A screenshots dir with one PNG per device for en-US. */
function screenshotDir() {
  const dir = mkdtempSync(join(tmpdir(), 'app-store-shots-'));
  for (const device of Object.keys(devices)) {
    mkdirSync(join(dir, device, 'en-US'), { recursive: true });
    writeFileSync(join(dir, device, 'en-US', '1-practice.png'), 'png');
  }
  return dir;
}

test('the screenshots replace each set, creating the missing ones, and the sets are printed first', async () => {
  const calls = [];
  const api = async (method, path, data) => {
    calls.push(
      `${method} ${path}${data?.attributes?.screenshotDisplayType ? ` ${data.attributes.screenshotDisplayType}` : ''}`,
    );
    if (path.endsWith('/appScreenshotSets?limit=50')) {
      return { data: [{ id: 'set-67', attributes: { screenshotDisplayType: 'APP_IPHONE_67' } }] };
    }
    if (path.endsWith('/appScreenshots?limit=50')) return { data: path.includes('set-67') ? [{ id: 'old' }] : [] };
    if (method === 'POST' && path === '/v1/appScreenshotSets')
      return { data: { id: `set-${data.attributes.screenshotDisplayType}` } };
    if (method === 'POST') return { data: { id: 'shot', attributes: { uploadOperations: [] } } };
    return null;
  };
  const lines = await quietly(() =>
    replaceScreenshots(api, 'loc', screenshotDir(), 'en-US', 'en-US', async () => ({ ok: true })),
  );
  assert.deepEqual(lines, ['Screenshot sets of en-US: APP_IPHONE_67']);
  assert.ok(calls.includes('POST /v1/appScreenshotSets APP_IPHONE_61'));
  assert.ok(calls.includes('POST /v1/appScreenshotSets APP_IPAD_PRO_3GEN_129'));
  assert.ok(!calls.includes('POST /v1/appScreenshotSets APP_IPHONE_67'));
  assert.ok(calls.includes('DELETE /v1/appScreenshots/old'));
});

test('a refused screenshot set fails naming the type and the sets the localization has', async () => {
  const api = async (method, path) => {
    if (method === 'GET') return { data: [{ id: 's', attributes: { screenshotDisplayType: 'APP_IPHONE_65' } }] };
    if (path === '/v1/appScreenshotSets') {
      throw Object.assign(new Error('POST /v1/appScreenshotSets: 409 invalid display type'), { status: 409 });
    }
    return null;
  };
  await assert.rejects(
    quietly(() => replaceScreenshots(api, 'loc', screenshotDir(), 'en-US', 'en-US', async () => ({ ok: true }))),
    (error) => {
      assert.match(
        error.message,
        /refused the iphone screenshot set APP_IPHONE_61 for en-US \(POST \/v1\/appScreenshotSets: 409 invalid display type\)/,
      );
      assert.match(
        error.message,
        /Sets this localization has: APP_IPHONE_65\. Fix displayType in devices in tool\/app_store\.mjs/,
      );
      return true;
    },
  );
});
test("What's New takes the language's notes, else the English ones", () => {
  const notes = [
    { language: 'en-US', text: '- Faster' },
    { language: 'pl-PL', text: '- Szybciej' },
    { language: 'pa', text: '- ਤੇਜ਼' },
  ];
  assert.equal(whatsNewFor(notes, 'pl'), '- Szybciej');
  assert.equal(whatsNewFor(notes, 'pa-IN'), '- ਤੇਜ਼');
  assert.equal(whatsNewFor(notes, 'de-DE'), '- Faster');
  assert.equal(whatsNewFor([], 'en-US'), undefined);
});

/** A fake App Store Connect with [versions] and one valid build of 1.5.0, unless [build] is null. */
function fakeStore({ versions, build = { id: 'b1', attributes: { version: '431' } }, draft = null, items = [] }) {
  const writes = [];
  const api = async (method, path, data) => {
    if (method !== 'GET') {
      writes.push(`${method} ${path} ${JSON.stringify(data.attributes ?? data)}`);
      return { data: { id: `new-${data.type}`, attributes: data.attributes } };
    }
    if (path.startsWith('/v1/apps?')) return { data: [{ id: 'app' }] };
    if (path.startsWith('/v1/builds?')) {
      assert.match(path, /filter\[preReleaseVersion\.version\]=1\.5\.0&filter\[processingState\]=VALID/);
      return { data: build ? [build] : [] };
    }
    if (path.startsWith('/v1/apps/app/appStoreVersions')) return { data: versions };
    if (path.endsWith('/appStoreVersionLocalizations?limit=200')) {
      return { data: ['en-US', 'pl'].map((locale) => ({ id: `loc-${locale}`, attributes: { locale } })) };
    }
    if (path.startsWith('/v1/reviewSubmissions?')) return { data: draft ? [draft] : [] };
    if (path.startsWith('/v1/reviewSubmissions/')) return { data: items };
    throw new Error(`unexpected ${method} ${path}`);
  };
  return { api, writes };
}

const version = (id, versionString, appVersionState) => ({ id, attributes: { versionString, appVersionState } });
const notes = [
  { language: 'en-US', text: '- Faster' },
  { language: 'pl-PL', text: '- Szybciej' },
];

async function quietly(run) {
  const log = console.log;
  const lines = [];
  console.log = (line) => lines.push(line);
  try {
    await run();
  } finally {
    console.log = log;
  }
  return lines;
}

test('review attaches the build, writes What’s New and submits', async () => {
  const { api, writes } = fakeStore({
    versions: [version('v2', '1.5.0', 'PREPARE_FOR_SUBMISSION'), version('v1', '1.4.1', 'READY_FOR_DISTRIBUTION')],
  });
  const lines = await quietly(() => review(api, '1.5.0', notes, false));
  assert.deepEqual(writes, [
    'PATCH /v1/appStoreVersions/v2/relationships/build {"type":"builds","id":"b1"}',
    'PATCH /v1/appStoreVersionLocalizations/loc-en-US {"whatsNew":"- Faster"}',
    'PATCH /v1/appStoreVersionLocalizations/loc-pl {"whatsNew":"- Szybciej"}',
    'POST /v1/reviewSubmissions {"platform":"IOS"}',
    'POST /v1/reviewSubmissionItems {"type":"reviewSubmissionItems","relationships":{"reviewSubmission":{"data":{"type":"reviewSubmissions","id":"new-reviewSubmissions"}},"appStoreVersion":{"data":{"type":"appStoreVersions","id":"v2"}}}}',
    'PATCH /v1/reviewSubmissions/new-reviewSubmissions {"submitted":true}',
  ]);
  assert.equal(lines.at(-1), '::notice::Version 1.5.0 (build 431) is submitted for App Review');
});

test('a dry run only reads and says what it would do', async () => {
  const { api, writes } = fakeStore({
    versions: [version('v2', '1.4.2', 'PREPARE_FOR_SUBMISSION'), version('v1', '1.4.1', 'READY_FOR_DISTRIBUTION')],
  });
  const lines = await quietly(() => review(api, '1.5.0', notes, true));
  assert.deepEqual(writes, []);
  assert.deepEqual(lines, [
    'Would rename version 1.4.2 to 1.5.0',
    'Would attach build 431 to version 1.5.0',
    'Would set What\'s New of en-US: "- Faster"',
    'Would set What\'s New of pl: "- Szybciej"',
    'Would submit version 1.5.0 (build 431) for App Review',
  ]);
});

test('the first version gets no What’s New; a new version is created when none is open', async () => {
  const first = fakeStore({ versions: [version('v1', '1.5.0', 'PREPARE_FOR_SUBMISSION')] });
  const lines = await quietly(() => review(first.api, '1.5.0', notes, false));
  assert.ok(lines.includes("::notice::First App Store version: no What's New"));
  assert.ok(!first.writes.some((w) => w.includes('whatsNew')));

  const next = fakeStore({ versions: [version('v1', '1.4.1', 'READY_FOR_DISTRIBUTION')] });
  await quietly(() => review(next.api, '1.5.0', notes, false));
  assert.equal(next.writes[0], 'POST /v1/appStoreVersions {"platform":"IOS","versionString":"1.5.0"}');
  assert.equal(
    next.writes[1],
    'PATCH /v1/appStoreVersions/new-appStoreVersions/relationships/build {"type":"builds","id":"b1"}',
  );
});

test('a draft submission that holds the version is submitted as it is', async () => {
  const { api, writes } = fakeStore({
    versions: [version('v2', '1.5.0', 'PREPARE_FOR_SUBMISSION'), version('v1', '1.4.1', 'READY_FOR_DISTRIBUTION')],
    draft: { id: 'd1', attributes: { state: 'READY_FOR_REVIEW' } },
    items: [{ id: 'i1', relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: 'v2' } } } }],
  });
  await quietly(() => review(api, '1.5.0', notes, false));
  assert.ok(!writes.some((w) => w.startsWith('POST /v1/reviewSubmission')));
  assert.equal(writes.at(-1), 'PATCH /v1/reviewSubmissions/d1 {"submitted":true}');
});

test('review stops without a processed build or when the version is already in review', async () => {
  const noBuild = fakeStore({ versions: [], build: null });
  await assert.rejects(review(noBuild.api, '1.5.0', notes, true), /No processed build of 1\.5\.0 in TestFlight/);
  const inReview = fakeStore({ versions: [version('v2', '1.5.0', 'WAITING_FOR_REVIEW')] });
  await assert.rejects(review(inReview.api, '1.5.0', notes, false), /Version 1\.5\.0 is WAITING_FOR_REVIEW/);
  assert.deepEqual(inReview.writes, []);
});

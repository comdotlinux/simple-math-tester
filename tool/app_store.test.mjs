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
  token,
  upload,
  urls,
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
    verify('sha256', Buffer.from(`${header}.${payload}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(signature, 'base64url')),
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
  assert.equal(pickEditable([item('1', { appVersionState: 'READY_FOR_DISTRIBUTION' }), item('2', { appVersionState: 'PREPARE_FOR_SUBMISSION' })]).id, '2');
  assert.equal(pickEditable([item('1', { state: 'READY_FOR_DISTRIBUTION' }), item('2', { state: 'REJECTED' })]).id, '2');
  assert.equal(pickEditable([item('1', { appStoreState: 'METADATA_REJECTED' })]).id, '1');
  assert.equal(pickEditable([item('1', { appStoreState: 'WAITING_FOR_REVIEW' })]), undefined);
});

test('API calls carry a token and fail with Apple’s error details', async () => {
  assert.throws(() => connect({}), /Missing APPSTORE_API_KEY, APPSTORE_KEY_ID, APPSTORE_ISSUER_ID/);
  const calls = [];
  const api = connect(env, async (url, init) => {
    calls.push({ url, init });
    return url.endsWith('/bad')
      ? new Response(JSON.stringify({ errors: [{ title: 'Conflict', detail: 'locale not supported' }] }), { status: 409 })
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
    const op = (offset, length) => ({ method: 'PUT', url: `https://up/${offset}`, offset, length, requestHeaders: [{ name: 'Content-Type', value: 'image/png' }] });
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
    if (path === '/v1/apps/app/appInfos') return { data: [{ id: 'info', attributes: { state: 'PREPARE_FOR_SUBMISSION' } }] };
    if (path.startsWith('/v1/apps/app/appStoreVersions')) {
      return { data: [{ id: 'ver', attributes: { versionString: '1.4.1', appVersionState: 'PREPARE_FOR_SUBMISSION' } }] };
    }
    if (path.startsWith('/v1/appInfos/info/')) return { data: [{ id: 'info-en', attributes: { locale: 'en-US' } }] };
    if (path.startsWith('/v1/appStoreVersions/ver/')) return { data: [{ id: 'ver-en', attributes: { locale: 'en-US' } }] };
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

test('the screenshot sets are the required iPhone medium size, iPhone large and iPad 13"', () => {
  assert.deepEqual(
    Object.fromEntries(Object.entries(devices).map(([device, d]) => [device, d.displayType])),
    { iphone: 'APP_IPHONE_61', 'iphone-large': 'APP_IPHONE_67', ipad: 'APP_IPAD_PRO_3GEN_129' },
  );
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
    calls.push(`${method} ${path}${data?.attributes?.screenshotDisplayType ? ` ${data.attributes.screenshotDisplayType}` : ''}`);
    if (path.endsWith('/appScreenshotSets?limit=50')) {
      return { data: [{ id: 'set-67', attributes: { screenshotDisplayType: 'APP_IPHONE_67' } }] };
    }
    if (path.endsWith('/appScreenshots?limit=50')) return { data: path.includes('set-67') ? [{ id: 'old' }] : [] };
    if (method === 'POST' && path === '/v1/appScreenshotSets') return { data: { id: `set-${data.attributes.screenshotDisplayType}` } };
    if (method === 'POST') return { data: { id: 'shot', attributes: { uploadOperations: [] } } };
    return null;
  };
  const lines = await quietly(() => replaceScreenshots(api, 'loc', screenshotDir(), 'en-US', 'en-US', async () => ({ ok: true })));
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
      assert.match(error.message, /refused the iphone screenshot set APP_IPHONE_61 for en-US \(POST \/v1\/appScreenshotSets: 409 invalid display type\)/);
      assert.match(error.message, /Sets this localization has: APP_IPHONE_65\. Fix displayType in devices in tool\/app_store\.mjs/);
      return true;
    },
  );
});

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

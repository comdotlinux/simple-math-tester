// App Store Connect API for the App Store workflows. No dependencies: the JWT
// is signed with node:crypto from the .p8 key.
// Usage (secrets from the `release` environment, see docs/app-store.md):
//   APPSTORE_API_KEY=... APPSTORE_KEY_ID=... APPSTORE_ISSUER_ID=... \
//     node tool/app_store.mjs listing [screenshots dir]
// `listing` writes every play/listing/<code>.json to the version being prepared
// (name, subtitle, privacy URL; description, keywords, promotional text, support
// and marketing URL). With a screenshots dir (<dir>/<device>/<Play code>/*.png,
// device iphone or ipad) it also replaces each language's screenshots.
import { createHash, sign } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { basename, join } from 'node:path';
import { pathToFileURL } from 'node:url';

export const bundleId = 'com.linux.simplemath';
export const appName = 'Simple Math Tester: Practice';
export const urls = {
  marketingUrl: 'https://math.munich-tech.de',
  supportUrl: 'https://math.munich-tech.de/impressum',
  privacyPolicyUrl: 'https://math.munich-tech.de/privacy',
};

// Play listing code to App Store Connect locale ("Managing metadata in your app
// by using locale shortcodes" in the App Store Connect API docs).
export const appStoreLocales = {
  'en-US': 'en-US',
  'de-DE': 'de-DE',
  'pl-PL': 'pl',
  'hi-IN': 'hi',
  'mr-IN': 'mr-IN',
  'te-IN': 'te-IN',
  'ta-IN': 'ta-IN',
  'ml-IN': 'ml-IN',
  'fr-FR': 'fr-FR',
  ro: 'ro',
  uk: 'uk',
  'pt-BR': 'pt-BR',
  'pt-PT': 'pt-PT',
  pa: 'pa-IN',
};

// iPhone 6.9" (1290 x 2796) and iPad 13" (2048 x 2732).
export const displayTypes = { iphone: 'APP_IPHONE_67', ipad: 'APP_IPAD_PRO_3GEN_129' };

// Versions and app infos whose texts can still be changed.
const editable = ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'INVALID_BINARY'];
const listingDir = new URL('../play/listing/', import.meta.url);

/** An App Store Connect API token (ES256 JWT, 20 minutes at most; this one 10). */
export function token({ keyId, issuerId, key }, now = Date.now()) {
  const part = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const iat = Math.floor(now / 1000);
  const data = `${part({ alg: 'ES256', kid: keyId, typ: 'JWT' })}.${part({ iss: issuerId, iat, exp: iat + 600, aud: 'appstoreconnect-v1' })}`;
  const signature = sign('sha256', Buffer.from(data), { key, dsaEncoding: 'ieee-p1363' });
  return `${data}.${signature.toString('base64url')}`;
}

/** api(method, path, data) for App Store Connect; throws with Apple's error details. */
export function connect(env, fetchImpl = fetch) {
  const missing = ['APPSTORE_API_KEY', 'APPSTORE_KEY_ID', 'APPSTORE_ISSUER_ID'].filter((n) => !env[n]);
  if (missing.length) throw new Error(`Missing ${missing.join(', ')} (secrets of the release environment)`);
  const credentials = { keyId: env.APPSTORE_KEY_ID, issuerId: env.APPSTORE_ISSUER_ID, key: env.APPSTORE_API_KEY };
  // shortcut: no retry on 429 (Apple allows about 3600 requests an hour; a full listing run needs about 800).
  return async (method, path, data) => {
    const response = await fetchImpl(`https://api.appstoreconnect.apple.com${path}`, {
      method,
      // A fresh token per request: a run with screenshots outlasts one token.
      headers: {
        Authorization: `Bearer ${token(credentials)}`,
        ...(data ? { 'Content-Type': 'application/json' } : {}),
      },
      body: data ? JSON.stringify({ data }) : undefined,
    });
    const text = await response.text();
    const body = text ? JSON.parse(text) : null;
    if (!response.ok) {
      const details = (body?.errors ?? []).map((e) => e.detail || e.title).join('; ');
      const error = new Error(`${method} ${path}: ${response.status} ${details}`);
      error.status = response.status;
      throw error;
    }
    return body;
  };
}

/** The App Store texts of one listing file: app info and version localization. */
export function appStoreTexts(listing) {
  return {
    info: { name: appName, subtitle: listing.subtitle, privacyPolicyUrl: urls.privacyPolicyUrl },
    version: {
      description: listing.fullDescription,
      // Spaces after commas count against the 100 characters.
      keywords: listing.keywords.split(',').map((k) => k.trim()).filter(Boolean).join(','),
      promotionalText: listing.shortDescription,
      marketingUrl: urls.marketingUrl,
      supportUrl: urls.supportUrl,
    },
  };
}

/** The editable item of a list, by `state`, `appVersionState` or `appStoreState`. */
export function pickEditable(items) {
  return items.find((i) => editable.includes(i.attributes.state ?? i.attributes.appVersionState ?? i.attributes.appStoreState));
}

/** Reserves, uploads and commits one screenshot (Apple's "Uploading assets"). */
export async function upload(api, setId, file, put = fetch) {
  const bytes = await readFile(file);
  const shot = (
    await api('POST', '/v1/appScreenshots', {
      type: 'appScreenshots',
      attributes: { fileName: basename(file), fileSize: bytes.length },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } },
    })
  ).data;
  for (const op of shot.attributes.uploadOperations) {
    const response = await put(op.url, {
      method: op.method,
      headers: Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value])),
      body: bytes.subarray(op.offset, op.offset + op.length),
    });
    if (!response.ok) throw new Error(`Upload of ${file} failed: ${response.status}`);
  }
  await api('PATCH', `/v1/appScreenshots/${shot.id}`, {
    type: 'appScreenshots',
    id: shot.id,
    attributes: { uploaded: true, sourceFileChecksum: createHash('md5').update(bytes).digest('hex') },
  });
  return shot.id;
}

/** Updates the localization of [locale] of type [type], or creates it. */
async function upsert(api, type, existing, locale, attributes, relationships) {
  if (existing) return (await api('PATCH', `/v1/${type}/${existing.id}`, { type, id: existing.id, attributes })).data;
  return (await api('POST', `/v1/${type}`, { type, attributes: { locale, ...attributes }, relationships })).data;
}

// shortcut: appScreenshotSets are deprecated for the App Asset Library; move when Apple removes them.
/** Replaces every screenshot of one version localization; returns the set ids. */
async function replaceScreenshots(api, localizationId, dir, code) {
  const sets = (await api('GET', `/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=50`)).data;
  const ids = [];
  for (const [device, displayType] of Object.entries(displayTypes)) {
    const folder = join(dir, device, code);
    const files = (await readdir(folder).catch(() => [])).filter((n) => n.endsWith('.png')).sort();
    if (files.length === 0) throw new Error(`No ${device} screenshots in ${folder}`);
    const set =
      sets.find((s) => s.attributes.screenshotDisplayType === displayType) ??
      (
        await api('POST', '/v1/appScreenshotSets', {
          type: 'appScreenshotSets',
          attributes: { screenshotDisplayType: displayType },
          relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localizationId } } },
        })
      ).data;
    for (const old of (await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`)).data) {
      await api('DELETE', `/v1/appScreenshots/${old.id}`);
    }
    // Uploaded in file order, which is the order the App Store shows them in.
    for (const name of files) await upload(api, set.id, join(folder, name));
    ids.push(set.id);
  }
  return ids;
}

/** Waits until App Store Connect has processed every screenshot of [setIds]. */
async function waitForScreenshots(api, setIds) {
  let pending = setIds;
  for (let round = 0; round < 40 && pending.length; round++) {
    await new Promise((resolve) => setTimeout(resolve, 15000));
    const next = [];
    for (const id of pending) {
      const shots = (await api('GET', `/v1/appScreenshotSets/${id}/appScreenshots?limit=50`)).data;
      const failed = shots.filter((s) => s.attributes.assetDeliveryState?.state === 'FAILED');
      if (failed.length) {
        const why = failed.map((s) => `${s.attributes.fileName}: ${JSON.stringify(s.attributes.assetDeliveryState.errors)}`);
        throw new Error(`App Store Connect rejected screenshots:\n${why.join('\n')}`);
      }
      if (shots.some((s) => s.attributes.assetDeliveryState?.state !== 'COMPLETE')) next.push(id);
    }
    pending = next;
  }
  if (pending.length) console.log(`::warning::${pending.length} screenshot sets still processing; check App Store Connect`);
}

/** The app, its editable app info and the App Store version being prepared. */
export async function findApp(api) {
  const app = (await api('GET', `/v1/apps?filter[bundleId]=${bundleId}`)).data[0];
  if (!app) throw new Error(`No app with bundle id ${bundleId} in App Store Connect`);
  const info = pickEditable((await api('GET', `/v1/apps/${app.id}/appInfos`)).data);
  const version = pickEditable((await api('GET', `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=10`)).data);
  if (!info || !version) throw new Error('No App Store version in preparation: create one in App Store Connect first');
  return { app, info, version };
}

/** Writes every listing (and with [screenshots], the screenshots) to App Store Connect. */
export async function listing(api, screenshots) {
  const { info, version } = await findApp(api);
  console.log(`Version ${version.attributes.versionString}`);
  const byLocale = (body) => Object.fromEntries(body.data.map((l) => [l.attributes.locale, l]));
  const infoLocalizations = byLocale(await api('GET', `/v1/appInfos/${info.id}/appInfoLocalizations?limit=200`));
  const versionLocalizations = byLocale(
    await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`),
  );
  const setIds = [];
  for (const [code, locale] of Object.entries(appStoreLocales)) {
    const texts = appStoreTexts(JSON.parse(await readFile(new URL(`${code}.json`, listingDir), 'utf8')));
    try {
      await upsert(api, 'appInfoLocalizations', infoLocalizations[locale], locale, texts.info, {
        appInfo: { data: { type: 'appInfos', id: info.id } },
      });
    } catch (error) {
      // A locale App Store Connect does not take is skipped, not fatal.
      if (infoLocalizations[locale] || error.status !== 409) throw error;
      console.log(`::notice::App Store Connect did not take ${locale} (${code}), skipped: ${error.message}`);
      continue;
    }
    const localization = await upsert(api, 'appStoreVersionLocalizations', versionLocalizations[locale], locale, texts.version, {
      appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
    });
    console.log(`Updated ${locale}`);
    if (screenshots) {
      setIds.push(...(await replaceScreenshots(api, localization.id, screenshots, code)));
      console.log(`Replaced the screenshots of ${locale}`);
    }
  }
  if (setIds.length) await waitForScreenshots(api, setIds);
  console.log('::notice::App Store listing updated; it reaches users with the next version App Review accepts');
}

async function main() {
  const [command, arg] = process.argv.slice(2);
  if (command === 'listing') return listing(connect(process.env), arg);
  throw new Error('Usage: node tool/app_store.mjs listing [screenshots dir]');
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

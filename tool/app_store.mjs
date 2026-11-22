// App Store Connect API for the App Store workflows. No dependencies: the JWT
// is signed with node:crypto from the .p8 key.
// Usage (secrets from the `release` environment, see docs/app-store.md):
//   APPSTORE_API_KEY=... APPSTORE_KEY_ID=... APPSTORE_ISSUER_ID=... \
//     node tool/app_store.mjs listing [screenshots dir]
//     node tool/app_store.mjs review <version> [notes.json] [--dry-run]
// `listing` writes every play/listing/<code>.json to the version being prepared
// (name, subtitle, privacy URL; description, keywords, promotional text, support
// and marketing URL). With a screenshots dir (<dir>/<device>/<Play code>/*.png,
// device a key of `devices`) it also replaces each language's screenshots.
// `devices <device>` prints that device's sizes as environment lines for the workflow.
// `review` puts the TestFlight build of <version> on its App Store version,
// writes What's New from notes.json ([{language: Play code, text}], made by
// .github/play-release-notes-languages.jq) and submits it for App Review.
import { createHash, sign } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
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

// The screenshot sets, by device folder: App Store Connect's display type and
// the size app-store-listing.yml shoots (logical size times pixel ratio).
// iphone: "iPhone with Dynamic Island (medium display)", 6.1"/6.3", the one
// iPhone size App Store Connect requires (1179 x 2556 or 1206 x 2622); Apple
// scales it down for smaller phones. iphone-large: "iPhone with Dynamic Island
// (large display)", 6.7"/6.9", optional. ipad: 13" (2048 x 2732 or 2064 x 2752).
// A wrong guess is a one-line fix here.
export const devices = {
  iphone: { displayType: 'APP_IPHONE_61', size: '402x874', ratio: 3, pixels: '1206x2622' },
  'iphone-large': { displayType: 'APP_IPHONE_67', size: '430x932', ratio: 3, pixels: '1290x2796' },
  ipad: { displayType: 'APP_IPAD_PRO_3GEN_129', size: '1024x1366', ratio: 2, pixels: '2048x2732' },
};

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
      keywords: listing.keywords
        .split(',')
        .map((k) => k.trim())
        .filter(Boolean)
        .join(','),
      promotionalText: listing.shortDescription,
      marketingUrl: urls.marketingUrl,
      supportUrl: urls.supportUrl,
    },
  };
}

/** The editable item of a list, by `state`, `appVersionState` or `appStoreState`. */
export function pickEditable(items) {
  return items.find((i) =>
    editable.includes(i.attributes.state ?? i.attributes.appVersionState ?? i.attributes.appStoreState),
  );
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
export async function replaceScreenshots(api, localizationId, dir, code, locale, put = fetch) {
  const sets = (await api('GET', `/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=50`)).data;
  const existing = sets.map((s) => s.attributes.screenshotDisplayType);
  console.log(`Screenshot sets of ${locale}: ${existing.join(', ') || 'none'}`);
  const ids = [];
  for (const [device, { displayType }] of Object.entries(devices)) {
    const folder = join(dir, device, code);
    const files = (await readdir(folder).catch(() => [])).filter((n) => n.endsWith('.png')).sort();
    if (files.length === 0) throw new Error(`No ${device} screenshots in ${folder}`);
    let set = sets.find((s) => s.attributes.screenshotDisplayType === displayType);
    if (!set) {
      try {
        set = (
          await api('POST', '/v1/appScreenshotSets', {
            type: 'appScreenshotSets',
            attributes: { screenshotDisplayType: displayType },
            relationships: {
              appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localizationId } },
            },
          })
        ).data;
      } catch (error) {
        throw new Error(
          `App Store Connect refused the ${device} screenshot set ${displayType} for ${locale} (${error.message}). ` +
            `Sets this localization has: ${existing.join(', ') || 'none'}. Fix displayType in devices in tool/app_store.mjs.`,
        );
      }
    }
    for (const old of (await api('GET', `/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`)).data) {
      await api('DELETE', `/v1/appScreenshots/${old.id}`);
    }
    // Uploaded in file order, which is the order the App Store shows them in.
    for (const name of files) await upload(api, set.id, join(folder, name), put);
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
        const why = failed.map(
          (s) => `${s.attributes.fileName}: ${JSON.stringify(s.attributes.assetDeliveryState.errors)}`,
        );
        throw new Error(`App Store Connect rejected screenshots:\n${why.join('\n')}`);
      }
      if (shots.some((s) => s.attributes.assetDeliveryState?.state !== 'COMPLETE')) next.push(id);
    }
    pending = next;
  }
  if (pending.length)
    console.log(`::warning::${pending.length} screenshot sets still processing; check App Store Connect`);
}

/** The app record of [bundleId]. */
async function appRecord(api) {
  const app = (await api('GET', `/v1/apps?filter[bundleId]=${bundleId}`)).data[0];
  if (!app) throw new Error(`No app with bundle id ${bundleId} in App Store Connect`);
  return app;
}

/** The app, its editable app info and the App Store version being prepared. */
export async function findApp(api) {
  const app = await appRecord(api);
  const info = pickEditable((await api('GET', `/v1/apps/${app.id}/appInfos`)).data);
  const version = pickEditable(
    (await api('GET', `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=10`)).data,
  );
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
    const updateVersion = (existing) =>
      upsert(api, 'appStoreVersionLocalizations', existing, locale, texts.version, {
        appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
      });
    let localization;
    try {
      localization = await updateVersion(versionLocalizations[locale]);
    } catch (error) {
      if (versionLocalizations[locale] || error.status !== 409) throw error;
      // Creating the app info localization can add the version localization too, so
      // the list read at the start misses it: read it again and update it.
      const fresh = byLocale(
        await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`),
      );
      if (!fresh[locale]) throw error;
      localization = await updateVersion(fresh[locale]);
    }
    console.log(`Updated ${locale}`);
    if (screenshots) {
      setIds.push(...(await replaceScreenshots(api, localization.id, screenshots, code, locale)));
      console.log(`Replaced the screenshots of ${locale}`);
    }
  }
  if (setIds.length) await waitForScreenshots(api, setIds);
  console.log('::notice::App Store listing updated; it reaches users with the next version App Review accepts');
}

/** What's New for an App Store [locale] from release notes [{language: Play code, text}]; English otherwise. */
export function whatsNewFor(notes, locale) {
  const byLocale = Object.fromEntries(notes.map((n) => [appStoreLocales[n.language], n.text]));
  return byLocale[locale] ?? byLocale['en-US'];
}

/**
 * Puts the TestFlight build of [versionString] on its App Store version, writes
 * What's New from [notes] and submits the version for App Review. [dryRun] only
 * reads and prints what it would do.
 */
export async function review(api, versionString, notes, dryRun) {
  const act = async (what, write) => {
    console.log(`${dryRun ? 'Would ' : ''}${what}`);
    return dryRun ? undefined : write();
  };
  const app = await appRecord(api);
  const build = (
    await api(
      'GET',
      `/v1/builds?filter[app]=${app.id}&filter[preReleaseVersion.version]=${versionString}` +
        '&filter[processingState]=VALID&filter[expired]=false&sort=-uploadedDate&limit=1',
    )
  ).data[0];
  if (!build)
    throw new Error(
      `No processed build of ${versionString} in TestFlight: push tag v${versionString}, then wait for processing`,
    );

  const versions = (await api('GET', `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=50`)).data;
  const open = pickEditable(versions);
  let version = versions.find((v) => v.attributes.versionString === versionString);
  if (version && version !== open) {
    const state = version.attributes.appVersionState ?? version.attributes.appStoreState;
    throw new Error(`Version ${versionString} is ${state} in App Store Connect; there is nothing to submit`);
  }
  if (!version && open) {
    // App Store Connect keeps one version in preparation; it takes the new number.
    await act(`rename version ${open.attributes.versionString} to ${versionString}`, () =>
      api('PATCH', `/v1/appStoreVersions/${open.id}`, {
        type: 'appStoreVersions',
        id: open.id,
        attributes: { versionString },
      }),
    );
    version = open;
  }
  if (!version) {
    version = await act(
      `create version ${versionString}`,
      async () =>
        (
          await api('POST', '/v1/appStoreVersions', {
            type: 'appStoreVersions',
            attributes: { platform: 'IOS', versionString },
            relationships: { app: { data: { type: 'apps', id: app.id } } },
          })
        ).data,
    );
  }
  await act(`attach build ${build.attributes.version} to version ${versionString}`, () =>
    api('PATCH', `/v1/appStoreVersions/${version.id}/relationships/build`, { type: 'builds', id: build.id }),
  );

  // The first version of an app has no What's New.
  if (!versions.some((v) => v.id !== version?.id)) {
    console.log("::notice::First App Store version: no What's New");
  } else if (!version) {
    console.log("Would set What's New in every language of the new version");
  } else {
    const localizations = (
      await api('GET', `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`)
    ).data;
    for (const l of localizations) {
      const whatsNew = whatsNewFor(notes, l.attributes.locale);
      await act(`set What's New of ${l.attributes.locale}: ${JSON.stringify(whatsNew)}`, () =>
        api('PATCH', `/v1/appStoreVersionLocalizations/${l.id}`, {
          type: 'appStoreVersionLocalizations',
          id: l.id,
          attributes: { whatsNew },
        }),
      );
    }
  }

  // A draft submission (READY_FOR_REVIEW) is reused; App Store Connect allows one.
  const draft = (
    await api('GET', `/v1/reviewSubmissions?filter[app]=${app.id}&filter[platform]=IOS&filter[state]=READY_FOR_REVIEW`)
  ).data[0];
  await act(`submit version ${versionString} (build ${build.attributes.version}) for App Review`, async () => {
    const submission =
      draft ??
      (
        await api('POST', '/v1/reviewSubmissions', {
          type: 'reviewSubmissions',
          attributes: { platform: 'IOS' },
          relationships: { app: { data: { type: 'apps', id: app.id } } },
        })
      ).data;
    const items = draft ? (await api('GET', `/v1/reviewSubmissions/${draft.id}/items?limit=50`)).data : [];
    if (!items.some((i) => i.relationships?.appStoreVersion?.data?.id === version.id)) {
      await api('POST', '/v1/reviewSubmissionItems', {
        type: 'reviewSubmissionItems',
        relationships: {
          reviewSubmission: { data: { type: 'reviewSubmissions', id: submission.id } },
          appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
        },
      });
    }
    await api('PATCH', `/v1/reviewSubmissions/${submission.id}`, {
      type: 'reviewSubmissions',
      id: submission.id,
      attributes: { submitted: true },
    });
  });
  if (!dryRun)
    console.log(`::notice::Version ${versionString} (build ${build.attributes.version}) is submitted for App Review`);
}

async function main() {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'listing') return listing(connect(process.env), args[0]);
  if (command === 'devices' && devices[args[0]]) {
    const { size, ratio, pixels } = devices[args[0]];
    return console.log(`SCREENSHOT_SIZE=${size}\nSCREENSHOT_PIXEL_RATIO=${ratio}\nSCREENSHOT_PIXELS=${pixels}`);
  }
  if (command === 'review' && args[0]) {
    const [notesFile] = args.slice(1).filter((a) => a !== '--dry-run');
    const notes = notesFile ? JSON.parse(await readFile(notesFile, 'utf8')) : [];
    return review(connect(process.env), args[0], notes, args.includes('--dry-run'));
  }
  throw new Error(
    'Usage: node tool/app_store.mjs listing [screenshots dir] | devices <device> | review <version> [notes.json] [--dry-run]',
  );
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

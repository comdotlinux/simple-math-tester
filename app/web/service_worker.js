'use strict';

// CI replaces this line in the built copy with the first 8 characters of the
// sha256 of precache_manifest.json, so every build installs a new worker.
const BUILD = 'dev';
const CACHE = `app-${BUILD}`;
const MANIFEST = 'precache_manifest.json';
const NEVER_CACHED = new Set(['_headers', '_redirects', 'service_worker.js']);
const NETWORK_TIMEOUT_MS = 4000;

const scopePath = new URL(self.registration.scope).pathname;
// The page is cached as "./" because the host redirects index.html there.
const cacheKey = (url) => (url === 'index.html' ? './' : url);

// Each cache is a snapshot of one build, filled completely at install and
// never changed afterwards, so an offline start always gets matching files.
self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      try {
        // A missing manifest (development and flutter drive servers) fails the install.
        const manifest = await download(MANIFEST);
        const { entries } = await manifest.clone().json();
        // skwasm and its wimp variant are only loaded by --wasm builds.
        const wasm = entries.some((e) => /^main\.dart\..*wasm$/.test(e.url));
        const previous = await previousBuild();
        const cache = await caches.open(CACHE);
        await Promise.all(
          entries
            .filter((e) => !NEVER_CACHED.has(e.url))
            .filter((e) => wasm || !/^canvaskit\/(skwasm|wimp)/.test(e.url))
            .map(async (e) => {
              const key = cacheKey(e.url);
              // Only a hashed name guarantees unchanged content.
              const unchanged =
                e.urlHashed &&
                previous?.hashes.get(e.url) === e.hash &&
                (await previous.cache.match(key));
              await cache.put(key, unchanged || (await download(key)));
            }),
        );
        // Stored last: its presence marks this cache complete for the next install.
        await cache.put(MANIFEST, manifest);
      } catch (error) {
        // All or nothing: the previous worker and its cache stay in charge.
        await caches.delete(CACHE);
        throw error;
      }
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const name of await caches.keys()) {
        if (name.startsWith('app-') && name !== CACHE) await caches.delete(name);
      }
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  if (
    request.method !== 'GET' ||
    request.headers.has('range') ||
    url.origin !== self.location.origin ||
    url.pathname.startsWith('/api/')
  ) {
    return;
  }
  const path = url.pathname.slice(scopePath.length);
  if (request.mode === 'navigate') {
    // The static pages fall back to their own cached copy (the Impressum shell
    // then shows its error line); every other address gets the app.
    const page = /^(impressum|privacy)(\.html)?$/.exec(path)?.[1];
    event.respondWith(networkFirst(request, page ? `${page}.html` : './'));
    return;
  }
  event.respondWith(
    (async () => {
      const entry = (await manifestEntries()).get(path);
      if (!entry) return fetch(request);
      if (entry.urlHashed) return (await cached(path)) || fetch(request);
      return networkFirst(request, cacheKey(path));
    })(),
  );
});

// The network answer, or the snapshot's when the network fails or hangs.
async function networkFirst(request, key) {
  const network = fetch(request);
  const fallback = await cached(key);
  if (!fallback) return network;
  network.catch(() => {});
  const timeout = new Promise((resolve) => setTimeout(resolve, NETWORK_TIMEOUT_MS, fallback));
  try {
    return await Promise.race([network, timeout]);
  } catch {
    return fallback;
  }
}

// Does not create the cache, unlike caches.open().
function cached(key) {
  return caches.match(key, { cacheName: CACHE });
}

let entriesByUrl;
async function manifestEntries() {
  if (entriesByUrl) return entriesByUrl;
  const response = await cached(MANIFEST);
  if (!response) return new Map();
  entriesByUrl = new Map((await response.json()).entries.map((e) => [e.url, e]));
  return entriesByUrl;
}

async function previousBuild() {
  for (const name of await caches.keys()) {
    if (!name.startsWith('app-') || name === CACHE) continue;
    const cache = await caches.open(name);
    const response = await cache.match(MANIFEST);
    if (!response) continue;
    const { entries } = await response.json();
    return { cache, hashes: new Map(entries.map((e) => [e.url, e.hash])) };
  }
  return null;
}

async function download(url) {
  const response = await fetch(url, { cache: 'no-cache' });
  if (response.status !== 200 || response.type !== 'basic') {
    throw new Error(`${url}: HTTP ${response.status} ${response.type}`);
  }
  return rebuilt(response);
}

// A redirected response cannot answer a navigation, so it is stored as a new one.
async function rebuilt(response) {
  if (!response.redirected) return response;
  const { status, statusText, headers } = response;
  return new Response(await response.blob(), { status, statusText, headers });
}

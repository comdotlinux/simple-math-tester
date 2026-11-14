'use strict';

// CI replaces this line in the built copy with the first 8 characters of the
// sha256 of precache_manifest.json, so every build installs a new worker.
const BUILD = 'dev';
const CACHE = `app-${BUILD}`;
const MANIFEST = 'precache_manifest.json';
const NEVER_CACHED = new Set(['_headers', '_redirects', 'service_worker.js']);

const scopePath = new URL(self.registration.scope).pathname;
// The page is cached as "./" because the host redirects index.html there.
const cacheKey = (url) => (url === 'index.html' ? './' : url);

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      // A missing manifest (development and flutter drive servers) fails the install.
      const response = await fetch(MANIFEST, { cache: 'no-cache' });
      if (!response.ok) throw new Error(`${MANIFEST}: HTTP ${response.status}`);
      const { entries } = await response.clone().json();
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
            const unchanged =
              previous?.hashes.get(e.url) === e.hash &&
              (await previous.cache.match(key));
            await cache.put(key, unchanged || (await download(key)));
          }),
      );
      // Stored last: its presence marks this cache complete for the next install.
      await cache.put(MANIFEST, response);
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
    url.origin !== self.location.origin ||
    url.pathname.startsWith('/api/')
  ) {
    return;
  }
  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, './', false));
    return;
  }
  const path = url.pathname.slice(scopePath.length);
  event.respondWith(
    (async () => {
      const entry = (await manifestEntries()).get(path);
      if (!entry) return fetch(request);
      if (entry.urlHashed) {
        return (await (await caches.open(CACHE)).match(path)) || fetch(request);
      }
      return networkFirst(request, cacheKey(path), true);
    })(),
  );
});

async function networkFirst(request, key, writeBack) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request);
    if (writeBack && response.ok) await cache.put(key, await rebuilt(response.clone()));
    return response;
  } catch (error) {
    const cached = await cache.match(key);
    if (cached) return cached;
    throw error;
  }
}

let entriesByUrl;
function manifestEntries() {
  entriesByUrl ??= (async () => {
    const response = await (await caches.open(CACHE)).match(MANIFEST);
    const entries = response ? (await response.json()).entries : [];
    return new Map(entries.map((e) => [e.url, e]));
  })();
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
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return rebuilt(response);
}

// A redirected response cannot answer a navigation, so it is stored as a new one.
async function rebuilt(response) {
  if (!response.redirected) return response;
  const { status, statusText, headers } = response;
  return new Response(await response.blob(), { status, statusText, headers });
}

// Offline check of the release web build in Chrome (plan phase 10, criteria
// 55(b), 56 and 57). Both builds must already carry their service worker stamp.
// Usage: node tool/browser_check.mjs <build dir> <same app built with --build-number=2>
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const [firstBuild, secondBuild] = process.argv.slice(2);
const port = 8790;
const origin = `http://localhost:${port}`;
const serverScript = fileURLToPath(new URL('pages_like_server.mjs', import.meta.url));

// Saved progress as SharedPreferencesAsync writes it on web: the raw key, and
// the document string JSON-encoded once more.
const progressKey = 'progress';
const seededDocument = {
  schemaVersion: 1,
  selectedOperations: ['multiply'],
  history: [3, 4, 5].map((lhs) => ({
    lhs,
    rhs: 6,
    kind: 'multiply',
    result: lhs * 6,
    level: 1,
    firstAnswer: lhs * 6,
    elapsedMs: 1500,
    hintsUsed: 0,
    answeredAt: '2026-11-13T17:00:00.000Z',
    sprint: false,
  })),
};

async function serve(dir) {
  const server = spawn(process.execPath, [serverScript, dir, String(port)], {
    stdio: ['ignore', 'pipe', 'inherit'],
  });
  await once(server.stdout, 'data');
  return async () => {
    if (server.exitCode !== null || server.signalCode !== null) return;
    server.kill();
    await once(server, 'exit');
  };
}

async function openApp(page, path) {
  await page.goto(origin + path);
  // Flutter builds its accessibility tree, which the assertions read, only on request.
  await page.locator('flt-semantics-placeholder').evaluate((el) => el.click());
  await page.getByRole('tab', { name: 'Practice' }).waitFor();
}

async function expectHistory(page, count) {
  await page.getByRole('tab', { name: 'My answers' }).click();
  await page.getByText(`${count} questions completed.`, { exact: true }).waitFor();
  // Each answer row is one semantics node holding all of its lines.
  await page.getByText('3 × 6 Correct Your answer: 18').waitFor();
}

function savedHistoryLength(page) {
  return page.evaluate(
    (key) => JSON.parse(JSON.parse(localStorage.getItem(key))).history.length,
    progressKey,
  );
}

function appCaches(page) {
  return page.evaluate(async () =>
    (await caches.keys()).filter((name) => name.startsWith('app-')),
  );
}

async function expectedCache(dir) {
  const worker = await readFile(`${dir}/service_worker.js`, 'utf8');
  return `app-${worker.match(/^const BUILD = '(\w+)';$/m)[1]}`;
}

function check(condition, message) {
  if (!condition) throw new Error(message);
  console.log(`ok: ${message}`);
}

const browser = await chromium.launch({ channel: 'chrome' });
let stopServer = async () => {};
try {
  let context;
  let page;
  for (const start of ['/', '/index.html']) {
    context = await browser.newContext();
    context.setDefaultTimeout(60_000);
    page = await context.newPage();
    stopServer = await serve(firstBuild);

    await page.goto(`${origin}/version.json`);
    await page.evaluate(
      ([key, value]) => localStorage.setItem(key, value),
      [progressKey, JSON.stringify(JSON.stringify(seededDocument))],
    );

    const requests = [];
    context.on('request', (request) => requests.push(request.url()));
    await openApp(page, start);
    await page.getByRole('tab', { name: 'Practice' }).click();
    await page.getByRole('textbox').fill('7');
    await page.getByRole('button', { name: 'Check answer' }).click();
    await page.waitForFunction(
      (key) => JSON.parse(JSON.parse(localStorage.getItem(key))).history.length === 4,
      progressKey,
    );
    await expectHistory(page, 4);
    const foreign = requests.filter((url) => new URL(url).origin !== origin);
    check(
      requests.length > 0 && foreign.length === 0,
      `start ${start}: all ${requests.length} requests went to ${origin}` +
        (foreign.length ? `; others: ${foreign.join(', ')}` : ''),
    );

    await page.waitForFunction(() => navigator.serviceWorker.controller?.state === 'activated');
    await stopServer();
    await openApp(page, start);
    await expectHistory(page, 4);
    check((await savedHistoryLength(page)) === 4, `start ${start}: offline reload shows the saved history`);
    if (start === '/index.html') break;
    await context.close();
  }

  // A new deploy is picked up online, then still works offline.
  stopServer = await serve(secondBuild);
  const secondCache = await expectedCache(secondBuild);
  await openApp(page, '/');
  // The online load finds the new worker; wait until it has replaced the old cache.
  for (let i = 0; (await appCaches(page)).join() !== secondCache; i++) {
    if (i === 120) throw new Error(`caches never became ${secondCache}`);
    await page.waitForTimeout(500);
  }
  await openApp(page, '/');
  const version = await page.evaluate(() =>
    fetch('version.json', { cache: 'no-store' }).then((r) => r.json()),
  );
  check(version.build_number === '2', 'version.json shows build number 2');
  const names = await appCaches(page);
  check(names.length === 1 && names[0] === secondCache, `exactly one cache remains: ${names}`);

  await stopServer();
  await openApp(page, '/');
  await expectHistory(page, 4);
  check(true, 'offline reload after the update renders the app');
} finally {
  await stopServer();
  await browser.close();
}

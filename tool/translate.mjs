// Translates new and changed strings of app/lib/l10n/app_en.arb into every
// language below with DeepSeek, and writes the ARB files.
// Usage: DEEPSEEK_API_KEY=... node tool/translate.mjs [--dry-run]
// DEEPSEEK_MODEL picks the model (default deepseek-flash). --dry-run only
// lists what would be translated and needs no key.
//
// To add a language: add its code here and run the Translate workflow. A
// new script also needs a bundled font (see docs/translations.md).
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export const languages = ['de', 'pl', 'hi', 'mr', 'te', 'ta', 'ml', 'fr', 'ro'];

const dir = new URL('../app/lib/l10n/', import.meta.url);
// The English text each translation was made from, as a short hash per key,
// so a changed English string is translated again.
const sourcesFile = new URL('translation_sources.json', dir);
const endpoint = 'https://api.deepseek.com/chat/completions';

export const hash = (text) => createHash('sha256').update(text).digest('hex').slice(0, 12);

/** The argument names of an ICU message: {name} and {name, plural, ...}. */
export function placeholders(message) {
  return [...new Set([...message.matchAll(/\{(\w+)\s*[,}]/g)].map((m) => m[1]))].sort();
}

/** Why [translation] cannot replace [source], or null when it can. */
export function problem(source, translation) {
  if (typeof translation !== 'string' || translation.trim() === '') return 'empty';
  let depth = 0;
  for (const c of translation) {
    depth += c === '{' ? 1 : c === '}' ? -1 : 0;
    if (depth < 0) break;
  }
  if (depth !== 0) return 'unbalanced braces';
  const want = placeholders(source).join();
  const got = placeholders(translation).join();
  if (want !== got) return `placeholders ${got || 'none'} instead of ${want}`;
  if (/plural,/.test(source) && !/\bother\s*\{/.test(translation)) return 'plural without other';
  // Digits stay Western (0-9) in every language.
  if (/(?![0-9])\p{Nd}/u.test(translation)) return 'non-Western digits';
  return null;
}

/** The keys of [language] whose translation is missing or out of date. */
export function stale(template, arb, sources) {
  return Object.keys(template).filter(
    (key) => !key.startsWith('@') && (!(key in arb) || sources[key] !== hash(template[key])),
  );
}

export const languageName = (code) => new Intl.DisplayNames(['en'], { type: 'language' }).of(code);

export async function readJson(url, fallback) {
  try {
    return JSON.parse(await readFile(url, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return fallback;
    throw error;
  }
}

async function ask(model, key, template, arb, language, keys) {
  const request = Object.fromEntries(
    keys.map((k) => [k, { text: template[k], description: template[`@${k}`]?.description ?? '' }]),
  );
  const existing = Object.fromEntries(
    Object.entries(arb).filter(([k]) => !k.startsWith('@') && !keys.includes(k)),
  );
  const system = [
    `You translate the user interface of a free arithmetic practice app for children aged about 6 to 12 from English into ${languageName(language)} (${language}).`,
    'Use friendly, simple, natural everyday words a school child understands, and the informal "you". Button labels must stay short: the app runs on 360 px wide phones.',
    'Messages use ICU syntax. Keep every {placeholder} name exactly; never translate, add or drop one. Keep plural/select structure; inside a plural, add the CLDR categories the language needs (e.g. few, many) and keep "other".',
    'Numbers and math symbols (+ − × ÷ = ?) stay as given; digits are always Western 0-9.',
    'Keep these words unchanged: Impressum, XP, GitHub, Cloudflare, Cloudflare Pages, Cloudflare Turnstile, Google Play, Android, iOS.',
    'Answer with one JSON object that maps each requested key to its translated message string, nothing else.',
  ].join('\n');
  const user = JSON.stringify({
    translate: request,
    existingTranslationsForConsistency: existing,
  });
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model,
      thinking: { type: 'disabled' },
      response_format: { type: 'json_object' },
      temperature: 0.2,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
    }),
  });
  if (!response.ok) {
    throw new Error(`DeepSeek answered ${response.status}: ${(await response.text()).slice(0, 500)}`);
  }
  const body = await response.json();
  return JSON.parse(body.choices[0].message.content);
}

/** The ARB in template order, locale first, without keys the template lost. */
function ordered(template, arb, language) {
  const out = { '@@locale': language };
  for (const key of Object.keys(template)) {
    if (!key.startsWith('@') && key in arb) out[key] = arb[key];
  }
  return out;
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const key = process.env.DEEPSEEK_API_KEY;
  const model = process.env.DEEPSEEK_MODEL || 'deepseek-flash';
  if (!dryRun && !key) throw new Error('DEEPSEEK_API_KEY is not set');

  const template = JSON.parse(await readFile(new URL('app_en.arb', dir), 'utf8'));
  const sources = await readJson(sourcesFile, {});
  let failures = 0;
  for (const language of languages) {
    const file = new URL(`app_${language}.arb`, dir);
    const arb = await readJson(file, {});
    sources[language] ??= {};
    let keys = stale(template, arb, sources[language]);
    console.log(`${language}: ${keys.length} to translate${keys.length ? `: ${keys.join(', ')}` : ''}`);
    if (dryRun || keys.length === 0) continue;

    // One retry for answers that fail the checks.
    for (let attempt = 1; attempt <= 2 && keys.length > 0; attempt++) {
      const answer = await ask(model, key, template, arb, language, keys);
      const rejected = [];
      for (const k of keys) {
        const why = problem(template[k], answer[k]);
        if (why) {
          rejected.push(k);
          console.log(`${language}: ${k} rejected (attempt ${attempt}): ${why}`);
        } else {
          arb[k] = answer[k];
          sources[language][k] = hash(template[k]);
        }
      }
      keys = rejected;
    }
    failures += keys.length;
    // Hashes of keys the template no longer has are dropped.
    sources[language] = Object.fromEntries(
      Object.entries(sources[language]).filter(([k]) => k in template),
    );
    await writeFile(file, `${JSON.stringify(ordered(template, arb, language), null, 2)}\n`);
  }
  if (!dryRun) {
    const sorted = Object.fromEntries(languages.map((l) => [l, sources[l]]));
    await writeFile(sourcesFile, `${JSON.stringify(sorted, null, 2)}\n`);
  }
  if (failures > 0) throw new Error(`${failures} strings could not be translated; see above`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

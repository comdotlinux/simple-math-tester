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

export const languages = ['de', 'pl', 'hi', 'mr', 'te', 'ta', 'ml', 'fr', 'ro', 'uk'];

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

// One request translates at most this many keys or English characters, so the
// answer stays far below max_tokens (a whole new language once came back empty).
export const batchKeys = 40;
export const batchChars = 3000;
// Existing translations sent along for consistent wording, at most this many characters.
const contextChars = 3000;
export const maxTokens = 8192;

/** [keys] split into batches of at most [maxKeys] keys and about [maxChars] English characters. */
export function batches(template, keys, maxKeys = batchKeys, maxChars = batchChars) {
  const out = [];
  let chars = 0;
  for (const k of keys) {
    const last = out.at(-1);
    if (!last || last.length >= maxKeys || chars + template[k].length > maxChars) {
      out.push([k]);
      chars = template[k].length;
    } else {
      last.push(k);
      chars += template[k].length;
    }
  }
  return out;
}

/** The translations object in a chat completion [body], or an Error saying why there is none. */
export function parseAnswer(body, keys) {
  const choice = body?.choices?.[0];
  if (choice?.finish_reason === 'length') return new Error('cut off (finish_reason length)');
  let answer;
  try {
    answer = JSON.parse(choice?.message?.content ?? '');
  } catch {
    return new Error(`unparseable JSON (finish_reason ${choice?.finish_reason})`);
  }
  if (typeof answer !== 'object' || answer === null) return new Error('answer is not a JSON object');
  // The model sometimes wraps the answer, e.g. in {"translate": {...}}.
  const values = Object.values(answer);
  if (!keys.some((k) => k in answer) && values.length === 1 && typeof values[0] === 'object') {
    answer = values[0] ?? {};
  }
  if (!keys.some((k) => k in answer)) {
    return new Error(`none of the requested keys in the answer (got: ${Object.keys(answer).slice(0, 5).join(', ') || 'nothing'})`);
  }
  return answer;
}

async function ask(model, key, template, arb, language, keys) {
  const request = Object.fromEntries(
    keys.map((k) => [k, { text: template[k], description: template[`@${k}`]?.description ?? '' }]),
  );
  const existing = {};
  let chars = 0;
  for (const [k, v] of Object.entries(arb)) {
    if (k.startsWith('@') || keys.includes(k) || chars + v.length > contextChars) continue;
    existing[k] = v;
    chars += v.length;
  }
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
      max_tokens: maxTokens,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
    }),
  });
  if (!response.ok) {
    throw new Error(`DeepSeek answered ${response.status}: ${(await response.text()).slice(0, 500)}`);
  }
  const answer = parseAnswer(await response.json(), keys);
  if (answer instanceof Error) throw answer;
  return answer;
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
    const all = stale(template, arb, sources[language]);
    console.log(`${language}: ${all.length} to translate${all.length ? `: ${all.join(', ')}` : ''}`);
    if (dryRun || all.length === 0) continue;

    const parts = batches(template, all);
    for (const [i, batch] of parts.entries()) {
      const name = `${language}: batch ${i + 1}/${parts.length}`;
      let keys = batch;
      // One retry for answers that fail the checks or do not arrive.
      for (let attempt = 1; attempt <= 2 && keys.length > 0; attempt++) {
        let answer;
        try {
          answer = await ask(model, key, template, arb, language, keys);
        } catch (error) {
          console.log(`${name} failed (attempt ${attempt}): ${error.message}`);
          continue;
        }
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
    }
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

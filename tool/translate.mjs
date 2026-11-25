// Translates new and changed strings of app/lib/l10n/app_en.arb into every
// language below with DeepSeek, and writes the ARB files.
// Usage: DEEPSEEK_API_KEY=... node tool/translate.mjs [--dry-run]
// DEEPSEEK_MODEL picks the model (default deepseek-flash). --dry-run only
// lists what would be translated and needs no key.
// Exits 2 when some strings could not be translated (the others are written),
// and lists them, per language, also in the file FAILED_KEYS_FILE if set.
//
// To add a language: add its code here and run the Translate workflow. A
// new script also needs a bundled font (see docs/translations.md).
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// An ARB locale: a language code, with _COUNTRY for a regional variant (pt is
// Brazilian Portuguese, pt_PT European).
export const languages = [
  'de',
  'pl',
  'hi',
  'mr',
  'te',
  'ta',
  'ml',
  'fr',
  'ro',
  'uk',
  'pt',
  'pt_PT',
  'pa',
  'tr',
  'gu',
  'bn',
  'ar',
  'ur',
];

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

/**
 * The Western digits of [message] outside {placeholders}, sorted: those of the
 * text outside a plural/select, then, in braces, those of each distinct
 * branch. In an "=1{1 second}" branch the 1 stands for the argument, so it
 * counts as {count}: a language may write "one{{count} ...}" instead.
 */
export function digits(message) {
  const sorted = (text) => (text.match(/[0-9]/g) ?? []).sort().join('');
  // shortcut: one plural/select level, as in every message so far; a nested plural needs a real ICU parser.
  let rest = message.replace(/\{\w+\}/g, '');
  const branches = new Set();
  rest = rest.replace(/(=(\d+)|\w+)\s*\{([^{}]*)\}/g, (_, _selector, value, text) => {
    branches.add(sorted(value ? text.replace(new RegExp(`(?<![0-9])${value}(?![0-9])`, 'g'), '') : text));
    return '';
  });
  const outside = sorted(rest.replace(/\{\w+\s*,\s*\w+\s*,/g, ''));
  return branches.size ? `${outside}{${[...branches].sort().join('|')}}` : outside;
}

/** Why [translation] cannot replace [source], or null when it can. */
export function problem(source, translation) {
  if (typeof translation !== 'string') return `not a string: ${JSON.stringify(translation)?.slice(0, 80)}`;
  if (translation.trim() === '') return 'empty';
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
  // gen-l10n accepts only =0, =1 and =2 as exact plural cases.
  const exact = translation.match(/=(?![012]\s*\{)\d+\s*\{/);
  if (exact) return `plural case ${exact[0].replace(/\s*\{$/, '')} (only =0, =1, =2)`;
  // Digits stay Western (0-9) in every language.
  if (/(?![0-9])\p{Nd}/u.test(translation)) return 'non-Western digits';
  // No number may be changed, added or dropped.
  if (digits(translation) !== digits(source)) {
    return `digits ${digits(translation) || 'none'} instead of ${digits(source) || 'none'}`;
  }
  return null;
}

/** The keys of [language] whose translation is missing or out of date. */
export function stale(template, arb, sources) {
  return Object.keys(template).filter(
    (key) => !key.startsWith('@') && (!(key in arb) || sources[key] !== hash(template[key])),
  );
}

// Spelled out where the plain language name leaves the variant or script open.
const promptNames = {
  pt: 'Brazilian Portuguese (Brazil)',
  pt_PT: 'European Portuguese (Portugal)',
  pa: 'Punjabi in Gurmukhi script',
  gu: 'Gujarati',
  bn: 'Bengali (Bangla)',
  ar: 'Arabic (Modern Standard Arabic)',
  ur: 'Urdu',
};

/** The English name of [code] that DeepSeek is told to translate into. */
export const languageName = (code) => promptNames[code] ?? new Intl.DisplayNames(['en'], { type: 'language' }).of(code);

/** [text] with every decimal digit of any script turned into Western 0-9. */
export function westernDigits(text) {
  if (typeof text !== 'string') return text;
  return text.replace(/(?![0-9])\p{Nd}/gu, (digit) => {
    // Digits come in runs of ten from zero (some runs follow each other, such
    // as the mathematical digits), so the value is the distance from the run's start, mod 10.
    let start = digit.codePointAt(0);
    while (/\p{Nd}/u.test(String.fromCodePoint(start - 1))) start--;
    return String((digit.codePointAt(0) - start) % 10);
  });
}

export async function readJson(url, fallback) {
  try {
    return JSON.parse(await readFile(url, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return fallback;
    throw error;
  }
}

// A first request translates at most this many keys or English characters.
// A batch that fails is sent again as fallback batches of the smaller size,
// each with up to [fallbackAttempts] attempts.
export const batchKeys = 60;
export const batchChars = 4500;
export const fallbackKeys = 20;
export const fallbackChars = 1500;
export const fallbackAttempts = 3;
// Existing translations sent along for consistent wording, at most this many characters.
const contextChars = 3000;
// Far above a batch's answer, so an answer is not cut off (DeepSeek allows up to 393216).
export const maxTokens = 32768;

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
  // The model sometimes wraps the answer, e.g. in {"translate": {...}}, or echoes the
  // whole request with the translations under "translate".
  if (!keys.some((k) => k in answer)) {
    // "translate" first: an echoed "notes" object has the same keys.
    const { translate, notes: _notes, existingTranslationsForConsistency: _existing, ...rest } = answer;
    const inner = [translate, ...Object.values(rest)].find(
      (v) => typeof v === 'object' && v !== null && keys.some((k) => k in v),
    );
    if (inner) answer = inner;
  }
  if (!keys.some((k) => k in answer)) {
    return new Error(
      `none of the requested keys in the answer (got: ${Object.keys(answer).slice(0, 5).join(', ') || 'nothing'})`,
    );
  }
  return answer;
}

async function ask(model, key, template, arb, language, keys) {
  // Plain strings: sent as {text, description} objects, the model sometimes answered with objects too.
  const request = Object.fromEntries(keys.map((k) => [k, template[k]]));
  const notes = Object.fromEntries(keys.map((k) => [k, template[`@${k}`]?.description ?? '']));
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
    'Numbers and math symbols (+ − × ÷ = ?) stay as given; digits are always Western 0-9. Never change, add or drop a number.',
    // A glossary of terms, not of translations: the standard school word is the model's to pick.
    'These are school mathematics terms: perimeter, area, angle, side, triangle, rectangle, square, circle, equation, blank (the empty box in an equation). Translate each with the standard term schools in the target language use, and always the same way.',
    'Keep these words unchanged: Impressum, XP, GitHub, Cloudflare, Cloudflare Pages, Cloudflare Turnstile, Google Play, Android, iOS.',
    'The notes say where each string is shown and how; use them, but do not translate them.',
    'Answer with one JSON object that maps each requested key to its translated message string, nothing else.',
  ].join('\n');
  const user = JSON.stringify({
    translate: request,
    notes,
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

/**
 * Sends [keys] with [request] (keys => answer, or throws) up to [attempts]
 * times; after a rejected or missing string only those keys are sent again.
 * Returns the accepted strings and the keys that still failed.
 */
async function attempt(name, template, keys, request, attempts, log) {
  const accepted = {};
  for (let n = 1; n <= attempts && keys.length > 0; n++) {
    let answer;
    try {
      answer = await request(keys);
    } catch (error) {
      log(`${name} failed (attempt ${n}/${attempts}, ${keys.length} keys): ${error.message}`);
      continue;
    }
    const rejected = [];
    for (const k of keys) {
      // An answer that mirrors a {text: ...} object still counts.
      const text = westernDigits(answer[k]?.text ?? answer[k]);
      const why = k in answer ? problem(template[k], text) : 'missing';
      if (why) {
        rejected.push(k);
        log(`${name}: ${k} rejected (attempt ${n}/${attempts}): ${why}`);
      } else {
        accepted[k] = text;
      }
    }
    keys = rejected;
  }
  return { accepted, failed: keys };
}

/**
 * Translates [keys] with [request] in one attempt. Keys that fail (any error,
 * or rejected and missing strings) are sent again in batches of [fallbackKeys]
 * with up to [fallbackAttempts] attempts each. Returns the accepted strings
 * and the keys that failed every attempt.
 */
export async function translateBatch(name, template, keys, request, log = console.log) {
  const first = await attempt(name, template, keys, request, 1, log);
  const accepted = { ...first.accepted };
  const failed = [];
  const parts = batches(template, first.failed, fallbackKeys, fallbackChars);
  for (const [i, part] of parts.entries()) {
    const fallbackName = `${name} fallback ${i + 1}/${parts.length}`;
    const result = await attempt(fallbackName, template, part, request, fallbackAttempts, log);
    Object.assign(accepted, result.accepted);
    failed.push(...result.failed);
  }
  return { accepted, failed };
}

/**
 * The ARB in template order, locale first, without keys the template lost.
 * A key never translated gets the English text: it has no hash, so it stays
 * stale and is retried, and the app still finds every key.
 */
export function ordered(template, arb, language) {
  const out = { '@@locale': language };
  for (const key of Object.keys(template)) {
    if (!key.startsWith('@')) out[key] = key in arb ? arb[key] : template[key];
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
  const failed = {};
  let translated = 0;
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
      const result = await translateBatch(name, template, batch, (keys) =>
        ask(model, key, template, arb, language, keys),
      );
      for (const [k, text] of Object.entries(result.accepted)) {
        arb[k] = text;
        sources[language][k] = hash(template[k]);
        translated++;
      }
      if (result.failed.length) {
        failed[language] ??= [];
        failed[language].push(...result.failed);
      }
    }
    // Hashes of keys the template no longer has are dropped.
    sources[language] = Object.fromEntries(Object.entries(sources[language]).filter(([k]) => k in template));
    await writeFile(file, `${JSON.stringify(ordered(template, arb, language), null, 2)}\n`);
  }
  if (!dryRun) {
    const sorted = Object.fromEntries(languages.map((l) => [l, sources[l]]));
    await writeFile(sourcesFile, `${JSON.stringify(sorted, null, 2)}\n`);
  }
  process.exitCode = await reportFailures(failed, translated, process.env.FAILED_KEYS_FILE);
}

/**
 * Lists the keys that failed every attempt, per language ({language: keys}),
 * also in [file] when given. Returns the exit code: 0 when none failed, 2 when
 * some did; throws when nothing at all could be translated.
 */
export async function reportFailures(failed, translated, file, log = console.log) {
  if (Object.keys(failed).length === 0) return 0;
  // A failed key keeps its old (or hand-written, or English) text and old hash, so it stays stale.
  const list = Object.entries(failed)
    .map(([l, keys]) => `- ${l}: ${keys.join(', ')}`)
    .join('\n');
  log(`Not translated after every retry, retried on the next run:\n${list}`);
  // Nothing at all worked: most likely the key, model or endpoint is wrong.
  if (translated === 0) throw new Error('No string could be translated; see above');
  // The workflow still opens the pull request, then fails the run with this list.
  if (file) await writeFile(file, `${list}\n`);
  return 2;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

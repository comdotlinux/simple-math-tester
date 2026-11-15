// Translates new and changed texts of the Play store listing
// (play/listing/en-US.json) into every app language with DeepSeek, and writes
// play/listing/<Play language code>.json.
// Usage: DEEPSEEK_API_KEY=... node tool/translate_listing.mjs [--dry-run | --check]
// --dry-run only lists what would be translated; --check only checks every
// listing file against Play's limits. Neither needs a key.
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

import { hash, languageName, languages, readJson } from './translate.mjs';

// Play's store listing language codes (Play Console Help, "Add translations
// and localized assets"): most carry a region, Romanian does not.
export const playCodes = {
  de: 'de-DE',
  pl: 'pl-PL',
  hi: 'hi-IN',
  mr: 'mr-IN',
  te: 'te-IN',
  ta: 'ta-IN',
  ml: 'ml-IN',
  fr: 'fr-FR',
  ro: 'ro',
};

// Play's limits in characters.
export const limits = { title: 30, shortDescription: 80, fullDescription: 4000 };
const fields = Object.keys(limits);
// Names that stay in Latin letters in every language.
const brands = ['Simple Math Tester'];

const dir = new URL('../play/listing/', import.meta.url);
// The English text each translated field was made from, as a short hash.
const sourcesFile = new URL('translation_sources.json', dir);
const endpoint = 'https://api.deepseek.com/chat/completions';

/** Why [text] cannot be the listing [field] translated from [source], or null. */
export function problem(field, source, text) {
  if (typeof text !== 'string' || text.trim() === '') return 'empty';
  const length = [...text].length;
  if (length > limits[field]) return `${length} characters, Play allows ${limits[field]}`;
  if (/(?![0-9])\p{Nd}/u.test(text)) return 'non-Western digits';
  const lost = brands.find((brand) => source.includes(brand) && !text.includes(brand));
  if (lost) return `"${lost}" missing`;
  return null;
}

/** The fields of a listing that are missing or whose English changed. */
export function stale(english, listing, sources) {
  return fields.filter((f) => !(f in listing) || sources[f] !== hash(english[f]));
}

/** The problems of every field of a listing file, as "file: field: why". */
export function check(name, english, listing) {
  return fields
    .map((f) => [f, problem(f, english[f], listing[f])])
    .filter(([, why]) => why)
    .map(([f, why]) => `${name}: ${f}: ${why}`);
}

async function ask(model, key, english, language, keys) {
  const system = [
    `You translate the Google Play store listing of a free arithmetic practice app for children aged about 6 to 12 from English into ${languageName(language)} (${language}).`,
    'Parents read it. Use natural, friendly, simple words a native speaker would use in an app store, not a word-by-word translation.',
    `Keep these names unchanged, in Latin letters: ${brands.join(', ')}, Google Play, Android.`,
    'Digits are always Western 0-9. Keep the line breaks and the "- " list items of the English text.',
    `Hard limits in characters: title ${limits.title}, shortDescription ${limits.shortDescription}, fullDescription ${limits.fullDescription}.`,
    'Answer with one JSON object that maps each requested field to its translated text, nothing else.',
  ].join('\n');
  const user = JSON.stringify(Object.fromEntries(keys.map((k) => [k, english[k]])));
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

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const checkOnly = process.argv.includes('--check');
  const key = process.env.DEEPSEEK_API_KEY;
  const model = process.env.DEEPSEEK_MODEL || 'deepseek-flash';

  const english = JSON.parse(await readFile(new URL('en-US.json', dir), 'utf8'));
  const missing = languages.filter((l) => !playCodes[l]);
  if (missing.length) throw new Error(`No Play language code for ${missing.join(', ')} in playCodes`);

  if (checkOnly) {
    const problems = [];
    for (const name of (await readdir(dir)).filter((n) => n.endsWith('.json')).sort()) {
      if (name === 'translation_sources.json') continue;
      problems.push(...check(name, english, JSON.parse(await readFile(new URL(name, dir), 'utf8'))));
    }
    if (problems.length) throw new Error(`Listing problems:\n${problems.join('\n')}`);
    console.log('Every listing file fits Play');
    return;
  }
  const own = check('en-US.json', english, english);
  if (own.length) throw new Error(own.join('\n'));
  if (!dryRun && !key) throw new Error('DEEPSEEK_API_KEY is not set');

  const sources = await readJson(sourcesFile, {});
  let failures = 0;
  for (const language of languages) {
    const code = playCodes[language];
    const file = new URL(`${code}.json`, dir);
    const listing = await readJson(file, {});
    sources[code] ??= {};
    let keys = stale(english, listing, sources[code]);
    console.log(`${code}: ${keys.length} to translate${keys.length ? `: ${keys.join(', ')}` : ''}`);
    if (dryRun || keys.length === 0) continue;

    // One retry for answers that fail the checks.
    for (let attempt = 1; attempt <= 2 && keys.length > 0; attempt++) {
      const answer = await ask(model, key, english, language, keys);
      const rejected = [];
      for (const k of keys) {
        const why = problem(k, english[k], answer[k]);
        if (why) {
          rejected.push(k);
          console.log(`${code}: ${k} rejected (attempt ${attempt}): ${why}`);
        } else {
          listing[k] = answer[k];
          sources[code][k] = hash(english[k]);
        }
      }
      keys = rejected;
    }
    failures += keys.length;
    // A listing is pushed only when complete; a partial one waits for the next run.
    if (fields.every((f) => f in listing)) {
      const out = Object.fromEntries(fields.map((f) => [f, listing[f]]));
      await writeFile(file, `${JSON.stringify(out, null, 2)}\n`);
    }
  }
  if (!dryRun) {
    const sorted = Object.fromEntries(languages.map((l) => [playCodes[l], sources[playCodes[l]]]));
    await writeFile(sourcesFile, `${JSON.stringify(sorted, null, 2)}\n`);
  }
  if (failures > 0) throw new Error(`${failures} listing texts could not be translated; see above`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

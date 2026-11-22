// Translates new and changed texts of the store listing
// (play/listing/en-US.json) into every app language with DeepSeek, and writes
// play/listing/<Play language code>.json. Play takes title and the two
// descriptions; the App Store also takes subtitle and keywords (tool/app_store.mjs).
// Usage: DEEPSEEK_API_KEY=... node tool/translate_listing.mjs [--dry-run | --check]
// --dry-run only lists what would be translated; --check only checks every
// listing file against the stores' limits. Neither needs a key.
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

import {
  digits,
  hash,
  languageName,
  languages,
  maxTokens,
  parseAnswer,
  readJson,
  westernDigits,
} from './translate.mjs';

// Play's store listing language codes (Play Console Help, "Add translations
// and localized assets"): most carry a region, Romanian, Ukrainian and
// Punjabi do not.
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
  uk: 'uk',
  pt: 'pt-BR',
  pt_PT: 'pt-PT',
  pa: 'pa',
};

// The stores' limits in characters: Play's, then the App Store's own fields.
export const limits = { title: 30, shortDescription: 80, fullDescription: 4000, subtitle: 30, keywords: 100 };
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
  if (length > limits[field]) return `${length} characters, the store allows ${limits[field]}`;
  if (/(?![0-9])\p{Nd}/u.test(text)) return 'non-Western digits';
  if (digits(text) !== digits(source)) return `digits ${digits(text) || 'none'} instead of ${digits(source) || 'none'}`;
  const lost = brands.find((brand) => source.includes(brand) && !text.includes(brand));
  if (lost) return `"${lost}" missing`;
  return null;
}

/** What DeepSeek is told about a rejected [field] before it tries again. */
export function retryNote(field, why) {
  const length = why.match(/^(\d+) characters/);
  if (length) {
    return `Your ${field} had ${length[1]} characters; the store allows at most ${limits[field]}. Write a shorter one.`;
  }
  if (why.endsWith('missing')) return `Your ${field} lost ${why.replace(/ missing$/, '')}: keep it exactly, in Latin letters.`;
  if (why === 'non-Western digits') return `Your ${field} had non-Western digits: use only Western digits 0-9.`;
  if (why.startsWith('digits ')) return `Your ${field} changed a number: keep exactly the numbers of the English text.`;
  return `Your ${field} was ${why}: write the whole translation.`;
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

async function ask(model, key, english, language, keys, rejected) {
  const system = [
    `You translate the Google Play and App Store listing of a free arithmetic practice app for children aged about 6 to 12 from English into ${languageName(language)} (${language}).`,
    'Parents read it. Use natural, friendly, simple words a native speaker would use in an app store, not a word-by-word translation.',
    `Keep these names unchanged, in Latin letters: ${brands.join(', ')}, Google Play, App Store, Android.`,
    'Digits are always Western 0-9; never change, add or drop a number. Keep the line breaks and the "- " list items of the English text.',
    `Hard limits in characters: ${Object.entries(limits).map(([k, v]) => `${k} ${v}`).join(', ')}.`,
    'keywords are App Store search words, separated by commas without spaces; translate them as words a parent would search for.',
    'The fields to translate are under "translate". If "yourRejectedAnswers" is there, your last answer for those fields was rejected: fix exactly the problem it names.',
    'Answer with one JSON object that maps each requested field to its translated text, nothing else.',
  ].join('\n');
  const user = JSON.stringify({
    translate: Object.fromEntries(keys.map((k) => [k, english[k]])),
    // The previous attempt's rejected answers and why, so the retry can fix them.
    ...(Object.keys(rejected).length ? { yourRejectedAnswers: rejected } : {}),
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
    console.log('Every listing file fits the stores');
    return;
  }
  const own = check('en-US.json', english, english);
  if (own.length) throw new Error(own.join('\n'));
  if (!dryRun && !key) throw new Error('DEEPSEEK_API_KEY is not set');

  const sources = await readJson(sourcesFile, {});
  const failed = [];
  let translated = 0;
  for (const language of languages) {
    const code = playCodes[language];
    const file = new URL(`${code}.json`, dir);
    const listing = await readJson(file, {});
    sources[code] ??= {};
    let keys = stale(english, listing, sources[code]);
    console.log(`${code}: ${keys.length} to translate${keys.length ? `: ${keys.join(', ')}` : ''}`);
    if (dryRun || keys.length === 0) continue;

    const accepted = {};
    let rejected = {};
    let why = {};
    for (let attempt = 1; attempt <= 3 && keys.length > 0; attempt++) {
      let answer;
      try {
        answer = await ask(model, key, english, language, keys, rejected);
      } catch (error) {
        console.log(`${code}: attempt ${attempt} failed: ${error.message}`);
        why = Object.fromEntries(keys.map((k) => [k, 'no answer']));
        continue;
      }
      rejected = {};
      why = {};
      for (const k of keys) {
        const text = westernDigits(answer[k]);
        const reason = problem(k, english[k], text);
        if (reason) {
          why[k] = reason;
          rejected[k] = { yourAnswer: text, problem: retryNote(k, reason) };
          console.log(`${code}: ${k} rejected (attempt ${attempt}): ${reason}`);
        } else {
          accepted[k] = text;
        }
      }
      keys = Object.keys(why);
    }
    failed.push(...keys.map((k) => `${code} ${k} (${why[k]})`));
    // A listing file is always complete, so play-listing.yml can push it: a new
    // language with a failed field waits for the next run. A field that failed in
    // an existing listing keeps its old text and old hash, so it stays stale.
    Object.assign(listing, accepted);
    if (fields.every((f) => f in listing)) {
      const out = Object.fromEntries(fields.map((f) => [f, listing[f]]));
      await writeFile(file, `${JSON.stringify(out, null, 2)}\n`);
      for (const k of Object.keys(accepted)) sources[code][k] = hash(english[k]);
      translated += Object.keys(accepted).length;
    } else if (Object.keys(accepted).length) {
      failed.push(`${code} not written: ${Object.keys(accepted).join(', ')} translated but the listing is incomplete`);
    }
  }
  if (!dryRun) {
    const sorted = Object.fromEntries(languages.map((l) => [playCodes[l], sources[playCodes[l]]]));
    await writeFile(sourcesFile, `${JSON.stringify(sorted, null, 2)}\n`);
  }
  if (failed.length === 0) return;
  console.log(`Not translated, retried on the next run:\n- ${failed.join('\n- ')}`);
  // Nothing at all worked: most likely the key, model or endpoint is wrong.
  if (translated === 0) throw new Error('No listing text could be translated; see above');
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

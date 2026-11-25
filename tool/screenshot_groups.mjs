// Prints the screenshot matrix groups as JSON for the listing workflows:
// [{"id":1,"pairs":"en:en-US de:de-DE ..."}, ...], three languages per group
// (en first, shot without SCREENSHOT_LANGUAGES). New languages in translate.mjs
// join the groups with no workflow edit.
import { languages } from './translate.mjs';
import { playCodes } from './translate_listing.mjs';

const missing = languages.filter((l) => !playCodes[l]);
if (missing.length) throw new Error(`No Play language code for ${missing.join(', ')}`);
const pairs = ['en:en-US', ...languages.map((l) => `${l}:${playCodes[l]}`)];
const groups = [];
for (let i = 0; i < pairs.length; i += 3)
  groups.push({ id: groups.length + 1, pairs: pairs.slice(i, i + 3).join(' ') });
console.log(JSON.stringify(groups));

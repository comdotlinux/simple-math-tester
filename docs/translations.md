# Translations

The app is in English (the source) and German, Polish, Hindi, Marathi,
Telugu, Tamil, Malayalam, French, Romanian, Ukrainian, Portuguese (Brazil and
Portugal) and Punjabi (Gurmukhi). It follows the device language, English
when that language has no translation; Settings > Language overrides it.

## Where the texts are

- `app/lib/l10n/app_en.arb` is the template: every text the app shows, each
  with a description for translators. Placeholders such as `{count}` and ICU
  plurals stay as they are in every language, and digits stay Western (0-9).
- `app/lib/l10n/app_<code>.arb` holds one language. A regional variant has
  its own full file named `<language>_<COUNTRY>`: `app_pt.arb` is Brazilian
  Portuguese (for `pt`, `pt_BR` and every other Portuguese), `app_pt_PT.arb`
  European. The saved language is that code, such as `pt_PT`. `flutter pub get` (and
  every build) generates the Dart classes from these files; they are not
  committed.
- `app/lib/l10n/translation_sources.json` records which English text each
  translation was made from, so a changed English text is translated again.
- `app/test/l10n_test.dart` checks that every language has every key with
  the same placeholders, and that each language fits a 360x640 phone.

## A new or changed text

1. Add or change the text in `app_en.arb`, with a description, and use it in
   the code through `AppLocalizations.of(context)`.
2. Merge it. On `main`, a change to `app_en.arb` (or to the language list in
   `tool/translate.mjs`) starts the **Translate new and changed strings**
   workflow by itself; it can also be run by hand from `main` (Actions tab,
   Run workflow). For each language it translates only the keys missing from
   that language's file or whose English changed, checks placeholders,
   plurals and digits, runs the translation tests, and opens a pull request
   from the branch `translations/auto`, or updates the open one. Strings
   go to DeepSeek in batches of up to 60 (about 4500 English characters,
   `max_tokens` 32768), as plain `key: text` pairs with the descriptions in
   a separate `notes` map (when each key was an object with its text and
   description, the model sometimes answered with objects, which failed
   every retry; an answer object's `text` is still accepted, and a rejected
   value that is not a string is quoted in the log). When a batch fails (HTTP error, an answer cut off or
   not valid JSON), its keys are sent again in batches of 20, each with up
   to two retries; a rejected or missing string is sent again the same way,
   alone with the other failed keys. A string that fails every attempt keeps
   its old text (English in a new file) and is retried on the next run. The
   other translations still go into the pull request, but the run then
   fails and its last step lists the failed keys per language.
3. The workflow starts the Flutter checks on that branch itself. Review and
   merge the pull request.

### What a translation must keep

`problem()` in `tool/translate.mjs` rejects a translation that loses or adds
a placeholder, has unbalanced braces, a plural without `other`, or digits
other than Western 0-9 (other scripts' digits are first turned into 0-9).
It also rejects a changed, added or dropped number: the digits outside
`{placeholders}` must be the same in English and in the translation, in any
order. Digits in placeholder names do not count. In a plural, each branch
is compared on its own, and the number of an `=1{1 second}` branch counts
as the argument, so `one{{count} секунда}` matches it. Added plural
categories (`few`, `many`) must carry the same numbers as the English
branches. The store listing (`tool/translate_listing.mjs`) applies the same
digit rule.

The prompt names the school mathematics terms perimeter, area, angle, side,
triangle, rectangle, square, circle, equation and blank (the empty box in an
equation), and asks for the standard school term of the target language,
always the same one. It lists no translations: those are the model's, and a
native speaker should check them. Changing the prompt does not translate
existing strings again; only a changed English text does, since the hashes
in `translation_sources.json` are made from the English text alone.

Locally the same script runs with your own key:

```sh
DEEPSEEK_API_KEY=... node tool/translate.mjs           # writes the ARB files
node tool/translate.mjs --dry-run                      # lists what would change
```

`DEEPSEEK_MODEL` picks the model (default `deepseek-flash`). The workflow
runs only on `main`, uses the `release` environment secret `DEEPSEEK_API_KEY`,
and the variable `DEEPSEEK_MODEL`.

The workflow needs **Settings > Actions > General > Workflow permissions >
Allow GitHub Actions to create and approve pull requests** turned on in the
repository settings; without it the last step fails.

## The Play store listing

`play/listing/en-US.json` holds the English store title and descriptions,
and the App Store's subtitle and keywords;
`tool/translate_listing.mjs` translates them the same way into
`play/listing/<Play code>.json`, with hashes in
`play/listing/translation_sources.json`. The Translate workflow runs it too,
so listing translations arrive in the same pull request. Locally:
`node tool/translate_listing.mjs --dry-run`, or `--check` for the stores' length
limits. Pushing the listings to Play and to the App Store are separate, manual
workflows; see "Store listing" in [play-store.md](play-store.md) and
[app-store.md](app-store.md).

## A new language

1. Add its code to `languages` in `tool/translate.mjs`, and its Play store
   listing code to `playCodes` in `tool/translate_listing.mjs`, and that code's
   App Store locale to `appStoreLocales` in `tool/app_store.mjs`. Where the
   English name leaves the variant or script open, name it in `promptNames`
   there (such as "European Portuguese (Portugal)"). Add its English name to
   `englishLanguageNames` in `app/lib/labels.dart`.
2. Merge it; the workflow runs and creates `app_<code>.arb`, including `languageName`,
   the language's name in itself, which the language list shows.
3. If the language uses a script that Roboto and the bundled Noto Sans
   fonts (Devanagari, Telugu, Tamil, Malayalam, Gurmukhi) do not cover, bundle a Noto
   Sans font for it: add the regular and bold files with their licence under
   `app/assets/fonts/`, list the family in `app/pubspec.yaml`, add it to
   `fontFallback` in `app/lib/app_theme.dart`, and add the language to the
   script check at the end of `tool/browser_check.mjs`. Without the font the
   web app would download one from fonts.gstatic.com, which the privacy
   policy rules out.

Machine translations are a start: a native speaker should read them, above
all the privacy policy.

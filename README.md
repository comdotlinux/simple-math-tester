# Simple Math Tester

A friendly arithmetic practice app for school beginners. Practice with addition,
subtraction, multiplication and division, then review answers for the current
session. Algebra (equations with one missing number) and geometry (perimeter,
area, sides and angles of figures drawn to scale) can be switched on; see
[docs/question-kinds.md](docs/question-kinds.md). Supports web, Android and iOS.

## Local setup

Flutter and the other project tools are managed with [mise](https://mise.jdx.dev/).
The Flutter version is pinned in `mise.toml` and matches CI.

```sh
mise install
cd app
mise exec -- flutter pub get --enforce-lockfile
mise exec -- flutter run
```

Use `mise exec -- flutter devices` to list available targets. iOS builds require
macOS and Xcode. Android builds require an Android SDK and accepted licenses.

## Checks

Run all Flutter and Dart commands through `mise` from `app/`:

```sh
mise exec -- dart format --output=none --set-exit-if-changed lib test integration_test integration_test_web test_driver tool
mise exec -- flutter analyze
mise exec -- flutter test
mise exec -- flutter test integration_test -d linux
mise exec -- flutter build web --release
mise exec -- flutter build apk --release
```

The integration command builds and launches the real Linux app, then runs the
named journeys of every feature. See `app/integration_test/README.md` for the
layout, the feature inventory, and the rule that every feature or fix adds a
journey. On a headless Linux host, prefix it with `xvfb-run -a`.

CI runs web checks and the Impressum function tests first, then Linux
integration. The Chrome and offline checks, Cloudflare deployment, and the
Android and iOS jobs then run in parallel.
Pull requests and pushes to `main` skip the Android and iOS jobs (builds,
emulators, simulator); they run only on manual runs ("Run workflow", environment
`none` runs all checks without deploying). A change that breaks only the Android
or iOS build is therefore found by a manual run or at release time. Deployment
downloads the tested web artifact instead of repeating tests or compilation.
Branch pushes skip deployment; `main` pushes and manual runs with an environment
deploy after the prerequisite checks pass.

CI uploads the Linux release bundle, Android APK, and unsigned iOS app as build
artifacts with 3-day retention.

A separate workflow, `play-bundle.yml`, builds the Google Play app bundle on `v*`
tags and on manual runs (no inputs), not on pushes to `main`. It signs with the upload key from
repository secrets, or with a throwaway key when the secrets are not set, fails if
the bundle carries the Android debug certificate or requests a permission not in
`app/android/expected-permissions.txt`, and checks 16 KB page support of
the APKs built from it (`zipalign -c -P 16`, `.so` LOAD alignment of at least
0x4000). Only the secret-signed bundle is uploaded (3-day retention). Release builds
use `app/android/key.properties` when it exists and debug signing otherwise; the
Android application id is `com.linux.simplemathtester`. See `docs/play-store.md`
for the Play Console answers and the publishing walkthrough.

On macOS, also run:

```sh
mise exec -- flutter build ios --release --no-codesign
```

See `DESIGN.md` for the visual and accessibility contract. Session answers remain
in memory and are cleared when the app restarts.

## Impressum

The web build's `/impressum` page (`app/web/impressum.html`) shows the provider
identification only after a Cloudflare Turnstile check. The Pages Function
`functions/api/impressum.js` (deployed with the site, because the deploy command
runs at the repository root) verifies the token and returns the text. It reads two
secrets, set on the Pages project's Production environment only (preview
deployments answer 500): `TURNSTILE_SECRET_KEY` and `IMPRESSUM_TEXT`. Neither the
text nor the secret is in this repository. The site key is public and sits in
`impressum.html`; see walkthrough row 4b in `docs/play-store.md`. The app's
settings sheet links to the page and shows the privacy policy offline from
`app/lib/legal.dart`, which a test keeps equal to `app/web/privacy.html`.

Test the function from the repository root with Node 22 or later (no install
needed; two tests call Cloudflare's verification with its published test keys and
are skipped when it is unreachable):

```sh
node --test tool/functions_test/
```

CI runs this in its own job beside the web checks; deployment waits for it.

## Reports from the app

A player (with a grown-up) can report a question that looks wrong, or a problem
with the app, without a GitHub account. The app (#150) sends a fixed report code
to the Pages Function `functions/api/report.js` (#149), which opens a GitHub
issue on `comdotlinux/simple-math-tester`. The app never holds a token. The
function's tests are in `tool/functions_test/report.test.mjs`, with GitHub
replaced by a fake; they run with the command above.

### The endpoint

`POST /api/report` (`https://math.munich-tech.de/api/report` from the phone and
desktop apps, same origin from the web app). The body is JSON of at most 1024
bytes with `Content-Type: application/json` (an optional `; charset=utf-8` is
accepted). There is no free text anywhere.

```json
{"type":"question","kind":"geometry","variant":"rectangleArea","params":[3,4],"level":2,
 "reason":"wrongAnswer","version":"1.3.0","platform":"android","locale":"pt_PT"}
{"type":"problem","category":"sound","version":"1.3.0","platform":"web","locale":"de"}
```

The function accepts exactly these two shapes. A missing key, an extra key or a
value of the wrong type is rejected.

| Field | Allowed |
|---|---|
| `type` | `question`, `problem` |
| `kind` | `algebra`, `geometry` (arithmetic questions are not reported) |
| `variant` | a family name of that kind, from `functions/report-allowlist.json` |
| `params` | 1 to 4 integers, each from -1000 to 1000 |
| `level` | integer 1 to 5 |
| `reason` | `wrongAnswer`, `unclearQuestion`, `wrongHint`, `wrongDrawing` |
| `category` | `crash`, `display`, `sound`, `translation`, `other` |
| `version` | three dot-separated numbers of 1 to 4 digits, such as `1.3.0` |
| `platform` | `android`, `ios`, `web`, `linux`, `macos`, `windows` |
| `locale` | an app language as Flutter's `Locale.toString()`, such as `de` or `pt_PT`, from `functions/report-allowlist.json` |

Answers have a short plain-text body and `Cache-Control: no-store`, and no CORS
headers (the web app calls the same origin; native apps need no CORS):

| Status | Body | Meaning |
|---|---|---|
| 201 | `Reported.` | A new issue was created |
| 200 | `Already reported.` | An open issue with the same title exists; it got a +1 reaction |
| 400 | `Invalid report.` | Not one of the two shapes, wrong `Content-Type`, or larger than 1024 bytes |
| 405 | `Method not allowed.` | Any method but POST |
| 429 | `Too many reports.` | 100 or more issues with the two labels are open; nothing was created |
| 500 | `Not configured.` | No `GITHUB_REPORT_TOKEN`, or GitHub dropped the label (token without the right access) |
| 502 | `Unavailable.` | GitHub did not answer within 8 seconds, answered with an error, or could not be reached |

### The issues

| Report | Title | Label |
|---|---|---|
| Question | `Suspect question: <kind> <variant> [<params>] L<level>`, such as `Suspect question: geometry rectangleArea [3,4] L2` | `suspect-question` |
| Problem | `Reported problem: <category> <version> <platform>`, such as `Reported problem: sound 1.3.0 web` | `reported-problem` |

The params in the title are joined with commas, no spaces. The issue body lists
every field of the report, each value in backticks, from a fixed template. The
title is the key: the function lists the open issues with the label and looks
for the same title. A repeat adds a +1 reaction to that issue instead of a new
one. A reaction notifies no one, and GitHub keeps one +1 per account, so it
means "reported more than once", not how often. The reason and language of a
repeat are not kept. After the issue is closed, the next report of the same
question opens a new one.

The two labels exist on the repository (created with #149). The function does
not create labels; if one is deleted, issues come back without it and the
function answers 500. Create it again with:

```sh
gh label create suspect-question --color D93F0B --description "Reported from the app: a question that may be wrong (functions/api/report.js)"
gh label create reported-problem --color FBCA04 --description "Reported from the app: a problem (functions/api/report.js)"
```

### What is stored, and what is not

- **Stored, in the public issue:** only the validated report fields: kind,
  family name, numbers, level, reason or category, app version, platform and
  app language.
- **Not stored or logged:** the IP address, the request body and headers. The
  function has no log statement and no storage, and its answers never contain
  the token, the request or GitHub's error text.

Every value that reaches an issue is an integer or a string from an allow-list of
plain identifiers, so no Markdown, HTML, link or @mention can get in. A test sends
hostile strings (Markdown, HTML, @mentions, URLs, long strings, null bytes,
nested objects, prototype keys) in every field and expects 400 and no GitHub call.

### The family and language list

`functions/report-allowlist.json` holds the algebra and geometry family names,
the app languages and the param limits. The function imports it; the Dart test
`app/test/report_allowlist_test.dart` compares it with `AlgebraSource.families`,
`GeometryFamily.values` and `AppLocalizations.supportedLocales`, and checks that
every question's params fit the limits. A new family or language fails that test
until it is added to the JSON file. A JSON file in `functions/` is not a route
(only `.js` and `.ts` files are).

### Secret and owner steps

The function reads one secret, `GITHUB_REPORT_TOKEN`, on the Pages project's
Production environment, set like `IMPRESSUM_TEXT` (walkthrough row 4b in
`docs/play-store.md`). It is not a GitHub Actions secret: the deploy job only
uploads the site and `functions/`, and Cloudflare hands the secret to the
function at run time. Until it is set, valid reports get 500, so the function is
safe to deploy first.

1. GitHub, Settings, Developer settings, Fine-grained personal access tokens,
   Generate new token. Name `simple-math-tester reports`, resource owner
   `comdotlinux`, repository access "Only select repositories" with
   `comdotlinux/simple-math-tester` only, repository permission **Issues: Read
   and write** (GitHub adds Metadata: Read-only), nothing else. Note the expiry
   date: an expired token makes every report answer 502.
2. Cloudflare dashboard, Workers & Pages, `simple-math-tester`, Settings,
   Variables and Secrets, Add: type **Secret**, name `GITHUB_REPORT_TOKEN`, the
   token as value, environment **Production**. Paste the token nowhere else.
3. A secret reaches only the next deployment. Redeploy `main` with
   `gh workflow run flutter-checks.yml --ref main -f environment-name=prod`
   (this run also builds the phones, about 30 minutes).
4. Send one report and check that the issue appears with its label, then close
   it:

   ```sh
   curl -sS -X POST https://math.munich-tech.de/api/report \
     -H 'Content-Type: application/json' \
     --data '{"type":"problem","category":"other","version":"0.0.0","platform":"linux","locale":"en"}'
   ```

To renew the token, generate a new one with the same settings, replace the secret
value in the dashboard and redeploy as in step 3.

### Abuse limits and their gaps

- Body at most 1024 bytes, read as a stream and cut off there; POST only; JSON
  only.
- Every field from an allow-list or a bounded integer, so a report carries no
  content.
- At most 100 open issues with the two labels together (`OPEN_LIMIT` in
  `report.js`); at the limit the function answers 429 and creates nothing. A
  repeat still gets its reaction, as it creates nothing.
- Repeats cost one reaction, which GitHub keeps once per account.
- Each GitHub call has an 8-second timeout.

Gaps:

- **No per-IP rate limit.** The function stores nothing about callers. A script
  can create up to 100 issues (all from the allow-list: noise, not content) and
  then block new reports with 429 until the owner closes issues. A rate limit
  needs a Cloudflare rule (Security, WAF, Rate limiting rules, for example 5
  requests per minute per IP on `/api/report`), which the owner adds in the
  dashboard if abuse happens.
- Each request makes two GitHub list calls. A flood of valid requests uses up the
  token's rate limit (5000 requests per hour); reports then answer 502 until the
  hour resets.
- The limit counts open issues only.

## Modernization record

Upgraded on 2026-11-13:

- Flutter 3.13.5 to 3.50.0, with bundled Dart 3.14.0.
- `duration` 3.0.13 to 4.0.3, `provider` 6.0.5 to 6.1.5+1, and `collection`
  1.17.1 to 1.19.1.
- `flutter_lints` 2.0.3 to 6.0.0; added `material_ui` 1.11.0 for Flutter's
  standalone Material package migration.
- Removed unused `cupertino_icons` and `flutter_otp_text_field`; neither had
  references in `app/lib` or `app/test`.
- `material_color_utilities` 0.13.0 and `test_api` 0.7.14 remain constrained by
  the Flutter SDK. Versions 0.13.1 and 0.7.15 are not resolvable without
  dependency overrides, which this project intentionally does not use.

## Platform verification limits

Linux cannot build iOS. Use the macOS CI job or a local macOS Xcode toolchain for
the unsigned iOS build. Android and iOS keyboard, safe-area, navigation and
background/resume behavior also require emulator, simulator or device smoke
tests. Browser emulation is not native execution evidence. CI job definitions
alone do not prove those checks passed.

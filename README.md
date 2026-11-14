# Simple Math Tester

A friendly arithmetic practice app for school beginners. Practice with addition,
subtraction, multiplication and division, then review answers for the current
session. Supports web, Android and iOS.

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
Pull requests skip the Android and iOS jobs (builds, emulators, simulator) to keep
rounds short; they run on every push to `main` and on manual runs ("Run
workflow", environment `none` runs all checks without deploying). Deployment
downloads the tested web artifact instead of repeating tests or compilation.
Branch pushes skip deployment; `main` pushes and manual runs with an environment
deploy after the prerequisite checks pass.

CI uploads the Linux release bundle, Android APK, and unsigned iOS app as build
artifacts with 3-day retention.

A separate workflow, `play-bundle.yml`, builds the Google Play app bundle on every
push to `main` and on manual runs (no inputs). It signs with the upload key from
repository secrets, or with a throwaway key when the secrets are not set, fails if
the bundle carries the Android debug certificate, and checks 16 KB page support of
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

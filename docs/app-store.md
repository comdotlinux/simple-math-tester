# App Store and TestFlight

The iOS app is `com.linux.simplemath` (team `296X8GK5BR`), shown on the home
screen as "Simple Math". Its App Store name is "Simple Math Tester: Practice"
("Simple Math Tester" and "Simple Math" are taken). Android, web and the in-app
title keep their names.
No Mac is needed: GitHub Actions macOS runners build, sign and upload.

## Secrets

Set once by the owner in the `release` environment (`gh secret set NAME -e release`),
like the Android keystore and Play secrets, from an App Store Connect team API key
with the **Admin** role (Users and Access, Integrations, App Store Connect API).
API keys have fixed roles only, and only Admin may create the cloud-managed
distribution certificate that `-allowProvisioningUpdates` uses at export; an App
Manager key fails with "Cloud signing permission error". The key in use is
`github-ci-admin`. A key's role cannot be changed: to rotate, create a new key,
replace `APPSTORE_API_KEY` and `APPSTORE_KEY_ID`, then revoke the old key.

| Secret | Value |
|---|---|
| `APPSTORE_API_KEY` | Content of the downloaded `AuthKey_<id>.p8` |
| `APPSTORE_KEY_ID` | Key ID |
| `APPSTORE_ISSUER_ID` | Issuer ID |
| `APPLE_TEAM_ID` | `296X8GK5BR` |

Tag runs and runs on `main` use the `release` environment. A tag run fails with
"Missing secrets in the release environment: ..." when one is not set. Runs on
other branches get no secrets and build an unsigned app instead.

## How the IPA is built

`.github/workflows/ios-bundle.yml` runs on `v*` tags and by hand (no inputs).
It writes the key to `~/.appstoreconnect/private_keys` on the runner, archives
unsigned (signing at archive time wants a development profile, which needs a
registered device; the team has none), and exports with
`app/ios/ExportOptions.plist` (method `app-store-connect`),
`-allowProvisioningUpdates` and the API key. The export signs: Apple manages the
distribution certificate and the App Store profile in the cloud. The workflow
then checks the IPA is signed by "Apple Distribution" with bundle id
`com.linux.simplemath`, and prints its entitlements.
The build number is `run number * 10 + attempt`, like `play-bundle.yml`.

- A manual run on `main` builds and signs the IPA, then discards it. On another
  branch it builds unsigned.
- A tag run sets the version from the tag and uploads to TestFlight with
  `xcrun altool --upload-app`.

`ITSAppUsesNonExemptEncryption` is `false` in `Info.plist`: the app uses no
encryption beyond the system's, so TestFlight asks no export-compliance question.

## Store listing

The App Store texts come from the same files as Play's:
[`play/listing/en-US.json`](../play/listing/en-US.json) and its translations
(see "Title and descriptions" in [play-store.md](play-store.md) and
[translations.md](translations.md)). `tool/app_store.mjs` maps them:

| App Store field | Limit | From |
|---|---|---|
| Name | 30 | "Simple Math Tester: Practice" in every language |
| Subtitle | 30 | `subtitle` (App Store only) |
| Promotional text | 170 | `shortDescription` |
| Description | 4000 | `fullDescription` |
| Keywords | 100 | `keywords` (App Store only), comma-separated |
| Support URL | | `https://math.munich-tech.de/impressum` |
| Marketing URL | | `https://math.munich-tech.de` |
| Privacy policy URL | | `https://math.munich-tech.de/privacy` |

"What's New" is written by `app-store-review.yml` (see "Submitting for App
Review"); the first version has none. Category, age rating, privacy answers and pricing are set by
the owner in App Store Connect; nothing here changes them.

Play codes map to App Store Connect locales (App Store Connect API, "Managing
metadata in your app by using locale shortcodes"): `pl-PL` to `pl`, `hi-IN` to
`hi`, `pa` to `pa-IN`; the others are the same. A locale App Store Connect
refuses is skipped with a notice.

After the Translate pull request is merged, write the listings by hand:
`gh workflow run app-store-listing.yml` (from `main`; it needs the `release`
environment). It writes the texts of every language to the version in "Prepare
for Submission" (or rejected), and creates the languages that are missing.
By default it also shoots the eight Play scenes of `app/tool/screenshots_test.dart`
in every language for each screenshot set, in a matrix of device x language group of three (`tool/screenshot_groups.mjs`; a new language needs no workflow edit),
and replaces each language's screenshots with them (untick `screenshots` for
texts only). A run on another branch only shoots; its artifacts are
`app-store-screenshots-<device>-<group>` (runs before the groups made `app-store-screenshots-<device>`; `screenshots-from-run` takes both, the `app-store-screenshots-*` pattern matches them). Apple reviews the texts with the next version
submitted.

The sets are one table, `devices` in `tool/app_store.mjs`; the workflow reads
the sizes from it (`node tool/app_store.mjs devices <device>`):

| Device | App Store Connect slot | Display type | Shot at | Pixels |
|---|---|---|---|---|
| `iphone` | iPhone with Dynamic Island (medium display), 6.1"/6.3", **required** | `APP_IPHONE_61` | 402 x 874 at 3x | 1206 x 2622 |
| `iphone-large` | iPhone with Dynamic Island (large display), 6.7"/6.9", optional | `APP_IPHONE_67` | 430 x 932 at 3x | 1290 x 2796 |
| `ipad` | iPad 13" display, required for iPad | `APP_IPAD_PRO_3GEN_129` | 1024 x 1366 at 2x | 2048 x 2732 |

Apple scales the medium iPhone set down for smaller phones, so the other slots
(Face ID, Home Button, iPhone Duo) stay empty. Before uploading, the run prints
the sets each language already has; if App Store Connect refuses a set, it
stops and names the display type and those sets, so the table can be fixed.

`tool/app_store.mjs` needs no dependency: it signs the API token (ES256 JWT)
with `node:crypto` from `APPSTORE_API_KEY` and calls the App Store Connect API
with `fetch`. Its tests are `tool/app_store.test.mjs`.

## Releasing to TestFlight

1. Before tagging: `gh workflow run ios-bundle.yml --ref main` and wait for green.
2. The same `v*` tag that starts `play-bundle.yml` starts `ios-bundle.yml`.
3. After the upload, App Store Connect processes the build (minutes to an hour).
   Internal testers in TestFlight get it then. External testing is done by the
   owner in App Store Connect.

## Submitting for App Review

`.github/workflows/app-store-review.yml` (manual, from `main`, `release`
environment) takes inputs `version` (the tag, `v1.4.1`), `dry-run` (on by
default) and `notes-since` (optional tag). It runs `tool/app_store.mjs review`:

1. Finds the newest processed (VALID, not expired) TestFlight build of that
   version. None: the run stops; push the tag and wait for processing.
2. Finds the App Store version of that number. If there is none, the version in
   preparation takes the number, or a new version is created. A version already
   waiting for or in review stops the run.
3. Attaches the build to the version.
4. Writes What's New in every language of the version: the changes from the
   tag before `version` (or `notes-since`) to `version`, summed up and
   translated by `.github/play-release-notes.sh` like the Play notes; a language
   without a valid translation gets the English text. The app's first App Store
   version has no What's New, so this step is skipped for it.
5. Submits the version for App Review (a review submission with the version as
   its item; a draft submission is reused).

```sh
gh workflow run app-store-review.yml -f version=v1.4.1             # dry run: lists what it would do
gh workflow run app-store-review.yml -f version=v1.4.1 -f dry-run=false
```

Release type (manual or automatic after approval), age rating, privacy answers
and pricing stay as the owner set them in App Store Connect.

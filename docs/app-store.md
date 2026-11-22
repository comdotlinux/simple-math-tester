# App Store and TestFlight

The iOS app is `com.linux.simplemath` (team `296X8GK5BR`), shown on the home
screen as "Simple Math". Android, web and the in-app title keep their names.
No Mac is needed: GitHub Actions macOS runners build, sign and upload.

## Secrets

Set once by the owner (`gh secret set NAME`), from an App Store Connect API key
with the App Manager role (Users and Access, Integrations, App Store Connect API):

| Secret | Value |
|---|---|
| `APPSTORE_API_KEY` | Content of the downloaded `AuthKey_<id>.p8` |
| `APPSTORE_KEY_ID` | Key ID |
| `APPSTORE_ISSUER_ID` | Issuer ID |
| `APPLE_TEAM_ID` | `296X8GK5BR` |

The workflow fails with "Missing secrets: ..." when one is not set.

## How the IPA is built

`.github/workflows/ios-bundle.yml` runs on `v*` tags and by hand (no inputs).
It writes the key to `~/.appstoreconnect/private_keys` on the runner, archives
with `xcodebuild -allowProvisioningUpdates` and the API key (automatic signing:
Apple manages the distribution certificate and the profile in the cloud), and
exports with `app/ios/ExportOptions.plist` (method `app-store-connect`).
The build number is `run number * 10 + attempt`, like `play-bundle.yml`.

- A manual run builds and signs the IPA, then discards it.
- A tag run sets the version from the tag and uploads to TestFlight with
  `xcrun altool --upload-app`.

`ITSAppUsesNonExemptEncryption` is `false` in `Info.plist`: the app uses no
encryption beyond the system's, so TestFlight asks no export-compliance question.

## Releasing to TestFlight

1. Before tagging: `gh workflow run ios-bundle.yml --ref main` and wait for green.
2. The same `v*` tag that starts `play-bundle.yml` starts `ios-bundle.yml`.
3. After the upload, App Store Connect processes the build (minutes to an hour).
   Internal testers in TestFlight get it then. External testing and App Store
   review are done by the owner in App Store Connect.

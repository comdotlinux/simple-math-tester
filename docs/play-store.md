# Google Play: listing, declarations and publishing walkthrough

Everything the owner enters in Play Console, and the steps to publish. Play Console
menu names are written from memory; check them against the live console while
following the walkthrough. Facts behind the answers: the app's own code collects
no personal data, stores progress only on the device, has no accounts, no
analytics and no ads, and the Android release build requests no internet access
(`app/android/expected-permissions.txt` lists its only permission). Its one link
out is the Impressum entry in the settings, which opens
`https://math.munich-tech.de/impressum` in the system browser.

## Store listing

| Field | Value |
|---|---|
| App name | Simple Math Tester |
| Default language | English (United States), en-US |
| App or game | App |
| Free or paid | Free |
| Category | Education |
| Tags (optional) | Math, Education |
| Contact e-mail | The owner's developer e-mail (shown publicly on the listing) |
| Website | `https://math.munich-tech.de/impressum` (the Impressum; works once walkthrough row 4b is done) |
| Privacy policy URL | `https://math.munich-tech.de/privacy.html` (see below) |

The address is the custom domain `math.munich-tech.de` of the Cloudflare Pages
project `simple-math-tester` (also reachable at `simple-math-tester.pages.dev`).
Only `/impressum` uses the Turnstile check; the app and every other page load
without it. Cloudflare Pages redirects `/privacy.html` to `/privacy`; both work.

### Short description (80 characters at most)

> Friendly math practice for kids: add, subtract, multiply and divide.

### Full description (4000 characters at most)

> Simple Math Tester is a friendly arithmetic workbook for children who are
> starting school math.
>
> Practise addition, subtraction, multiplication and division, alone or mixed.
> Each kind of exercise has five difficulty levels. Start at Easy, Medium, Hard
> or Harder, and the app adapts to how well you answer.
>
> - Big, clear numbers and an on-screen number pad.
> - A wrong answer can be retried or skipped, and worked steps show how to solve it.
> - "My answers" lets you review what you practised.
> - Combos, experience points, player levels, a daily goal and a daily streak
>   reward real progress.
> - Relaxed practice has no timer. When you want speed, try the 60-second sprint.
> - Sound and vibration can be switched off.
>
> Private by design: no accounts, no ads, no tracking and no data collection.
> Progress is saved only on your device, and the app works fully offline.

## Graphics

Stored in [`docs/play-store/`](play-store/) (see its README for how they are made):

| Asset | Requirement | File |
|---|---|---|
| App icon | 512 x 512 PNG | [`play-store/icon-512.png`](play-store/icon-512.png) |
| Feature graphic | 1024 x 500 PNG or JPEG, no alpha | [`play-store/feature-graphic-1024x500.png`](play-store/feature-graphic-1024x500.png) |
| Phone screenshots | 2 to 8, 9:16, 1080 x 1920 | `play-store/phone-1-practice.png` to `play-store/phone-7-compact.png`, uploaded in that order |

## App content declarations

| Declaration | Answer |
|---|---|
| Privacy policy | `https://math.munich-tech.de/privacy.html` |
| Ads | No, the app does not contain ads. |
| App access | All functionality is available without special access (no login, no account). |
| Content rating | See the questionnaire answers below. |
| Target audience and content | Age groups 6 to 8 and 9 to 12. Includes children, so the Families Policy applies (answers below). |
| Data safety | No user data collected or shared (answers below). |
| Advertising ID | No, the app does not use the advertising ID. |
| Government apps | No, the app is not developed by or for a government. |
| Financial features | None; the app provides no financial features. |
| Health | No health features. |
| News app | No, it is not a news app. |
| Account deletion | Not applicable: the app has no accounts. |
| Trader status | Non-trader. The app is free, has no ads and no in-app purchases, and is a hobby project (plan section 4.6). Google then shows legal name, country and developer e-mail, not the address. |

### Content rating questionnaire (IARC)

- Category: Reference, news or educational (not a game; if the console requires a
  game category, choose "Educational" or the closest match).
- Violence, fear, sexuality, nudity, crude humour, offensive language: No.
- Controlled substances (drugs, alcohol, tobacco): No.
- Gambling, simulated gambling, loot boxes: No.
- Users can interact or exchange content with each other: No.
- Shares the user's location with others: No.
- Digital purchases: No.
- Unrestricted internet or web browsing: No. (The settings sheet has one link,
  to the developer's Impressum, which opens in the system browser; the app has
  no browser of its own.)
- Expected result: Everyone / PEGI 3 / USK 0.

### Families Policy

- Target age groups: 6 to 8 and 9 to 12; the app is designed for children.
- Ads: none, so no Families Self-Certified Ads SDK is needed.
- Data from children: none collected or transmitted. The included packages
  (`shared_preferences`, `audioplayers`, `provider`, `duration`, `material_ui`,
  `url_launcher`) work on the device only and send nothing; `url_launcher` only
  hands the Impressum address to the system browser.
- No accounts, no social features, no purchases.
- Links out of the app: one, the "Impressum" entry in the settings sheet (behind
  the gear icon, not on the practice screen). It opens the developer's
  provider identification on the app's own website in the system browser. That
  page loads Cloudflare Turnstile (a bot check that receives the visitor's IP
  address and browser signals); the privacy policy says so. The privacy policy
  itself is shown inside the app and needs no connection.
- Teacher Approved: optional, not applied for.

### Data safety

- Does the app collect or share any of the required user data types? No.
- With "No", the form asks no further data questions. Encryption in transit and
  deletion requests do not apply because nothing is collected.
- The Impressum link opens a web page in the browser; the app itself sends
  nothing. Cloudflare Turnstile on that page is part of the website, not of the
  app, and is described in the privacy policy, so the answer stays "No". If
  Play Console asks about links to websites, describe this one link.
- Independent security review: No.

## Points for a lawyer or the data-protection authority

From plan section 4.6 (research, not legal advice):

- Whether a bot check (Cloudflare Turnstile) in front of the Impressum is acceptable.
  If not, or if Turnstile or the function is unavailable for long, the fallback is
  to return the text without the check (a one-line change in
  `functions/api/impressum.js`) or to publish the text as a static page.
- Whether the one link out of the app (the Impressum, behind the settings gear)
  needs a parental gate for the Families Policy.
- Whether an Impressum is required for an ad-free hobby app, and with which address.
- Whether non-trader status is right for an ad-free free app.

## Publishing walkthrough

Steps in order. Wait for each step to be confirmed before the next. Secrets are
set only through `gh secret set` from a file or a hidden prompt, never typed on a
command line or printed. Rows 1 to 3 start only after the push run of
`play-bundle.yml` on `main` (from the merge that added this file) is green.

| # | Who | Step |
|---|---|---|
| 1 | Owner | Create the upload keystore outside the repository, so the password never appears in a transcript: `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`. Keep a second copy somewhere safe. |
| 2 | Implementer | Store the keystore as a repository secret without printing it: `base64 -w0 ~/upload-keystore.jks \| gh secret set ANDROID_KEYSTORE_BASE64`. |
| 3 | Owner | Enter the two passwords at the hidden prompts: `gh secret set ANDROID_KEYSTORE_PASSWORD` and `gh secret set ANDROID_KEY_PASSWORD`. The implementer sets `ANDROID_KEY_ALIAS` to `upload`. |
| 4 | Implementer | Done (2026-11-14): the first signed `.aab` (build 181) was built by `play-bundle.yml` and handed over. The workflow now keeps no `.aab`; later versions go through "Releasing to Play" below. |
| 4a | Owner | If Play Console asks: complete identity verification and device verification for the personal account. Testing cannot start before this. |
| 4b | Implementer, then owner | In the second 8a pull request, before it is merged. Implementer: create the Turnstile widget with `cloudflare turnstile widgets create --body '{"name":"impressum","domains":["<site host>"],"mode":"managed"}'`, sending the output to a new file outside the repository and never to the terminal (it contains the widget secret); read only the site key from that file with `jq` and commit it in `impressum.html`; set `TURNSTILE_SECRET_KEY` on the Production environment with `cloudflare pages projects edit simple-math-tester --body <JSON built by jq from that file>` (type `secret_text`), again sending output to a new file. Owner: enter `IMPRESSUM_TEXT` in the Cloudflare dashboard (Pages project, Settings, Variables and Secrets, type Secret, Production). A secret reaches only the next deployment, so both are set before the merge; if one is set later, redeploy `main` with `gh workflow run flutter-checks.yml -f environment-name=prod`. After the deploy, open the live Impressum page and confirm it shows the right details. |
| 5 | Owner | In Play Console: declare trader status as non-trader when asked (the app is free and has no ads), then create the app (name, default language, "App", "Free") and accept the declarations. |
| 6 | Owner, with the implementer reading out each answer from this file | Fill "App content": privacy policy URL, ads declaration, app access, content rating questionnaire, target audience (includes children, so the Families Policy answers), Data safety, Advertising ID, and the remaining declarations. |
| 7 | Owner | Fill the store listing: texts from this file, graphics from `docs/play-store/`. |
| 8 | Owner | Done (2026-11-14): build 181 uploaded to Internal testing, Play App Signing accepted, installed from Play. |
| 9 | Owner | Testing, Closed testing: create a track, add 15 or more testers by e-mail list (12 are required; the extra ones cover opt-outs, which would restart the count for that tester), roll out, and send them the opt-in link. They must stay opted in for 14 consecutive days. |
| 10 | Owner | For every later version: publish a GitHub release (see "Releasing to Play" below). The build lands on the internal testing track; promote it to closed testing with `play-promote.yml` ("Promoting a release" below). |
| 11 | Owner | After 14 days: "Apply for production access", answer the questions about the test, then create the production release. |

## How the bundle is built

`.github/workflows/play-bundle.yml` runs on every push to `main`, by hand ("Run
workflow", no inputs) and when a GitHub release is published. With the four
`ANDROID_*` secrets it signs the bundle with the upload key; without them it signs
with a throwaway key made in the job. Every run fails if the bundle carries the
Android debug certificate and checks 16 KB page support of the APKs built from
the bundle. Pull requests build no Android or iOS app. On `main` the bundle (and
the APK and iOS app in `flutter-checks.yml`) is built, checked and discarded.

Locally, `app/android/key.properties` (git-ignored) selects the upload key:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyPassword=...
keyAlias=upload
```

Without that file, release builds are debug-signed and Gradle prints
`Release signing: debug signing (no key.properties)`.

## Releasing to Play

Pushing a version tag releases: `git tag v1.0.1 && git push origin v1.0.1`.
`play-bundle.yml` then checks the tag (`v1.2.3`, on a commit that is on `main`),
builds the bundle with that version, uploads it to the **internal testing** track
and creates the GitHub release. The build number stays run number x 10 + run
attempt, so it always grows. The `.aab` is not attached to the release.

Release notes:

- GitHub release: GitHub's automatic notes, the pull requests merged since the
  previous tag.
- Play: a 2 to 5 line summary of those notes written by DeepSeek for parents and
  children. Without `DEEPSEEK_API_KEY`, or when the call fails, Play gets the
  automatic notes instead. Either way `.github/play-release-notes.jq` removes
  Markdown, HTML, links and "by @user in ..." and keeps whole lines up to Play's
  500 characters.

One-time setup (owner, about 15 minutes; the first `.aab` must already have been
uploaded by hand, walkthrough row 8, done 2026-11-14):

1. In Google Cloud Console, create a project (for example `simple-math-tester-play`)
   and enable the **Google Play Android Developer API** for it.
2. IAM and admin, Service accounts: create a service account (for example
   `play-upload`) with no project roles. Keys, Add key, JSON: save the file outside
   the repository.
3. Play Console, Users and permissions, Invite new users: enter the **service
   account's** e-mail, not your own. It looks like
   `play-upload@<project-id>.iam.gserviceaccount.com`; copy it from `client_email`
   in the JSON key or from the Email column of the service account list. Add the app
   Simple Math Tester, give it **Release to testing tracks** (nothing else), and send
   the invitation. Nobody has to accept it.
4. Store the key without printing it:
   `gh secret set PLAY_SERVICE_ACCOUNT_JSON --repo comdotlinux/simple-math-tester < <key file>`.
   Then keep the key file somewhere safe or move it out of Downloads.

Optional, for the DeepSeek summary (the key is asked for at a hidden prompt):

```
gh secret set DEEPSEEK_API_KEY --repo comdotlinux/simple-math-tester
gh variable set DEEPSEEK_MODEL --repo comdotlinux/simple-math-tester --body deepseek-flash
```

`DEEPSEEK_MODEL` is optional (default `deepseek-flash`).

**Keep the release secrets in the `release` environment.** Only `v*` tags may
deploy to it, so a pushed branch with a changed workflow cannot read them. To move
them from the repository (each command reads a file or asks at a hidden prompt):

```
R=comdotlinux/simple-math-tester
base64 -w0 ~/upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64 --repo $R --env release
gh secret set ANDROID_KEYSTORE_PASSWORD --repo $R --env release
gh secret set ANDROID_KEY_PASSWORD --repo $R --env release
gh secret set ANDROID_KEY_ALIAS --repo $R --env release --body upload
gh secret set PLAY_SERVICE_ACCOUNT_JSON --repo $R --env release < <key file>
gh secret set DEEPSEEK_API_KEY --repo $R --env release
```

Then remove the repository-level copies of those six secrets (Settings, Secrets
and variables, Actions, Repository secrets); while a repository copy exists, any
workflow run can still read it. Push the next tag and check the release run.

Each release:

1. On `main`, pulled: `git tag v1.0.1 && git push origin v1.0.1`.
2. The "Play app bundle" run builds, uploads and creates the release; its log shows
   the Play notes, and its last notice says which version is on the internal track.
   If it fails, fix the cause and re-run the job; nothing is released until the
   upload worked. A re-run uploads a new build number with the same version.
   The first tag's GitHub notes list every pull request merged so far.
3. Promote the release to closed testing or production when ready (below).

### Promoting a release

`.github/workflows/play-promote.yml` (manual only) moves a version that is on the
internal testing track to closed testing (Play track `alpha`) or production. It
does not rebuild: it reads the internal track, takes the release named
`<version> (<build number>)` (the newest build if a tag was built twice), and
puts the same build and the same Play release notes on the target track. Start
it on the version tag, because only `v*` tags may use the `release` environment:

```
gh workflow run play-promote.yml --ref v1.1.0 -f version=v1.1.0 -f track=closed-testing
gh workflow run play-promote.yml --ref v1.1.0 -f version=v1.1.0 -f track=production -f rollout=100
```

`rollout` is a percent from 1 to 100 (default 100). Below 100 is a staged
rollout; to widen it, run the same command again with a larger percent, and 100
completes it. The run's last notice says which version is on which track at what
percent. The workflow exists only from the tag after this change on; promote
older versions in Play Console.

- Production, one time: in Play Console, Users and permissions, give the service
  account **Release to production, exclude devices, and use Play App Signing** as
  well. Without it, or without production access, the run fails and prints
  Google's error.
- A new personal developer account gets production access only after a closed
  test with at least 12 testers opted in for 14 consecutive days (walkthrough rows
  9 to 11).
- Google reviews every release on closed testing and production before users get
  it.
- Play sends no notice when a review is approved (real-time developer
  notifications cover only purchases and subscriptions), so nothing can promote
  automatically on approval. Each promotion is a manual run.

The App Store (iOS) is not set up yet.

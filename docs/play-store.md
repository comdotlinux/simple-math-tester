# Google Play: listing, declarations and publishing walkthrough

Everything the owner enters in Play Console, and the steps to publish. Play Console
menu names are written from memory; check them against the live console while
following the walkthrough. Facts behind the answers: the app's own code collects
no personal data, stores progress only on the device, has no accounts, no
analytics and no ads, and the Android release build requests no internet access
(`app/android/expected-permissions.txt` lists its only permission). Its one link
out is the Impressum entry in the settings, which opens
`https://simple-math-tester.pages.dev/impressum` in the system browser.

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
| Website | `https://simple-math-tester.pages.dev/impressum` (the Impressum; works once walkthrough row 4b is done) |
| Privacy policy URL | `https://simple-math-tester.pages.dev/privacy.html` (see below) |

The address is the Cloudflare Pages project `simple-math-tester` at its default
`pages.dev` host. During the walkthrough, open the latest production deployment
in the Cloudflare dashboard (or the deploy job's log in GitHub Actions) and
confirm the host before entering it. If a custom domain is added later, update
both URLs. Cloudflare Pages redirects `/privacy.html` to `/privacy`; both work.

### Short description (80 characters at most)

> Friendly math practice for kids: add, subtract, multiply and divide.

### Full description (4000 characters at most)

> Simple Math Tester is a friendly arithmetic workbook for children who are
> starting school math.
>
> Practise addition, subtraction, multiplication and division, alone or mixed.
> Each kind of exercise has five difficulty levels. Start at Easy, Medium or
> Hard, and the app adapts to how well you answer.
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
| Phone screenshots | At least 2 | Not yet in the folder. Capture them from the app (for example with `app/tool/screenshots_test.dart`) and add them to `docs/play-store/`. The internal track accepts the listing without final graphics. |

## App content declarations

| Declaration | Answer |
|---|---|
| Privacy policy | `https://simple-math-tester.pages.dev/privacy.html` |
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
| 4 | Implementer | Run the app bundle workflow (`gh workflow run play-bundle.yml`, then `gh run watch`), download the signed `.aab` (`gh run download`, artifact `simple-math-tester-play-bundle`, kept 3 days) and tell the owner where it is. |
| 4a | Owner | If Play Console asks: complete identity verification and device verification for the personal account. Testing cannot start before this. |
| 4b | Implementer, then owner | In the second 8a pull request, before it is merged. Implementer: create the Turnstile widget with `cloudflare turnstile widgets create --body '{"name":"impressum","domains":["<site host>"],"mode":"managed"}'`, sending the output to a new file outside the repository and never to the terminal (it contains the widget secret); read only the site key from that file with `jq` and commit it in `impressum.html`; set `TURNSTILE_SECRET_KEY` on the Production environment with `cloudflare pages projects edit simple-math-tester --body <JSON built by jq from that file>` (type `secret_text`), again sending output to a new file. Owner: enter `IMPRESSUM_TEXT` in the Cloudflare dashboard (Pages project, Settings, Variables and Secrets, type Secret, Production). A secret reaches only the next deployment, so both are set before the merge; if one is set later, redeploy `main` with `gh workflow run flutter-checks.yml -f environment-name=prod`. After the deploy, open the live Impressum page and confirm it shows the right details. |
| 5 | Owner | In Play Console: declare trader status as non-trader when asked (the app is free and has no ads), then create the app (name, default language, "App", "Free") and accept the declarations. |
| 6 | Owner, with the implementer reading out each answer from this file | Fill "App content": privacy policy URL, ads declaration, app access, content rating questionnaire, target audience (includes children, so the Families Policy answers), Data safety, Advertising ID, and the remaining declarations. |
| 7 | Owner | Fill the store listing: texts from this file, graphics from `docs/play-store/`. |
| 8 | Owner | Testing, Internal testing: create a release, upload the `.aab`, accept Play App Signing, roll out; install on one device and confirm the app starts. |
| 9 | Owner | Testing, Closed testing: create a track, add 15 or more testers by e-mail list (12 are required; the extra ones cover opt-outs, which would restart the count for that tester), roll out, and send them the opt-in link. They must stay opted in for 14 consecutive days. |
| 10 | Implementer | For every later change: run `play-bundle.yml` again (each run gets a higher build number, run number x 10 + run attempt) and hand over the new `.aab`; the owner uploads it to the closed track. |
| 11 | Owner | After 14 days: "Apply for production access", answer the questions about the test, then create the production release. |

## How the bundle is built

`.github/workflows/play-bundle.yml` runs on every push to `main` and by hand
("Run workflow", no inputs). With the four `ANDROID_*` secrets it signs the
bundle with the upload key and uploads it as an artifact; without them it signs
with a throwaway key made in the job and uploads nothing. Both paths fail if the
bundle carries the Android debug certificate, and both check 16 KB page support
of the APKs built from the bundle.

Locally, `app/android/key.properties` (git-ignored) selects the upload key:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyPassword=...
keyAlias=upload
```

Without that file, release builds are debug-signed and Gradle prints
`Release signing: debug signing (no key.properties)`.

---
name: smt
description: Load the Simple Math Tester project context (code map, build and test commands, CI workflows, release process, board workflow, pitfalls) and pick up work through the GitHub Projects board. Use at the start of any session in this repository, and before any feature, bug fix or release.
triggers:
  - smt
  - simple math tester
  - continue the work
  - what is next on the board
---

# Simple Math Tester: pick up the work

Flutter maths practice app for children. Web build at math.munich-tech.de (Cloudflare Pages), Android on Google Play (`com.linux.simplemathtester`). Repository `comdotlinux/simple-math-tester`.

`CLAUDE.md` holds the binding rules. This skill is the map and the working method. If the two disagree, `CLAUDE.md` wins; fix this file in the same pull request.

## 1. Start of every session

Run these and read the output before proposing or changing anything:

```sh
git fetch origin --tags && git status --short --branch
git log --oneline -8 origin/main
git tag --sort=-v:refname | head -3
gh pr list
gh issue list --state open
gh run list --branch main -L 6
gh project item-list 1 --owner comdotlinux -L 200 --format json \
  --jq '.items[] | select(.status != "Done") | "\(.status)\t#\(.content.number)\t\(.title)"'
```

Then read `CLAUDE.md`, and the doc for the area you will touch (section 3).

`gh` must act as the repository owner account. Check with `gh api user --jq .login`. If another account is active, do not switch accounts; start each command that uses `gh` or the git remote with `export GH_TOKEN=$(gh auth token --user comdotlinux)`. Never print the token.

## 2. Every feature and every bug goes through the board

Board: GitHub Projects **SimpleMatchTester**, https://github.com/users/comdotlinux/projects/1. No code change without an issue on it.

1. **Task:** an issue labelled `task`. For a new owner request, create it and add it to the board.
2. **Sub-issues:** split the task before work starts, each small enough for one pull request, each with Why, Work and Acceptance. A small standalone fix can be a single sub-issue.
3. **One pull request per sub-issue.** Body says `Fixes #<n>` (with the `#`). Title uses Conventional Commits, because pull requests are squash-merged and the title becomes the commit on `main`.
4. **Status:** In Progress when work starts, Review when the pull request is open, Done when merged. Close the task when all its sub-issues are closed, with a comment that names what shipped and what is left.
5. **Label `owner`:** Play Console, devices, repository settings. Do not attempt it; report what the owner has to do.

```sh
gh issue create --label task --title "..." --body "..."
gh project item-add 1 --owner comdotlinux --url <issue-url>
gh project item-edit 1 --owner comdotlinux --url <issue-url> --field Status --value "In Progress"
# link a sub-issue to its task
gh api -X POST repos/comdotlinux/simple-math-tester/issues/<task>/sub_issues \
  -F sub_issue_id=$(gh api repos/comdotlinux/simple-math-tester/issues/<sub> --jq .id)
```

`gh project item-edit` can fail without an error message. Read the status back with `gh project item-list` after setting it.

Merge rule: merge when every pull request check is green. For a visual change, save light and dark screenshots (360x640 and 1280x900) and give them to the owner; `app/tool/screenshots_test.dart` makes them.

## 3. Where things are

| Path | What |
|---|---|
| `app/` | The Flutter app |
| `functions/api/impressum.js` | Cloudflare Pages function for the Impressum |
| `functions/api/report.js`, `functions/report-allowlist.json` | Pages function that turns a report code from the app into a GitHub issue; its family and language allow-list (README, "Reports from the app") |
| `tool/` | Node tools: `translate.mjs`, `translate_listing.mjs`, `app_store.mjs` (App Store Connect API: listing, review submission), `browser_check.mjs`, their tests |
| `play/listing/` | Store texts per language for Play and the App Store, `en-US.json` is the source |
| `docs/play-store/` | Store screenshots |
| `.github/workflows/` | CI, release, translation |
| `.github/play-*.sh`, `*.jq` | Release-note and promotion scripts, with tests |

Docs to read for an area:

| Area | Read |
|---|---|
| Design, look, behaviour | `DESIGN.md` |
| Algebra and geometry, levels, how correctness is checked | `docs/question-kinds.md` |
| Strings and languages | `docs/translations.md` |
| Play Console, release, promotion, listing | `docs/play-store.md` |
| Third-party material | `docs/attributions.md` |
| Journeys (integration tests) | `app/integration_test/README.md` |
| Impressum and report functions, their secrets | `README.md` |

`app/lib/`, by job:

| File | Job |
|---|---|
| `operations.dart` | `OperationType` (add, subtract, multiply, divide, algebra, geometry), sealed `Problem` and sealed `ProblemSource`, algebra families and level tables |
| `geometry.dart`, `figure.dart`, `figure_view.dart` | Geometry families, the figure model and to-scale layout, the painter |
| `solution_steps.dart`, `hint_steps.dart`, `hint_modal.dart` | Hints for every kind, as structured steps (`EquationStep`, `FigureStep` with the `FigureParts` it highlights); the hint-step view; the in-app hint modal (after a wrong answer: Try again or Show a hint) and the nudge to try first after many hints |
| `hundredths.dart` | Parsing and formatting answers as whole hundredths |
| `math_tester_model.dart`, `rules.dart` | Game state, draws, levels, tiers, sprint |
| `report.dart`, `report_dialog.dart` | The one request: `ReportClient` (HTTP to `/api/report`), the flag and its state, the report dialog and the grown-up check |
| `progress.dart`, `progress_store.dart` | Saved progress (schema 2) and its storage |
| `problem_page.dart`, `number_pad.dart`, `question_text.dart`, `hud.dart` | The practice screen |
| `results_page.dart`, `home_page.dart`, `licences_page.dart`, `legal.dart` | History, shell, licences, privacy |
| `labels.dart`, `keys.dart`, `l10n/` | Text forms and semantics, widget keys for tests, ARB files |
| `app_theme.dart`, `slab.dart`, `celebration.dart`, `sound_player.dart` | Look, confetti, sound |

Tests: `app/test/` (unit and widget), `app/integration_test/journeys/` (journeys, taps go through keys in `keys.dart`), `app/tool/screenshots_test.dart` (screenshots).

## 4. Build and check locally

Tool versions are pinned in `mise.toml` (Flutter 3.50.0, Node). Prefix with `mise exec --` or put the pinned Flutter first on `PATH`.

```sh
cd app
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
flutter test integration_test -d linux      # add xvfb-run -a when headless
cd .. && node --test tool/functions_test/ tool/translate.test.mjs tool/translate_listing.test.mjs tool/app_store.test.mjs
node tool/translate_listing.mjs --check
npm ci --prefix tool && tool/node_modules/.bin/biome ci .   # JS lint and format; biome check --write . fixes
```

Publish the branch early. CI is the source of truth; run quick local checks alongside it.

## 5. What CI does

| Workflow | Runs on | Does |
|---|---|---|
| `flutter-checks.yml` | pull requests, pushes to `main`, manual | Analyze, test, web build (the required check "Analyze, test and build web"), Linux and Chrome journeys, offline web check, Pages function tests. Deploys the web build on `main`. Android APK and Android emulators run only on manual runs; the iOS build and iOS simulator (macOS runners) only on a manual run with `-f ios=true`. |
| `translate.yml` | pushes to `main` that change `app_en.arb`, `play/listing/en-US.json` or the two translate tools, manual | Translates new and changed strings and the store listing, opens or updates one pull request from `translations/auto`, starts the Flutter checks on that branch itself |
| `play-bundle.yml` | `v*` tags, manual | Builds and signs the bundle, checks permissions, signer and 16 KB pages. A tag run uploads to the Play internal track and creates the GitHub release. A manual run uploads nothing. |
| `ios-bundle.yml` | `v*` tags, manual | Archives and signs the IPA (automatic signing with the App Store Connect API key). A tag run uploads to TestFlight. A manual run uploads nothing. See `docs/app-store.md`. |
| `play-promote.yml` | manual | Moves a version from internal to closed testing or production, and writes release notes |
| `play-listing.yml` | manual | Pushes store texts and screenshots to Play |
| `app-store-review.yml` | manual | Puts a version's TestFlight build on its App Store version, writes What's New and submits it for App Review; `dry-run` (default) only lists what it would do |
| `app-store-listing.yml` | manual | Writes store texts and iPhone and iPad screenshots of every language to the App Store version being prepared (`tool/app_store.mjs`, `release` environment) |

`main` takes changes only through pull requests with the required check green. Only admins can create `v*` tags.

## 6. Release

Order matters. Do not skip a step.

1. Every sub-issue of the task is merged. `main` is green.
2. The Translate run for the last change to `app_en.arb` is green and its pull request is merged. Otherwise other languages ship English text.
3. Start the pre-release checks on `main`, and wait until all are green:
   ```sh
   gh workflow run play-bundle.yml --ref main
   gh workflow run ios-bundle.yml --ref main
   gh workflow run flutter-checks.yml --ref main -f environment-name=none -f ios=true
   ```
   `-f ios=true` adds the unsigned iOS build and the iOS simulator journeys. Leave it out on every other manual run: macOS minutes are scarce (#223).
4. Pick the version from the commits since the last tag: any `feat` gives a minor bump, `feat!` or `BREAKING CHANGE` a major one, otherwise a patch.
5. `git fetch origin --tags`, confirm `origin/main` is the commit you checked, then `git tag vX.Y.Z origin/main && git push origin vX.Y.Z`.
6. Wait for the `play-bundle.yml` run of the tag: both jobs green, GitHub release exists. Wait for the `ios-bundle.yml` run of the tag too: green means the build is in TestFlight (App Store Connect processes it next).
7. Promote: `gh workflow run play-promote.yml --ref main -f version=vX.Y.Z -f track=closed-testing`. Its last notice names the version, build number and track. For the App Store, once the build is processed in TestFlight: `gh workflow run app-store-review.yml --ref main -f version=vX.Y.Z` (dry run), read its log, then again with `-f dry-run=false`.
8. Store text or screenshots changed: `gh workflow run play-listing.yml` and `gh workflow run app-store-listing.yml`. Ask the owner first; they write to the public listings.
9. Close the task and set the board to Done.

Tagging, promoting, submitting for App Review and pushing the listings reach real users. Do them only when the owner asked for a release.

## 7. Invariants that are easy to break

- **Maths is checked by code, never by a model.** Each question comes from a pure build over a finite range. An independent oracle (`app/test/oracle.dart`, `app/test/geometry_oracle.dart`) reads only what the child sees and checks every question and every hint step in `exhaustive_test.dart` and `geometry_test.dart`. A new family needs its count added, mutation tests that must fail, and hint recomputation. Never weaken an oracle check to make a test pass. A family's space only grows (saved params must stay valid), so a layout change must keep every existing problem reading on every canvas in `geometry_test.dart`; the layout rules there (labels next to their own angle and nearer its arc than any other, arcs at one point apart, the figure filling its canvas) run on every problem.
- **Hints of algebra and geometry keep one shape:** what is asked, the idea and why, one small calculation a step, then the answer and its check; sentences of at most 15 English words. A geometry step's `FigureParts` are the parts its calculation reads; `hint_style_test.dart` and the geometry hint tests check both, so a new family's hint is written in that shape.
- **Answers are whole hundredths.** No floating point in an answer or a comparison (`3.14 * 3 * 3` is `28.259999999999998` in doubles).
- **Variant and family names are saved with each attempt.** Never rename one. Saved progress stays schema 2; new data is an additive field; entries that do not decode are kept and written back unchanged.
- **Textbook rows** (`*_known_answers_test.dart`) take the expected value from the printed answer only. Never compute or recall one. Sources allowed: Illustrative Mathematics and Open Up Resources 6-8 (CC BY 4.0), with attribution.
- **Strings:** English only, in `app/lib/l10n/app_en.arb` with an `@` description; copy the English text into the other ARB files without source hashes. Numbers are placeholders, not literals. The Translate workflow replaces the copies on `main`.
- **Store listing:** a digit added to `play/listing/en-US.json` fails `translate_listing.mjs --check` until the translations land, which happens only after the merge.
- **INTERNET only for a report sent after the grown-up check** (`app/android/expected-permissions.txt`, issue #150). The app makes no other request: marking a question is local, a report needs the grown-up check, holds no free text, and is never queued or retried on its own. Tests and journeys inject a fake `ReportClient`; none may call the real endpoint.
- **New kinds** are off by default, start at level 1 whatever the tier, and are not drawn in sprints. `arithmeticKinds` is the one set that decides this.
- **No file is deleted.** Move a file that must go to a temporary location for the owner. Write logs and screenshots to new, uniquely named files.
- **No secrets, keystore or Impressum text** in output, logs or commits. Secrets are set only with `gh secret set`.
- **No session links or agent attribution** in commits, pull requests or comments.

## 8. Known traps

- The Translate pull request is written by a bot, and the `main` ruleset wants an extra approval for it. With all checks green it still shows as blocked. The owner approves it, or allows an admin merge for that pull request; ask each time. An agent's `gh pr merge --admin` can be blocked by the session's permission check; then the owner runs `! gh pr merge <n> --squash --admin` in the session.
- Translations can break layouts that pass in English: the every-language tests on `translations/auto` are where long labels (Malayalam, Ukrainian, German at text scale 2) first overflow. Fix the layout on `main` (wrap or scale the label), then run `gh workflow run translate.yml --ref main` so the branch picks it up.
- `play-listing.yml` shoots every scene of `app/tool/screenshots_test.dart` in every language as a matrix of language groups of three (`tool/screenshot_groups.mjs`, one `phone-screenshots-<n>` artifact each; the App Store workflow adds the device: `app-store-screenshots-<device>-<n>`), so each job stays far below the 60-minute limit. A branch run only shoots. The listing push needs the Translate pull request merged first.
- Visual changes (practice page, pad, figures): the agent stops at green checks with light and dark screenshots; the owner looks before the merge.
- A manual `flutter-checks.yml` run on a branch builds Android and runs the emulators (about 30 minutes) but uses no macOS runner unless `-f ios=true` is given. A pull request run does neither.
- Several pull requests that touch `operations.dart`, `solution_steps.dart`, `problem_page.dart`, `progress.dart` or `app_en.arb` at once will conflict. Keep diffs local and rebase onto `origin/main` when it moves.
- Widget tests that start with a default `Progress(tier: ...)` show the one-time new-kind card above the toggles. Pass `seenKinds: [for (final k in OperationType.values) k.name]` when the old layout is needed.
- A shell loop that waits with `pgrep -f "<text>"` matches itself and never ends. Use `gh run watch <id> --exit-status` or `gh pr checks <pr> --watch`.
- iOS signing: the App Store Connect API key must have the Admin role (cloud signing; App Manager gives "Cloud signing permission error"). `ios-bundle.yml` archives unsigned and signs at export. Check the signer with `codesign -dvv` (Authority lines appear only from `-dvv`).
- A rerun of a tag run uses the workflow file as it was at the tag. A workflow fix needs a new tag.
- Widget and integration tests: put `pumpAndSettle` between `ensureVisible` and `tap`. The scroll pins the End header (a setState), so the control moves one frame later.
- Do not push to a pull request while a merge-on-green job waits for it: it restarts every check. The GraphQL rate limit (and its secondary limit) is shared by every agent and polling loop; poll with REST (`gh api repos/.../commits/<sha>/check-runs`) and merge with `gh api -X PUT repos/comdotlinux/simple-math-tester/pulls/<n>/merge -f merge_method=squash`. In zsh, `for p in $list` does not split on spaces; use an array or literal words.
- App Store screenshots: the required slots are iPhone 6.3" (1206x2622) and iPad 13" (2048x2732); iPhone 6.9" (1290x2796) is optional. Apple copies them to each new version, so a release needs no new shoot. `app-store-listing.yml` takes about 45 minutes with screenshots; if only the upload fails, rerun with `-f screenshots-from-run=<run id>` (artifacts last 7 days), or `-f screenshots=false` for texts only. With no version in preparation (after a release went live) it stops; add `-f version=X.Y.Z` to create that version first.
- No bundled font has U+25A1 or U+2192. The blank (a line on the baseline) and the arrow are drawn widgets; tests fail if those characters reach a `RichText` or a semantics label.

## 9. Before saying a task is done

- Pull request merged, issue closed, board status read back as Done.
- `main` checks green on the merge commit.
- Report what was not checked (real device, other languages, journeys not run locally) and what the owner has to do.

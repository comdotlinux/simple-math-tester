# Simple Math Tester

Flutter arithmetic practice app for children (`app/`), web build on Cloudflare Pages (math.munich-tech.de, `functions/` for the Impressum), Android release on Google Play (`com.linux.simplemathtester`). GitHub Actions in `.github/`, Node tools in `tool/`, docs in `docs/`.

## Picking up work

Run the `/smt` skill (`.claude/skills/smt/SKILL.md`) at the start of a session: it holds the code map, the build and test commands, what each workflow does, the release steps and the start-of-session checklist. Every feature and every bug goes through the board below.

## How work is tracked

Work is planned on the GitHub Projects board **SimpleMatchTester**
(https://github.com/users/comdotlinux/projects/1), linked to this repository.

- **Task:** an issue labelled `task`, on the board. The owner adds tasks (or board drafts) to pick up later.
- **Sub-issue:** a task is split into GitHub sub-issues before work starts, each small enough for one pull request.
- **Pull request:** exactly one PR per sub-issue. Its description says `Fixes #<sub-issue>`, so merging closes the issue.
- **Board status:** Todo, In Progress, Review, Done. Set In Progress when work on a sub-issue starts; merged PRs and closed issues move to Done.
- **Label `owner`:** work only the owner can do (Play Console, devices, repository settings). Do not attempt it; report what the owner has to do.
- New owner requests: create the `task` issue and its sub-issues, add them to the board, then work them one PR at a time.

## Rules for every change

- Change only this repository, and on GitHub only this repository.
- Never delete files or directories (no `rm`, `rmdir`, `find -delete`, `truncate`, `unlink`). Files that must go are moved to a temporary location for the owner to remove; write logs and snapshots to new, uniquely named files.
- Never print, log or commit secrets, the keystore or the Impressum text. Secrets are set only with `gh secret set`.
- No session trailers or links in commits and PR descriptions.
- Push first; CI (`flutter-checks.yml`) is the source of truth. `main` takes changes only through PRs with "Analyze, test and build web" green.
- Visual changes: show the owner screenshots before merging. Other PRs: merge when green.
- New or changed English strings go in `app/lib/l10n/app_en.arb` (with `@descriptions`); other languages may be hand-written but are replaced by the Translate workflow on `main` (see `docs/translations.md`). Do not add source hashes for hand-written translations.
- The Android release has the INTERNET permission only for a report a grown-up sends after the grown-up check (`app/android/expected-permissions.txt`, issue #150); the app makes no other request. Marking a question sends nothing; no report is sent without the grown-up check, no free text is ever sent, and nothing is sent later on its own (see the privacy policy in `app/lib/legal.dart` / `app/web/privacy.html`).
- Commits and PR titles use Conventional Commits: `feat:`, `fix:`, `docs:`, `ci:`, `test:`, `refactor:`, `chore:` (optional scope, e.g. `feat(android): ...`). PRs are squash-merged, so the PR title becomes the commit on `main`.
- Version bumps follow the commits since the last tag: any `feat` -> minor (`v1.1.4` -> `v1.2.0`), a breaking change (`feat!:` or `BREAKING CHANGE:`) -> major, otherwise patch.
- Releases: a `v*` tag on `main` builds and uploads to the Play internal track (`play-bundle.yml`); `play-promote.yml` promotes; `play-listing.yml` pushes store texts and screenshots. Pull requests and pushes to `main` build no Android or iOS app, so before creating a `v*` tag start both manual runs on `main` (`gh workflow run play-bundle.yml --ref main` and `gh workflow run flutter-checks.yml --ref main -f environment-name=none`), wait until both are green, and only then create the tag; if either is red, fix it on `main` first.

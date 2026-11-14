# Integration journeys

The real app, built once per device, driven through its own screens.

## The rule

Every new feature or bug fix adds or extends a named journey in its feature
file, and updates the inventory below. A pull request without one is not done.

## Layout

- `app_test.dart`: the single entry point. It only calls one function per
  feature. One target means one build per device, and `flutter drive` in the
  Chrome job takes exactly one target.
- `journeys/<feature>_journeys.dart`: one `group('<feature>', ...)` of short
  `testWidgets`, each named as behaviour a player can see.
- `support/helpers.dart`: starting from a saved document, restarting, release-safe
  typing, finders for the pad and toggles, `inHistory`, `semanticsNodesLabelled`,
  and `startHarness`.

Every test starts from its own saved document (`startWith` writes it through
the real `SharedPreferencesStore`, then runs `main()`), so tests never depend
on each other or on their order. `startHarness` runs the real `MathTesterApp`
widget on a model the test builds. Use it only where the real entry point
cannot get there in reasonable time: a test clock for the sprint timer and a
recorder for vibrations.

## Running

From `app/`:

```sh
mise exec -- flutter test integration_test -d linux          # add xvfb-run -a when headless
mise exec -- flutter test integration_test -d <device id>    # Android emulator, iOS simulator
mise exec -- flutter test integration_test/app_test.dart --plain-name 'operations' -d linux
```

CI (`.github/workflows/flutter-checks.yml`) runs the same entry point on Linux
(debug, `xvfb-run`), the iOS simulator and the Android emulator (also in
airplane mode), and in release mode in Chrome:

```sh
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart -d web-server --browser-name=chrome --release
```

The test names and counts show in each job's log. The offline web check of
phase 10 is not a Flutter journey. It lives in
[`tool/browser_check.mjs`](../../tool/browser_check.mjs).

## Release-build traps

The Chrome job runs a release build, where asserts and debug-only data are gone:

- Never call `tester.enterText`. Integration tests have no fake text input, and
  in release the field stays empty. Use `typeAnswer`/`submit`, which call
  `EditableTextState.updateEditingValue` like a real keyboard does. Input
  formatters still apply.
- Never use `find.bySemanticsLabel`. It reads `debugSemantics`, which is null in
  release. Use `semanticsNodesLabelled`, which walks the live semantics tree.
- The answers list is lazy. Rows below the fold do not exist yet, so find them
  with `inHistory`, which scrolls. Check rows from top to bottom.
- Phones hide much of the page. Use `tapVisible`/`tapKey`, which call
  `ensureVisible` before tapping. Below 700 px of height the field, the
  feedback and a dense pad dock at the bottom, and Next moves into the feedback
  strip after a check.
- A save is written asynchronously. Read it back with `waitForSaved`, and
  restart with `restartWhenSaved`.

## Feature inventory

Built from reading `lib/`. Each row needs at least one journey.

| Feature | File | Journeys |
| --- | --- | --- |
| Tier picker on first start | `tier_picker_journeys.dart` | a first start asks how hard to start and hides practice; choosing a tier starts every operation at its level |
| "Progress can't be saved" notice | `tier_picker_journeys.dart`, `persistence_journeys.dart` | a start without saving shows the can't-be-saved notice; data from a newer version is kept and not overwritten |
| Practice: check, retry, Next, skip | `practice_journeys.dart` | a wrong first answer is saved before Next; a retry after a wrong answer can still be right; a correct first answer is saved as correct; Next after a check shows a new question and adds no row; Next without an answer is saved as skipped; answers from play are kept in order: wrong, right, skipped; an empty answer asks for a number and records nothing; typing after feedback clears it |
| Number pad | `number_pad_journeys.dart` | each digit key types its digit; Delete removes the last digit; Check with nothing typed says enter a number first; an answer typed on the pad is checked from the pad; only digits reach the answer field |
| Keyboard switch (pad or system keyboard) | `number_pad_journeys.dart` | the keyboard button swaps the pad for the keyboard and back; with the pad, tapping the answer field opens no system keyboard; the keyboard button asks for one |
| Phone layout after a check | `number_pad_journeys.dart` | on a phone a check keeps question, answer, feedback and Next on screen |
| Hints / solution steps | `hints_journeys.dart` | Hint shows the first step and becomes Next step; before a check every step but the answer can be opened; a wrong first check opens the first step; after a valid check every step, the answer too, can open; hints used before Next are saved with the skip |
| Operation toggles (+ − × ÷) | `operations_journeys.dart` | only `<signs>`: Next shows only `<signs>` questions (all 15 non-empty selections, 20 draws each); the last selected operation cannot be turned off; turning an operation back on adds it to the draws |
| My answers page | `history_journeys.dart` | with no answers it shows the empty state and no stats; the empty state's Practice button returns to the question; the stats card shows saved totals once there are answers; an incorrect row shows your answer and the expected one; a correct row shows your answer; a skipped row says no answer was entered; a long history scrolls to its last answer; going back to Practice keeps the current question |
| Game loop (header) | `game_loop_journeys.dart` | a correct first answer adds XP to the header; a correct answer after a hint earns half the XP; the combo grows with right answers and a wrong one ends it; reaching the next level plays the celebration; the tenth right answer of the day fills the goal and grows the streak; a new day empties the goal ring and a missed day ends the streak; a goal reached yesterday keeps the streak today; right answers raise the operation's level |
| Sprint | `sprint_journeys.dart` | starting a sprint shows the countdown and hides practice extras; a sprint answer moves straight on and adds to the score; leaving for My answers ends the round, shows the result and saves the best; a lower score keeps the saved personal best; when the time runs out the round ends with its result |
| Settings sheet (gear) | `settings_journeys.dart` | the gear opens the settings sheet and a tap outside closes it; choosing another tier resets levels and draws a new question; tapping the current tier only closes the sheet |
| Vibration switch | `settings_journeys.dart` | the Vibration switch is saved; with Vibration off the pad keys stop buzzing |
| Sound switch | `settings_journeys.dart` | the Sound switch stays hidden until the app plays sound (phase 7 adds its journeys) |
| Light / dark theme | `settings_journeys.dart` | the app follows the system light or dark setting (the app has no in-app theme choice yet) |
| Saving and restart | `persistence_journeys.dart` | restart shows the saved history and selection; a restart keeps answers, selection, tier and switches; the operation selection survives a restart |
| Unreadable saved data | `persistence_journeys.dart` | unreadable saved data is backed up and the app starts fresh |
| Offline web app | `tool/browser_check.mjs` | not a Flutter journey (phase 10) |

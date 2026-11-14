# Integration journeys

The real app, built once per device, driven through its own screens.

## The rule

Every new feature or bug fix adds or extends a named journey in its feature
file, and updates the inventory below. A pull request without one is not done.

## Finders

Tests find widgets by what they are, not by what they say, so a change of
copy or layout does not break them. This holds here and in `test/`.

1. Every tap, navigation and `ensureVisible` goes through a `Key` from
   `lib/keys.dart` (`tapKey`, `tapVisible(tester, find.byKey(...))`,
   `inHistory(tester, find.byKey(historyRowKey(i)))`). Never tap by
   `find.text`, `find.byTooltip`, `find.byIcon` or `find.widgetWithText`.
   A control without a key gets one in `lib/keys.dart`.
2. Assertions find widgets by key and compare them with model values or
   shared values from `lib/`: `textOf(tester, key)` with `showsNumber(n)` or
   `showsXp(xp)`, `Tier.label`, `OperationType.label`, `statsColumns`.
   Literal copy stays only where the wording itself is the behaviour:
   feedback messages, the Skip / Next question / Check answer / Hint / Next
   step labels, a history row's verdict and answer lines, the sprint's mix
   sentence, and semantics or tooltip labels. Each file with such literals
   says so in a one-line comment.

## Layout

- `app_test.dart`: the single entry point. It only calls one function per
  feature. One target means one build per device, and `flutter drive` in the
  Chrome job takes exactly one target.
- `journeys/<feature>_journeys.dart`: one `group('<feature>', ...)` of short
  `testWidgets`, each named as behaviour a player can see.
- `support/helpers.dart`: starting from a saved document, restarting, release-safe
  typing, finders for the pad and toggles, `openPad`/`closePad`/`isPhone`,
  `textOf`, `showsNumber`, `showsXp`, `inHistory`, `semanticsNodesLabelled`,
  and `startHarness`.

Every test starts from its own saved document (`startWith` writes it through
the real `SharedPreferencesStore`, then starts the app as `main()` does, with
a `SilentSoundPlayer`), so tests never depend
on each other or on their order. `startHarness` runs the real `MathTesterApp`
widget on a model the test builds. Use it only where the real entry point
cannot get there in reasonable time: a test clock for the sprint timer and
recorders for vibrations and sounds.

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
  with `inHistory`, which scrolls. The newest answer is on top. Check rows from top to bottom. The list
  also loads 20 answers at a time as it scrolls; `inHistory` keeps scrolling
  through those loads.
- Phones hide much of the page. Use `tapVisible`/`tapKey`, which call
  `ensureVisible` before tapping. Below 700 px of height the field, the
  feedback and a dense pad dock at the bottom, and Next moves into the feedback
  strip after a check, where it reads "Next" (its label is "Next question").
- Phones (shortest side under 600) start with the system keyboard, larger
  screens with the pad. A journey that uses the pad calls `openPad` first, one
  that needs the system keyboard calls `closePad`; both do nothing where that
  input is already shown, so the same journey runs on the phone-sized
  emulator and simulator and on desktop-sized Linux and Chrome. With the
  system keyboard a phone below 700 px docks the field, Check and the
  feedback at the bottom, above the keyboard.
- A save is written asynchronously. Read it back with `waitForSaved`, and
  restart with `restartWhenSaved`.

## Feature inventory

Built from reading `lib/`. Each row needs at least one journey.

| Feature | File | Journeys |
| --- | --- | --- |
| Tier picker on first start | `tier_picker_journeys.dart` | a first start asks how hard to start and hides practice (it offers Easy, Medium, Hard, Harder); choosing a tier starts every operation at its level; choosing Hard starts every operation at level 4; choosing Harder starts every operation at level 5; a saved old Hard tier restarts as Harder with levels kept |
| "Progress can't be saved" notice | `tier_picker_journeys.dart`, `persistence_journeys.dart` | a start without saving shows the can't-be-saved notice; data from a newer version is kept and not overwritten |
| Practice: check, retry, Next, Skip | `practice_journeys.dart` | a wrong first answer is saved before Next; a retry after a wrong answer can still be right; a correct first answer is saved as correct; Next after a check shows a new question and adds no row; Next without an answer is saved as skipped; answers from play are kept in order: wrong, right, skipped; an empty answer asks for a number and records nothing; typing after feedback clears it |
| Answer-first flow (Enter, focus, Skip) | `practice_journeys.dart`, `number_pad_journeys.dart`, `settings_journeys.dart`, `history_journeys.dart`, `sprint_journeys.dart`, `hints_journeys.dart` | Enter checks the answer and a second Enter shows the next question; a new answer after a wrong check is checked, not skipped; the answer field keeps the focus after a check and after Skip or Next; the button says Skip before a check and Next question after; pressing Check twice checks, then moves on; closing settings and going back to Practice focus the answer again; in a sprint Enter checks and moves on once; a hint tap keeps the focus on the answer |
| Default input per screen size | `number_pad_journeys.dart` | a phone starts with the system keyboard, a larger screen with the pad |
| Number pad | `number_pad_journeys.dart` | each digit key types its digit; Delete removes the last digit; Check with nothing typed says enter a number first; an answer typed on the pad is checked from the pad; only digits reach the answer field |
| Keyboard switch (pad or system keyboard) | `number_pad_journeys.dart` | the keyboard button swaps the pad for the keyboard and back; with the keyboard, Enter checks the typed answer; with the pad, tapping the answer field opens no system keyboard; the keyboard button asks for one (see below for what each device proves) |
| Phone layout after a check | `number_pad_journeys.dart` | on a phone a check keeps question, answer, feedback and Next on screen (with the pad); on a phone with the system keyboard, Enter checks, Enter again moves on, and question, answer, feedback and Next stay above the keyboard |
| Hints / solution steps | `hints_journeys.dart` | Hint shows the first step and becomes Next step; before a check every step but the answer can be opened; a wrong first check opens the first step; after a valid check every step, the answer too, can open; hints used before Next are saved with the skip |
| Operation toggles (+ − × ÷) | `operations_journeys.dart` | only `<signs>`: Next shows only `<signs>` questions (all 15 non-empty selections, 20 draws each); the last selected operation cannot be turned off; turning an operation back on adds it to the draws |
| My answers page | `history_journeys.dart` | with no answers it shows the empty state and no stats; the empty state's Practice button returns to the question; the stats card shows saved totals once there are answers; the stats table shows each operation's accuracy and level; an incorrect row shows your answer and the expected one; a correct row shows your answer; a skipped row says no answer was entered; a long history loads more on scroll and keeps stats pinned (answers show newest first and load 20 at a time with a loading row, the oldest one is followed by the end marker, scrolled down the stats are a compact bar still on screen, back at the top the full card shows); going back to Practice keeps the current question |
| Game loop (header) | `game_loop_journeys.dart` | a correct first answer adds XP to the header; a correct answer after a hint earns half the XP; the combo grows with right answers and a wrong one ends it; reaching the next level plays the celebration; the tenth right answer of the day fills the goal and grows the streak; a new day empties the goal ring and a missed day ends the streak; a goal reached yesterday keeps the streak today; right answers raise the operation's level |
| Sprint | `sprint_journeys.dart` | starting a sprint shows the countdown and hides practice extras; a sprint answer moves straight on and adds to the score; leaving for My answers ends the round, shows the result and saves the best; a lower score keeps the saved personal best; when the time runs out the round ends with its result |
| Settings sheet (gear) | `settings_journeys.dart` | the gear opens the settings sheet and a tap outside closes it (`closeSettings` taps the barrier above the sheet, or uses system back when the sheet fills the screen); the sheet lists Easy, Medium, Hard and Harder; choosing another tier resets levels and draws a new question; tapping the current tier only closes the sheet |
| Privacy and Impressum (settings) | `settings_journeys.dart` | Privacy shows the privacy policy inside the app; Impressum asks the browser for the production Impressum (`startHarness(openLink:)` takes a recording opener, so no journey opens the real page) |
| Vibration switch | `settings_journeys.dart` | the Vibration switch is saved; with Vibration off the pad keys stop buzzing |
| Sound switch | `sound_journeys.dart` | the Sound switch shows in settings, on by default; turning Sound off is saved and survives a restart; with Sound off no sound plays; with it on, one per checked answer (`startHarness(sounds:)` takes a counting player; every other journey starts with `SilentSoundPlayer`) |
| Light / dark theme | `settings_journeys.dart` | the app follows the system light or dark setting; choosing Dark makes the app dark and survives a restart; System follows the device again |
| Comfortable / compact layout | `settings_journeys.dart` | choosing Compact shows dense answer rows and survives a restart; Comfortable brings the cards back |
| Saving and restart | `persistence_journeys.dart` | restart shows the saved history and selection; a restart keeps answers, selection, tier and switches; XP and a streak earned in play are shown again after a restart; the operation selection survives a restart |
| Unreadable saved data | `persistence_journeys.dart` | unreadable saved data is backed up and the app starts fresh |
| Offline web app | `tool/browser_check.mjs` | not a Flutter journey (phase 10) |

### What the keyboard journey proves on each device

"a phone starts with the system keyboard, a larger screen with the pad"
follows the device: the Android emulator and the iOS simulator are phone
sized, so there it proves the system keyboard default (`number`); Linux and
Chrome run at desktop size, so there it proves the pad default (`none`). The
other keyboard journeys open the pad or the keyboard first with
`openPad`/`closePad`, so they prove the same on every device.

"with the pad, tapping the answer field opens no system keyboard" checks two
things. The keyboard type (`none` with the pad, `number` without it) is proven
on every device. On a phone it also proves that the keyboard button closes
the soft keyboard the app opened at start. The zero keyboard-height check (`viewInsets.bottom == 0`) only
means something on the Android emulator, which shows a soft keyboard. Linux
and Chrome have no soft keyboard, and the iOS simulator uses the Mac's
hardware keyboard by default, so there it passes trivially. The CI emulator
(`reactivecircus/android-emulator-runner` v2.38.0, no keyboard or animation
inputs set) uses the action's defaults: `enable-hw-keyboard: false`, so no
`hw.keyboard=yes` is written and the soft keyboard shows, and
`disable-animations: true`, which sets the three animation scales to 0.

"on a phone with the system keyboard ..." measures against the real keyboard
inset: on the Android emulator the soft keyboard is up, elsewhere the inset
is 0 and it checks the docked layout without one.

Known limit: on iOS web (Safari) the system keyboard opens only after the
player taps the answer field, because Safari opens it only for a user
gesture; the app's autofocus cannot open it. No CI job runs iOS web.

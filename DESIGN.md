# Design

## Source of truth
Active · 2026-11-14. Practice and My answers on web, iOS and Android; Google Play
is the first store target. User approved playful learning, required native mobile
support, then approved the engagement plan that replaces the 2026-11-13 calm brief.
Evidence: the engagement plan approved on 2026-11-14 (a local planning file, not
in the repository), `README.md`,
`app/lib/{main,home_page,problem_page,results_page}.dart`, existing tests, platform
projects and `.omx/plans/modernize-flutter-app.md` (history of the earlier redesign).
No existing brand assets, screenshots or design brief were supplied.

## Brand
**A little practice. A big discovery.** An inviting math workbook that rewards real
progress. Warm, curious, optimistic. Relaxed practice has no timer, no
scores-as-punishment and no leaderboard. Speed is opt-in: a 60-second sprint sits
beside it. Distinctive motif: oversized arithmetic marks and heavy numerals.

## Product goals
Make answering and reviewing math feel clear and rewarding, and bring a child back
because they are getting better. Four operations, chosen by the player. Five
difficulty levels per operation, starting at Easy, Medium or Hard and adapting to
accuracy. Combo, XP, player levels, a daily goal and a daily streak reward progress.
Retry and skip behavior stay. Progress and the last 200 answers are saved on the
device. No accounts, cloud features or leaderboards. Success means a child can
enter, check, retry and move on without losing input or context, and sees progress
that survives closing the app.

## Engagement principle
Mastery, not compulsion. Every reward follows real arithmetic progress; sessions
stay short and challenge stays fair. The audience includes children, so the product
excludes guilt messaging, loss-framed nags, push notifications, ads, and paid or
random rewards. A lapsed streak shows 0 with no message; the best streak stays
visible in stats.

## Privacy and trust
Works offline: fully on native, on web after one online visit. No analytics; nothing
leaves the device. Settings holds an Impressum and a privacy entry.

## Personas and jobs
Everyone from school beginners to adults practicing arithmetic, with a parent or
teacher possibly nearby. The player picks a starting tier; difficulty then adapts
per operation, so advanced questions appear only after the player earns them.
Phones and tablets are first-class; desktop supports keyboard-first practice.

## Information architecture
Two destinations: **Practice** and **My answers**. Practice centers one problem and
one answer field, with operation selection (at least one stays on) and the sprint
mode; a header shows the daily streak, daily goal, XP with level, and combo.
My answers shows stats and a chronological review of the last 200 answers. Settings
(starting tier, sound, haptics, Impressum, privacy) is a secondary sheet, not a
third destination. Keep the current question/draft when switching destinations.
A new problem is drawn after a reload.

## Design principles
1. One obvious next action; secondary actions stay visually quieter.
2. Celebrate effort without hiding errors; every status has words and an icon.
3. Math stays readable; decoration never competes with the equation.
4. Adapt layout, not functionality, across platforms and text scales.
5. Juice never costs accessibility: motion, sound and haptics are optional or
   reducible, and both themes keep full contrast.

## Visual language
- Two themes follow the system setting. Light playful: warm sunny page `#FFF6E3`,
  white cards, navy ink `#18213B` for text, outlines and slabs. Dark neon: near-black
  page `#0B0F17`, card `#161C29`, warm white ink `#F5F2E9`, aqua outlines `#5CE1E6`
  over deep teal slabs `#1C5A66`. Flat solid colours, no purple, no gradients.
- Colour has one job in both themes: yellow primary action, blue operations, green
  correct and daily goal, tomato wrong, orange streak flame, teal XP, lime combo,
  cyan sprint. Accents are fills; text and icons on them use their `on` colour
  (navy in light, near-black in dark). Every pair is listed in `contrastPairs`.
- Depth: 2px outlines and a hard 5px slab below raised cards and buttons, no blur.
  A pressed button sinks to 1px. Unselected toggles sit flat on a sunken fill.
- Bundled Roboto 400/500/700 only. Question 64px Bold with tabular figures; titles
  36px Bold; body at least 16px; avoid uppercase paragraph text. Weight and scale
  carry hierarchy.
- Spacing 8/12/16/24/32/48; radii 28px cards, 18px controls.
- Decorative arithmetic shapes made with native widgets, excluded from semantics.
- Feedback motion (pop on correct, shake on wrong, XP count-up, particle burst on
  level-up and goal) stays brief; zero duration under disableAnimations.
- Sound has a switch; haptics have a switch. Both default on. The Sound switch
  shows in settings only once sound plays (`soundPlays`).

## Components
`app/lib/app_theme.dart` owns colours, shape values and every component theme; the
`AppTokens` roles exist once per theme and no widget names a colour. `Slab`
(`app/lib/slab.dart`) is the one shared widget: the hard slab under a card or
button. Adaptive navigation shell, game-style header (flame, goal ring, combo, XP
bar), question card with an operation band, one row of four operation toggles,
answer field, feedback strip, hint steps, sprint card, stats chips and result rows
share tokens. Buttons have minimum 48px height; focus thickens their edge to 4px ink.
The on-screen number pad (`app/lib/number_pad.dart`) has digits in two rows of five,
then Delete and a wide Check key, all slab buttons at least 48px. It edits the same
text field, which keeps focus and accepts digits only. Phone-height pages dock the
field, a compact feedback strip (which carries Next after a check) and a denser pad
together below the page, and the question card drops its band, so the question,
answer, feedback and Next stay on screen; taller pages dock the pad alone below the
page; pages 700px and wider dock it
beside the practice column; when docking would squeeze the question (short screens,
large text) it sits under the field, above the feedback, so a message never moves a
key. A keyboard button on the field hides the pad and opens the system keyboard, so
dictation and IME stay reachable; a hardware keyboard always types and Enter checks.
There is one Check button, moved into the pad while it shows. `padReplacesKeyboard`
is the one per-platform switch for platforms where the soft keyboard cannot be kept
closed. The celebration (`app/lib/celebration.dart`) is flat outlined confetti thrown
from both side edges, clear of the question.

## Accessibility
Target WCAG AA contrast in both themes: 4.5:1 normal text, 3:1 large text/UI
boundaries. Preserve system text scaling, focus outlines, semantic labels, logical
tab order and live feedback announcements. No color-only status. Touch and keyboard
both submit. Respect reduced motion. Safe areas and keyboard insets remain usable on
mobile; header, pad and sprint card stay inside the safe area.

## Responsive behavior
Below 800 logical pixels: compact header, bottom navigation, stacked content.
At/above 800: spacious navigation rail, bounded centered main content. Use available
constraints and scrollable content, not fixed page heights. At 200% text scale,
navigation can use the compact layout. Test 320/390/600/768/800/1440 widths,
short viewports, keyboard insets and 200% text scale. Results wrap, never clip.

## Interaction states
Initial: a clear question with an empty labeled answer field; before a starting tier
is chosen, a tier picker covers Practice. Invalid: inline hint, no submission.
The first valid check is the answer on record; retries are allowed and do not change
it. Correct: encouraging confirmation, combo and XP; a correct first check pops the
answer and the header XP counts up. Wrong: invitation to try again with the first
hint opened and a short shake. A level-up or the reached daily goal throws one
confetti burst. Motion never blocks typing and never loops. Haptics: a light tap per
pad key, stronger on correct, wrong and a milestone, all behind the haptics switch. Hints are progressive: Hint shows one step, Next step
shows another, and only the last step states the answer. Next skips and records
Skipped when nothing was checked. Sprint: 60 seconds, hints and Next off, any valid
check moves to the next problem; the result card shows score beside the personal
best. Results: useful empty state, then correct/incorrect/skipped rows.
No data-loading placeholders: computation and history are local. If progress cannot
be saved, a neutral header line says so and practice continues.

## Content voice
Short, kind and specific: “Your answer”, “Check answer”, “You got it!”, “Not quite.
Try another answer.” Avoid shame, excessive punctuation, baby talk and fake rewards.

## Implementation constraints
Flutter stable, Provider retained. New runtime dependencies only where a requirement
needs them (device storage, sound, opening the Impressum link). Support web/iOS/Android, latest OS versions,
with native Flutter controls; no browser-only imports in shared UI. Regressions
precede fixes. Format, analyze, tests, web build and native gates apply. Capture
actual release-browser screenshots of both themes for empty/populated/feedback states.

## Open questions
- [ ] Release owner: Google Play production access and listing; iOS publication is later.
- [ ] Product owner: which address the Impressum publishes.

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
- Two themes follow the system setting: light playful and dark neon. Flat solid
  colours, no purple, no gradients. Pale accents always use dark ink.
- Heavy numerals and large type for the problem. Use bundled Flutter typography; no
  network-loaded fonts or new font package. Weight and scale carry hierarchy. Body
  at least 16px; avoid uppercase paragraph text.
- Spacing 8/12/16/24/32/48; 24–32px main card radii. Hard offset shadows give
  buttons a pressed look; no soft heavy shadows. Large editorial heading, small
  section label.
- Decorative arithmetic shapes made with native widgets, excluded from semantics.
- Feedback motion (pop on correct, shake on wrong, XP count-up, particle burst on
  level-up and goal) stays brief; zero duration under disableAnimations.
- Sound has a switch; haptics have a switch. Both default on.

## Components
`app/lib/app_theme.dart` owns colors and global theme; both themes share one set of
tokens. Adaptive navigation shell, persistent header, practice workbook card, answer
field, number pad, feedback strip, sprint card and results rows share tokens.
Buttons have minimum 48px height. No general-purpose component framework needed.
The on-screen number pad has digits, backspace and a large Check key. It edits the
same text field. A keyboard toggle hides the pad and opens the system keyboard, so
dictation and IME stay reachable; a hardware keyboard always types and Enter checks.
There is one Check button, moved into the pad while it shows.

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
it. Correct: encouraging confirmation, combo and XP. Wrong: invitation to try again
with the first hint opened. Hints are progressive: Hint shows one step, Next step
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

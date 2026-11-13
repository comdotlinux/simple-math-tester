# Design

## Source of truth
Active · 2026-11-13. Practice and Results on web, iOS and Android.
User approved playful learning and required native mobile support. Evidence:
`README.md`, `app/lib/{main,home_page,problem_page,results_page}.dart`, existing
tests, platform projects and `.omx/plans/modernize-flutter-app.md`.
No existing brand assets, screenshots or design brief were supplied.

## Brand
**A little practice. A big discovery.** An inviting math workbook, not a dashboard.
Warm, curious, optimistic. No pressure, scores-as-punishment, leaderboard or timers
counting down. Distinctive motif: oversized arithmetic marks on a paper-like canvas.

## Product goals
Make answering and reviewing math feel clear and rewarding. Keep the existing
four operations, ranges, retry/skip behavior and in-memory session. No accounts,
cloud features, difficulty controls or gamification expansion. Success means a
child can enter, check, retry and move on without losing input or context.

## Personas and jobs
School beginners practicing arithmetic, with a parent or teacher nearby. The
approved brief preserves current ranges, even though some questions are advanced.
Phones and tablets are first-class; desktop supports keyboard-first practice.

## Information architecture
Two destinations: **Practice** and **My answers**. Practice centers one problem and
one answer field; My answers shows session summary and chronological answer review.
Keep the current question/draft when switching destinations. Session-only history.

## Design principles
1. One obvious next action; secondary actions stay visually quieter.
2. Celebrate effort without hiding errors; every status has words and an icon.
3. Math stays readable; decoration never competes with the equation.
4. Adapt layout, not functionality, across platforms and text scales.

## Visual language
- Canvas `#F7F5EE`, paper `#FFFEF9`, ink `#203B36`, muted ink `#526760`.
- Primary deep teal `#226453`, mint `#E1EEE4`, warm yellow `#F1CC68`, peach
  `#F7DDD1`, error ink `#9F382C`. Pale accents always use dark ink.
- Rounded, bold display typography with generous tracking for math. Use bundled
  Flutter typography; no network-loaded fonts or new font package. Weight and
  scale carry hierarchy. Body at least 16px; avoid uppercase paragraph text.
- Spacing 8/12/16/24/32/48; 24–32px main card radii; fine warm borders, no heavy
  shadows or gradients. Large editorial heading, small section label, no stat grid.
- Decorative arithmetic shapes made with native widgets, excluded from semantics.
- Feedback fade/scale at most 200ms; zero duration under disableAnimations.

## Components
`app/lib/app_theme.dart` owns colors and global theme. Adaptive navigation shell,
practice workbook card, answer field, feedback strip, and results rows share tokens.
Buttons have minimum 48px height. No general-purpose component framework needed.

## Accessibility
Target WCAG AA contrast: 4.5:1 normal text, 3:1 large text/UI boundaries. Preserve
system text scaling, focus outlines, semantic labels, logical tab order and live
feedback announcements. No color-only status. Touch and keyboard both submit.
Respect reduced motion. Safe areas and keyboard insets remain usable on mobile.

## Responsive behavior
Below 800 logical pixels: compact header, bottom navigation, stacked content.
At/above 800: spacious navigation rail, bounded centered main content. Use available
constraints and scrollable content, not fixed page heights. At 200% text scale,
navigation can use the compact layout. Test 320/390/600/768/800/1440 widths,
short viewports, keyboard insets and 200% text scale. Results wrap, never clip.

## Interaction states
Initial: a clear question with an empty labeled answer field. Invalid: inline hint,
no timer stop or submission. Correct: encouraging confirmation; wrong: invitation
to try again; Next remains available for skipping. Next archives once and clears
the draft. Results: useful empty state, then correct/incorrect/skipped rows.
No data-loading placeholders: computation and history are local. Installed native
app requires no network for practice; initial web asset loading is separate.

## Content voice
Short, kind and specific: “Your answer”, “Check answer”, “You got it!”, “Not quite.
Try another answer.” Avoid shame, excessive punctuation, baby talk and fake rewards.

## Implementation constraints
Flutter stable, Provider retained, no new third-party runtime dependencies. Support
web/iOS/Android with native Flutter controls; no browser-only imports in shared UI.
Regressions precede fixes. Format, analyze, tests, web build and native gates apply.
Capture actual release-browser screenshots for empty/populated/feedback states.

## Open questions
- [ ] Product owner: revisit difficulty in a separate change; current ranges preserved.
- [ ] Release owner: production signing/store publication is outside this change.

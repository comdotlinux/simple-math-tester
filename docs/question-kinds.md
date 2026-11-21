# Algebra and geometry

Besides the four arithmetic operations, the app has two more kinds of
question: **algebra** (equations with one missing number) and **geometry**
(figures drawn to scale). Both have five levels, like the arithmetic kinds.
This page lists what each level asks and how the tests show that every
question and answer is right. The counts below are the ones the tests print
and check (`app/test/exhaustive_test.dart`, `app/test/geometry_test.dart`).

## Off by default

The four arithmetic operations are on by default. Algebra and geometry stay
off until the player switches them on. A kind the player has never switched
on, answered or closed gets a one-time card under the header ("New:
Algebra", "Tap here to switch it on"). Tapping it switches the kind on;
closing it hides that card for good. The card shows one kind at a time.

Both kinds start at level 1 whatever starting tier the player chose (a tier
sets only the arithmetic levels), and the 60-second sprint draws only from
the arithmetic operations.

## Algebra

The unknown is a blank, a thick line on the baseline about two digits wide
(3 + __ = 7), at levels 1 and 2 and the letter *n* from level 3. The tables
write it as □, the text form the app keeps in saved progress and tests.
Screen readers say "blank" for it. Every answer is whole and at
least 0, except at level 5, where answers can be below zero or in tenths.
With algebra on, the number pad has a minus key and a decimal key.

| Level | What it asks | Ranges | Example | Problems |
|---|---|---|---|---|
| 1 | A missing addend, subtrahend or minuend: a + □ = c, □ + a = c, c − □ = a, □ − a = b | a and b 0 to 10 | 3 + □ = 7 (4) | 484 |
| 2 | A missing factor, divisor or dividend: □ × a = c, a × □ = c, c ÷ □ = a, □ ÷ a = b; a square or square root: a² = □, √c = □ | a 2 to 10, b 1 to 10; squares and roots of 1 to 10 | 18 ÷ □ = 6 (3), 7² = □ (49), √49 = □ (7) | 380 |
| 3 | The same four forms with the letter *n*: n + a = c, n − a = b, a × n = c, n ÷ a = b; a² = n, √c = n | a 2 to 12, the other number 0 to 20; squares and roots of 6 to 12 | 3 × n = 15 (5), √144 = n (12) | 938 |
| 4 | Two steps: an + b = c and an − b = c (an means a × n); a² = n, √c = n | a 2 to 9, b 1 to 20, n 1 to 20; squares and roots of 13 to 20 | 2n + 3 = 11 (4), 17² = n (289) | 6127 |
| 5 | Brackets, a division, answers below zero and in tenths: a(n − b) = c, a(n + b) = c, n ÷ a + b = c, an + b = c with n below zero, an = c with n in tenths; n² = c and an² = c with the line "n is positive" | a 2 to 9, b 1 to 10, n −10 to 10; n² = c with n 1 to 12, an² = c with a 2 to 9 and n 2 to 12 | 3n + 9 = 3 (−2), 4n = 10 (2.5), 2n² = 50 (5) | 6020 |

Squares and square roots come in two kinds. At levels 2 to 4 the question
works out a square or a root (a² = □, √c = n); c is always a perfect
square, and the range moves up with the level (bases 1 to 10, then 6 to
12, then 13 to 20), so no level repeats a lower level's whole range. At level 5 the child solves n² = c or
an² = c. Such an equation has two solutions, n and −n, so the line "n is
positive" stands under it on the card, in the pinned band and in the
history, and screen readers hear it; with that line there is exactly one
answer. No question asks for a negative root or for two answers. The
exponent and the root sign are the characters ² and √, which every
bundled Roboto face has (the web build fetches no font for them); screen
readers say "7 squared" and "square root of 49".

| Variant | Form | Params | Levels | Problems |
|---|---|---|---|---|
| `missingSquare` | a² = □ | `[a]`, 1 to 10 | 2 | 10 |
| `missingSquareRoot` | √c = □, c = r × r | `[r]`, 1 to 10 | 2 | 10 |
| `aSquared` | a² = n | `[a]`, 6 to 12; 13 to 20 | 3; 4 | 7; 8 |
| `squareRootOfC` | √c = n, c = r × r | `[r]`, 6 to 12; 13 to 20 | 3; 4 | 7; 8 |
| `nSquared` | n² = c, n is positive | `[n]`, 1 to 12 | 5 | 12 |
| `anSquared` | an² = c, n is positive | `[a, n]`, a 2 to 9, n 2 to 12 | 5 | 88 |

Every hint has the same shape, written for a child of 7 to 12: what the
question asks ("We need the number that goes in the blank."), the idea the
working uses, with a short why (adding and taking away undo each other;
the two sides of = are like a balance), then the working one small
calculation at a time, and last the answer. Hints undo one step at a time;
only the last step states the answer,
followed by a check with the answer put back into the equation. A square
says what it means (7² means 7 × 7); a root asks which number times itself
makes the square; an² = c first divides both sides by a, then asks for the
root.

## Geometry

The figure is drawn to scale in place of the question text, with a short
prompt ("Perimeter?", "Area?") and cues that need no words: a thick outline
for a perimeter, a shaded inside for an area. History and screen readers
get a sentence that names the shape, every label and the question.
Decimal answers (halves, circles) are exact hundredths, written with the
language's decimal separator.

| Level | What it asks | Ranges | Example | Problems |
|---|---|---|---|---|
| 1 | The perimeter of a square, a rectangle or a triangle | Sides 1 to 12, a rectangle's longer side at most 4 times the shorter; triangles with whole sides 2 to 12 and every angle at least 20° | Rectangle 5 by 3: 16 | 276 |
| 2 | The area of a rectangle, with a unit grid on it | Sides 1 to 10, the longer at most 4 times the shorter | Rectangle 5 by 3: 15 | 84 |
| 3 | A missing side (a `?` on the side) of a square or rectangle, from its perimeter or area | As level 1 | Perimeter 16, one side 5: 3 | 240 |
| 4 | A missing angle, with an arc at every angle and a square in a right angle: in a triangle, on a straight line, in a right angle; two crossing lines with one angle given and the opposite angle or a neighbour asked; three angles around a point; the outside angle of a triangle with one side drawn longer (from the two opposite inside angles, or an inside angle from the outside angle and the other one); an isosceles triangle with a tick on each equal side (a base angle from the top angle, or the top angle from a base angle) | Every angle whole and at least 20° (at least 10° in a right angle); crossing lines 20° to 160°; around a point 20° to 170° in steps of 5°; outside angle 66° to 160°; isosceles top angle 20° to 140° | Triangle with 50° and 60°: 70; crossing at 50°: opposite 50, neighbour 130; around a point 100° and 150°: 110; inside angles 50° and 60°: outside angle 110; isosceles with a 40° top: 70 | 22553 |
| 5 | The area of a right triangle; the perimeter and area of an L-shape and of rectangles with sides in halves; a circle's circumference (from its diameter) and area (from its radius), with "Use π = 3.14" shown; Pythagoras: the longest side or a leg of a right triangle, and the diagonal of a rectangle (drawn, with a `?` on its middle); the fourth angle of a quadrilateral; two parallel lines (an arrow on each) and a line across them, one angle given and the corresponding, alternate or co-interior angle at the other crossing asked; a triangle on the diameter of a circle with its third corner on the circle (that angle unlabelled), one angle at the diameter given and the other asked; two similar triangles (equal angles marked by one, two and three arcs), a side of one asked from its partner and the two bottom sides | Legs 1 to 12; L-shapes with outer sides 4 to 12; halves 0.5 to 12; diameter 1 to 20, radius 1 to 10; Pythagoras: the whole-number triangles 3-4-5, 6-8-10, 5-12-13, 9-12-15, 8-15-17 and 12-16-20, both leg orders (sides up to 20, so not "at most 12"); quadrilateral angles 20° to 160° in steps of 10°, 120 of the 2255 left out (see below); parallel lines crossed at 60° to 120°; the angle at the diameter 20° to 70°; similar triangles with whole sides up to 8 (the bottom longest and at most twice the shortest), 2 or 3 times as big | Legs 6 and 4: 12; 2.5 by 1.5: 3.75; diameter 6: 18.84; legs 3 and 4: 5; 6 by 8: diagonal 10; 80°, 100° and 70°: 110; parallel lines crossed at 70°: co-interior angle 110; 35° at the diameter: 55; sides 5 and 3, twice as big with bottom 10: 6 | 4397 |

Families (the variant names saved with each answer) by level: 1
`squarePerimeter`, `rectanglePerimeter`, `trianglePerimeter`; 2
`rectangleArea`; 3 `squareSideFromPerimeter`, `squareSideFromArea`,
`rectangleSideFromPerimeter`, `rectangleSideFromArea`; 4 `triangleAngle`
(7381), `straightAngle` (141), `rightAngle` (71),
`verticallyOppositeAngles` (282), `anglesAroundPoint` (496),
`exteriorAngle` (14060), `isoscelesTriangle` (122); 5
`rightTriangleArea`, `lShapePerimeter`, `lShapeArea`,
`halvesRectanglePerimeter`, `halvesRectangleArea`, `circleCircumference`,
`circleArea`, `pythagorasHypotenuse` (12), `pythagorasLeg` (12),
`rectangleDiagonal` (12), `quadrilateralAngles` (2135), `parallelLines`
(244), `angleInSemicircle` (51), `similarTriangles` (363).

Hints have the algebra shape: what is asked, naming the school word once
("This is called the perimeter."), the rule and why it holds, the working
one number or one small calculation a step, then the answer and its check
(the answer put back, the sides counted, or "a bit more than 3 × 6 = 18"
for π). Only the last step states the answer. A theorem hint names the
theorem and says why it holds ("Vertically opposite angles are equal",
"Angles around a point always add up to 360°", "Pythagoras' theorem", "The
outside angle of a triangle equals the two opposite inside angles added
together", "An isosceles triangle has two equal sides and two equal
angles", "The four angles of a quadrilateral add up to 360°",
"Corresponding angles are equal", "Alternate angles are equal",
"Co-interior angles add up to 180°", "An angle in a semicircle is always a
right angle", "Similar triangles have the same shape"),
then works in small steps; for Pythagoras each side's square on its own,
the sum or the difference, then which number times itself makes it.

Each step is data (`FigureStep` in `solution_steps.dart`): its numbers,
its calculation as terms and signs with the value, its check, and the
parts of the figure it uses (`FigureParts`: edges, angles, grid rows, the
right-angle mark, the outline, the inside, the diagonal). The hint modal
shows the figure right above the newest step with those parts drawn as an
accent band edged in the colour drawn on the accent, and their labels on
accent patches (`HintSteps` in `hint_steps.dart`).

How a figure is laid out (`layoutFigure` in `app/lib/figure.dart`): one
uniform scale, as large as fits the canvas with every label in it. A side
label stands outside the middle of its side. An angle label stands inside
its angle on the line that halves it, just past the arc, when its box fits
there clear of every line, tick, arc and label and nearer its own corner
than any other; otherwise just outside the corner on that line, across
from the angle (and further out only as far as clears another label). An
angle between rays or outside a side drawn on is open, so its label always
stands in it: between the rays, or just past their ends when the angle is
too narrow; an outside angle's arc reaches out to just before its label.
Every angle has its own arc; arcs of rays at one point have different
radii (the narrowest angle, whose label stands farthest out, the largest),
so they never join into a circle. An arc is at most a third of the way to
the nearest other corner. The canvas is 150 px tall on the phone card and
210 px on the regular card at text scale 1, and grows by two lines of label
text as the text grows (`figureCanvasHeight`: about 197 and 257 px at text
scale 2), so large text gets a taller canvas rather than a smaller figure.

Crossing lines and rays around a point have no up or down, so the drawing
is turned (in steps of 15°); so are a triangle with a side drawn on and a
quadrilateral. The turns are tried from the one whose corners could fill
the canvas most until one keeps every side at least 16 px, the labels
apart and each angle label nearer the middle of its own arc than of any
other (a turn whose labels had to move out of each other's way is kept
only if no other turn does better). Four rays around a point are still
left out: `anglesAroundPoint` params are the two given angles of three
rays, and four rays need a third given angle, a new sentence and a new
hint.

A triangle with a side drawn on stands on the side across from the larger
of the two given inside angles, and the side drawn on borders the outside
angle along the triangle's long side, away from the other labels. Outside
angles below 66° are left out: their label stands so far out between the
two lines that on the phone card at text scale 2 it is nearer another
angle's arc than its own. Isosceles triangles stand on their base. A
quadrilateral's sides are chosen from its angles so its shortest side is
as long as it can be next to its thinnest width. 120 of the 2255 angle
combinations still do not read on the phone card at text scale 2 (a few
also at 1): every turn leaves a side shorter than 16 px, a label nearer
another angle's arc than its own, or a label pushed far from its angle.
No simple rule on the angles or side ratios separates them, so
`quadrilateralsLeftOut` in `app/lib/geometry.dart` lists them, and a test
checks that each still fails on some card.

Two parallel lines lie across the card with the line across rising to the
right; they are not turned. Each labelled angle is open, like an angle
between rays: its label stands between its two lines just past the arc,
and its arc reaches out to just before the label, so the label is nearer
its own arc than the arc at the other crossing. Each parallel line carries
an arrow, drawn at the first place along it from the left that keeps clear
of the labels and arcs. The lines are 12 apart for every 4 of line past a
crossing (18 for co-interior angles, whose two labels both stand between
the lines on one side). Lines crossed at less than 60° (or more than 120°)
are left out: the label of a narrow angle between the lines stands so far
out that on the phone card at text scale 2 it is nearer the other
crossing's arc than its own, or meets the other label. A triangle on a
diameter is drawn with its circle and the circle's centre; its two angle
labels stand inside their angles or outside the circle across from them,
never across the circle's line, and the angle on the circle has no mark.
Two similar triangles stand on one line, the smaller at the left, with a
gap of 0.8 times the smaller's bottom side; the arcs that mark equal
angles are 4 px apart.

## How correctness is checked

- **Pure builds over finite ranges.** Every algebra form and geometry
  family is a pure function from a short list of whole numbers to a
  question and its answer, and each level has a finite list of those
  parameter lists. The tests list every problem of every level; nothing is
  sampled.
- **Independent oracles.** The tests check each question with code that
  shares nothing with the app's builds and reads only what the child sees.
  For algebra (`app/test/oracle.dart`), that is the displayed English
  question text: it is parsed with the `math_expressions` package (a test-only
  dependency), the equation must have exactly one solution, that solution
  must be the app's answer, and putting it back must make both sides equal
  in exact hundredths. Squares and roots go to the package as `^2` and
  `sqrt`. An equation in n² is solved by the oracle itself: it evaluates
  left minus right at four points, requires them to lie on one parabola,
  finds every real root with the quadratic formula, keeps those above zero
  when the question ends in the condition line, and requires exactly one;
  without the line, `n² = 49` is rejected as having two solutions. For geometry (`app/test/geometry_oracle.dart`), it is
  the shape type, the prompt and the drawn layout: each side label belongs
  to its nearest edge; an angle label stands on the line that halves its
  angle (inside it, or straight out across its corner) and nearer the
  middle of its own arc than of any other arc, which also decides between
  two angles whose halving lines both pass through it; every drawn edge matches one common scale within
  0.5%, right angles are right, the grid squares are evenly spaced and their
  count is the area, and the oracle solves the figure from the labels.
  For two crossing lines it checks that the rays make two straight lines
  and decides from where the `?` is drawn whether it is opposite the given
  angle (equal) or beside it (180° minus). For Pythagoras it finds the legs
  and the longest side from the right-angle mark (or, in a rectangle, that
  the marked line joins opposite corners), computes the missing side in
  whole numbers (the square of the longest side is the squares of the legs
  added) and rejects a result that is not a whole number. For an outside
  angle it checks that the drawn-on line starts at a corner and continues
  a side straight on, reads the outside angle's label inside it and adds
  the two opposite inside angles. For an isosceles triangle it reads the
  tick marks (each across the middle of a side), checks the two ticked
  sides are drawn equal and derives all three angles from the one given.
  For a quadrilateral it checks the shape is convex and the four angles
  add up to 360°. For parallel lines it reads the two arrows (each along
  one line, pointing the same way), checks those two lines are drawn
  parallel and that the third line crosses both with every arm at least
  16 px long, numbers the four angles at each crossing from the arrow's
  way round, reads each label by its angle and nearest arc, and takes the
  `?` as equal to the given angle when the two are an even number of
  places apart round their crossings (corresponding, alternate, or
  vertically opposite to one of those) and as 180° minus it otherwise. For
  a triangle in a circle it checks that exactly one side has both ends on
  the circle and its middle at the centre, that the third corner is on the
  circle and has no label, and takes the `?` as 90° minus the given angle.
  For similar triangles it counts the arcs at each corner (one, two and
  three in each triangle), checks that corners with as many arcs have
  equal angles, matches the sides between them, takes how many times as
  big one triangle is from two matching labelled sides, and requires the
  `?` (its matching side times that, in whole hundredths) and every side
  drawn to one scale.
- **Exhaustive runs.** Algebra: 484, 380, 938, 6127 and 6020 problems
  (levels 1 to 5), each through the oracle, and the oracle recomputes every
  hint step of every problem. Geometry: 27550 problems, each laid out on 6
  canvas sizes at text scale 1 and 2, 330600 oracle checks in all (3312,
  1008, 2880, 270636 and 52764 for levels 1 to 5). Layout rules are checked
  for every figure too: label text at least 12 px, labels inside the canvas,
  apart from each other and off every line, sides at least 16 px, each
  angle label within 16.5 px of its arc, one of its lines or its corner
  (or as near as it can stand clear of another label) and nearer its own
  arc than any other, arcs at one point apart, the figure filling at least
  40% of the canvas across its tighter direction at text scale 1 (24% at
  text scale 2), readable colours in every palette.
- **Mutation tests.** The oracles must reject wrong versions: an answer + 1,
  a displayed number + 1, a generator that returns the result + 1, a hint
  calculation off by 1, the exponent or the root sign removed, a radicand
  + 1, the condition line removed (two solutions) (algebra); an answer + 1, a label changed, moved or
  hidden, the figure stretched by 20%, the prompts swapped, a grid square,
  an angle arc, the right-angle square or the π line removed, the radius
  and diameter cues swapped, the missing side or angle (`?`) moved, a ray
  turned by 10° with its label kept, the diagonal removed or drawn
  along a side, a tick mark removed or moved, a ticked side drawn 20%
  longer, the side drawn on removed or bent by 10°, an arrow removed,
  moved to the line across or turned round, one parallel line turned by
  3°, the circle moved or grown, a label on the corner on the circle,
  equal-angle marks swapped, the bigger similar triangle stretched by 20%
  (geometry); in a geometry hint step, a value, a term, a
  number or a check off by one, a highlight removed from a label the step
  reads, and a label highlighted that the step does not read.
- **Hint style.** `app/test/hint_style_test.dart` checks every algebra and
  geometry hint: at most 15 words a sentence in English, at most 300
  characters a step in every language, at most one calculation a step,
  the shape (what is asked, the idea, the working, the answer with its
  check), and that the longest hint of each family fits 320x568 at text
  scale 2; `app/test/hint_modal_test.dart` steps through the longest hint
  of each family, and of arithmetic, in the hint modal at 320x568 and
  360x640, text scale 1 and 2, light and dark.
- **Textbook rows.** `app/test/algebra_known_answers_test.dart` holds
  equations with the answers printed for them in Illustrative Mathematics
  (see [attributions.md](attributions.md)). The oracle must accept each
  printed answer and reject the answer + 1, and at least one row per level
  is also built by the app's own generator. The rows cover a few forms per
  level, not the whole range; some (such as 3e + 10.50 = 30) test the
  oracle only, because the app does not ask them. Nine forms have no row,
  because none of the public pages read so far prints an answer for them
  in the app's form and ranges: □ − a = b, □ × a = c, c ÷ □ = a,
  □ ÷ a = b, n − a = b, n ÷ a = b, an − b = c, n ÷ a + b = c and
  an + b = c with n below zero.
  `app/test/geometry_known_answers_test.dart` does the same for figure
  questions printed there (units dropped): the app builds them at levels
  2 to 5; a circle given by its diameter, a square with a side of 15, an
  L-shape cut at the bottom right and a missing side in halves are read
  by the oracle only. Level 1 (perimeters) and the families the test
  lists (a missing side from an area, the angle in a triangle, L-shapes,
  rectangles in halves, the circumference, and the theorem families:
  crossing lines, angles around a point, Pythagoras, the outside angle,
  isosceles triangles, quadrilaterals, parallel lines, the angle in a
  semicircle, similar triangles) have no built row. Geometry
  families without a row rest on the oracle and on figures worked by hand
  in `app/test/geometry_test.dart`, one or more per family.
- **Whole hundredths, no floating point.** Answers are whole numbers of
  hundredths (2.5 is 250). The app parses what the child types into
  hundredths and compares whole numbers. Circles use π = 3.14, shown on the
  screen, so a circumference is 314 × d hundredths and an area 314 × r × r.

## Saved progress

Each algebra or geometry answer is saved with its variant name (such as
`anPlusB` or `circleArea`), its parameters, its level and its result
(progress schema version 2). The variant names are permanent: renaming one
would make old answers unreadable. An entry whose variant this build does
not know, whose parameters do not fit, or whose stored result differs from
what its parameters build is kept and saved back unchanged, not dropped.

Every answer of any kind also saves its hint use. `hintsUsed`, saved from
the start, is the number of hint steps seen before the first check.
`hintOpened` (a hint was opened on the question, before or after the first
check) and `answerShown` (its last step, the answer, showed) are additive:
written only when true, so an answer without a hint keeps the bytes older
builds wrote, and an entry without them reads as false. An entry with
`hintsUsed` above 0 counts as a hint opened even without `hintOpened`, so
answers saved before these fields still count right. An older build reads
the entry and drops the two fields when it saves again (it keeps no unknown
fields of an answer it can read); `hintsUsed` survives. Sprint answers
never have a hint.

### Hint use: the nudge and the totals

The definitions behind the nudge to try first and the hint totals on My
answers (`hintNudgeDue` and `hintTotals` in `app/lib/rules.dart`):

- **Answer:** a saved practice attempt with a valid first check. A skip is
  no answer, and a sprint answer never has a hint, so neither counts. The
  saved history keeps the last 200 attempts, so the totals cover those.
- **Hint used:** a hint was opened on the question, before or after its
  first check (`hintOpened`, or `hintsUsed` above 0).
- **Correct without a hint:** the first valid check was right, and no hint
  step showed before it (`hintsUsed` is 0), the same rule that halves the
  XP. A hint opened after a right answer does not take it away.
- **Nudge:** when the player asks for a hint that is not open yet, the
  last 10 answers are read from the saved history, without the current
  question's own attempt. If a hint was used on more than 5 of them, the
  nudge shows first, at most once per question; with fewer than 10 answers
  it never shows. Nothing new is counted or saved for it.
- **Totals** show on My answers once a hint was used on an answer. A kind
  shows its lines from its first answer; the line on right answers shows
  from the first right answer, so nothing is divided by zero. Percentages
  are whole numbers, rounded half up.

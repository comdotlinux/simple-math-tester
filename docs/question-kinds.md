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

The unknown is an empty box at levels 1 and 2 and the letter *n* from
level 3. Screen readers say "blank" for the box. Every answer is whole and at
least 0, except at level 5, where answers can be below zero or in tenths.
With algebra on, the number pad has a minus key and a decimal key.

| Level | What it asks | Ranges | Example | Problems |
|---|---|---|---|---|
| 1 | A missing addend, subtrahend or minuend: a + □ = c, □ + a = c, c − □ = a, □ − a = b | a and b 0 to 10 | 3 + □ = 7 (4) | 484 |
| 2 | A missing factor, divisor or dividend: □ × a = c, a × □ = c, c ÷ □ = a, □ ÷ a = b | a 2 to 10, b 1 to 10 | 18 ÷ □ = 6 (3) | 360 |
| 3 | The same four forms with the letter *n*: n + a = c, n − a = b, a × n = c, n ÷ a = b | a 2 to 12, the other number 0 to 20 | 3 × n = 15 (5) | 924 |
| 4 | Two steps: an + b = c and an − b = c (an means a × n) | a 2 to 9, b 1 to 20, n 1 to 20 | 2n + 3 = 11 (4) | 6111 |
| 5 | Brackets, a division, answers below zero and in tenths: a(n − b) = c, a(n + b) = c, n ÷ a + b = c, an + b = c with n below zero, an = c with n in tenths | a 2 to 9, b 1 to 10, n −10 to 10 | 3n + 9 = 3 (−2), 4n = 10 (2.5) | 5920 |

Hints undo one step at a time; only the last step states the answer,
followed by a check with the answer put back into the equation.

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
| 4 | A missing angle, with an arc at every angle and a square in a right angle: in a triangle, on a straight line, in a right angle | Every angle whole and at least 20° (at least 10° in a right angle) | Triangle with 50° and 60°: 70 | 7593 |
| 5 | The area of a right triangle; the perimeter and area of an L-shape and of rectangles with sides in halves; a circle's circumference (from its diameter) and area (from its radius), with "Use π = 3.14" shown | Legs 1 to 12; L-shapes with outer sides 4 to 12; halves 0.5 to 12; diameter 1 to 20, radius 1 to 10 | Legs 6 and 4: 12; 2.5 by 1.5: 3.75; diameter 6: 18.84 | 1568 |

Hints name the sides or angles, then the calculation; only the last step
states the answer.

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
  in exact hundredths. For geometry (`app/test/geometry_oracle.dart`), it is
  the shape type, the prompt and the drawn layout: each label belongs to its
  nearest edge or angle, every drawn edge matches one common scale within
  0.5%, right angles are right, the grid squares are evenly spaced and their
  count is the area, and the oracle solves the figure from the labels.
- **Exhaustive runs.** Algebra: 484, 360, 924, 6111 and 5920 problems
  (levels 1 to 5), each through the oracle, and the oracle recomputes every
  hint step of every problem. Geometry: 9761 problems, each laid out on 6
  canvas sizes at text scale 1 and 2, 117132 oracle checks in all (3312,
  1008, 2880, 91116 and 18816 for levels 1 to 5). Layout rules are checked
  for every figure too: label text at least 12 px, labels inside the canvas
  and apart from each other, readable colours in every palette.
- **Mutation tests.** The oracles must reject wrong versions: an answer + 1,
  a displayed number + 1, a generator that returns the result + 1, a hint
  calculation off by 1 (algebra); an answer + 1, a label changed, moved or
  hidden, the figure stretched by 20%, the prompts swapped, a grid square,
  an angle arc or the π line removed, the radius and diameter cues swapped,
  and the missing side moved (geometry).
- **Textbook rows.** `app/test/algebra_known_answers_test.dart` holds
  equations with the answers printed for them in Illustrative Mathematics
  (see [attributions.md](attributions.md)). The oracle must accept each
  printed answer and reject the answer + 1, and at least one row per level
  is also built by the app's own generator. The rows cover a few forms per
  level, not the whole range; some (such as 3e + 10.50 = 30) test the
  oracle only, because the app does not ask them. Geometry has no textbook
  rows: its known answers are figures worked by hand in
  `app/test/geometry_test.dart`, one or more per family.
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

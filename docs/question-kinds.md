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

Hints undo one step at a time; only the last step states the answer,
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
  in exact hundredths. Squares and roots go to the package as `^2` and
  `sqrt`. An equation in n² is solved by the oracle itself: it evaluates
  left minus right at four points, requires them to lie on one parabola,
  finds every real root with the quadratic formula, keeps those above zero
  when the question ends in the condition line, and requires exactly one;
  without the line, `n² = 49` is rejected as having two solutions. For geometry (`app/test/geometry_oracle.dart`), it is
  the shape type, the prompt and the drawn layout: each label belongs to its
  nearest edge or angle, every drawn edge matches one common scale within
  0.5%, right angles are right, the grid squares are evenly spaced and their
  count is the area, and the oracle solves the figure from the labels.
- **Exhaustive runs.** Algebra: 484, 380, 938, 6127 and 6020 problems
  (levels 1 to 5), each through the oracle, and the oracle recomputes every
  hint step of every problem. Geometry: 9761 problems, each laid out on 6
  canvas sizes at text scale 1 and 2, 117132 oracle checks in all (3312,
  1008, 2880, 91116 and 18816 for levels 1 to 5). Layout rules are checked
  for every figure too: label text at least 12 px, labels inside the canvas
  and apart from each other, readable colours in every palette.
- **Mutation tests.** The oracles must reject wrong versions: an answer + 1,
  a displayed number + 1, a generator that returns the result + 1, a hint
  calculation off by 1, the exponent or the root sign removed, a radicand
  + 1, the condition line removed (two solutions) (algebra); an answer + 1, a label changed, moved or
  hidden, the figure stretched by 20%, the prompts swapped, a grid square,
  an angle arc or the π line removed, the radius and diameter cues swapped,
  and the missing side moved (geometry).
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
  rectangles in halves, the circumference) have no built row. Geometry
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

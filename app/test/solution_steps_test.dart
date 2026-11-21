import 'dart:math';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/hundredths.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/solution_steps.dart';

import 'en.dart';

/// The steps of [problem] as text, in English unless [l] is given.
List<String> steps(Problem problem, [AppLocalizations? l]) => [
  for (final step in solutionSteps(problem)) step(l ?? en),
];

final _languages = [
  for (final locale in AppLocalizations.supportedLocales)
    lookupAppLocalizations(locale),
];

/// The numbers [problem] shows: for arithmetic, its two operands; a minus
/// sign straight before a number makes it negative (`3(n + 5) = −6`), and a
/// figure shows decimals (π = 3.14).
Set<num> shownNumbers(Problem problem) => {
  for (final match in RegExp(r'−?\d+(?:\.\d+)?').allMatches(problem.question))
    num.parse(match[0]!.replaceFirst('−', '-')),
};

/// Criterion 6: at least 2 steps, and no step before the last contains the
/// result as a whole-number token unless the question shows that number, in
/// every language. [source] draws one problem of a kind, so a later phase can
/// run the same check per difficulty level.
void expectStepsHideResult(
  Problem Function(OperationType type, Random random) source, {
  required int level,
  String label = '',
}) {
  const fixed = [
    ArithmeticProblem(3, 4, OperationType.plus, 7),
    ArithmeticProblem(10, 20, OperationType.plus, 30),
    ArithmeticProblem(50, 60, OperationType.plus, 110),
    ArithmeticProblem(1000, 2000, OperationType.plus, 3000),
    ArithmeticProblem(2, 10, OperationType.multiply, 20),
    ArithmeticProblem(4, 5, OperationType.multiply, 20),
    ArithmeticProblem(12, 3, OperationType.minus, 9),
    ArithmeticProblem(5, 5, OperationType.minus, 0),
    ArithmeticProblem(5000, 1000, OperationType.minus, 4000),
    ArithmeticProblem(100, 40, OperationType.minus, 60),
    ArithmeticProblem(1000, 300, OperationType.minus, 700),
    ArithmeticProblem(10000, 5000, OperationType.minus, 5000),
    ArithmeticProblem(12, 3, OperationType.divide, 4.0),
  ];

  // In every language: a translation must not add or drop a number.
  void check(Problem problem) {
    // A result the question shows is already on screen (10000 − 5000).
    final shown = shownNumbers(problem).contains(problem.result);
    for (final l in _languages) {
      // An equation's or figure's answer as the language writes it, not
      // part of a longer number: 2 is not in −2 or 2,5, 3.14 not in 13.14.
      final token = switch (problem) {
        EquationProblem(:final resultHundredths) ||
        FigureProblem(:final resultHundredths) => RegExp(
          '(?<![\\d.,−])'
          '${RegExp.escape(formatHundredths(resultHundredths, l.localeName))}'
          '(?![\\d]|[.,]\\d)',
        ),
        _ => RegExp('(?<!\\d)${problem.result.toInt()}(?!\\d)'),
      };
      final steps = solutionSteps(problem).map((step) => step(l)).toList();
      expect(steps.length, greaterThanOrEqualTo(2), reason: problem.question);
      for (final step in steps.take(shown ? 0 : steps.length - 1)) {
        expect(
          token.hasMatch(step),
          isFalse,
          reason: '${problem.question}: $step',
        );
      }
      expect(token.hasMatch(steps.last), isTrue, reason: problem.question);
    }
  }

  test('criterion 6$label: fixed cases keep the result for the last step', () {
    fixed.forEach(check);
  });

  for (final type in OperationType.values) {
    if (level > type.highestLevel) continue;
    test('criterion 6$label: 300 seeded $type problems hide the result', () {
      final random = Random(600 + type.index);
      var checked = 0;
      while (checked < 300) {
        final problem = source(type, random);
        if (shownNumbers(problem).contains(problem.result)) continue;
        check(problem);
        checked++;
      }
    });
  }
}

void main() {
  for (var level = 1; level <= maxLevel; level++) {
    expectStepsHideResult(
      (type, random) => type.generate(random, level),
      level: level,
      label: ' at level $level',
    );
  }

  test('addition shows place values and carrying', () {
    expect(steps(const ArithmeticProblem(19, 6, OperationType.plus, 25)), [
      'Break 19 into 10 + 9 and 6 into 6.',
      'Add matching places: 10 + 0 = 10; 9 + 6 = 15.',
      'Combine the parts: 10 + 15 = 25.',
    ]);
  });

  test('single-digit addition counts on without the answer', () {
    expect(steps(const ArithmeticProblem(3, 4, OperationType.plus, 7)), [
      'Start at 4 and count on 3 more: 5, 6, …',
      'So 3 + 4 = 7.',
    ]);
  });

  test('addition in one place adds the digits of that place', () {
    expect(steps(const ArithmeticProblem(50, 60, OperationType.plus, 110)), [
      '50 is 5 tens and 60 is 6 tens. Add 5 + 6, then make it tens.',
      'So 50 + 60 = 110.',
    ]);
  });

  test('subtraction hops to round numbers', () {
    expect(steps(const ArithmeticProblem(12, 3, OperationType.minus, 9)), [
      'Find the difference between 12 and 3: what do you add to 3 to make 12?',
      'Hop to round numbers: from 3 up to 10 is 7; from 10 up to 12 is 2.',
      'Add the hops: 7 + 2 = 9. So 12 − 3 = 9.',
    ]);
  });

  test('subtraction without safe hops counts up instead', () {
    expect(steps(const ArithmeticProblem(13, 3, OperationType.minus, 10)), [
      'Find the difference between 13 and 3: what do you add to 3 to make 13?',
      'Count up from 3 to 13 in hops, for example to the next ten, and keep '
          'track of how far you went.',
      'So 13 − 3 = 10. Check: 10 + 3 = 13.',
    ]);
  });

  test('subtraction of equal numbers explains that nothing is left', () {
    expect(steps(const ArithmeticProblem(5, 5, OperationType.minus, 0)), [
      'Find the difference between 5 and 5.',
      'Both numbers are the same, so taking one away from the other leaves '
          'nothing.',
      'So 5 − 5 = 0.',
    ]);
  });

  test('multiplication shows partial products', () {
    expect(
      steps(const ArithmeticProblem(4, 223, OperationType.multiply, 892)),
      [
        'Split 223 into 200 + 20 + 3.',
        'Multiply each part by 4: 4 × 200 = 800; 4 × 20 = 80; 4 × 3 = 12.',
        'Add the products: 800 + 80 + 12 = 892.',
      ],
    );
  });

  test('multiplication of a single part counts in groups', () {
    expect(steps(const ArithmeticProblem(4, 5, OperationType.multiply, 20)), [
      '4 × 5 means 4 groups of 5.',
      'Count in 5s, 4 times: 5, 10, 15, …',
      'So 4 × 5 = 20.',
    ]);
  });

  test('division counts in groups of the divisor', () {
    expect(steps(const ArithmeticProblem(12, 3, OperationType.divide, 4.0)), [
      'How many 3s make 12? Think: 3 × ? = 12.',
      'Count in 3s: 3, 6, 9, … until you reach 12. How many 3s did you count?',
      '3 × 4 = 12, so 12 ÷ 3 = 4.',
    ]);
  });

  test('addition up to 10 counts on, also from 10', () {
    expect(steps(const ArithmeticProblem(6, 10, OperationType.plus, 16)), [
      'Start at 10 and count on 6 more: 11, 12, 13, …',
      'So 6 + 10 = 16.',
    ]);
  });

  test('addition of two round ten thousands names the place', () {
    expect(
      steps(const ArithmeticProblem(10000, 10000, OperationType.plus, 20000)),
      [
        '10000 is 1 ten thousand and 10000 is 1 ten thousand. '
            'Add 1 + 1, then make it ten thousands.',
        'So 10000 + 10000 = 20000.',
      ],
    );
  });

  test('subtraction inside one ten counts one at a time', () {
    expect(steps(const ArithmeticProblem(7, 3, OperationType.minus, 4)), [
      'Find the difference between 7 and 3: what do you add to 3 to make 7?',
      'Count up from 3 to 7 one at a time and keep track of how many you '
          'counted.',
      'So 7 − 3 = 4. Check: 4 + 3 = 7.',
    ]);
  });

  test('subtraction of round numbers takes away in their shared place', () {
    expect(
      steps(const ArithmeticProblem(5000, 1000, OperationType.minus, 4000)),
      [
        'Find the difference between 5000 and 1000: what do you add to 1000 '
            'to make 5000?',
        '5000 is 5 thousands and 1000 is 1 thousand. Take away 5 − 1, then '
            'make it thousands.',
        'So 5000 − 1000 = 4000. Check: 4000 + 1000 = 5000.',
      ],
    );
    expect(
      steps(const ArithmeticProblem(1000, 300, OperationType.minus, 700))[1],
      '1000 is 10 hundreds and 300 is 3 hundreds. Take away 10 − 3, then '
      'make it hundreds.',
    );
    expect(
      steps(const ArithmeticProblem(100, 40, OperationType.minus, 60))[1],
      '100 is 10 tens and 40 is 4 tens. Take away 10 − 4, then make it tens.',
    );
    expect(
      steps(const ArithmeticProblem(10000, 5000, OperationType.minus, 5000))[1],
      '10000 is 10 thousands and 5000 is 5 thousands. Take away 10 − 5, then '
      'make it thousands.',
    );
  });

  test('round subtraction drops the counts when they would show it', () {
    // 100 is 10 tens and 90 is 9 tens: "10" is the answer.
    expect(
      steps(const ArithmeticProblem(100, 90, OperationType.minus, 10))[1],
      isNot(contains('tens')),
    );
  });

  test('multiplication splits the factor that has more than one place', () {
    expect(
      steps(const ArithmeticProblem(17, 50, OperationType.multiply, 850)),
      [
        'Split 17 into 10 + 7.',
        'Multiply each part by 50: 50 × 10 = 500; 50 × 7 = 350.',
        'Add the products: 500 + 350 = 850.',
      ],
    );
  });

  test('multiplication of two round numbers multiplies the digits', () {
    expect(
      steps(const ArithmeticProblem(20, 30, OperationType.multiply, 600)),
      [
        'Take the zeros off and multiply the digits: 2 × 3 = 6.',
        '20 and 30 have 2 zeros together. Write them after 6.',
        'So 20 × 30 = 600.',
      ],
    );
  });

  test('division with a quotient of 10 or more takes tens first', () {
    expect(
      steps(const ArithmeticProblem(2047, 23, OperationType.divide, 89.0)),
      [
        'How many 23s make 2047? Think: 23 × ? = 2047.',
        'Take tens first: 23 × 80 = 1840, and 2047 − 1840 = 207 is left to '
            'share into 23s.',
        '23 × 89 = 2047, so 2047 ÷ 23 = 89.',
      ],
    );
  });

  test('division by tens drops the numbers when they would show it', () {
    // 11 × 30 = 330 leaves 33, the answer itself.
    expect(
      steps(const ArithmeticProblem(363, 11, OperationType.divide, 33.0)),
      [
        'How many 11s make 363? Think: 11 × ? = 363.',
        'Multiply 11 by round tens until you get close to 363, then count on '
            'in 11s for the rest.',
        '11 × 33 = 363, so 363 ÷ 11 = 33.',
      ],
    );
  });

  test('division drops the count when it would show the answer', () {
    expect(steps(const ArithmeticProblem(18, 3, OperationType.divide, 6.0)), [
      'How many 3s make 18? Think: 3 × ? = 18.',
      'Count in 3s until you reach 18. How many 3s did you count?',
      '3 × 6 = 18, so 18 ÷ 3 = 6.',
    ]);
  });

  group('equation steps', () {
    final source = OperationType.algebra.source as AlgebraSource;
    EquationProblem equation(String variant, int a, int b) =>
        source.build(OperationType.algebra, variant, [a, b])!;
    // The steps after what is asked and the idea, which the test 'every
    // equation hint starts with what is asked' covers.
    List<String> work(Problem problem) => steps(problem).skip(2).toList();

    test('name what to undo, then state the answer and put it back', () {
      expect(work(equation('missingSecondAddend', 3, 4)), [
        'Adding 3 and the blank makes 7. To undo the adding, take 3 away '
            'from 7.',
        '7 − 3 = 4, so the blank is 4. Check: 3 + 4 = 7',
      ]);
      expect(work(equation('missingFirstAddend', 3, 4)), [
        'Adding 3 and the blank makes 7. To undo the adding, take 3 away '
            'from 7.',
        '7 − 3 = 4, so the blank is 4. Check: 4 + 3 = 7',
      ]);
      expect(work(equation('missingSubtrahend', 3, 4)), [
        'Taking the blank away from 7 leaves 3. To find the blank, take 3 '
            'away from 7.',
        '7 − 3 = 4, so the blank is 4. Check: 7 − 4 = 3',
      ]);
      expect(work(equation('missingMinuend', 3, 4)), [
        'Taking 3 away from the blank leaves 4. To undo the taking away, add '
            '3 back to 4.',
        '4 + 3 = 7, so the blank is 7. Check: 7 − 3 = 4',
      ]);
      expect(work(equation('missingFirstFactor', 4, 5)), [
        'Multiplying 4 and the blank makes 20. To undo the multiplying, '
            'divide 20 by 4.',
        '20 ÷ 4 = 5, so the blank is 5. Check: 5 × 4 = 20',
      ]);
      expect(work(equation('missingSecondFactor', 4, 5)), [
        'Multiplying 4 and the blank makes 20. To undo the multiplying, '
            'divide 20 by 4.',
        '20 ÷ 4 = 5, so the blank is 5. Check: 4 × 5 = 20',
      ]);
      expect(work(equation('missingDivisor', 6, 3)), [
        'Dividing 18 by the blank gives 6. To find the blank, divide 18 by 6.',
        '18 ÷ 6 = 3, so the blank is 3. Check: 18 ÷ 3 = 6',
      ]);
      expect(work(equation('missingDividend', 3, 6)), [
        'Dividing the blank by 3 gives 6. To undo the dividing, multiply 6 '
            'by 3.',
        '6 × 3 = 18, so the blank is 18. Check: 18 ÷ 3 = 6',
      ]);
    });

    test('every equation ends with its answer put back', () {
      for (
        var level = 1;
        level <= OperationType.algebra.highestLevel;
        level++
      ) {
        for (final problem in source.problems(OperationType.algebra, level)) {
          final last = steps(problem).last;
          final answer = formatHundredths(problem.resultHundredths, 'en');
          if (level <= 2) {
            expect(
              last,
              endsWith(
                problem.question.replaceAll(EquationProblem.blank, answer),
              ),
            );
            expect(last, contains('the blank is $answer.'));
          } else {
            expect(
              last,
              endsWith('Check: ${equationHint(problem).last.check}'),
            );
            expect(last, contains('so n = $answer.'));
          }
        }
      }
    });

    EquationProblem letter(String variant, List<int> params) =>
        source.build(OperationType.algebra, variant, params)!;
    const belowZero =
        'This time the answer is less than zero. It is written with a minus '
        'sign (−) in front.';

    test('every equation hint starts with what is asked, then the idea', () {
      const blank = 'We need the number that goes in the blank.';
      const letterN = 'We need the number that n stands for.';
      const addAndTakeAway =
          'Adding and taking away undo each other. Taking away is also '
          'called subtracting.';
      const multiplyAndDivide = 'Multiplying and dividing undo each other.';
      const squared =
          'A small ² after a number means the number times itself. We call '
          'it squared.';
      const balance =
          'The two sides of = are equal, like a balance. Do the same to both '
          'sides, one step at a time.';
      for (final (variant, params, start) in [
        ('missingSecondAddend', [3, 4], [blank, addAndTakeAway]),
        ('missingMinuend', [3, 4], [blank, addAndTakeAway]),
        (
          'missingSubtrahend',
          [3, 4],
          [
            blank,
            'In a take away, the part taken away and the part left can swap '
                'places.',
          ],
        ),
        ('missingFirstFactor', [4, 5], [blank, multiplyAndDivide]),
        ('missingDividend', [3, 6], [blank, multiplyAndDivide]),
        (
          'missingDivisor',
          [6, 3],
          [
            blank,
            'In a division, the number you divide by and the result can swap '
                'places.',
          ],
        ),
        ('missingSquare', [7], [blank, squared]),
        (
          'missingSquareRoot',
          [7],
          [
            blank,
            'The square root √ undoes squaring. Squaring means a number times '
                'itself.',
          ],
        ),
        ('aSquared', [12], [letterN, squared]),
        ('nSquared', [7], [letterN, squared]),
        ('nPlusA', [5, 7], [letterN, balance]),
        ('anSquared', [2, 5], [letterN, balance]),
        ('aBracketNMinusB', [3, 2, -4], [letterN, balance]),
      ]) {
        expect(steps(letter(variant, params)).take(2), start, reason: variant);
      }
    });

    test('level 3 names the undo for both sides, then does it', () {
      expect(work(letter('nPlusA', [5, 7])), [
        'To undo + 5, take 5 away from both sides.',
        '12 − 5 = 7, so n = 7. Check: 7 + 5 = 12',
      ]);
      expect(work(letter('nMinusA', [5, 7])), [
        'To undo − 5, add 5 to both sides.',
        '7 + 5 = 12, so n = 12. Check: 12 − 5 = 7',
      ]);
      expect(work(letter('aTimesN', [3, 5])), [
        'To undo × 3, divide both sides by 3.',
        '15 ÷ 3 = 5, so n = 5. Check: 3 × 5 = 15',
      ]);
      expect(work(letter('nDividedByA', [4, 3])), [
        'To undo ÷ 4, multiply both sides by 4.',
        '3 × 4 = 12, so n = 12. Check: 12 ÷ 4 = 3',
      ]);
    });

    test('level 4 says what 2n means, then undoes one step at a time', () {
      expect(work(letter('anPlusB', [2, 3, 4])), [
        '2n means 2 × n.',
        'To undo + 3, take 3 away from both sides. 11 − 3 = 8, so 2n = 8.',
        'To undo × 2, divide both sides by 2.',
        '8 ÷ 2 = 4, so n = 4. Check: 2 × 4 + 3 = 11',
      ]);
      expect(work(letter('anMinusB', [4, 5, 5])), [
        '4n means 4 × n.',
        'To undo − 5, add 5 to both sides. 15 + 5 = 20, so 4n = 20.',
        'To undo × 4, divide both sides by 4.',
        '20 ÷ 4 = 5, so n = 5. Check: 4 × 5 − 5 = 15',
      ]);
    });

    test('level 5 explains the minus sign of an answer below zero first', () {
      expect(work(letter('aBracketNMinusB', [3, 2, -4])), [
        belowZero,
        '3(n − 2) means 3 × (n − 2).',
        'To undo × 3, divide both sides by 3. −18 ÷ 3 = −6, so n − 2 = −6.',
        'To undo − 2, add 2 to both sides.',
        '−6 + 2 = −4, so n = −4. Check: 3(−4 − 2) = −18',
      ]);
      expect(work(letter('aBracketNPlusB', [3, 2, 2])), [
        '3(n + 2) means 3 × (n + 2).',
        'To undo × 3, divide both sides by 3. 12 ÷ 3 = 4, so n + 2 = 4.',
        'To undo + 2, take 2 away from both sides.',
        '4 − 2 = 2, so n = 2. Check: 3(2 + 2) = 12',
      ]);
      expect(work(letter('nDividedByAPlusB', [4, 3, -2])), [
        belowZero,
        'To undo + 3, take 3 away from both sides. 1 − 3 = −2, so n ÷ 4 = −2.',
        'To undo ÷ 4, multiply both sides by 4.',
        '−2 × 4 = −8, so n = −8. Check: −8 ÷ 4 + 3 = 1',
      ]);
      expect(work(letter('anPlusBNegativeN', [3, 9, -2])), [
        belowZero,
        '3n means 3 × n.',
        'To undo + 9, take 9 away from both sides. 3 − 9 = −6, so 3n = −6.',
        'To undo × 3, divide both sides by 3.',
        '−6 ÷ 3 = −2, so n = −2. Check: 3 × (−2) + 9 = 3',
      ]);
    });

    test('a square says what it means; a root asks which number times '
        'itself makes the square; an² = c divides first', () {
      expect(work(letter('missingSquare', [7])), [
        '7² means 7 × 7.',
        '7 × 7 = 49, so the blank is 49. Check: 7² = 49',
      ]);
      expect(work(letter('missingSquareRoot', [7])), [
        '√49 asks: which number times itself makes 49?',
        '7 × 7 = 49, so the blank is 7. Check: √49 = 7',
      ]);
      expect(work(letter('aSquared', [12])), [
        '12² means 12 × 12.',
        '12 × 12 = 144, so n = 144. Check: 12² = 144',
      ]);
      expect(work(letter('squareRootOfC', [17])), [
        '√289 asks: which number times itself makes 289?',
        '17 × 17 = 289, so n = 17. Check: √289 = 17',
      ]);
      const positive =
          'n² means n × n, and n is positive. Which number above zero '
          'times itself makes';
      expect(work(letter('nSquared', [7])), [
        '$positive 49?',
        '7 × 7 = 49, so n = 7. Check: 7² = 49',
      ]);
      expect(work(letter('anSquared', [2, 5])), [
        '2n² means 2 × n².',
        'To undo × 2, divide both sides by 2. 50 ÷ 2 = 25, so n² = 25.',
        '$positive 25?',
        '5 × 5 = 25, so n = 5. Check: 2 × 5² = 50',
      ]);
    });

    test('level 5 tenths use the language decimal separator', () {
      expect(work(letter('anTenths', [4, 25])), [
        '4n means 4 × n.',
        'To undo × 4, divide both sides by 4.',
        '10 ÷ 4 = 2.5, so n = 2.5. Check: 4 × 2.5 = 10',
      ]);
      expect(
        steps(letter('anTenths', [4, -25])).last,
        '−10 ÷ 4 = −2.5, so n = −2.5. Check: 4 × (−2.5) = −10',
      );
      final german = lookupAppLocalizations(const Locale('de'));
      expect(
        steps(letter('anTenths', [4, 25]), german).last,
        contains('10 ÷ 4 = 2,5'),
      );
      expect(
        steps(letter('anTenths', [4, 25]), german).last,
        endsWith('4 × 2,5 = 10'),
      );
    });
  });
}

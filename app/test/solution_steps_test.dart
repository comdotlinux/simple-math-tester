import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
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

/// The whole numbers [problem] shows: for arithmetic, its two operands.
Set<int> shownNumbers(Problem problem) => {
  for (final match in RegExp(r'\d+').allMatches(problem.question))
    int.parse(match[0]!),
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
    final token = RegExp('(?<!\\d)${problem.result.toInt()}(?!\\d)');
    // A result the question shows is already on screen (10000 − 5000).
    final shown = shownNumbers(problem).contains(problem.result);
    for (final l in _languages) {
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

    test('name what to undo, then state the answer and put it back', () {
      expect(steps(equation('missingSecondAddend', 3, 4)), [
        'Adding 3 and the blank makes 7. To undo the adding, take 3 away '
            'from 7.',
        '7 − 3 = 4, so the blank is 4. Check: 3 + 4 = 7',
      ]);
      expect(steps(equation('missingFirstAddend', 3, 4)), [
        'Adding 3 and the blank makes 7. To undo the adding, take 3 away '
            'from 7.',
        '7 − 3 = 4, so the blank is 4. Check: 4 + 3 = 7',
      ]);
      expect(steps(equation('missingSubtrahend', 3, 4)), [
        'Taking the blank away from 7 leaves 3. To find the blank, take 3 '
            'away from 7.',
        '7 − 3 = 4, so the blank is 4. Check: 7 − 4 = 3',
      ]);
      expect(steps(equation('missingMinuend', 3, 4)), [
        'Taking 3 away from the blank leaves 4. To undo the taking away, add '
            '3 back to 4.',
        '4 + 3 = 7, so the blank is 7. Check: 7 − 3 = 4',
      ]);
      expect(steps(equation('missingFirstFactor', 4, 5)), [
        'Multiplying 4 and the blank makes 20. To undo the multiplying, '
            'divide 20 by 4.',
        '20 ÷ 4 = 5, so the blank is 5. Check: 5 × 4 = 20',
      ]);
      expect(steps(equation('missingSecondFactor', 4, 5)), [
        'Multiplying 4 and the blank makes 20. To undo the multiplying, '
            'divide 20 by 4.',
        '20 ÷ 4 = 5, so the blank is 5. Check: 4 × 5 = 20',
      ]);
      expect(steps(equation('missingDivisor', 6, 3)), [
        'Dividing 18 by the blank gives 6. To find the blank, divide 18 by 6.',
        '18 ÷ 6 = 3, so the blank is 3. Check: 18 ÷ 3 = 6',
      ]);
      expect(steps(equation('missingDividend', 3, 6)), [
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
          final answer = formatNumber(problem.result);
          expect(
            last,
            endsWith(
              problem.question.replaceAll(EquationProblem.blank, answer),
            ),
          );
          expect(last, contains('the blank is $answer.'));
        }
      }
    });
  });
}

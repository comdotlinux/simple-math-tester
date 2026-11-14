import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/solution_steps.dart';

/// Criterion 6: at least 2 steps, and no step before the last contains the
/// result as a whole-number token. [source] draws one problem of a kind, so
/// a later phase can run the same check per difficulty level.
void expectStepsHideResult(
  Problem Function(OperationType type, Random random) source, {
  String label = '',
}) {
  const fixed = [
    Problem(3, 4, OperationType.plus, 7),
    Problem(10, 20, OperationType.plus, 30),
    Problem(50, 60, OperationType.plus, 110),
    Problem(1000, 2000, OperationType.plus, 3000),
    Problem(2, 10, OperationType.multiply, 20),
    Problem(4, 5, OperationType.multiply, 20),
    Problem(12, 3, OperationType.minus, 9),
    Problem(5, 5, OperationType.minus, 0),
    Problem(12, 3, OperationType.divide, 4.0),
  ];

  void check(Problem problem) {
    final steps = solutionSteps(problem);
    final token = RegExp('(?<!\\d)${problem.result.toInt()}(?!\\d)');
    expect(steps.length, greaterThanOrEqualTo(2), reason: problem.question);
    for (final step in steps.take(steps.length - 1)) {
      expect(
        token.hasMatch(step),
        isFalse,
        reason: '${problem.question}: $step',
      );
    }
    expect(token.hasMatch(steps.last), isTrue, reason: problem.question);
  }

  test('criterion 6$label: fixed cases keep the result for the last step', () {
    fixed.forEach(check);
  });

  for (final type in OperationType.values) {
    test('criterion 6$label: 300 seeded $type problems hide the result', () {
      final random = Random(600 + type.index);
      var checked = 0;
      while (checked < 300) {
        final problem = source(type, random);
        if (problem.result == problem.lhs || problem.result == problem.rhs) {
          continue;
        }
        check(problem);
        checked++;
      }
    });
  }
}

void main() {
  expectStepsHideResult((type, random) => type.generate(random));

  test('addition shows place values and carrying', () {
    expect(solutionSteps(const Problem(19, 6, OperationType.plus, 25)), [
      'Break 19 into 10 + 9 and 6 into 6.',
      'Add matching places: 10 + 0 = 10; 9 + 6 = 15.',
      'Combine the parts: 10 + 15 = 25.',
    ]);
  });

  test('single-digit addition counts on without the answer', () {
    expect(solutionSteps(const Problem(3, 4, OperationType.plus, 7)), [
      'Start at 4 and count on 3 more: 5, 6, …',
      'So 3 + 4 = 7.',
    ]);
  });

  test('addition in one place adds the digits of that place', () {
    expect(solutionSteps(const Problem(50, 60, OperationType.plus, 110)), [
      '50 is 5 tens and 60 is 6 tens. Add 5 + 6, then make it tens.',
      'So 50 + 60 = 110.',
    ]);
  });

  test('subtraction hops to round numbers', () {
    expect(solutionSteps(const Problem(12, 3, OperationType.minus, 9)), [
      'Find the difference between 12 and 3: what do you add to 3 to make 12?',
      'Hop to round numbers: from 3 up to 10 is 7; from 10 up to 12 is 2.',
      'Add the hops: 7 + 2 = 9. So 12 − 3 = 9.',
    ]);
  });

  test('subtraction without safe hops counts up instead', () {
    expect(solutionSteps(const Problem(13, 3, OperationType.minus, 10)), [
      'Find the difference between 13 and 3: what do you add to 3 to make 13?',
      'Count up from 3 to 13 in hops, for example to the next ten, and keep '
          'track of how far you went.',
      'So 13 − 3 = 10. Check: 10 + 3 = 13.',
    ]);
  });

  test('subtraction of equal numbers explains that nothing is left', () {
    expect(solutionSteps(const Problem(5, 5, OperationType.minus, 0)), [
      'Find the difference between 5 and 5.',
      'Both numbers are the same, so taking one away from the other leaves '
          'nothing.',
      'So 5 − 5 = 0.',
    ]);
  });

  test('multiplication shows partial products', () {
    expect(solutionSteps(const Problem(4, 223, OperationType.multiply, 892)), [
      'Split 223 into 200 + 20 + 3.',
      'Multiply each part by 4: 4 × 200 = 800; 4 × 20 = 80; 4 × 3 = 12.',
      'Add the products: 800 + 80 + 12 = 892.',
    ]);
  });

  test('multiplication of a single part counts in groups', () {
    expect(solutionSteps(const Problem(4, 5, OperationType.multiply, 20)), [
      '4 × 5 means 4 groups of 5.',
      'Count in 5s, 4 times: 5, 10, 15, …',
      'So 4 × 5 = 20.',
    ]);
  });

  test('division counts in groups of the divisor', () {
    expect(solutionSteps(const Problem(12, 3, OperationType.divide, 4.0)), [
      'How many 3s make 12? Think: 3 × ? = 12.',
      'Count in 3s: 3, 6, 9, … until you reach 12. How many 3s did you count?',
      '3 × 4 = 12, so 12 ÷ 3 = 4.',
    ]);
  });

  test('division drops the count when it would show the answer', () {
    expect(solutionSteps(const Problem(18, 3, OperationType.divide, 6.0)), [
      'How many 3s make 18? Think: 3 × ? = 18.',
      'Count in 3s until you reach 18. How many 3s did you count?',
      '3 × 6 = 18, so 18 ÷ 3 = 6.',
    ]);
  });
}

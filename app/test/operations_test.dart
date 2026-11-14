import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';

void main() {
  test('all operations calculate correct results', () {
    expect(OperationType.plus.calculate(12, 3), 15);
    expect(OperationType.minus.calculate(12, 3), 9);
    expect(OperationType.multiply.calculate(12, 3), 36);
    expect(OperationType.divide.calculate(12, 3), 4);
  });

  test('the level table is the one in the plan', () {
    const sums = [(1, 10), (1, 20), (10, 100), (100, 1000), (1000, 10000)];
    const factors = [
      ((2, 5), (2, 5)),
      ((2, 10), (2, 10)),
      ((2, 12), (2, 20)),
      ((2, 20), (11, 50)),
      ((11, 30), (11, 99)),
    ];
    for (final type in [OperationType.plus, OperationType.minus]) {
      expect(type.levels, [for (final range in sums) (range, range)]);
    }
    for (final type in [OperationType.multiply, OperationType.divide]) {
      expect(type.levels, factors);
    }
  });

  Matcher inRange(Range range) => inInclusiveRange(range.$1, range.$2);

  for (var level = 1; level <= maxLevel; level++) {
    for (final type in OperationType.values) {
      test('criterion 17: 500 $type problems at level $level stay in the '
          'table', () {
        final (first, second) = type.levels[level - 1];
        final random = Random(level * 10 + type.index);
        for (var i = 0; i < 500; i++) {
          final problem = type.generate(random, level);
          final (lhs, rhs) = (problem.lhs, problem.rhs);
          expect(problem.kind, type);
          expect(problem.level, level);
          expect(problem.result, type.calculate(lhs, rhs));
          expect(problem.result, problem.result.truncate());
          expect(problem.result, greaterThanOrEqualTo(0));
          switch (type) {
            case OperationType.plus:
              expect(lhs, inRange(first));
              expect(rhs, inRange(second));
            case OperationType.minus:
              expect(lhs, inRange(first));
              expect(rhs, inRange(second));
              expect(lhs, greaterThanOrEqualTo(rhs));
            case OperationType.multiply:
              expect(min(lhs, rhs), inRange(first));
              expect(max(lhs, rhs), inRange(second));
            case OperationType.divide:
              expect(rhs, inRange(first));
              expect(problem.result, inRange(second));
          }
        }
      });
    }
  }

  test('multiplication shows the smaller factor on either side', () {
    final random = Random(5);
    final problems = [
      for (var i = 0; i < 100; i++) OperationType.multiply.generate(random, 4),
    ];
    expect(problems.where((p) => p.lhs < p.rhs), isNotEmpty);
    expect(problems.where((p) => p.lhs > p.rhs), isNotEmpty);
  });

  test('a whole-number answer of either type matches the result', () {
    const sum = Problem(2, 3, OperationType.plus, 5);
    const quotient = Problem(12, 3, OperationType.divide, 4.0);
    Attempt answer(Problem problem, num? value) => Attempt(
      problem,
      firstAnswer: value,
      elapsedMs: 0,
      answeredAt: DateTime(2026),
    );

    expect(answer(sum, 5.0).correct, isTrue);
    expect(answer(quotient, 4).correct, isTrue);
    expect(answer(sum, 4.5).correct, isFalse);
    expect(answer(sum, null).skipped, isTrue);
    expect(answer(sum, null).correct, isFalse);
  });

  test('whole numbers are formatted without a decimal part', () {
    expect(formatNumber(4.0), '4');
    expect(formatNumber(14), '14');
    expect(formatNumber(4.5), '4.5');
    expect(formatNumber(-3.0), '-3');
  });

  test('question text uses the operation symbol', () {
    expect(const Problem(12, 3, OperationType.divide, 4.0).question, '12 ÷ 3');
  });
}

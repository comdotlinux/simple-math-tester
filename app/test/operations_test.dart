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

  test('operand and result ranges are unchanged', () {
    expect(
      [
        for (final type in OperationType.values)
          [type.minOperand, type.maxOperand, type.minResult, type.maxResult],
      ],
      [
        [2, 10000, 3, 10000],
        [2, 10000, 0, 10000],
        [2, 500, 10, 1000],
        [3, 1000, 2, 1000],
      ],
    );
  });

  for (final type in OperationType.values) {
    test('$type generates problems inside its ranges', () {
      final random = Random(type.index);
      for (var i = 0; i < 10000; i++) {
        final problem = type.generate(random);
        expect(problem.kind, type);
        expect(problem.level, 1);
        expect(problem.lhs, inInclusiveRange(type.minOperand, type.maxOperand));
        expect(problem.rhs, inInclusiveRange(type.minOperand, type.maxOperand));
        expect(
          problem.result,
          inInclusiveRange(type.minResult, type.maxResult),
        );
        expect(problem.result, problem.result.truncate());
        expect(problem.result, type.calculate(problem.lhs, problem.rhs));
      }
    });
  }

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

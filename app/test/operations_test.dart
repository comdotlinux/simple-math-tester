import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';

void main() {
  test('all operations calculate correct results', () {
    expect(
      (OperationType.plus.source as ArithmeticSource).calculate(12, 3),
      15,
    );
    expect(
      (OperationType.minus.source as ArithmeticSource).calculate(12, 3),
      9,
    );
    expect(
      (OperationType.multiply.source as ArithmeticSource).calculate(12, 3),
      36,
    );
    expect(
      (OperationType.divide.source as ArithmeticSource).calculate(12, 3),
      4,
    );
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
      expect((type.source as ArithmeticSource).levels, [
        for (final range in sums) (range, range),
      ]);
    }
    for (final type in [OperationType.multiply, OperationType.divide]) {
      expect((type.source as ArithmeticSource).levels, factors);
    }
  });

  Matcher inRange(Range range) => inInclusiveRange(range.$1, range.$2);

  for (var level = 1; level <= maxLevel; level++) {
    for (final type in arithmeticKinds) {
      test('criterion 17: 500 $type problems at level $level stay in the '
          'table', () {
        final (first, second) =
            (type.source as ArithmeticSource).levels[level - 1];
        final random = Random(level * 10 + type.index);
        for (var i = 0; i < 500; i++) {
          final problem = type.generate(random, level) as ArithmeticProblem;
          final (lhs, rhs) = (problem.lhs, problem.rhs);
          expect(problem.kind, type);
          expect(problem.level, level);
          expect(
            problem.result,
            (type.source as ArithmeticSource).calculate(lhs, rhs),
          );
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
            case OperationType.algebra:
              fail('not an arithmetic kind');
          }
        }
      });
    }
  }

  test('multiplication shows the smaller factor on either side', () {
    final random = Random(5);
    final problems = [
      for (var i = 0; i < 100; i++)
        OperationType.multiply.generate(random, 4) as ArithmeticProblem,
    ];
    expect(problems.where((p) => p.lhs < p.rhs), isNotEmpty);
    expect(problems.where((p) => p.lhs > p.rhs), isNotEmpty);
  });

  test('a whole-number answer of either type matches the result', () {
    const sum = ArithmeticProblem(2, 3, OperationType.plus, 5);
    const quotient = ArithmeticProblem(12, 3, OperationType.divide, 4.0);
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
    expect(
      const ArithmeticProblem(12, 3, OperationType.divide, 4.0).question,
      '12 ÷ 3',
    );
  });

  group('algebra', () {
    const kind = OperationType.algebra;
    final source = kind.source as AlgebraSource;

    test('has level 1 only so far; arithmetic has 5', () {
      expect(kind.highestLevel, 1);
      for (final type in arithmeticKinds) {
        expect(type.highestLevel, maxLevel);
      }
    });

    test('level 1 is 484 different missing-number problems in four families '
        'of 121', () {
      final problems = source.problems(kind, 1).toList();
      expect(problems, hasLength(484));
      expect(problems.map((p) => p.question).toSet(), hasLength(484));
      final byVariant = <String, int>{};
      for (final p in problems) {
        byVariant[p.variant] = (byVariant[p.variant] ?? 0) + 1;
        expect([p.kind, p.level], [kind, 1]);
        final [a, b] = p.params;
        expect(a, inInclusiveRange(0, 10));
        expect(b, inInclusiveRange(0, 10));
        // Every number shown and the answer are whole and at least 0; the
        // largest is the sum of the other two.
        final numbers = [
          for (final token in p.tokens) ?int.tryParse(token),
          p.result.toInt(),
        ]..sort();
        expect(numbers.first, greaterThanOrEqualTo(0));
        expect(numbers[0] + numbers[1], numbers[2], reason: p.question);
        expect(p.tokens.where((t) => t == EquationProblem.blank), hasLength(1));
      }
      expect(byVariant, {
        'missingSecondAddend': 121,
        'missingFirstAddend': 121,
        'missingSubtrahend': 121,
        'missingMinuend': 121,
      });
    });

    test('each family builds its form', () {
      String question(String variant) =>
          source.build(kind, variant, [3, 4])!.question;
      expect(question('missingSecondAddend'), '3 + □ = 7');
      expect(question('missingFirstAddend'), '□ + 3 = 7');
      expect(question('missingSubtrahend'), '7 − □ = 3');
      expect(question('missingMinuend'), '□ − 3 = 4');
      expect(source.build(kind, 'missingMinuend', [3, 4])!.result, 7);
      expect(source.build(kind, 'missingSubtrahend', [3, 4])!.result, 4);
    });

    test('an unknown variant or params that do not fit build nothing', () {
      expect(source.build(kind, 'missingFactor', [3, 4]), isNull);
      expect(source.build(kind, 'missingMinuend', [3]), isNull);
      expect(source.build(kind, 'missingMinuend', [3, 4, 5]), isNull);
      expect(source.build(kind, 'missingMinuend', [-1, 4]), isNull);
    });

    test('generate draws every family, only problems of the level', () {
      final all = {for (final p in source.problems(kind, 1)) p.question};
      final random = Random(7);
      final variants = <String>{};
      for (var i = 0; i < 2000; i++) {
        final problem = kind.generate(random, 1) as EquationProblem;
        expect(all, contains(problem.question));
        expect(problem.level, 1);
        variants.add(problem.variant);
      }
      expect(variants, hasLength(4));
    });
  });
}

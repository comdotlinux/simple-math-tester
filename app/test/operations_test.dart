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
            case OperationType.algebra || OperationType.geometry:
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

    test('has levels 1 to 5, as arithmetic does', () {
      expect(kind.highestLevel, 5);
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

    test('level 2 is 360 different missing-factor problems in four families '
        'of 90, and 10 squares and 10 square roots', () {
      final problems = source.problems(kind, 2).toList();
      expect(problems, hasLength(380));
      expect(problems.map((p) => p.question).toSet(), hasLength(380));
      final byVariant = <String, int>{};
      for (final p in problems) {
        byVariant[p.variant] = (byVariant[p.variant] ?? 0) + 1;
        expect([p.kind, p.level], [kind, 2]);
        expect(p.tokens.where((t) => t == EquationProblem.blank), hasLength(1));
        if (p.params case [final r]) {
          // a² = □ with a 1 to 10, or √c = □ with c = r × r.
          expect(r, inInclusiveRange(1, 10));
          expect(
            p.question,
            p.variant == 'missingSquare' ? '$r² = □' : '√${r * r} = □',
          );
          continue;
        }
        final [a, b] = p.params;
        expect(a, inInclusiveRange(2, 10));
        expect(b, inInclusiveRange(1, 10));
        // Every number shown and the answer are whole and at least 1; the
        // largest is the product of the other two.
        final numbers = [
          for (final token in p.tokens) ?int.tryParse(token),
          p.result.toInt(),
        ]..sort();
        expect(numbers.first, greaterThanOrEqualTo(1));
        expect(numbers[0] * numbers[1], numbers[2], reason: p.question);
        expect(p.tokens.where((t) => t == EquationProblem.blank), hasLength(1));
      }
      expect(byVariant, {
        'missingFirstFactor': 90,
        'missingSecondFactor': 90,
        'missingDivisor': 90,
        'missingDividend': 90,
        'missingSquare': 10,
        'missingSquareRoot': 10,
      });
    });

    Map<String, int> countByVariant(int level) {
      final counts = <String, int>{};
      for (final p in source.problems(kind, level)) {
        counts[p.variant] = (counts[p.variant] ?? 0) + 1;
      }
      return counts;
    }

    test('levels 3 to 5 have their families, ranges and counts', () {
      // a 2..12 and the other number 0..20.
      // Squares and roots: bases 6..12 at level 3, 13..20 at level 4.
      expect(countByVariant(3), {
        'nPlusA': 231,
        'nMinusA': 231,
        'aTimesN': 231,
        'nDividedByA': 231,
        'aSquared': 7,
        'squareRootOfC': 7,
      });
      // a 2..9, b 1..20, n 1..20; an − b at least 0.
      expect(countByVariant(4), {
        'anPlusB': 3200,
        'anMinusB': 2911,
        'aSquared': 8,
        'squareRootOfC': 8,
      });
      // a 2..9, b 1..10, n −10..10 (the quotient for ÷, never 0); tenths
      // −10.0..10.0, never whole, with a whole right-hand side.
      expect(countByVariant(5), {
        'aBracketNMinusB': 1680,
        'aBracketNPlusB': 1680,
        'nDividedByAPlusB': 1600,
        'anPlusBNegativeN': 800,
        'anTenths': 160,
        // n² = c with n 1..12; an² = c with a 2..9 and n 2..12.
        'nSquared': 12,
        'anSquared': 88,
      });
      for (var level = 3; level <= 5; level++) {
        for (final p in source.problems(kind, level)) {
          expect([p.kind, p.level], [kind, level]);
          expect(p.tokens, isNot(contains(EquationProblem.blank)));
          // The condition line "n > 0" names n a second time.
          expect(
            'n'.allMatches(p.question.replaceFirst(', n > 0', '')),
            hasLength(1),
            reason: p.question,
          );
          for (final (i, (low, high))
              in source.levels[level - 1]
                  .firstWhere((family) => family.$1 == p.variant)
                  .$2
                  .indexed) {
            expect(p.params[i], inInclusiveRange(low, high));
          }
        }
      }
    });

    test('level 5 answers go below zero and into tenths', () {
      final answers = {
        for (final p in source.problems(kind, 5)) p.resultHundredths,
      };
      expect(answers.where((a) => a < 0), isNotEmpty);
      expect(answers.where((a) => a % 100 != 0), isNotEmpty);
      expect(answers.every((a) => a % 10 == 0), isTrue);
      for (final p in source.problems(kind, 5)) {
        switch (p.variant) {
          case 'anPlusBNegativeN':
            expect(p.resultHundredths, isNegative);
          case 'anTenths':
            expect(p.resultHundredths % 100, isNot(0));
        }
      }
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
      expect(question('missingFirstFactor'), '□ × 3 = 12');
      expect(question('missingSecondFactor'), '3 × □ = 12');
      expect(question('missingDivisor'), '12 ÷ □ = 3');
      expect(question('missingDividend'), '□ ÷ 3 = 4');
      expect(source.build(kind, 'missingDivisor', [3, 4])!.result, 4);
      expect(source.build(kind, 'missingDividend', [3, 4])!.result, 12);
      String letter(String variant, List<int> params) =>
          source.build(kind, variant, params)!.question;
      expect(letter('nPlusA', [5, 7]), 'n + 5 = 12');
      expect(letter('nMinusA', [5, 7]), 'n − 5 = 7');
      expect(letter('aTimesN', [3, 5]), '3 × n = 15');
      expect(letter('nDividedByA', [4, 3]), 'n ÷ 4 = 3');
      expect(letter('anPlusB', [2, 3, 4]), '2n + 3 = 11');
      expect(letter('anMinusB', [4, 5, 5]), '4n − 5 = 15');
      expect(letter('aBracketNMinusB', [3, 2, 6]), '3(n − 2) = 12');
      expect(letter('aBracketNMinusB', [3, 2, -4]), '3(n − 2) = −18');
      expect(letter('aBracketNPlusB', [3, 2, 2]), '3(n + 2) = 12');
      expect(letter('nDividedByAPlusB', [4, 3, 1]), 'n ÷ 4 + 3 = 4');
      expect(letter('anPlusBNegativeN', [3, 9, -2]), '3n + 9 = 3');
      expect(letter('anTenths', [4, 25]), '4n = 10');
      expect(letter('anTenths', [5, -2]), '5n = −1');
      expect(source.build(kind, 'nMinusA', [5, 7])!.result, 12);
      expect(source.build(kind, 'nDividedByA', [4, 3])!.result, 12);
      expect(source.build(kind, 'nDividedByAPlusB', [4, 3, 1])!.result, 4);
      expect(source.build(kind, 'anTenths', [4, 25])!.resultHundredths, 250);
      expect(source.build(kind, 'anTenths', [5, -2])!.resultHundredths, -20);
      expect(letter('missingSquare', [7]), '7² = □');
      expect(letter('missingSquareRoot', [7]), '√49 = □');
      expect(letter('aSquared', [12]), '12² = n');
      expect(letter('squareRootOfC', [20]), '√400 = n');
      expect(letter('nSquared', [7]), 'n² = 49, n > 0');
      expect(letter('anSquared', [2, 5]), '2n² = 50, n > 0');
      expect(source.build(kind, 'missingSquare', [7])!.result, 49);
      expect(source.build(kind, 'missingSquareRoot', [7])!.result, 7);
      expect(source.build(kind, 'aSquared', [12])!.result, 144);
      expect(source.build(kind, 'squareRootOfC', [20])!.result, 20);
      expect(source.build(kind, 'nSquared', [7])!.result, 7);
      expect(source.build(kind, 'anSquared', [2, 5])!.result, 5);
    });

    test('an unknown variant or params that do not fit build nothing', () {
      expect(source.build(kind, 'missingFactor', [3, 4]), isNull);
      expect(source.build(kind, 'missingMinuend', [3]), isNull);
      expect(source.build(kind, 'missingMinuend', [3, 4, 5]), isNull);
      expect(source.build(kind, 'missingMinuend', [-1, 4]), isNull);
      // A factor or divisor of 0 would give no answer or every answer.
      expect(source.build(kind, 'missingFirstFactor', [0, 4]), isNull);
      expect(source.build(kind, 'missingSecondFactor', [0, 4]), isNull);
      expect(source.build(kind, 'missingDivisor', [3, 0]), isNull);
      expect(source.build(kind, 'missingDivisor', [0, 4]), isNull);
      expect(source.build(kind, 'missingDividend', [0, 4]), isNull);
      // Levels 3 and 4 show no number below zero.
      expect(source.build(kind, 'nPlusA', [-1, 4]), isNull);
      expect(source.build(kind, 'nMinusA', [3, -4]), isNull);
      expect(source.build(kind, 'aTimesN', [0, 4]), isNull);
      expect(source.build(kind, 'nDividedByA', [0, 4]), isNull);
      expect(source.build(kind, 'anPlusB', [2, 3, 0]), isNull);
      expect(source.build(kind, 'anMinusB', [2, 5, 2]), isNull);
      expect(source.build(kind, 'anMinusB', [1, 1, 4]), isNull);
      // Level 5: n ÷ a with the quotient 0, a negative family with n at
      // least 0, and tenths that are whole or give a decimal right side.
      expect(source.build(kind, 'nDividedByAPlusB', [4, 3, 0]), isNull);
      expect(source.build(kind, 'anPlusBNegativeN', [3, 9, 0]), isNull);
      expect(source.build(kind, 'anTenths', [4, 20]), isNull);
      expect(source.build(kind, 'anTenths', [3, 25]), isNull);
      expect(source.build(kind, 'aBracketNPlusB', [1, 2, 3]), isNull);
      // Squares and roots: one param (two for an²), never below zero; n at
      // least 1, and at least 2 where a is divided off first.
      expect(source.build(kind, 'missingSquare', [3, 4]), isNull);
      expect(source.build(kind, 'missingSquare', [-3]), isNull);
      expect(source.build(kind, 'missingSquareRoot', [-3]), isNull);
      expect(source.build(kind, 'aSquared', []), isNull);
      expect(source.build(kind, 'squareRootOfC', [-1]), isNull);
      expect(source.build(kind, 'nSquared', [0]), isNull);
      expect(source.build(kind, 'nSquared', [-7]), isNull);
      expect(source.build(kind, 'anSquared', [2, 1]), isNull);
      expect(source.build(kind, 'anSquared', [1, 5]), isNull);
      expect(source.build(kind, 'anSquared', [5]), isNull);
    });

    test('generate draws every family, only problems of the level', () {
      for (var level = 1; level <= kind.highestLevel; level++) {
        final all = {for (final p in source.problems(kind, level)) p.question};
        final random = Random(7);
        final variants = <String>{};
        for (var i = 0; i < 2000; i++) {
          final problem = kind.generate(random, level) as EquationProblem;
          expect(all, contains(problem.question));
          expect(problem.level, level);
          variants.add(problem.variant);
        }
        expect(variants, hasLength(source.levels[level - 1].length));
      }
    });

    test('generate draws each family of a level equally often, also one that '
        'rejects most params', () {
      for (final level in [2, 3, 4, 5]) {
        final families = source.levels[level - 1].length;
        final random = Random(11);
        const draws = 10000;
        final counts = <String, int>{};
        for (var i = 0; i < draws; i++) {
          final problem = kind.generate(random, level) as EquationProblem;
          counts[problem.variant] = (counts[problem.variant] ?? 0) + 1;
        }
        for (final count in counts.values) {
          expect(count, closeTo(draws / families, draws / families * 0.1));
        }
      }
    });
  });
}

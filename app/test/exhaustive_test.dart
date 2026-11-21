import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/solution_steps.dart';

import 'oracle.dart';

const _arithmetic = [
  OperationType.plus,
  OperationType.minus,
  OperationType.multiply,
  OperationType.divide,
];

/// Problems drawn at a level too large to enumerate.
const _sample = 20000;

/// Fixed draws for [ArithmeticSource.generate]: the two numbers in order,
/// and [flag] for every coin it tosses.
class _Draws implements Random {
  _Draws(this.ints, this.flag);

  final List<int> ints;
  final bool flag;
  var drawn = 0;

  @override
  int nextInt(int max) {
    final value = ints[drawn++];
    if (value >= max) throw RangeError.range(value, 0, max - 1);
    return value;
  }

  @override
  bool nextBool() => flag;

  @override
  double nextDouble() => throw UnsupportedError('nextDouble');
}

/// Every distinct problem of [type] at [level], made by its own `generate`:
/// each pair from the level's two ranges, with both outcomes of the coin.
List<ArithmeticProblem> _everyProblem(OperationType type, int level) {
  final ((aMin, aMax), (bMin, bMax)) =
      (type.source as ArithmeticSource).levels[level - 1];
  final problems = <String, ArithmeticProblem>{};
  for (var a = 0; a <= aMax - aMin; a++) {
    for (var b = 0; b <= bMax - bMin; b++) {
      for (final flag in [false, true]) {
        final draws = _Draws([a, b], flag);
        final problem = type.generate(draws, level) as ArithmeticProblem;
        expect(draws.drawn, 2, reason: 'generate draws two numbers');
        problems[problem.question] = problem;
      }
    }
  }
  return problems.values.toList();
}

int _pairs(OperationType type, int level) {
  final ((aMin, aMax), (bMin, bMax)) =
      (type.source as ArithmeticSource).levels[level - 1];
  return (aMax - aMin + 1) * (bMax - bMin + 1);
}

void main() {
  group('arithmetic through the oracle', () {
    final clock = Stopwatch();
    setUpAll(clock.start);
    tearDownAll(() {
      // ignore: avoid_print
      print('Exhaustive arithmetic: ${clock.elapsedMilliseconds} ms in total');
    });

    for (final type in _arithmetic) {
      for (var level = 1; level <= maxLevel; level++) {
        // Levels 1 to 3, and any level with at most _sample pairs, are
        // enumerated; the rest are sampled from a fixed seed.
        final enumerate = level <= 3 || _pairs(type, level) <= _sample;
        test('${type.name} level $level: every problem is right, whole and '
            'at least 0', () {
          final start = clock.elapsedMilliseconds;
          final random = Random(1000 * level + type.index);
          final problems = enumerate
              ? _everyProblem(type, level)
              : [
                  for (var i = 0; i < _sample; i++)
                    type.generate(random, level) as ArithmeticProblem,
                ];
          final failures = [
            for (final problem in problems)
              if (check(problem.question, problem.result) != Verdict.ok ||
                  problem.result < 0 ||
                  problem.result != problem.result.round())
                '${problem.question} = ${problem.result}',
          ];
          expect(failures, isEmpty);
          // ignore: avoid_print
          print(
            '${type.name} level $level: ${problems.length} problems '
            '${enumerate ? 'enumerated' : 'sampled'} in '
            '${clock.elapsedMilliseconds - start} ms',
          );
        });
      }
    }
  });

  group('algebra through the oracle', () {
    const kind = OperationType.algebra;
    final source = kind.source as AlgebraSource;
    // The plan's count of each level's problems.
    const counts = {1: 484, 2: 360};

    for (var level = 1; level <= kind.highestLevel; level++) {
      test('level $level: every problem has its answer as the one solution, '
          'whole and at least 0', () {
        final clock = Stopwatch()..start();
        final problems = source.problems(kind, level).toList();
        expect(problems, hasLength(counts[level]));
        final failures = [
          for (final problem in problems)
            if (check(problem.question, problem.result) != Verdict.ok ||
                problem.result < 0 ||
                problem.result != problem.result.round() ||
                RegExp(r'-|\.').hasMatch(problem.question))
              '${problem.question} → ${problem.result}',
        ];
        expect(failures, isEmpty);
        // ignore: avoid_print
        print(
          'algebra level $level: ${problems.length} problems enumerated in '
          '${clock.elapsedMilliseconds} ms',
        );
      });

      test('level $level: an answer + 1 and a displayed right-hand side + 1 '
          'fail', () {
        for (final p in source.problems(kind, level)) {
          expect(
            check(p.question, p.result + 1),
            Verdict.wrongRoot,
            reason: p.question,
          );
          final right = int.parse(p.tokens.last);
          final mutant = [
            ...p.tokens.take(p.tokens.length - 1),
            '${right + 1}',
          ];
          expect(
            check(mutant.join(' '), p.result),
            Verdict.wrongRoot,
            reason: mutant.join(' '),
          );
        }
      });

      test('level $level: the oracle recomputes every hint step', () {
        final failures = <String>[];
        for (final p in source.problems(kind, level)) {
          final hint = equationHint(p);
          final shown = {for (final token in p.tokens) ?int.tryParse(token)};
          for (final step in hint) {
            // Each calculation undoes the operation around the blank with
            // numbers the question shows, so its value is the answer.
            if (check(step.calculation, p.result) != Verdict.ok ||
                !shown.containsAll([step.left, step.right])) {
              failures.add('${p.question}: ${step.calculation}');
            }
          }
          // Only the last step states the answer and puts it back.
          final last = hint.last;
          final [left, right] = last.check!.split(' = ');
          if (hint.length < 2 ||
              last.move != EquationMove.answer ||
              last.value != p.result ||
              last.check != p.question.replaceAll(box, '${p.result}') ||
              check(left, int.parse(right)) != Verdict.ok ||
              hint
                  .take(hint.length - 1)
                  .any((step) => step.value != null || step.check != null)) {
            failures.add('${p.question}: ${last.calculation}, ${last.check}');
          }
        }
        expect(failures, isEmpty);
      });

      test('level $level: a hint calculation or check off by 1 fails', () {
        for (final p in source.problems(kind, level)) {
          final last = equationHint(p).last;
          final calculation = '${last.left} ${last.sign} ${last.right + 1}';
          expect(
            check(calculation, p.result),
            Verdict.wrongResult,
            reason: calculation,
          );
          final [left, right] = p.question
              .replaceAll(box, '${p.result + 1}')
              .split(' = ');
          expect(check(left, int.parse(right)), Verdict.wrongResult);
        }
      });
    }
  });

  group('mutations fail the oracle', () {
    late final problems = [
      for (final type in _arithmetic)
        for (var level = 1; level <= 3; level++) ..._everyProblem(type, level),
    ];

    test('a generator that returns result + 1', () {
      for (final p in problems) {
        final mutant = ArithmeticProblem(p.lhs, p.rhs, p.kind, p.result + 1);
        expect(
          check(mutant.question, mutant.result),
          Verdict.wrongResult,
          reason: mutant.question,
        );
      }
    });

    test('a displayed right operand + 1', () {
      for (final p in problems) {
        final mutant = ArithmeticProblem(p.lhs, p.rhs + 1, p.kind, p.result);
        expect(
          check(mutant.question, p.result),
          Verdict.wrongResult,
          reason: mutant.question,
        );
      }
    });
  });

  group('the character table', () {
    test('maps the app characters and the box', () {
      expect(toEvaluatorSyntax('12 − 3 × 4 ÷ 2'), '12-3*4/2');
      expect(toEvaluatorSyntax('3 + $box = 7'), '3+n=7');
      expect(toEvaluatorSyntax('n + 5 = 12'), 'n+5=12');
    });

    test('a digit directly before a letter or a bracket multiplies', () {
      expect(toEvaluatorSyntax('2n + 3 = 11'), '2*n+3=11');
      expect(toEvaluatorSyntax('12n = 24'), '12*n=24');
      expect(toEvaluatorSyntax('3(n − 2) = 12'), '3*(n-2)=12');
      expect(toEvaluatorSyntax('3$box = 6'), '3*n=6');
      expect(toEvaluatorSyntax('3 × n = 15'), '3*n=15');
      expect(toEvaluatorSyntax('(n − 2) + 1 = 4'), '(n-2)+1=4');
    });

    test('rejects any other character', () {
      for (final text in ['3 - 2', '3 * 2', '3 / 2', '2x = 4', '3,5 + 1']) {
        expect(() => toEvaluatorSyntax(text), throwsFormatException);
        expect(check(text, 1), Verdict.unparsable, reason: text);
      }
    });
  });

  group('every planned algebra form', () {
    const samples = {
      '3 + $box = 7': 4,
      '$box + 4 = 9': 5,
      '9 − $box = 4': 5,
      '$box − 4 = 5': 9,
      '$box × 4 = 20': 5,
      '4 × $box = 20': 5,
      '18 ÷ $box = 6': 3,
      '$box ÷ 3 = 6': 18,
      'n + 5 = 12': 7,
      'n − 5 = 7': 12,
      '3 × n = 15': 5,
      'n ÷ 4 = 3': 12,
      '2n + 3 = 11': 4,
      '4n − 5 = 15': 5,
      '3(n − 2) = 12': 6,
      '3(n + 2) = 12': 2,
      'n ÷ 4 + 3 = 7': 16,
      '3n + 9 = 3': -2,
      '4n = 10': 2.5,
    };

    samples.forEach((question, answer) {
      test('$question has the one solution $answer', () {
        expect(check(question, answer), Verdict.ok);
        expect(check(question, answer + 1), Verdict.wrongRoot);
        expect(check(question, answer + 0.1), Verdict.wrongRoot);
      });
    });

    test('a displayed right-hand side + 1 fails', () {
      samples.forEach((question, answer) {
        final last = RegExp(r'\d+$');
        final mutant = question.replaceFirstMapped(
          last,
          (m) => '${int.parse(m[0]!) + 1}',
        );
        expect(check(mutant, answer), Verdict.wrongRoot, reason: mutant);
      });
    });

    test('rejects equations without exactly one solution', () {
      expect(check('0 × n = 0', 0), Verdict.zeroSlope);
      expect(check('0 × n = 5', 1), Verdict.zeroSlope);
      expect(check('n + n = 4', 2), Verdict.unknownNotOnce);
      expect(check('2 + 3 = 5', 0), Verdict.unknownNotOnce);
      expect(check('0 ÷ $box = 0', 4), Verdict.zeroDivisor);
      expect(check('6 ÷ $box = 0', 0), Verdict.zeroDivisor);
      expect(check('12 ÷ (n + 1) = 3', 3), Verdict.notLinear);
      expect(check('n + 5 = 12', 8), Verdict.wrongRoot);
      expect(check('n + 5 = 12 = 12', 7), Verdict.unparsable);
      expect(check('n + 5', 7), Verdict.unparsable);
    });
  });
}

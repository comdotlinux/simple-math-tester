import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/hundredths.dart';
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

/// The condition line's text form, which an equation in n² may end with.
const _positive = ', n > 0';

/// The moves of an equation hint's second step, the idea.
const _ideas = {
  EquationMove.addAndTakeAway,
  EquationMove.swapTakeAway,
  EquationMove.multiplyAndDivide,
  EquationMove.swapDivide,
  EquationMove.squared,
  EquationMove.squareRoot,
  EquationMove.balance,
};

/// [p]'s question with [hundredths] in place of the unknown, bracketed where
/// it multiplies and is below zero (`3 × (−2) + 9 = 3`); a condition line is
/// left out.
String _substitute(EquationProblem p, int hundredths) {
  final number = formatHundredths(hundredths, 'en');
  return p.question
      .replaceFirst(_positive, '')
      .replaceAllMapped(
        RegExp('(\\d)?n|$box'),
        (m) => m[1] == null
            ? number
            : '${m[1]} × ${hundredths < 0 ? '($number)' : number}',
      );
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
    // The count of each level's problems.
    const counts = {1: 484, 2: 380, 3: 938, 4: 6127, 5: 6020};
    final clock = Stopwatch();
    setUpAll(clock.start);
    tearDownAll(() {
      // ignore: avoid_print
      print('Exhaustive algebra: ${clock.elapsedMilliseconds} ms in total');
    });

    test('every level has a count', () {
      expect(counts.keys, [for (var l = 1; l <= kind.highestLevel; l++) l]);
    });

    for (var level = 1; level <= kind.highestLevel; level++) {
      // Negative numbers and tenths first come at level 5.
      final signedDecimal = level >= 5;
      late final problems = source.problems(kind, level).toList();

      test(
        'level $level: every problem has its answer as the one solution'
        '${signedDecimal ? ' in tenths at most' : ', whole and at least 0'}',
        () {
          final start = clock.elapsedMilliseconds;
          expect(problems, hasLength(counts[level]));
          expect(
            problems.map((p) => p.question).toSet(),
            hasLength(counts[level]),
          );
          final failures = [
            for (final problem in problems)
              if (check(problem.question, problem.result) != Verdict.ok ||
                  problem.resultHundredths % 10 != 0 ||
                  !signedDecimal &&
                      (problem.resultHundredths < 0 ||
                          problem.resultHundredths % 100 != 0 ||
                          RegExp(r'−\d|-|\.').hasMatch(problem.question)))
                '${problem.question} → ${problem.result}',
          ];
          expect(failures, isEmpty);
          // ignore: avoid_print
          print(
            'algebra level $level: ${problems.length} problems enumerated in '
            '${clock.elapsedMilliseconds - start} ms',
          );
        },
      );

      test(
        'level $level: an answer + 1 and a displayed right-hand side + 1 '
        '(a base or radicand + 1 where the unknown is on the right) fail',
        () {
          for (final p in problems) {
            expect(
              check(p.question, p.result + 1),
              Verdict.wrongRoot,
              reason: p.question,
            );
            final i = p.tokens.indexOf('=') + 1;
            final tokens = [...p.tokens];
            if (parseHundredths(p.tokens[i]) case final right?) {
              tokens[i] = signedText(right ~/ 100 + 1);
            } else {
              // 7² = □ becomes 8² = □, √49 = n becomes √50 = n.
              tokens[0] = tokens[0].replaceFirstMapped(
                RegExp(r'\d+'),
                (m) => '${int.parse(m[0]!) + 1}',
              );
            }
            final mutant = EquationProblem(
              p.variant,
              p.params,
              tokens,
              p.kind,
              p.resultHundredths,
            ).question;
            expect(check(mutant, p.result), Verdict.wrongRoot, reason: mutant);
          }
        },
      );

      test('level $level: the oracle recomputes every hint step', () {
        final start = clock.elapsedMilliseconds;
        final failures = <String>[];
        for (final p in problems) {
          final hint = equationHint(p);
          void fail(EquationStep step) => failures.add(
            '${p.question}: ${step.move.name} ${step.calculation}',
          );
          final shown = {
            for (final match in RegExp(r'−?\d+').allMatches(p.question))
              int.parse(match[0]!.replaceFirst('−', '-')),
          };
          final condition = p.question.endsWith(_positive) ? _positive : '';
          // The value of the last undo done, which the next one starts from.
          int? previous;
          // The square whose root the last step finds.
          int? square;
          for (final (i, step) in hint.indexed) {
            final last = i == hint.length - 1;
            // What is asked comes first, then the idea; neither has a
            // calculation.
            if ((step.move == EquationMove.ask) != (i == 0) ||
                _ideas.contains(step.move) != (i == 1)) {
              fail(step);
            }
            if (i < 2) {
              if (step.valueHundredths != null || step.sign.isNotEmpty) {
                fail(step);
              }
              continue;
            }
            if (step.move == EquationMove.whichRoot ||
                step.move == EquationMove.whichPositiveRoot) {
              // A square the question shows or the undo before left; the
              // question has the condition line exactly when the step asks
              // for a number above zero, and √ when it asks for a root.
              if (!(shown.contains(step.right) || step.right == previous) ||
                  last ||
                  hint[i + 1].move != EquationMove.rootAnswer ||
                  (step.move == EquationMove.whichPositiveRoot) !=
                      condition.isNotEmpty ||
                  (step.move == EquationMove.whichRoot) !=
                      p.question.contains('√${step.right}')) {
                fail(step);
              }
              square = step.right;
              continue;
            }
            if (step.move == EquationMove.rootAnswer) {
              // The root times itself makes that square; the root is the
              // value, at least 0.
              final value = step.valueHundredths!;
              if (!last ||
                  square == null ||
                  step.left != step.right ||
                  value != step.left * 100 ||
                  value < 0 ||
                  check(step.calculation, square) != Verdict.ok) {
                fail(step);
              }
              continue;
            }
            if (step.move == EquationMove.belowZero) {
              // Right after the idea, and only when the answer is below zero.
              if (i != 2 || p.resultHundredths >= 0) fail(step);
              continue;
            }
            if (step.move == EquationMove.means) {
              // The short form is in the question, and writing it out keeps
              // the one solution.
              final meaning = step.meaning!;
              final shorthand = step.shorthand!;
              if (!p.question.contains(shorthand) ||
                  !meaning.contains('×') ||
                  check(
                        p.question.replaceFirst(shorthand, meaning),
                        p.result,
                      ) !=
                      Verdict.ok) {
                fail(step);
              }
              continue;
            }
            final value = step.valueHundredths;
            // Numbers the question shows, or the value the step before left.
            if (!shown.contains(step.right) ||
                !(shown.contains(step.left) || step.left == previous) ||
                (step.check != null) != last ||
                (step.move == EquationMove.answer) != last ||
                !signedDecimal && (step.left < 0 || (value ?? 0) < 0)) {
              fail(step);
            }
            if (value == null) {
              // Names the calculation the next step does.
              final next = hint[i + 1];
              if (next.valueHundredths == null ||
                  next.calculation != step.calculation) {
                fail(step);
              }
              continue;
            }
            if (check(step.calculation, value / 100) != Verdict.ok ||
                !last && value == p.resultHundredths) {
              fail(step);
            }
            if (!last) {
              // Every undo before the last leaves the same one solution,
              // with the question's condition line.
              final equation = step.equation ?? '';
              if (check('$equation$condition', p.result) != Verdict.ok ||
                  !equation.endsWith(' = ${signedText(value ~/ 100)}')) {
                fail(step);
              }
              previous = value ~/ 100;
            }
          }
          // The last step states the answer and puts it back.
          final last = hint.last;
          final [left, right] = last.check!.split(' = ');
          if (hint.length < 2 ||
              !{
                EquationMove.answer,
                EquationMove.rootAnswer,
              }.contains(last.move) ||
              last.valueHundredths != p.resultHundredths ||
              last.check != _substitute(p, p.resultHundredths) ||
              check(left, parseHundredths(right)! / 100) != Verdict.ok ||
              (p.resultHundredths < 0) !=
                  (hint[2].move == EquationMove.belowZero)) {
            failures.add('${p.question}: ${last.calculation}, ${last.check}');
          }
        }
        expect(failures, isEmpty);
        // ignore: avoid_print
        print(
          'algebra level $level: hints of ${problems.length} problems '
          'recomputed in ${clock.elapsedMilliseconds - start} ms',
        );
      });

      test('level $level: a hint calculation or check off by 1 fails', () {
        for (final p in problems) {
          final hint = equationHint(p);
          for (final (i, step) in hint.indexed) {
            // A root's last step makes the square the step before names.
            final value = step.move == EquationMove.rootAnswer
                ? hint[i - 1].right * 100
                : step.valueHundredths;
            if (value == null) continue;
            final calculations = [
              '${signedText(step.left + 1)} ${step.sign} ${step.right}',
              // 0 × a and 0 ÷ a are 0 for every a.
              if (step.left != 0 || step.sign == '+' || step.sign == '−')
                '${signedText(step.left)} ${step.sign} ${step.right + 1}',
            ];
            for (final calculation in calculations) {
              expect(
                check(calculation, value / 100),
                Verdict.wrongResult,
                reason: calculation,
              );
            }
          }
          final [left, right] = _substitute(
            p,
            p.resultHundredths + 100,
          ).split(' = ');
          expect(
            check(left, parseHundredths(right)! / 100),
            Verdict.wrongResult,
            reason: '$left = $right',
          );
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
      '13.68 + n = 16.05': 2.37,
      '7² = $box': 49,
      '√49 = $box': 7,
      '12² = n': 144,
      '√400 = n': 20,
      'n² = 49, n > 0': 7,
      '2n² = 50, n > 0': 5,
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
        // Only a number at the very end, not a blank or a condition line.
        if (!question.contains(RegExp(r'= \d+$'))) return;
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
      // A gentle curve with its true root claimed, and with decimals.
      expect(check('1 ÷ (n + 1000) = 0.01', -900), Verdict.notLinear);
      expect(check('13.68 ÷ (n + 1) = 0.01', 1367), Verdict.notLinear);
      expect(check('n + 5 = 12', 8), Verdict.wrongRoot);
      expect(check('n + 5 = 12 = 12', 7), Verdict.unparsable);
      expect(check('n + 5', 7), Verdict.unparsable);
    });

    test('an equation in n² needs its condition line for one solution', () {
      expect(check('n² = 49', 7), Verdict.twoSolutions);
      expect(check('n² = 49', -7), Verdict.twoSolutions);
      expect(check('2n² = 50', 5), Verdict.twoSolutions);
      expect(check('n² = 49, n > 0', -7), Verdict.wrongRoot);
      expect(check('n² = 0, n > 0', 0), Verdict.noSolution);
      expect(check('n² + 1 = 0', 1), Verdict.noSolution);
      expect(check('n + 5 = 2, n > 0', -3), Verdict.noSolution);
      expect(check('n² = 0', 0), Verdict.ok);
      expect(check('(n − 3)² = 0', 3), Verdict.ok);
      expect(check('n² = 50, n > 0', 7.07), Verdict.wrongRoot);
      expect(check('1 ÷ (n² + 1) = 1, n > 0', 1), Verdict.notLinear);
      expect(check('7² + 1', 50), Verdict.ok);
      expect(check('√49 × 2', 14), Verdict.ok);
      expect(check('√49, n > 0', 7), Verdict.unparsable);
      expect(check('√n = 7', 49), Verdict.unparsable);
      expect(check('√50 = n', 7.07), Verdict.wrongRoot);
    });
  });

  group('squares and roots: mutations fail the oracle', () {
    const kind = OperationType.algebra;
    final source = kind.source as AlgebraSource;
    const families = {
      'missingSquare',
      'missingSquareRoot',
      'aSquared',
      'squareRootOfC',
      'nSquared',
      'anSquared',
    };
    late final problems = [
      for (var level = 1; level <= kind.highestLevel; level++)
        for (final p in source.problems(kind, level))
          if (families.contains(p.variant)) p,
    ];

    test('every family is asked at some level', () {
      expect({for (final p in problems) p.variant}, families);
      expect(problems, hasLength(20 + 14 + 16 + 100));
    });

    test('the exponent, the root sign or the condition line removed', () {
      for (final p in problems) {
        final question = p.question;
        // 1² and √1 are 1 itself: nothing to tell apart.
        if (p.params.last == 1) continue;
        if (question.contains('²')) {
          final mutant = question.replaceAll('²', '');
          expect(check(mutant, p.result), Verdict.wrongRoot, reason: mutant);
        }
        if (question.contains('√')) {
          final mutant = question.replaceAll('√', '');
          expect(check(mutant, p.result), Verdict.wrongRoot, reason: mutant);
        }
        if (question.endsWith(_positive)) {
          final mutant = question.replaceFirst(_positive, '');
          expect(check(mutant, p.result), Verdict.twoSolutions, reason: mutant);
        }
      }
    });

    test('a radicand + 1 is not a perfect square', () {
      for (final p in problems) {
        if (!p.question.contains('√')) continue;
        final mutant = p.question.replaceFirstMapped(
          RegExp(r'√(\d+)'),
          (m) => '√${int.parse(m[1]!) + 1}',
        );
        expect(check(mutant, p.result), Verdict.wrongRoot, reason: mutant);
      }
    });
  });
}

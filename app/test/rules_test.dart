import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

void main() {
  int reveal(int revealed, {bool checked = false, int stepCount = 3}) =>
      nextRevealed(
        revealed: revealed,
        event: HintEvent.reveal,
        stepCount: stepCount,
        checked: checked,
      );

  int wrongCheck(int revealed) => nextRevealed(
    revealed: revealed,
    event: HintEvent.wrongFirstCheck,
    stepCount: 3,
    checked: true,
  );

  test('Hint reveals 1 step and each Next step adds 1', () {
    expect(reveal(0), 1);
    expect(reveal(1), 2);
  });

  test('the last step needs a valid check first', () {
    expect(reveal(2), 2);
    expect(reveal(2, checked: true), 3);
    expect(reveal(3, checked: true), 3);
    expect(reveal(1, stepCount: 2), 1);
  });

  test('a wrong first check reveals at least 1 step and hides none', () {
    expect(wrongCheck(0), 1);
    expect(wrongCheck(1), 1);
    expect(wrongCheck(2), 2);
  });

  group('difficulty', () {
    const problem = Problem(2, 3, OperationType.plus, 5);
    Attempt answer({required bool right, int hints = 0, bool skip = false}) =>
        Attempt(
          problem,
          firstAnswer: skip ? null : (right ? 5 : 4),
          hintsUsed: hints,
          elapsedMs: 0,
          answeredAt: DateTime(2026, 11, 14),
        );
    final right = answer(right: true);
    final wrong = answer(right: false);

    List<int> state(Difficulty d) => [
      d.level,
      d.upCount,
      d.downCount,
      d.answered,
      d.correct,
    ];

    Difficulty apply(Difficulty d, Attempt attempt, int times) {
      for (var i = 0; i < times; i++) {
        d = difficultyAfter(d, attempt);
      }
      return d;
    }

    test('criterion 18: 3 hint-free correct answers raise the level by 1', () {
      final start = const Difficulty(level: 2, downCount: 1);
      expect(state(difficultyAfter(start, right)), [2, 1, 0, 1, 1]);
      expect(state(apply(start, right, 2)), [2, 2, 0, 2, 2]);
      expect(state(apply(start, right, 3)), [3, 0, 0, 3, 3]);
    });

    test('criterion 18: a hinted correct answer changes neither counter', () {
      const start = Difficulty(level: 2, upCount: 2, downCount: 1);
      final after = difficultyAfter(start, answer(right: true, hints: 1));
      expect(state(after), [2, 2, 1, 1, 1]);
    });

    test('criterion 18: 2 first-check wrong answers lower the level by 1', () {
      const start = Difficulty(level: 3, upCount: 2);
      expect(state(difficultyAfter(start, wrong)), [3, 0, 1, 1, 0]);
      expect(state(apply(start, wrong, 2)), [2, 0, 0, 2, 0]);
    });

    test('a wrong answer after a hint counts as wrong', () {
      const start = Difficulty(level: 3, downCount: 1);
      expect(state(difficultyAfter(start, answer(right: false, hints: 2))), [
        2,
        0,
        0,
        1,
        0,
      ]);
    });

    test('criterion 18: a skip changes neither counter nor the totals', () {
      const start = Difficulty(level: 3, upCount: 1, downCount: 1);
      final skip = answer(right: false, hints: 1, skip: true);
      expect(state(difficultyAfter(start, skip)), state(start));
    });

    test(
      'criterion 18: at level 5, 3 more correct leave level 5, upCount 0',
      () {
        final after = apply(const Difficulty(level: 5), right, 3);
        expect(state(after), [5, 0, 0, 3, 3]);
      },
    );

    test('criterion 18: at level 1, 2 wrong leave level 1, downCount 0', () {
      final after = apply(const Difficulty(level: 1), wrong, 2);
      expect(state(after), [1, 0, 0, 2, 0]);
    });

    test('criterion 18: choosing a tier sets every level, zeroes counters', () {
      var progress = Progress(
        difficulty: {
          OperationType.plus: const Difficulty(
            level: 4,
            upCount: 2,
            answered: 9,
            correct: 8,
          ),
          OperationType.divide: const Difficulty(level: 2, downCount: 1),
        },
      );
      for (final tier in Tier.values) {
        progress = progress.withTier(tier);
        expect(progress.tier, tier);
        for (final type in OperationType.values) {
          final d = progress.difficulty[type]!;
          expect([d.level, d.upCount, d.downCount], [tier.level, 0, 0]);
        }
        // The lifetime totals stay.
        expect(state(progress.difficulty[OperationType.plus]!).sublist(3), [
          9,
          8,
        ]);
      }
      expect(Tier.values.map((tier) => tier.level), [1, 3, 5]);
    });

    test('criterion 19: always right goes from 1 to 5 in exactly 12', () {
      var d = const Difficulty(level: 1);
      var answers = 0;
      while (d.level < 5) {
        d = difficultyAfter(d, right);
        answers++;
      }
      expect(answers, 12);
    });

    test('criterion 19: always wrong goes from 5 to 1 in exactly 8', () {
      var d = const Difficulty(level: 5);
      var answers = 0;
      while (d.level > 1) {
        d = difficultyAfter(d, wrong);
        answers++;
      }
      expect(answers, 8);
    });

    test('criterion 19: a 60-percent player stays off both limits', () {
      final random = Random(60);
      var d = const Difficulty(level: 1);
      final atLevel = <int, int>{};
      for (var i = 0; i < 500; i++) {
        atLevel.update(d.level, (n) => n + 1, ifAbsent: () => 1);
        d = difficultyAfter(d, random.nextDouble() < .6 ? right : wrong);
      }
      expect(atLevel[1] ?? 0, lessThan(500 * .8));
      expect(atLevel[5] ?? 0, lessThan(500 * .8));
    });
  });
}

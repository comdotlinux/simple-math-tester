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

  group('game loop', () {
    Attempt answer({
      bool right = true,
      bool skip = false,
      int hints = 0,
      int level = 1,
    }) => Attempt(
      Problem(2, 3, OperationType.plus, 5, level: level),
      firstAnswer: skip ? null : (right ? 5 : 4),
      hintsUsed: hints,
      elapsedMs: 0,
      answeredAt: DateTime(2026, 11, 14),
    );

    GameState play(GameState state, DateTime now, int correctAnswers) {
      for (var i = 0; i < correctAnswers; i++) {
        state = gameAfter(state, answer(), now);
      }
      return state;
    }

    List<Object?> fields(GameState s) => [
      s.xp,
      s.combo,
      s.dailyCount,
      s.lastActiveDate,
      s.lastGoalDate,
      s.streak,
      s.bestStreak,
    ];

    test('criterion 20: XP table', () {
      for (final (level, combo, hinted, xp) in [
        (1, 0, false, 10),
        (1, 0, true, 5),
        (1, 5, false, 15),
        (1, 5, true, 8),
        (1, 10, false, 20),
        (1, 15, false, 20),
        (5, 0, false, 50),
        (5, 5, true, 38),
        (5, 10, false, 100),
      ]) {
        expect(
          xpFor(level: level, comboBefore: combo, hinted: hinted),
          xp,
          reason: '($level, $combo, $hinted)',
        );
      }
    });

    test('criterion 20: the XP function uses integer arithmetic only', () {
      for (var level = 1; level <= 5; level++) {
        for (var combo = 0; combo <= 20; combo++) {
          for (final hinted in [false, true]) {
            final int xp = xpFor(
              level: level,
              comboBefore: combo,
              hinted: hinted,
            );
            final base = level * (10 + (combo < 10 ? combo : 10));
            // A half rounds up: (base + 1) ~/ 2, never a fraction.
            expect(xp, hinted ? (base + 1) ~/ 2 : base);
            expect(xp, isA<int>());
          }
        }
      }
    });

    test('criterion 20: wrong, skip give 0 XP; the combo rules', () {
      final now = DateTime(2026, 11, 14, 9);
      const start = GameState(combo: 4, xp: 70);
      final hinted = gameAfter(start, answer(hints: 1, level: 2), now);
      expect(hinted.combo, 5);
      expect(hinted.xp, 70 + (2 * 14 + 1) ~/ 2);

      final wrong = gameAfter(start, answer(right: false), now);
      expect([wrong.xp, wrong.combo, wrong.dailyCount], [70, 0, 0]);
      final skip = gameAfter(start, answer(skip: true), now);
      expect([skip.xp, skip.combo, skip.dailyCount], [70, 0, 0]);

      final right = gameAfter(start, answer(level: 3), now);
      expect([right.xp, right.combo, right.dailyCount], [70 + 42, 5, 1]);
    });

    test('player level L is reached at 100 × L × (L − 1) / 2 XP', () {
      expect(
        [for (var l = 1; l <= 5; l++) xpForLevel(l)],
        [0, 100, 300, 600, 1000],
      );
      for (final (xp, level) in [
        (0, 1),
        (99, 1),
        (100, 2),
        (250, 2),
        (299, 2),
        (300, 3),
        (1000, 5),
        (-5, 1),
      ]) {
        expect(playerLevel(xp), level, reason: '$xp XP');
      }
    });

    test('the player level matches its threshold for every XP up to 1e6', () {
      var level = 1;
      for (var xp = 0; xp <= 1000000; xp++) {
        if (xpForLevel(level + 1) <= xp) level++;
        expect(playerLevel(xp), level, reason: '$xp XP');
      }
    });

    test('the player level of huge XP is quick, exact and monotonic', () {
      const maxInt = 0x7FFFFFFFFFFFFFFF;
      final watch = Stopwatch()..start();
      final top = playerLevel(maxInt);
      final billion = playerLevel(maxStoredXp);
      expect(watch.elapsedMilliseconds, lessThan(50));

      expect(billion, 4472);
      expect(xpForLevel(billion), lessThanOrEqualTo(maxStoredXp));
      expect(xpForLevel(billion + 1), greaterThan(maxStoredXp));

      final steps = maxInt ~/ 100;
      expect(top * (top - 1) ~/ 2, lessThanOrEqualTo(steps));
      expect((top + 1) * top ~/ 2, greaterThan(steps));
      var previous = 0;
      for (final xp in [
        0,
        99,
        100,
        299,
        300,
        maxStoredXp,
        maxInt ~/ 2,
        maxInt - 100,
        maxInt,
      ]) {
        final level = playerLevel(xp);
        expect(level, greaterThanOrEqualTo(previous), reason: '$xp XP');
        previous = level;
      }
    });

    test('dates: yyyy-MM-dd, the date before crosses months and years', () {
      expect(localDate(DateTime(2026, 3, 9, 23, 59)), '2026-03-09');
      expect(dateBefore('2026-03-01'), '2026-02-28');
      expect(dateBefore('2028-03-01'), '2028-02-29');
      expect(dateBefore('2027-01-01'), '2026-12-31');
      // Daylight saving changes in Europe and the US.
      expect(dateBefore('2026-03-30'), '2026-03-29');
      expect(dateBefore('2026-10-26'), '2026-10-25');
      expect(dateBefore('2026-11-02'), '2026-11-01');
    });

    test('day change resets the daily count once the date moves on', () {
      const state = GameState(dailyCount: 6, lastActiveDate: '2026-11-14');
      expect(fields(dayChanged(state, DateTime(2026, 11, 14, 23, 59))), [
        0,
        0,
        6,
        '2026-11-14',
        null,
        0,
        0,
      ]);
      final next = dayChanged(state, DateTime(2026, 11, 15, 0, 1));
      expect([next.dailyCount, next.lastActiveDate], [0, '2026-11-15']);
      final first = dayChanged(const GameState(), DateTime(2026, 11, 14, 9));
      expect([first.dailyCount, first.lastActiveDate], [0, '2026-11-14']);
    });

    test('criterion 21: streak with an injected clock', () {
      final day1 = DateTime(2026, 11, 14, 9);
      final day2 = DateTime(2026, 11, 15, 18);
      final day4 = DateTime(2026, 11, 17, 7);

      var state = play(const GameState(), day1, 9);
      expect(state.streak, 0);
      state = play(state, day1, 1);
      expect(
        [state.streak, state.bestStreak, state.lastGoalDate],
        [1, 1, '2026-11-14'],
      );

      state = play(state, day2, 10);
      expect([state.streak, state.bestStreak], [2, 2]);

      // A second goal on the same date changes nothing.
      final again = play(state, day2, 10);
      expect(
        [again.streak, again.bestStreak, again.lastGoalDate],
        [2, 2, '2026-11-15'],
      );

      // 2026-11-16 is missed.
      state = play(state, day4, 10);
      expect([state.streak, state.bestStreak], [1, 2]);

      // Displayed streak: two dates after lastGoalDate it shows 0.
      expect(displayedStreak(state, DateTime(2026, 11, 17, 23)), 1);
      expect(displayedStreak(state, DateTime(2026, 11, 18, 23)), 1);
      expect(displayedStreak(state, DateTime(2026, 11, 19, 0, 1)), 0);
      expect(state.bestStreak, 2);
    });

    test('criterion 22: a clock set back 3 days changes no date', () {
      final today = DateTime(2026, 11, 14, 10);
      final setBack = today.subtract(const Duration(days: 3));
      const nearGoal = GameState(
        xp: 500,
        streak: 40,
        bestStreak: 40,
        dailyCount: 9,
        lastActiveDate: '2026-11-14',
        lastGoalDate: '2026-11-13',
      );
      final backwards = gameAfter(nearGoal, answer(), setBack);
      final normal = gameAfter(nearGoal, answer(), today);
      expect(fields(backwards), fields(normal));
      expect(backwards.streak, 41);
      expect(backwards.lastGoalDate, '2026-11-14');
      expect(backwards.lastActiveDate, '2026-11-14');
      expect(backwards.xp, 510);

      const goalDone = GameState(
        streak: 40,
        bestStreak: 40,
        dailyCount: 3,
        lastActiveDate: '2026-11-14',
        lastGoalDate: '2026-11-14',
      );
      final after = gameAfter(goalDone, answer(), setBack);
      expect(
        [after.streak, after.dailyCount, after.lastGoalDate],
        [40, 4, '2026-11-14'],
      );
      expect(displayedStreak(after, setBack), 40);
    });

    test('criterion 22: a date 300 days ahead of the clock is corrected', () {
      final now = DateTime(2026, 11, 14, 10);
      const ahead = GameState(
        streak: 40,
        bestStreak: 40,
        dailyCount: 7,
        lastActiveDate: '2027-09-10',
        lastGoalDate: '2027-09-10',
      );
      var state = gameAfter(ahead, answer(skip: true), now);
      expect([state.lastActiveDate, state.dailyCount], ['2026-11-14', 0]);
      expect(state.lastGoalDate, '2026-11-13');
      expect(displayedStreak(state, now), 40);

      state = play(state, now, 10);
      expect([state.streak, state.lastGoalDate], [41, '2026-11-14']);
    });

    test('a date 7 days or less ahead of the clock is not corrected', () {
      final now = DateTime(2026, 11, 14, 10);
      const ahead = GameState(
        streak: 5,
        dailyCount: 7,
        lastActiveDate: '2026-11-21',
        lastGoalDate: '2026-11-20',
      );
      final state = dayChanged(ahead, now);
      expect(fields(state), fields(ahead));
      final corrected = dayChanged(ahead, DateTime(2026, 11, 13, 23));
      expect(
        [corrected.lastActiveDate, corrected.dailyCount],
        ['2026-11-13', 0],
      );
      expect(corrected.lastGoalDate, '2026-11-12');
    });

    test('the goal ring shows the count only on its own date', () {
      const state = GameState(dailyCount: 6, lastActiveDate: '2026-11-14');
      expect(goalRingValue(state, DateTime(2026, 11, 14, 23, 59)), 6);
      expect(goalRingValue(state, DateTime(2026, 11, 15, 0, 1)), 0);
    });
  });
}

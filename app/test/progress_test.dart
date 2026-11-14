import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

Attempt attempt(int index, {num? answer = 5, bool sprint = false}) => Attempt(
  Problem(index, 3, OperationType.divide, index / 3, level: 2),
  firstAnswer: answer,
  elapsedMs: 1200 + index,
  hintsUsed: 2,
  answeredAt: DateTime(2026, 11, 14, 9, 30, 15, 250),
  sprint: sprint,
);

void main() {
  test('criterion 9: encode then decode keeps every field', () {
    final original = Progress(
      selectedOperations: {OperationType.minus, OperationType.divide},
      history: [
        attempt(12),
        attempt(9, answer: null, sprint: true),
        attempt(6, answer: 2.5),
      ],
      tier: Tier.medium,
      difficulty: {
        OperationType.plus: const Difficulty(
          level: 4,
          upCount: 2,
          answered: 30,
          correct: 21,
        ),
        OperationType.divide: const Difficulty(
          level: 2,
          downCount: 1,
          answered: 7,
          correct: 3,
        ),
      },
      game: const GameState(
        xp: 250,
        combo: 4,
        dailyCount: 6,
        lastActiveDate: '2026-11-14',
        lastGoalDate: '2026-11-13',
        streak: 3,
        bestStreak: 7,
      ),
    );

    final decoded = Progress.decode(original.encode());

    expect(decoded.selectedOperations, original.selectedOperations);
    expect(decoded.extra, isEmpty);
    expect(decoded.tier, Tier.medium);
    for (final type in OperationType.values) {
      final (a, b) = (decoded.difficulty[type]!, original.difficulty[type]!);
      expect(
        [a.level, a.upCount, a.downCount, a.answered, a.correct],
        [b.level, b.upCount, b.downCount, b.answered, b.correct],
      );
    }
    expect(decoded.difficulty[OperationType.plus]!.upCount, 2);
    final game = decoded.game;
    expect(
      [
        game.xp,
        game.combo,
        game.dailyCount,
        game.lastActiveDate,
        game.lastGoalDate,
        game.streak,
        game.bestStreak,
      ],
      [250, 4, 6, '2026-11-14', '2026-11-13', 3, 7],
    );
    expect(decoded.history, hasLength(original.history.length));
    for (var i = 0; i < original.history.length; i++) {
      final (a, b) = (decoded.history[i], original.history[i]);
      expect(a.problem.lhs, b.problem.lhs);
      expect(a.problem.rhs, b.problem.rhs);
      expect(a.problem.kind, b.problem.kind);
      expect(a.problem.result, b.problem.result);
      expect(a.problem.level, b.problem.level);
      expect(a.firstAnswer, b.firstAnswer);
      expect(a.elapsedMs, b.elapsedMs);
      expect(a.hintsUsed, b.hintsUsed);
      expect(a.answeredAt, b.answeredAt);
      expect(a.sprint, b.sprint);
    }
    expect(decoded.encode(), original.encode());
  });

  test(
    'criterion 9: kinds by name, dates as ISO strings, numbers as numbers',
    () {
      final json = jsonDecode(
        Progress(history: [attempt(12)]).encode(),
      ) as Map<String, Object?>;
      expect(json['schemaVersion'], 1);
      final entry = (json['history']! as List).single as Map;
      expect(entry['kind'], 'divide');
      expect(entry['lhs'], 12);
      expect(entry['firstAnswer'], 5);
      expect(DateTime.parse(entry['answeredAt'] as String).isUtc, isTrue);
    },
  );

  test(
    'criterion 10: unknown fields, names and kinds survive a round trip',
    () {
      final unknownEntry = {
        'kind': 'power',
        'lhs': 2,
        'rhs': 8,
        'shape': {'x': 1},
      };
      final perOperation = {
        'plus': {'level': 2},
        'power': {'level': 4},
      };
      final source = jsonEncode({
        'schemaVersion': 1,
        'theme': 'dark',
        'operations': perOperation,
        'selectedOperations': ['plus', 'power'],
        'history': [
          Progress(history: [attempt(12)]).toJsonHistory().single,
          unknownEntry,
        ],
      });

      final decoded = Progress.decode(source);
      expect(decoded.selectedOperations, {OperationType.plus});
      expect(decoded.history, hasLength(1));
      expect(decoded.history.single.problem.kind, OperationType.divide);

      final again = jsonDecode(decoded.encode()) as Map<String, Object?>;
      expect(again['theme'], 'dark');
      expect((again['operations']! as Map)['power'], {'level': 4});
      expect(decoded.difficulty[OperationType.plus]!.level, 2);
      expect(again['selectedOperations'], ['plus', 'power']);
      expect((again['history']! as List).last, unknownEntry);
    },
  );

  test('criterion 10: missing fields decode with their defaults', () {
    final decoded = Progress.decode('{}');
    expect(decoded.selectedOperations, OperationType.values.toSet());
    expect(decoded.history, isEmpty);
    expect(decoded.tier, isNull);
    expect(decoded.difficulty.keys, OperationType.values);
    for (final value in decoded.difficulty.values) {
      expect(
        [
          value.level,
          value.upCount,
          value.downCount,
          value.answered,
          value.correct,
        ],
        [1, 0, 0, 0, 0],
      );
    }
    expect(
      Progress.decode('{"operations":{"minus":{"upCount":2}}}')
          .difficulty[OperationType.minus]!
          .level,
      1,
    );
    expect(jsonDecode(Progress().encode()) as Map, isNot(contains('tier')));
    final game = decoded.game;
    expect(
      [
        game.xp,
        game.combo,
        game.dailyCount,
        game.lastActiveDate,
        game.lastGoalDate,
        game.streak,
        game.bestStreak,
      ],
      [0, 0, 0, null, null, 0, 0],
    );
    expect(Progress.decode('{"streak":3}').game.xp, 0);

    final partial = Progress.decode(
      '{"history":[{"kind":"plus","lhs":1,"rhs":2,"result":3,'
      '"answeredAt":"2026-11-14T08:00:00.000Z"}]}',
    ).history.single;
    expect(partial.firstAnswer, isNull);
    expect(partial.elapsedMs, 0);
    expect(partial.hintsUsed, 0);
    expect(partial.problem.level, 1);
    expect(partial.sprint, isFalse);
  });

  test('a selection of only unknown kinds offers every known kind', () {
    final decoded = Progress.decode('{"selectedOperations":["power"]}');
    expect(decoded.selectedOperations, OperationType.values.toSet());
    expect(
      (jsonDecode(decoded.encode()) as Map)['selectedOperations'],
      contains('power'),
    );
  });

  for (final source in [
    'not json',
    '[1, 2]',
    '{"history": "abc"}',
    '{"selectedOperations": [1]}',
    '{"schemaVersion": "abc"}',
    '{"tier": 3}',
    '{"operations": []}',
    '{"operations": {"plus": 2}}',
    '{"operations": {"plus": {"level": "2"}}}',
    '{"operations": {"minus": {"answered": 1.5}}}',
    '{"xp": "abc"}',
    '{"combo": 1.5}',
    '{"streak": true}',
    '{"lastActiveDate": 20261114}',
    '{"lastGoalDate": "14.11.2026"}',
    '{"lastActiveDate": "2026-02-30"}',
    '{"bestStreak": "9"}',
    '{"history": [{"kind": "plus", "lhs": "1", "rhs": 2, "result": 3, '
        '"answeredAt": "2026-11-14T08:00:00.000Z"}]}',
  ]) {
    test('$source is a decode failure', () {
      expect(() => Progress.decode(source), throwsFormatException);
    });
  }

  test(
    'an unknown tier name asks again; a level outside 1 to 5 is clamped',
    () {
      final decoded = Progress.decode(
        '{"tier":"expert","operations":{"plus":{"level":9},'
        '"minus":{"level":0}}}',
      );
      expect(decoded.tier, isNull);
      expect(decoded.difficulty[OperationType.plus]!.level, 5);
      expect(decoded.difficulty[OperationType.minus]!.level, 1);
    },
  );

  List<int> state(Difficulty d) => [
    d.level,
    d.upCount,
    d.downCount,
    d.answered,
    d.correct,
  ];

  test('counters and totals the rule cannot produce are clamped', () {
    final decoded = Progress.decode(
      '{"operations":{'
      '"plus":{"level":2,"upCount":7,"downCount":5,"answered":4,"correct":9},'
      '"minus":{"upCount":-1,"downCount":-3,"answered":-2,"correct":-1},'
      '"multiply":{"upCount":2,"downCount":1,"answered":6,"correct":6}}}',
    ).difficulty;
    expect(state(decoded[OperationType.plus]!), [2, 2, 1, 4, 4]);
    expect(state(decoded[OperationType.minus]!), [1, 0, 0, 0, 0]);
    // Values the rule can reach are kept.
    expect(state(decoded[OperationType.multiply]!), [1, 2, 1, 6, 6]);
  });

  test('a tier without levels starts every operation at its level', () {
    for (final tier in Tier.values) {
      final progress = Progress(tier: tier);
      for (final type in OperationType.values) {
        expect(state(progress.difficulty[type]!), [tier.level, 0, 0, 0, 0]);
      }
      expect(
        state(
          Progress.decode(progress.encode()).difficulty[OperationType.plus]!,
        ),
        [tier.level, 0, 0, 0, 0],
      );
    }
    final given = Progress(
      tier: Tier.hard,
      difficulty: {OperationType.plus: const Difficulty(level: 2)},
    ).difficulty;
    expect(given[OperationType.plus]!.level, 2);
    expect(given[OperationType.minus]!.level, 5);
    expect(Progress().difficulty[OperationType.divide]!.level, 1);
  });

  test('a newer schemaVersion is not a decode failure', () {
    expect(
      () => Progress.decode('{"schemaVersion": 99, "history": "abc"}'),
      throwsA(isA<NewerProgressException>()),
    );
  });

  test(
    'criterion 13: history keeps the last 200 attempts in memory and JSON',
    () {
      var progress = Progress.decode(
        '{"history":[{"kind":"power","lhs":2,"rhs":8}]}',
      );
      for (var i = 0; i < 205; i++) {
        progress = progress.withAttempt(attempt(i + 1));
      }
      expect(progress.history, hasLength(Progress.historyCap));
      expect(progress.history.first.problem.lhs, 6);

      final stored = Progress.decode(progress.encode());
      expect(stored.history, hasLength(Progress.historyCap));
      final entries = stored.toJsonHistory();
      // The unknown entry is kept and does not count toward the cap.
      expect(entries, hasLength(Progress.historyCap + 1));
      expect((entries.first as Map)['kind'], 'power');
    },
  );

  test('decoding more than 200 attempts keeps the last 200', () {
    final long = Progress(history: [for (var i = 1; i <= 250; i++) attempt(i)]);
    expect(long.history, hasLength(200));
    expect(Progress.decode(long.encode()).history.first.problem.lhs, 51);
  });

  test('negative and absurd game values decode to their clamps', () {
    List<int> values(String source) {
      final game = Progress.decode(source).game;
      return [
        game.xp,
        game.combo,
        game.dailyCount,
        game.streak,
        game.bestStreak,
      ];
    }

    expect(
      values(
        '{"xp":-5,"combo":-1,"dailyCount":-3,"streak":-2,"bestStreak":-9}',
      ),
      [0, 0, 0, 0, 0],
    );
    expect(
      values(
        '{"xp":9000000000000000000,"combo":5000000,"dailyCount":99999999,'
        '"streak":123456789,"bestStreak":4}',
      ),
      [
        maxStoredXp,
        maxStoredRun,
        maxStoredDailyCount,
        maxStoredRun,
        maxStoredRun,
      ],
    );
    // bestStreak is never below streak.
    expect(values('{"streak":12,"bestStreak":3}').sublist(3), [12, 12]);
    expect(values('{"streak":12,"bestStreak":30}').sublist(3), [12, 30]);
  });

  test('history and selection are unmodifiable', () {
    final progress = Progress(history: [attempt(1)]);
    expect(() => progress.history.add(attempt(2)), throwsUnsupportedError);
    expect(() => progress.selectedOperations.clear(), throwsUnsupportedError);
  });
}

extension on Progress {
  List<Object?> toJsonHistory() =>
      (jsonDecode(encode()) as Map<String, Object?>)['history']! as List;
}

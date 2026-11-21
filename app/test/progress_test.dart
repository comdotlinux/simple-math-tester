import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:simple_math_tester/app_theme.dart' show AppPalette;
import 'package:simple_math_tester/hundredths.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

Attempt attempt(int index, {num? answer = 5, bool sprint = false}) => Attempt(
  ArithmeticProblem(index, 3, OperationType.divide, index / 3, level: 2),
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
        bestSprint: 132,
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
        game.bestSprint,
      ],
      [250, 4, 6, '2026-11-14', '2026-11-13', 3, 7, 132],
    );
    expect(decoded.history, hasLength(original.history.length));
    for (var i = 0; i < original.history.length; i++) {
      final (a, b) = (decoded.history[i], original.history[i]);
      expect(
        (a.problem as ArithmeticProblem).lhs,
        (b.problem as ArithmeticProblem).lhs,
      );
      expect(
        (a.problem as ArithmeticProblem).rhs,
        (b.problem as ArithmeticProblem).rhs,
      );
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

  test('a document saved by the release before the sealed Problem decodes to '
      'the same progress and encodes to the same bytes', () {
    // Written by Progress.encode on main at 4bc825a, with every operation in
    // the history, a skipped answer, sprint answers and decimal results.
    const saved =
        '{"schemaVersion":2,"selectedOperations":["plus","minus","divide"],"history":['
        '{"lhs":7,"rhs":5,"kind":"plus","result":12,"level":1,"firstAnswer":12,"elapsedMs":2300,"hintsUsed":0,"answeredAt":"2026-11-19T16:05:20.300Z","sprint":false},'
        '{"lhs":48,"rhs":27,"kind":"minus","result":21,"level":3,"firstAnswer":20,"elapsedMs":6100,"hintsUsed":2,"answeredAt":"2026-11-19T16:05:40.100Z","sprint":false},'
        '{"lhs":6,"rhs":7,"kind":"multiply","result":42,"level":2,"firstAnswer":null,"elapsedMs":9050,"hintsUsed":0,"answeredAt":"2026-11-19T16:05:50.050Z","sprint":false},'
        '{"lhs":84,"rhs":7,"kind":"divide","result":12.0,"level":3,"firstAnswer":12,"elapsedMs":4420,"hintsUsed":0,"answeredAt":"2026-11-19T16:05:40.420Z","sprint":true},'
        '{"lhs":2047,"rhs":23,"kind":"divide","result":89.0,"level":5,"firstAnswer":89.5,"elapsedMs":15999,"hintsUsed":1,"answeredAt":"2026-11-19T16:05:39.999Z","sprint":false},'
        '{"lhs":9876,"rhs":8765,"kind":"plus","result":18641,"level":5,"firstAnswer":18641,"elapsedMs":31007,"hintsUsed":0,"answeredAt":"2026-11-19T16:05:47.007Z","sprint":true}'
        '],"operations":{"plus":{"level":5,"upCount":1,"downCount":0,"answered":40,"correct":33},"minus":{"level":3,"upCount":0,"downCount":1,"answered":12,"correct":8},"multiply":{"level":2,"upCount":0,"downCount":0,"answered":5,"correct":2},"divide":{"level":4,"upCount":2,"downCount":0,"answered":21,"correct":17}},"tier":"hard","xp":1234,"combo":2,"dailyCount":9,"lastActiveDate":"2026-11-19","lastGoalDate":"2026-11-19","streak":4,"bestStreak":11,"bestSprint":87,"sound":false,"haptics":true,"themeMode":"dark","layoutMode":"compact","language":"de","palette":"ocean","updateReminderDate":"2026-11-18"}';
    Attempt entry(
      ArithmeticProblem problem,
      num? answer,
      int ms, {
      int hints = 0,
      bool sprint = false,
    }) => Attempt(
      problem,
      firstAnswer: answer,
      elapsedMs: ms,
      hintsUsed: hints,
      answeredAt: DateTime.utc(
        2026,
        11,
        19,
        16,
        5,
        ms % 60,
        ms % 1000,
      ).toLocal(),
      sprint: sprint,
    );
    final expected = Progress(
      selectedOperations: {
        OperationType.plus,
        OperationType.minus,
        OperationType.divide,
      },
      history: [
        entry(const ArithmeticProblem(7, 5, OperationType.plus, 12), 12, 2300),
        entry(
          const ArithmeticProblem(48, 27, OperationType.minus, 21, level: 3),
          20,
          6100,
          hints: 2,
        ),
        entry(
          const ArithmeticProblem(6, 7, OperationType.multiply, 42, level: 2),
          null,
          9050,
        ),
        entry(
          const ArithmeticProblem(84, 7, OperationType.divide, 12.0, level: 3),
          12,
          4420,
          sprint: true,
        ),
        entry(
          const ArithmeticProblem(
            2047,
            23,
            OperationType.divide,
            89.0,
            level: 5,
          ),
          89.5,
          15999,
          hints: 1,
        ),
        entry(
          const ArithmeticProblem(
            9876,
            8765,
            OperationType.plus,
            18641,
            level: 5,
          ),
          18641,
          31007,
          sprint: true,
        ),
      ],
      tier: Tier.hard,
      difficulty: {
        OperationType.plus: const Difficulty(
          level: 5,
          upCount: 1,
          answered: 40,
          correct: 33,
        ),
        OperationType.minus: const Difficulty(
          level: 3,
          downCount: 1,
          answered: 12,
          correct: 8,
        ),
        OperationType.multiply: const Difficulty(
          level: 2,
          answered: 5,
          correct: 2,
        ),
        OperationType.divide: const Difficulty(
          level: 4,
          upCount: 2,
          answered: 21,
          correct: 17,
        ),
      },
      game: const GameState(
        xp: 1234,
        combo: 2,
        dailyCount: 9,
        lastActiveDate: '2026-11-19',
        lastGoalDate: '2026-11-19',
        streak: 4,
        bestStreak: 11,
        bestSprint: 87,
      ),
      sound: false,
      themeMode: ThemeMode.dark,
      layoutMode: LayoutMode.compact,
      language: 'de',
      palette: AppPalette.ocean,
      updateReminderDate: '2026-11-18',
    );

    final decoded = Progress.decode(saved);

    expect(decoded.selectedOperations, expected.selectedOperations);
    expect(decoded.tier, expected.tier);
    expect(decoded.extra, isEmpty);
    for (final type in OperationType.values) {
      final (a, b) = (decoded.difficulty[type]!, expected.difficulty[type]!);
      expect(
        [a.level, a.upCount, a.downCount, a.answered, a.correct],
        [b.level, b.upCount, b.downCount, b.answered, b.correct],
      );
    }
    List<Object?> gameFields(GameState g) => [
      g.xp,
      g.combo,
      g.dailyCount,
      g.lastActiveDate,
      g.lastGoalDate,
      g.streak,
      g.bestStreak,
      g.bestSprint,
    ];
    expect(gameFields(decoded.game), gameFields(expected.game));
    expect(
      [
        decoded.sound,
        decoded.haptics,
        decoded.themeMode,
        decoded.layoutMode,
        decoded.language,
        decoded.palette,
        decoded.updateReminderDate,
      ],
      [
        expected.sound,
        expected.haptics,
        expected.themeMode,
        expected.layoutMode,
        expected.language,
        expected.palette,
        expected.updateReminderDate,
      ],
    );
    List<Object?> attemptFields(Attempt a) => [
      ...switch (a.problem) {
        ArithmeticProblem(:final lhs, :final rhs) => [lhs, rhs],
        EquationProblem(:final variant, :final params) ||
        FigureProblem(:final variant, :final params) => [variant, params],
      },
      a.problem.kind,
      a.problem.result,
      a.problem.level,
      a.firstAnswer,
      a.elapsedMs,
      a.hintsUsed,
      a.answeredAt,
      a.sprint,
    ];
    expect(
      decoded.history.map(attemptFields).toList(),
      expected.history.map(attemptFields).toList(),
    );
    expect(decoded.history.map((a) => a.problem.kind).toSet(), arithmeticKinds);
    expect(decoded.encode(), saved);
    expect(expected.encode(), saved);
  });

  test(
    'criterion 9: kinds by name, dates as ISO strings, numbers as numbers',
    () {
      final json = jsonDecode(
        Progress(history: [attempt(12)]).encode(),
      ) as Map<String, Object?>;
      expect(json['schemaVersion'], 2);
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
    expect(decoded.selectedOperations, arithmeticKinds);
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
        game.bestSprint,
      ],
      [0, 0, 0, null, null, 0, 0, 0],
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

  test('the sound and haptics switches default on and round trip off', () {
    final defaults = Progress.decode('{}');
    expect([defaults.sound, defaults.haptics], [true, true]);
    final json = jsonDecode(Progress().encode()) as Map<String, Object?>;
    expect([json['sound'], json['haptics']], [true, true]);

    final off = Progress.decode(
      Progress().withSwitches(sound: false, haptics: false).encode(),
    );
    expect([off.sound, off.haptics], [false, false]);
    expect(off.extra, isEmpty);
    final onlySound = Progress().withSwitches(sound: false);
    expect([onlySound.sound, onlySound.haptics], [false, true]);
    expect(
      () => Progress.decode('{"haptics":"yes"}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('the theme mode round trips and defaults to system', () {
    for (final mode in ThemeMode.values) {
      final json = jsonDecode(
        Progress().withThemeMode(mode).encode(),
      ) as Map<String, Object?>;
      expect(json['themeMode'], mode.name);
      final decoded = Progress.decode(jsonEncode(json));
      expect(decoded.themeMode, mode);
      expect(decoded.extra, isEmpty);
    }
    expect(Progress().themeMode, ThemeMode.system);
    expect(Progress.decode('{}').themeMode, ThemeMode.system);
    expect(
      Progress.decode('{"themeMode":"sepia"}').themeMode,
      ThemeMode.system,
    );
    expect(
      () => Progress.decode('{"themeMode":2}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('the update reminder date round trips and is absent by default', () {
    final json = jsonDecode(
      Progress().withUpdateReminderDate('2026-11-15').encode(),
    ) as Map<String, Object?>;
    expect(json['updateReminderDate'], '2026-11-15');
    final decoded = Progress.decode(jsonEncode(json));
    expect(decoded.updateReminderDate, '2026-11-15');
    expect(decoded.extra, isEmpty);
    expect(Progress().updateReminderDate, isNull);
    expect(Progress.decode('{}').updateReminderDate, isNull);
    expect(
      jsonDecode(Progress().encode()) as Map,
      isNot(contains('updateReminderDate')),
    );
  });

  test('a selection of only unknown kinds offers the arithmetic kinds', () {
    final decoded = Progress.decode('{"selectedOperations":["power"]}');
    expect(decoded.selectedOperations, arithmeticKinds);
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
    '{"updateReminderDate": "15.11.2026"}',
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

  test('a tier without levels starts every arithmetic kind at its level', () {
    for (final tier in Tier.values) {
      final progress = Progress(tier: tier);
      for (final type in arithmeticKinds) {
        expect(state(progress.difficulty[type]!), [tier.level, 0, 0, 0, 0]);
      }
      expect(state(progress.difficulty[OperationType.algebra]!), [
        1,
        0,
        0,
        0,
        0,
      ]);
      expect(
        state(
          Progress.decode(progress.encode()).difficulty[OperationType.plus]!,
        ),
        [tier.level, 0, 0, 0, 0],
      );
    }
    final given = Progress(
      tier: Tier.harder,
      difficulty: {OperationType.plus: const Difficulty(level: 2)},
    ).difficulty;
    expect(given[OperationType.plus]!.level, 2);
    expect(given[OperationType.minus]!.level, 5);
    expect(Progress().difficulty[OperationType.divide]!.level, 1);
  });

  test('a schema 1 hard tier loads as harder with its levels kept', () {
    final old = Progress.decode(
      '{"schemaVersion":1,"tier":"hard","operations":{"plus":{"level":2}}}',
    );
    expect(old.tier, Tier.harder);
    expect(old.difficulty[OperationType.plus]!.level, 2);
    expect(old.difficulty[OperationType.minus]!.level, 5);
    expect(
      Progress.decode('{"schemaVersion":1,"tier":"medium"}').tier,
      Tier.medium,
    );
    // Schema 2 means what it says, and saving writes schema 2.
    expect(Progress.decode(Progress(tier: Tier.hard).encode()).tier, Tier.hard);
    expect(Progress.decode(old.encode()).tier, Tier.harder);
    // Every save the app wrote carries schemaVersion, so a document without
    // one counts as the current schema: "hard" there is the new Hard.
    expect(Progress.decode('{"tier":"hard"}').tier, Tier.hard);
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
      expect((progress.history.first.problem as ArithmeticProblem).lhs, 6);

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
    expect(
      (Progress.decode(long.encode()).history.first.problem
              as ArithmeticProblem)
          .lhs,
      51,
    );
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

  test('a negative or absurd bestSprint decodes to its clamp', () {
    int best(String source) => Progress.decode(source).game.bestSprint;
    expect(best('{"bestSprint":-7}'), 0);
    expect(best('{"bestSprint":9000000000000000000}'), 1000000000);
    expect(best('{"bestSprint":1000000000}'), 1000000000);
    expect(best('{"bestSprint":420}'), 420);
  });

  group('a kind that is off by default (algebra)', () {
    final equation = (OperationType.algebra.source as AlgebraSource).build(
      OperationType.algebra,
      'missingSecondAddend',
      [3, 4],
    )!;
    final solved = Attempt(
      equation,
      firstAnswer: 4,
      elapsedMs: 3100,
      answeredAt: DateTime.utc(2026, 11, 21, 10).toLocal(),
    );

    test('default, empty and missing selections give the arithmetic kinds', () {
      expect(Progress().selectedOperations, arithmeticKinds);
      expect(
        Progress(selectedOperations: {}).selectedOperations,
        arithmeticKinds,
      );
      expect(
        Progress().withSelectedOperations({}).selectedOperations,
        arithmeticKinds,
      );
      expect(Progress.decode('{}').selectedOperations, arithmeticKinds);
      expect(
        Progress.decode('{"selectedOperations":[]}').selectedOperations,
        arithmeticKinds,
      );
      expect(
        Progress.decode('{"selectedOperations":["algebra"]}')
            .selectedOperations,
        {OperationType.algebra},
      );
    });

    test('starts at level 1 with tier harder and keeps its level when a tier '
        'is chosen', () {
      final harder = Progress(tier: Tier.harder);
      expect(harder.difficulty[OperationType.algebra]!.level, 1);
      expect(harder.difficulty[OperationType.plus]!.level, 5);
      final answered = Progress().withDifficulty(
        OperationType.algebra,
        const Difficulty(upCount: 2, answered: 6, correct: 5),
      );
      final chosen = answered.withTier(Tier.harder);
      expect(state(chosen.difficulty[OperationType.algebra]!), [1, 2, 0, 6, 5]);
      expect(chosen.difficulty[OperationType.minus]!.level, 5);
      expect(
        Progress.decode(chosen.encode())
            .difficulty[OperationType.algebra]!
            .level,
        1,
      );
    });

    test('its level is clamped to the highest level it has', () {
      expect(OperationType.algebra.highestLevel, 2);
      expect(
        Progress.decode('{"operations":{"algebra":{"level":4,"answered":3}}}')
            .difficulty[OperationType.algebra]!
            .level,
        2,
      );
    });

    test('has no operations entry before its first answer', () {
      final fresh = jsonDecode(Progress(tier: Tier.hard).encode()) as Map;
      expect(fresh['operations'] as Map, isNot(contains('algebra')));
      final answered = jsonDecode(
        Progress()
            .withDifficulty(
              OperationType.algebra,
              const Difficulty(answered: 1),
            )
            .encode(),
      ) as Map;
      expect((answered['operations'] as Map)['algebra'], {
        'level': 1,
        'upCount': 0,
        'downCount': 0,
        'answered': 1,
        'correct': 0,
      });
    });

    test('an attempt saves its variant and params and decodes to the same '
        'equation', () {
      final progress = Progress(history: [solved, attempt(9)]);
      final entries = progress.toJsonHistory();
      expect(entries.first, {
        'variant': 'missingSecondAddend',
        'params': [3, 4],
        'firstAnswerHundredths': 400,
        'kind': 'algebra',
        'result': 4,
        'level': 1,
        'firstAnswer': 4,
        'elapsedMs': 3100,
        'hintsUsed': 0,
        'answeredAt': '2026-11-21T10:00:00.000Z',
        'sprint': false,
      });
      // Arithmetic entries keep their shape.
      expect((entries.last as Map).keys, [
        'lhs',
        'rhs',
        'kind',
        'result',
        'level',
        'firstAnswer',
        'elapsedMs',
        'hintsUsed',
        'answeredAt',
        'sprint',
      ]);
      final decoded = Progress.decode(progress.encode());
      final problem = decoded.history.first.problem as EquationProblem;
      expect(
        [problem.variant, problem.params, problem.question, problem.result],
        [
          'missingSecondAddend',
          [3, 4],
          '3 + □ = 7',
          4,
        ],
      );
      expect(decoded.history.first.correct, isTrue);
      expect(decoded.encode(), progress.encode());
    });

    test('an equation answer is compared and saved as whole hundredths', () {
      Attempt answered(num? answer, [int? hundredths]) => Attempt(
        equation,
        firstAnswer: answer,
        answerHundredths: hundredths,
        elapsedMs: 10,
        answeredAt: DateTime.utc(2026, 11, 21, 10).toLocal(),
      );
      expect(equation.resultHundredths, 400);
      expect(answered(4, 400).correct, isTrue);
      expect(answered(numberOfHundredths(401), 401).correct, isFalse);
      expect(answered(numberOfHundredths(-400), -400).correct, isFalse);
      expect(answered(null).correct, isFalse);
      // Without the parsed hundredths, the number's text is read: 4.0 is
      // what this build's check stored before answers had hundredths.
      expect(answered(4.0).correct, isTrue);
      expect(answered(4.0).answerHundredths, 400);

      final decimal = answered(numberOfHundredths(-25), -25);
      final entry = Progress(history: [decimal]).toJsonHistory().single as Map;
      expect(entry['firstAnswerHundredths'], -25);
      expect(entry['firstAnswer'], -0.25);
      final back = Progress.decode(Progress(history: [decimal]).encode());
      expect(back.history.single.answerHundredths, -25);
      expect(back.history.single.correct, isFalse);
      expect(
        Progress.decode(Progress(history: [decimal]).encode()).encode(),
        Progress(history: [decimal]).encode(),
      );
    });

    test('the saved hundredths win; an entry without them (an older build '
        'drops fields it does not know) is read from its number', () {
      Attempt decoded(String fields) => Progress.decode(
        '{"history":[{"variant":"missingSecondAddend","params":[3,4],'
        '$fields"kind":"algebra","result":4,"level":1,"elapsedMs":10,'
        '"hintsUsed":0,"answeredAt":"2026-11-21T10:00:00.000Z",'
        '"sprint":false}]}',
      ).history.single;
      final fromHundredths = decoded(
        '"firstAnswerHundredths":400,"firstAnswer":3.99,',
      );
      expect(fromHundredths.answerHundredths, 400);
      expect(fromHundredths.firstAnswer, 4);
      expect(fromHundredths.correct, isTrue);
      expect(decoded('"firstAnswer":4.0,').correct, isTrue);
      expect(decoded('"firstAnswer":-2.5,').answerHundredths, -250);
      expect(decoded('"firstAnswer":0.29,').answerHundredths, 29);
      expect(decoded('"firstAnswer":null,').skipped, isTrue);
      expect(
        () => decoded('"firstAnswerHundredths":4.5,"firstAnswer":4,'),
        throwsFormatException,
        reason: 'as a malformed firstAnswer',
      );
    });

    test('a document with algebra survives an older build that does not '
        'know the kind', () {
      final written =
          Progress(
                selectedOperations: {OperationType.plus, OperationType.algebra},
                history: [attempt(6), solved],
              )
              .withDifficulty(
                OperationType.algebra,
                const Difficulty(answered: 1, correct: 1),
              )
              .encode();
      expect(written, contains('"algebra"'));
      // To a build without the kind, "algebra" is a name it does not know.
      final older = written.replaceAll('"algebra"', '"fromANewerBuild"');

      final decoded = Progress.decode(older);
      expect(decoded.selectedOperations, {OperationType.plus});
      expect(decoded.history, hasLength(1));
      expect(decoded.history.single.problem.kind, OperationType.divide);
      expect(decoded.encode(), older);
      // Back in this build, nothing was lost.
      final again = Progress.decode(
        decoded.encode().replaceAll('"fromANewerBuild"', '"algebra"'),
      );
      expect(again.encode(), written);
      expect(again.history.last.problem.question, '3 + □ = 7');
    });

    for (final (name, fields) in [
      ('an unknown variant', '"variant":"missingFactor","params":[3,4]'),
      ('no variant', '"params":[3,4]'),
      ('params that are not a list', '"variant":"missingMinuend","params":7'),
      (
        'a param that is not a whole number',
        '"variant":"missingMinuend","params":[3,"4"]',
      ),
      ('a decimal param', '"variant":"missingMinuend","params":[3,4.5]'),
      ('too few params', '"variant":"missingMinuend","params":[3]'),
      ('too many params', '"variant":"missingMinuend","params":[3,4,5]'),
      ('a negative param', '"variant":"missingMinuend","params":[-3,4]'),
    ]) {
      test('an algebra entry with $name is kept as it is', () {
        expectKept(
          '{$fields,"kind":"algebra","result":7,"level":1,'
          '"firstAnswer":7,"elapsedMs":10,"hintsUsed":0,'
          '"answeredAt":"2026-11-21T10:00:00.000Z","sprint":false}',
          solved,
        );
      });
    }

    test('an algebra entry whose result its params do not build is kept as '
        'it is', () {
      expectKept(
        '{"variant":"missingMinuend","params":[3,4],"kind":"algebra",'
        '"result":8,"level":1,"firstAnswer":8,"elapsedMs":10,"hintsUsed":0,'
        '"answeredAt":"2026-11-21T10:00:00.000Z","sprint":false}',
        solved,
      );
    });
  });

  group('the geometry kind', () {
    final figure = (OperationType.geometry.source as GeometrySource).build(
      OperationType.geometry,
      'rectanglePerimeter',
      [5, 3],
    )!;
    final solved = Attempt(
      figure,
      firstAnswer: 16,
      elapsedMs: 4200,
      answeredAt: DateTime.utc(2026, 11, 21, 11).toLocal(),
    );

    test('starts at level 1 with tier harder and is capped at level 2', () {
      expect(
        Progress(tier: Tier.harder).difficulty[OperationType.geometry]!.level,
        1,
      );
      expect(OperationType.geometry.highestLevel, 2);
      expect(
        Progress.decode('{"operations":{"geometry":{"level":5,"answered":3}}}')
            .difficulty[OperationType.geometry]!
            .level,
        2,
      );
      expect(
        Progress().selectedOperations,
        isNot(contains(OperationType.geometry)),
      );
    });

    test('an attempt saves its variant and params and decodes to the same '
        'figure', () {
      final progress = Progress(history: [solved, attempt(9)]);
      expect(progress.toJsonHistory().first, {
        'variant': 'rectanglePerimeter',
        'params': [5, 3],
        'firstAnswerHundredths': 1600,
        'kind': 'geometry',
        'result': 16,
        'level': 1,
        'firstAnswer': 16,
        'elapsedMs': 4200,
        'hintsUsed': 0,
        'answeredAt': '2026-11-21T11:00:00.000Z',
        'sprint': false,
      });
      final decoded = Progress.decode(progress.encode());
      final problem = decoded.history.first.problem as FigureProblem;
      expect(problem.figure, figure.figure);
      expect(
        [problem.variant, problem.params, problem.result],
        [
          'rectanglePerimeter',
          [5, 3],
          16,
        ],
      );
      expect(decoded.history.first.correct, isTrue);
      expect(decoded.encode(), progress.encode());
    });

    test('a document with geometry survives an older build that does not '
        'know the kind', () {
      final written =
          Progress(
                selectedOperations: {
                  OperationType.plus,
                  OperationType.geometry,
                },
                history: [attempt(6), solved],
              )
              .withDifficulty(
                OperationType.geometry,
                const Difficulty(answered: 1, correct: 1),
              )
              .encode();
      final older = written.replaceAll('"geometry"', '"fromANewerBuild"');
      final decoded = Progress.decode(older);
      expect(decoded.selectedOperations, {OperationType.plus});
      expect(decoded.history, hasLength(1));
      expect(decoded.encode(), older);
      final again = Progress.decode(
        decoded.encode().replaceAll('"fromANewerBuild"', '"geometry"'),
      );
      expect(again.encode(), written);
      expect(
        (again.history.last.problem as FigureProblem).figure,
        figure.figure,
      );
    });

    for (final (name, fields, result) in [
      ('an unknown variant', '"variant":"circleArea","params":[5,3]', 16),
      ('no variant', '"params":[5,3]', 16),
      (
        'params outside the family',
        '"variant":"rectanglePerimeter","params":[5,5]',
        20,
      ),
      ('a decimal param', '"variant":"squarePerimeter","params":[4.5]', 18),
      (
        'a result its params do not build',
        '"variant":"rectanglePerimeter","params":[5,3]',
        15,
      ),
    ]) {
      test('a geometry entry with $name is kept as it is', () {
        expectKept(
          '{$fields,"kind":"geometry","result":$result,"level":1,'
          '"firstAnswer":7,"elapsedMs":10,"hintsUsed":0,'
          '"answeredAt":"2026-11-21T10:00:00.000Z","sprint":false}',
          solved,
        );
      });
    }
  });

  test('history and selection are unmodifiable', () {
    final progress = Progress(history: [attempt(1)]);
    expect(() => progress.history.add(attempt(2)), throwsUnsupportedError);
    expect(() => progress.selectedOperations.clear(), throwsUnsupportedError);
  });
}

/// [entry] next to a decodable [known] attempt: the entry stays out of the
/// history, nothing throws, and the entry is written back unchanged.
void expectKept(String entry, Attempt known) {
  final source = jsonEncode({
    'history': [
      jsonDecode(entry),
      Progress(history: [known]).toJsonHistory().single,
    ],
  });
  final decoded = Progress.decode(source);
  expect(decoded.history, hasLength(1));
  expect(decoded.history.single.problem.runtimeType, known.problem.runtimeType);
  final history = decoded.toJsonHistory();
  expect(history.first, jsonDecode(entry));
  expect(Progress.decode(decoded.encode()).toJsonHistory(), history);
}

extension on Progress {
  List<Object?> toJsonHistory() =>
      (jsonDecode(encode()) as Map<String, Object?>)['history']! as List;
}

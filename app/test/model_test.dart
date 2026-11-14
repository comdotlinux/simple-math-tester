import 'dart:async';
import 'dart:math';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

void main() {
  const addition = Problem(2, 3, OperationType.plus, 5);
  final start = DateTime(2026, 11, 14, 9);

  MathTesterModel modelFor(
    Problem problem, {
    DateTime Function()? clock,
    Problem Function()? next,
    Random? random,
  }) {
    final model = MathTesterModel(
      initialProblem: problem,
      nextProblem: next ?? () => const Problem(6, 3, OperationType.minus, 3),
      random: random,
      clock: clock,
    );
    addTearDown(model.dispose);
    return model;
  }

  for (final type in OperationType.values) {
    test('accepts numeric input for $type', () {
      final problem = Problem(12, 3, type, type.calculate(12, 3));
      final model = modelFor(problem);

      model.setDraftInput('${problem.result}');
      expect(model.submitAnswer(), isTrue);
      expect(model.answerCorrect, isTrue);
      expect(model.history.single.correct, isTrue);
      expect(model.validationMessage, isNull);
    });
  }

  test('criterion 1: one valid check adds one entry before Next', () {
    final model = modelFor(addition);
    model.submitAnswer();
    expect(model.history, isEmpty);

    model.setDraftInput('4');
    model.submitAnswer();
    expect(model.history, hasLength(1));
    expect(model.history.single.problem, same(addition));
    expect(model.history.single.firstAnswer, 4);
  });

  test('a retry after a correct first check keeps the entry', () {
    var now = start;
    final model = modelFor(addition, clock: () => now);
    now = start.add(const Duration(seconds: 7));
    model.setDraftInput('5x');
    model.submitAnswer();
    model.setDraftInput('5');
    model.submitAnswer();
    final first = model.history.single;
    expect(first.firstAnswer, 5);
    expect(first.correct, isTrue);

    model.setDraftInput('4');
    model.submitAnswer();
    expect(model.answerCorrect, isFalse);
    now = start.add(const Duration(seconds: 20));
    model.setDraftInput('5');
    model.submitAnswer();
    expect(model.answerCorrect, isTrue);
    expect(model.history.single, same(first));
  });

  test('criterion 2: checking 5 then the correct value records Incorrect', () {
    var now = start;
    const problem = Problem(2, 4, OperationType.plus, 6);
    final model = modelFor(problem, clock: () => now);
    now = start.add(const Duration(milliseconds: 3250));
    model.setDraftInput('5');
    model.submitAnswer();
    final attempt = model.history.single;

    now = start.add(const Duration(seconds: 9));
    model.setDraftInput('6');
    model.submitAnswer();
    expect(model.answerCorrect, isTrue);
    expect(model.history, [same(attempt)]);
    expect(attempt.firstAnswer, 5);
    expect(attempt.skipped, isFalse);
    expect(attempt.correct, isFalse);
    expect(attempt.elapsedMs, 3250);
    expect(attempt.answeredAt, start.add(const Duration(milliseconds: 3250)));
    expect(attempt.hintsUsed, 0);
    expect(attempt.sprint, isFalse);
  });

  test('criterion 3: Next without a valid check adds one Skipped entry', () {
    var now = start;
    final model = modelFor(
      addition,
      clock: () => now,
      next: () => const Problem(2, 3, OperationType.plus, 5),
    );
    now = start.add(const Duration(seconds: 4));
    model.generateNextProblem();
    expect(model.history.single.skipped, isTrue);
    expect(model.history.single.problem, same(addition));
    expect(model.history.single.elapsedMs, 4000);
    expect(model.history.single.answeredAt, now);

    model.setDraftInput('hello');
    expect(model.submitAnswer(), isFalse);
    model.generateNextProblem();
    expect(model.history, hasLength(2));
    expect(model.history.every((attempt) => attempt.skipped), isTrue);
    expect(model.history.map((attempt) => attempt.problem.question), [
      '2 + 3',
      '2 + 3',
    ]);
  });

  test('criterion 3: Next after a valid check adds nothing more', () {
    final model = modelFor(addition);
    model.setDraftInput('5');
    model.submitAnswer();
    model.submitAnswer();
    model.generateNextProblem();
    expect(model.history, hasLength(1));
    expect(model.history.single.correct, isTrue);
    expect(model.draftInput, isEmpty);
    expect(model.answerCorrect, isNull);
    expect(model.validationMessage, isNull);
    expect(model.submitAnswer(), isFalse);
    expect(model.history, hasLength(1));
  });

  test('history is an unmodifiable list replaced on every change', () {
    final model = modelFor(addition);
    final before = model.history;
    model.setDraftInput('5');
    model.submitAnswer();
    final afterCheck = model.history;
    expect(afterCheck, isNot(same(before)));
    expect(before, isEmpty);
    expect(() => afterCheck.clear(), throwsUnsupportedError);
    model.submitAnswer();
    expect(model.history, same(afterCheck));
  });

  for (final text in [
    '',
    '  ',
    'hello',
    '1..2',
    'NaN',
    'Infinity',
    '-Infinity',
  ]) {
    test('invalid input "$text" records nothing', () {
      final model = modelFor(addition);
      model.setDraftInput(text);

      expect(model.submitAnswer(), isFalse);
      expect(model.validationMessage, isNotEmpty);
      expect(model.answerCorrect, isNull);
      expect(model.history, isEmpty);
    });
  }

  test('editing clears validation and navigation preserves the draft', () {
    final model = modelFor(addition);
    model.submitAnswer();
    model.setDraftInput(' 5 ');
    expect(model.validationMessage, isNull);
    model.setCurrentPage(1);
    model.setCurrentPage(0);
    expect(model.current, same(addition));
    expect(model.draftInput, ' 5 ');
    expect(model.submitAnswer(), isTrue);
    expect(model.answerCorrect, isTrue);
  });

  test('a draft without a check is recorded as skipped', () {
    final model = modelFor(addition);
    model.setDraftInput('5');
    model.generateNextProblem();
    expect(model.history.single.skipped, isTrue);
    expect(model.history.single.correct, isFalse);
  });

  test('invalid navigation is rejected without changing the current page', () {
    final model = modelFor(addition);
    expect(() => model.setCurrentPage(2), throwsRangeError);
    expect(model.currentPage, 0);
  });

  group('selected operations', () {
    MathTesterModel drawingModel(int seed) {
      final model = MathTesterModel(
        initialProblem: addition,
        random: Random(seed),
      );
      addTearDown(model.dispose);
      return model;
    }

    test('all four operations are selected by default', () {
      expect(drawingModel(1).selectedOperations, OperationType.values.toSet());
    });

    test('criterion 4: only multiplication selected draws 200 products', () {
      final model = drawingModel(42);
      for (final type in [
        OperationType.plus,
        OperationType.minus,
        OperationType.divide,
      ]) {
        model.toggleOperation(type);
      }
      expect(model.selectedOperations, {OperationType.multiply});
      for (var i = 0; i < 200; i++) {
        model.generateNextProblem();
        expect(model.current.kind, OperationType.multiply);
      }
    });

    test('criterion 4: deselecting the on-screen kind keeps the problem', () {
      final model = drawingModel(7);
      model.toggleOperation(OperationType.plus);
      expect(model.current, same(addition));
      expect(model.history, isEmpty);
      expect(model.selectedOperations, isNot(contains(OperationType.plus)));
      model.setDraftInput('5');
      model.submitAnswer();
      expect(model.history.single.problem, same(addition));
    });

    test('criterion 5: the last selected operation cannot be deselected', () {
      final model = drawingModel(3);
      var notifications = 0;
      model.addListener(() => notifications++);
      for (final type in [
        OperationType.plus,
        OperationType.minus,
        OperationType.multiply,
      ]) {
        model.toggleOperation(type);
      }
      final selection = model.selectedOperations;
      expect(notifications, 3);

      model.toggleOperation(OperationType.divide);
      expect(model.selectedOperations, {OperationType.divide});
      expect(model.selectedOperations, same(selection));
      expect(notifications, 3);

      model.toggleOperation(OperationType.plus);
      expect(model.selectedOperations, {
        OperationType.plus,
        OperationType.divide,
      });
    });
  });

  group('hints', () {
    const sum = Problem(12, 3, OperationType.plus, 15);

    test('steps reveal one at a time and the last needs a check', () {
      final model = modelFor(sum);
      expect(model.steps, hasLength(3));
      expect(model.revealedSteps, 0);
      model.revealStep();
      model.revealStep();
      expect(model.revealedSteps, 2);
      expect(model.canRevealStep, isFalse);
      model.revealStep();
      expect(model.revealedSteps, 2);

      model.setDraftInput('15');
      model.submitAnswer();
      expect(model.canRevealStep, isTrue);
      model.revealStep();
      expect(model.revealedSteps, 3);
      expect(model.canRevealStep, isFalse);
    });

    test('hintsUsed counts the steps revealed before the first check', () {
      final model = modelFor(sum);
      model.revealStep();
      model.setDraftInput('14');
      model.submitAnswer();
      expect(model.revealedSteps, 1);
      model.revealStep();
      model.setDraftInput('15');
      model.submitAnswer();
      expect(model.history.single.hintsUsed, 1);
    });

    test('a wrong first check reveals 1 step; a retry reveals none', () {
      final model = modelFor(sum);
      model.setDraftInput('14');
      model.submitAnswer();
      expect(model.revealedSteps, 1);
      expect(model.history.single.hintsUsed, 0);
      model.setDraftInput('13');
      model.submitAnswer();
      expect(model.revealedSteps, 1);
    });

    test('an invalid check does not unlock the final step', () {
      final model = modelFor(sum);
      model.revealStep();
      model.revealStep();
      for (final text in ['', 'hello']) {
        model.setDraftInput(text);
        expect(model.submitAnswer(), isFalse);
      }
      expect(model.canRevealStep, isFalse);
      model.revealStep();
      expect(model.revealedSteps, model.steps.length - 1);
    });

    test('a correct first check reveals nothing', () {
      final model = modelFor(sum);
      model.setDraftInput('15');
      model.submitAnswer();
      expect(model.revealedSteps, 0);
    });

    test(
      'a skip records the hints opened and the next problem starts at 0',
      () {
        final model = modelFor(sum);
        model.revealStep();
        model.revealStep();
        model.generateNextProblem();
        expect(model.history.single.skipped, isTrue);
        expect(model.history.single.hintsUsed, 2);
        expect(model.revealedSteps, 0);
        expect(model.steps.last, contains('= 3'));
      },
    );
  });

  group('difficulty', () {
    MathTesterModel seeded({Progress? progress, ProgressStore? store}) {
      final model = MathTesterModel(
        random: Random(11),
        progress: progress ?? Progress(tier: Tier.easy),
        store: store,
      );
      addTearDown(model.dispose);
      return model;
    }

    void answer(MathTesterModel model, {required bool right}) {
      model.setDraftInput('${model.current.result + (right ? 0 : 1)}');
      model.submitAnswer();
      model.generateNextProblem();
    }

    test('new problems are drawn at their operation\'s level', () {
      final model = seeded(
        progress: Progress(
          tier: Tier.easy,
          difficulty: {
            for (final type in OperationType.values)
              type: Difficulty(level: type.index + 2),
          },
        ),
      );
      for (var i = 0; i < 50; i++) {
        expect(model.current.level, model.current.kind.index + 2);
        model.generateNextProblem();
      }
    });

    test('the first valid check applies the rule once and saves it', () async {
      final store = MemoryProgressStore();
      final model = seeded(
        progress: Progress(
          tier: Tier.easy,
          selectedOperations: {OperationType.plus},
        ),
        store: store,
      );
      for (var i = 0; i < 3; i++) {
        answer(model, right: true);
      }
      expect(model.difficulty[OperationType.plus]!.level, 2);
      expect(model.current.level, 2);

      // A retry after a wrong first check does not count again.
      model.setDraftInput('${model.current.result + 1}');
      model.submitAnswer();
      model.setDraftInput('${model.current.result}');
      model.submitAnswer();
      final plus = model.difficulty[OperationType.plus]!;
      expect([plus.level, plus.upCount, plus.downCount], [2, 0, 1]);
      expect([plus.answered, plus.correct], [4, 3]);

      await pumpEventQueue();
      final saved = Progress.decode((await store.read(progressKey))!);
      expect(saved.difficulty[OperationType.plus]!.downCount, 1);
      expect(saved.difficulty[OperationType.plus]!.answered, 4);
    });

    test('a hinted correct answer and a skip leave the counters', () {
      final model = seeded(
        progress: Progress(
          tier: Tier.easy,
          selectedOperations: {OperationType.minus},
        ),
      );
      answer(model, right: true);
      model.revealStep();
      answer(model, right: true);
      model.generateNextProblem();
      final minus = model.difficulty[OperationType.minus]!;
      expect([minus.upCount, minus.answered, minus.correct], [1, 2, 2]);
      expect(model.history.map((a) => a.skipped), [false, false, true]);
    });

    test(
      'choosing a tier resets levels and replaces the problem unrecorded',
      () async {
        final store = MemoryProgressStore();
        final model = seeded(progress: Progress(), store: store);
        expect(model.tier, isNull);
        final before = model.current;

        model.chooseTier(Tier.hard);
        expect(model.tier, Tier.hard);
        expect(model.current, isNot(same(before)));
        expect(model.current.level, 5);
        expect(model.history, isEmpty);
        for (final value in model.difficulty.values) {
          expect([value.level, value.upCount, value.downCount], [5, 0, 0]);
        }

        answer(model, right: false);
        model.chooseTier(Tier.medium);
        expect(model.current.level, 3);
        expect(model.history, hasLength(1));
        await pumpEventQueue();
        expect(
          Progress.decode((await store.read(progressKey))!).tier,
          Tier.medium,
        );
      },
    );
  });

  group('game loop', () {
    MathTesterModel gameModel({
      required DateTime Function() clock,
      GameState game = const GameState(),
      ProgressStore? store,
    }) {
      final model = MathTesterModel(
        initialProblem: const Problem(2, 3, OperationType.plus, 5, level: 2),
        nextProblem: () => const Problem(6, 3, OperationType.minus, 3),
        clock: clock,
        store: store,
        progress: Progress(tier: Tier.easy, game: game),
      );
      addTearDown(model.dispose);
      return model;
    }

    void check(MathTesterModel model, String input) {
      model.setDraftInput(input);
      model.submitAnswer();
    }

    test('criterion 20: XP and combo at the first valid check only', () {
      final model = gameModel(
        clock: () => start,
        game: const GameState(combo: 3, xp: 40),
      );
      check(model, 'abc');
      expect([model.game.xp, model.game.combo], [40, 3]);
      check(model, '5');
      // Level 2, combo before 3: 2 × 13.
      expect(
        [model.game.xp, model.game.combo, model.game.dailyCount],
        [66, 4, 1],
      );
      check(model, '4');
      check(model, '5');
      expect([model.game.xp, model.game.combo], [66, 4], reason: 'retry');
      model.generateNextProblem();
      expect([model.game.xp, model.game.combo], [66, 4], reason: 'Next');

      // 6 − 3: a hint opened before the check halves the award.
      model.revealStep();
      check(model, '3');
      expect([model.game.xp, model.game.combo], [66 + 7, 5]);
      model.generateNextProblem();
      check(model, '4');
      expect([model.game.xp, model.game.combo], [73, 0], reason: 'wrong');
    });

    test('criterion 20: a skip sets the combo to 0 and awards nothing', () {
      final model = gameModel(
        clock: () => start,
        game: const GameState(combo: 6, xp: 90),
      );
      model.generateNextProblem();
      expect([model.game.xp, model.game.combo], [90, 0]);
    });

    test('the day change runs on load and on resume', () {
      var now = DateTime(2026, 11, 14, 23, 50);
      final model = gameModel(
        clock: () => now,
        game: const GameState(dailyCount: 8, lastActiveDate: '2026-11-13'),
      );
      expect(
        [model.game.dailyCount, model.game.lastActiveDate],
        [0, '2026-11-14'],
      );
      check(model, '5');
      expect(model.shownDailyCount, 1);

      now = DateTime(2026, 11, 15, 0, 10);
      expect(model.shownDailyCount, 0, reason: 'shown from the clock');
      expect(model.game.dailyCount, 1);
      var notified = false;
      model.addListener(() => notified = true);
      model.handleLifecycle(AppLifecycleState.resumed);
      expect(notified, isTrue);
      expect(
        [model.game.dailyCount, model.game.lastActiveDate],
        [0, '2026-11-15'],
      );
    });

    test('ten correct answers on one date reach the goal and save', () async {
      final store = MemoryProgressStore();
      final model = gameModel(
        clock: () => start,
        store: store,
        game: const GameState(
          streak: 2,
          bestStreak: 2,
          lastGoalDate: '2026-11-13',
        ),
      );
      for (var i = 0; i < 10; i++) {
        check(model, '${model.current.result}');
        model.generateNextProblem();
      }
      expect(
        [model.game.streak, model.shownStreak, model.game.bestStreak],
        [3, 3, 3],
      );
      await pumpEventQueue();
      final saved = Progress.decode((await store.read(progressKey))!).game;
      expect(
        [saved.xp, saved.streak, saved.dailyCount, saved.lastGoalDate],
        [model.game.xp, 3, 10, '2026-11-14'],
      );
    });
  });

  group('sprint', () {
    late StreamController<void> ticks;
    setUp(() => ticks = StreamController<void>.broadcast());
    tearDown(() => ticks.close());

    const plusLevel3 = Difficulty(
      level: 3,
      upCount: 2,
      downCount: 1,
      answered: 10,
      correct: 7,
    );

    MathTesterModel sprintModel({
      required DateTime Function() clock,
      GameState game = const GameState(),
      Tier? tier = Tier.easy,
      List<Attempt> history = const [],
      ProgressStore? store,
    }) {
      var drawn = 0;
      final model = MathTesterModel(
        initialProblem: const Problem(2, 3, OperationType.plus, 5, level: 3),
        nextProblem: () {
          drawn++;
          return Problem(drawn, 1, OperationType.plus, drawn + 1, level: 3);
        },
        clock: clock,
        store: store,
        ticker: () => ticks.stream,
        progress: Progress(
          tier: tier,
          game: game,
          history: history,
          difficulty: {OperationType.plus: plusLevel3},
        ),
      );
      addTearDown(model.dispose);
      return model;
    }

    void check(MathTesterModel model, String input) {
      model.setDraftInput(input);
      model.submitAnswer();
    }

    List<int> counters(Difficulty d) => [
      d.level,
      d.upCount,
      d.downCount,
      d.answered,
      d.correct,
    ];

    test(
      'criterion 25: ends at 60 s, 45 of them paused, and keeps levels',
      () async {
        var now = start;
        final store = MemoryProgressStore();
        final model = sprintModel(
          clock: () => now,
          store: store,
          game: const GameState(xp: 100, combo: 4, bestSprint: 30),
        );
        model.startSprint();
        expect(model.inSprint, isTrue);
        expect(model.game.combo, 0);
        expect(model.sprintSecondsLeft.value, 60);
        expect(model.current.question, '1 + 1');

        check(model, '2'); // level 3, combo 0: 30 XP
        expect(model.current.question, '2 + 1', reason: 'moves on when right');
        check(model, '3'); // level 3, combo 1: 33 XP
        check(model, '9');
        expect(model.current.question, '4 + 1', reason: 'moves on when wrong');
        check(model, 'x');
        expect(model.current.question, '4 + 1', reason: 'invalid stays');
        expect(model.validationMessage, 'Use a number for your answer.');
        expect(model.sprintScore, 63);
        expect(model.history.map((a) => a.sprint), [true, true, true]);
        expect(model.revealedSteps, 0, reason: 'a wrong check reveals nothing');

        now = start.add(const Duration(seconds: 15));
        ticks.add(null);
        await pumpEventQueue();
        expect(model.sprintSecondsLeft.value, 45);
        expect(model.inSprint, isTrue);

        // The answer typed on screen when time runs out is not recorded.
        model.setDraftInput('5');
        model.handleLifecycle(AppLifecycleState.paused);
        now = start.add(const Duration(seconds: 60));
        model.handleLifecycle(AppLifecycleState.resumed);

        expect(model.inSprint, isFalse);
        expect(ticks.hasListener, isFalse);
        expect(model.history, hasLength(3));
        expect(model.current.question, '5 + 1', reason: 'a new problem');
        expect(model.game.combo, 0);
        expect(model.game.xp, 163);
        expect(counters(model.difficulty[OperationType.plus]!), [
          3,
          2,
          1,
          13,
          9,
        ], reason: 'levels and counters as before; totals count');
        expect(model.lastSprint!.score, 63);
        expect(model.lastSprint!.best, 63);
        expect(model.lastSprint!.levels, [0, 0, 3, 0, 0]);
        expect(model.game.bestSprint, 63);
        await pumpEventQueue();
        final saved = Progress.decode((await store.read(progressKey))!);
        expect([saved.game.bestSprint, saved.game.combo], [63, 0]);
      },
    );

    test('criterion 25: My answers ends it with the score so far; a lower '
        'score keeps the best', () {
      final model = sprintModel(
        clock: () => start,
        game: const GameState(bestSprint: 500),
      );
      model.startSprint();
      check(model, '2');
      model.setCurrentPage(1);
      expect(model.inSprint, isFalse);
      expect(model.currentPage, 1);
      expect(model.lastSprint!.score, 30);
      expect(model.lastSprint!.best, 500);
      expect(model.game.bestSprint, 500);
      expect(model.current.question, '3 + 1', reason: 'not the one on screen');
      expect(model.history, hasLength(1));
    });

    test('a check after the time ran out records nothing and ends it', () {
      var now = start;
      final model = sprintModel(clock: () => now);
      model.startSprint();
      now = start.add(const Duration(seconds: 61));
      model.setDraftInput('2');
      expect(model.submitAnswer(), isFalse);
      expect(model.inSprint, isFalse);
      expect(model.history, isEmpty);
      expect(model.lastSprint!.score, 0);
      expect(model.lastSprint!.levels, [0, 0, 0, 0, 0]);
    });

    test('Next and hints do nothing during a round', () {
      final model = sprintModel(clock: () => start);
      model.startSprint();
      model.generateNextProblem();
      model.revealStep();
      expect(model.current.question, '1 + 1');
      expect(model.revealedSteps, 0);
      expect(model.history, isEmpty);
    });

    test('no sprint starts before a tier is chosen', () {
      final model = sprintModel(clock: () => start, tier: null);
      model.startSprint();
      expect(model.inSprint, isFalse);
      expect(ticks.hasListener, isFalse);
    });

    test('sprint answers count toward the 200 cap', () {
      final old = [
        for (var i = 0; i < Progress.historyCap; i++)
          Attempt(
            Problem(i, 1, OperationType.plus, i + 1),
            firstAnswer: i + 1,
            elapsedMs: 0,
            answeredAt: start,
          ),
      ];
      final model = sprintModel(clock: () => start, history: old);
      model.startSprint();
      check(model, '2');
      expect(model.history, hasLength(Progress.historyCap));
      expect(model.history.first.problem.lhs, 1);
      expect(model.history.last.sprint, isTrue);
      expect(model.history.last.problem.question, '1 + 1');
    });
  });
}

import 'dart:math';

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
}

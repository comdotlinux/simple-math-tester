import 'package:flutter/foundation.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

// Feedback, button and semantics wording stays literal: it is the behaviour.

Finder _label(Key key, String label) =>
    find.descendant(of: find.byKey(key), matching: find.text(label));

/// Ten saved answers, a hint opened on the first [hinted] of them.
List<Attempt> _answers(int hinted) => [
  for (var i = 0; i < 10; i++)
    Attempt(
      ArithmeticProblem(i, 1, OperationType.plus, i + 1),
      firstAnswer: i + 1,
      elapsedMs: 3000,
      answeredAt: DateTime(2026, 11, 21, 9, i),
      hintOpened: i < hinted,
    ),
];

void hintsJourneys() {
  group('hints', () {
    testWidgets('a wrong answer offers Try again and Show a hint, no steps', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      expect(_label(hintButtonKey, 'Hint'), findsOneWidget);

      await submit(tester, model.current.result + 1);

      expect(find.text('Not quite. Try another answer.'), findsOneWidget);
      expect(visibleSteps(tester), 0);
      expect(find.byKey(solutionStepsKey), findsNothing);
      expect(_label(tryAgainButtonKey, 'Try again'), findsOneWidget);
      expect(_label(hintButtonKey, 'Show a hint'), findsOneWidget);
    });

    // Typing after it is in test/hint_modal_test.dart: a typed value
    // injected here races the desktop engine's echo of the selection.
    testWidgets('Try again puts the focus back on the answer', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      await submit(tester, model.current.result + 1);
      final checked = model.current;

      await tapKey(tester, tryAgainButtonKey);

      expect(await answerFocused(tester), isTrue);
      expect(model.current, same(checked));
      expect(model.history, hasLength(1));
    });

    testWidgets('the hint steps through to the answer in its modal, closes '
        'back to the answer and reopens where it was', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      await submit(tester, model.current.result + 1);

      await tapKey(tester, hintButtonKey);
      expect(find.byKey(solutionStepsKey), findsOneWidget);
      expect(visibleSteps(tester), 1);
      while (model.revealedSteps < model.steps.length - 1) {
        expect(_label(revealStepButtonKey, 'Next step'), findsOneWidget);
        await tapKey(tester, revealStepButtonKey);
      }
      expect(find.text(model.steps.last(en)), findsNothing);
      expect(_label(revealStepButtonKey, 'Show the answer'), findsOneWidget);
      await tapKey(tester, revealStepButtonKey);
      expect(find.text(model.steps.last(en)), findsOneWidget);
      expect(model.hintOpened, isTrue);
      expect(model.answerShown, isTrue);

      await tapKey(tester, hintCloseKey);
      expect(find.byKey(solutionStepsKey), findsNothing);
      expect(visibleSteps(tester), 0);
      expect(await answerFocused(tester), isTrue);

      await tapKey(tester, hintButtonKey);
      expect(visibleSteps(tester), model.steps.length);
      // Escape and the dimmed area are in test/hint_modal_test.dart; a
      // simulated key does not reach the release web build.
      await tapKey(tester, hintCloseKey);
      expect(find.byKey(solutionStepsKey), findsNothing);
      expect(await answerFocused(tester), isTrue);

      // Answered right after the hint, the question moves on as before.
      await submit(tester, model.current.result);
      expect(model.answerCorrect, isTrue);
      final answered = model.current;
      await nextQuestion(tester);
      expect(model.current, isNot(same(answered)));
      expect(model.hintOpened, isFalse);
    });

    testWidgets('before a check every step but the answer can be opened', (
      tester,
    ) async {
      // Multiplication at level 1 always has three steps.
      await startWith(
        tester,
        Progress(tier: Tier.easy, selectedOperations: {OperationType.multiply}),
      );
      final model = modelOf(tester);
      expect(model.current.kind, OperationType.multiply);

      await tapKey(tester, hintButtonKey);
      expect(visibleSteps(tester), 1);
      await tapKey(tester, revealStepButtonKey);

      expect(visibleSteps(tester), 2);
      expect(revealEnabled(tester), isFalse);
      expect(find.text(model.steps.last(en)), findsNothing);
    });

    testWidgets('after hints on 6 of the last 10 answers a gentle nudge comes '
        'first: I will try keeps the question, Show the hint anyway opens it', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy, history: _answers(6)));
      final model = modelOf(tester);
      final question = model.current;

      await tapKey(tester, hintButtonKey);
      expect(find.byKey(hintNudgeKey), findsOneWidget);
      expect(
        find.text(
          'Try to solve it first. Working it out yourself helps you learn. '
          'The hint is still here if you need it.',
        ),
        findsOneWidget,
      );
      expect(_label(hintNudgeTryKey, 'I will try'), findsOneWidget);
      expect(
        _label(hintNudgeAnywayKey, 'Show the hint anyway'),
        findsOneWidget,
      );
      await tapKey(tester, hintNudgeTryKey);
      expect(find.byKey(hintNudgeKey), findsNothing);
      expect(find.byKey(solutionStepsKey), findsNothing);
      expect(model.hintOpened, isFalse);
      expect(model.current, same(question));
      expect(await answerFocused(tester), isTrue);

      // Asked again on the same question, the hint opens at once.
      await tapKey(tester, hintButtonKey);
      expect(find.byKey(hintNudgeKey), findsNothing);
      expect(find.byKey(solutionStepsKey), findsOneWidget);
      await tapKey(tester, hintCloseKey);

      // A wrong answer on the next question: the nudge again, then the hint.
      await nextQuestion(tester);
      await submit(tester, model.current.result + 1);
      await tapKey(tester, hintButtonKey);
      expect(find.byKey(hintNudgeKey), findsOneWidget);
      await tapKey(tester, hintNudgeAnywayKey);
      expect(find.byKey(solutionStepsKey), findsOneWidget);
      expect(model.history.last.hintOpened, isTrue);
      await tapKey(tester, hintCloseKey);
      expect(await answerFocused(tester), isTrue);
    });

    testWidgets('after hints on 5 of the last 10 answers the hint opens at '
        'once', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy, history: _answers(5)));
      await tapKey(tester, hintButtonKey);
      expect(find.byKey(hintNudgeKey), findsNothing);
      expect(find.byKey(solutionStepsKey), findsOneWidget);
    });

    testWidgets('hints used before Next are saved with the skip', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, selectedOperations: {OperationType.multiply}),
      );
      final model = modelOf(tester);
      await tapKey(tester, hintButtonKey);
      await tapKey(tester, revealStepButtonKey);
      await tapKey(tester, hintCloseKey);

      await nextQuestion(tester);

      expect(model.history.last.skipped, isTrue);
      expect(model.history.last.hintsUsed, 2);
      expect(model.history.last.hintOpened, isTrue);
      expect(model.revealedSteps, 0);
    });
  });
}

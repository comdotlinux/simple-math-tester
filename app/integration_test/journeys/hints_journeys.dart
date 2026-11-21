import 'package:flutter/foundation.dart' show Key;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

// Feedback, button and semantics wording stays literal: it is the behaviour.

Finder _label(Key key, String label) =>
    find.descendant(of: find.byKey(key), matching: find.text(label));

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

    testWidgets('Try again puts the focus back on the answer, and a right '
        'retry is checked', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      await submit(tester, model.current.result + 1);

      await tapKey(tester, tryAgainButtonKey);

      expect(await answerFocused(tester), isTrue);
      await typeAnswer(tester, '${model.current.result}');
      await pressEnter(tester);
      expect(model.answerCorrect, isTrue);
      expect(find.text('You got it!'), findsOneWidget);
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
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
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

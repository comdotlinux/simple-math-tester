import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

// Feedback, button and semantics wording stays literal: it is the behaviour.

Finder _revealLabel(String label) => find.descendant(
  of: find.byKey(revealStepButtonKey),
  matching: find.text(label),
);

void hintsJourneys() {
  group('hints', () {
    testWidgets('Hint shows the first step and becomes Next step', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      expect(_revealLabel('Hint'), findsOneWidget);
      expect(visibleSteps(tester), 0);

      await tapKey(tester, revealStepButtonKey);

      expect(find.byKey(solutionStepsKey), findsOneWidget);
      expect(visibleSteps(tester), 1);
      expect(_revealLabel('Next step'), findsOneWidget);
    });

    testWidgets('a hint tap keeps the focus on the answer', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      expect(await answerFocused(tester), isTrue);

      await tapKey(tester, revealStepButtonKey);

      expect(modelOf(tester).revealedSteps, 1);
      expect(await answerFocused(tester), isTrue);
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

      await tapKey(tester, revealStepButtonKey);
      await tapKey(tester, revealStepButtonKey);

      expect(visibleSteps(tester), 2);
      expect(revealEnabled(tester), isFalse);
      expect(find.text(model.steps.last), findsNothing);
    });

    testWidgets('a wrong first check opens the first step', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);

      await submit(tester, model.current.result + 1);

      expect(find.byKey(solutionStepsKey), findsOneWidget);
      expect(visibleSteps(tester), 1);
      // A right retry opens nothing more by itself.
      await submit(tester, model.current.result);
      expect(visibleSteps(tester), 1);
    });

    testWidgets('after a valid check every step, the answer too, can open', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      await submit(tester, model.current.result + 1);
      await submit(tester, model.current.result);

      while (revealEnabled(tester)) {
        await tapKey(tester, revealStepButtonKey);
      }

      expect(visibleSteps(tester), model.steps.length);
      expect(find.text(model.steps.last), findsOneWidget);
    });

    testWidgets('hints used before Next are saved with the skip', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, selectedOperations: {OperationType.multiply}),
      );
      final model = modelOf(tester);
      await tapKey(tester, revealStepButtonKey);
      await tapKey(tester, revealStepButtonKey);

      await nextQuestion(tester);

      expect(model.history.last.skipped, isTrue);
      expect(model.history.last.hintsUsed, 2);
      expect(visibleSteps(tester), 0);
    });
  });
}

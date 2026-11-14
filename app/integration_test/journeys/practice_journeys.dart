import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

void practiceJourneys() {
  group('practice', () {
    testWidgets('a wrong first answer is saved before Next', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final answer = model.current.result;

      await submit(tester, answer + 1);

      expect(find.text('Not quite. Try another answer.'), findsOneWidget);
      // The first valid check is recorded at once, before "Next question".
      expect(model.history, hasLength(1));
      expect(model.history.single.firstAnswer, answer + 1);
      final saved = await waitForSaved((p) => p.history.length == 1);
      expect(saved.history.single.firstAnswer, answer + 1);
    });

    testWidgets('a retry after a wrong answer can still be right', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final answer = model.current.result;
      await submit(tester, answer + 1);

      await submit(tester, answer);

      expect(model.draftInput, formatNumber(answer));
      expect(model.answerCorrect, isTrue);
      expect(find.text('You got it!'), findsOneWidget);
      // Only the first check counts.
      expect(model.history, hasLength(1));
      expect(model.history.single.firstAnswer, answer + 1);
    });

    testWidgets('a correct first answer is saved as correct', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final answer = model.current.result;

      await submit(tester, answer);

      expect(model.answerCorrect, isTrue);
      expect(find.text('You got it!'), findsOneWidget);
      expect(model.history.last.firstAnswer, answer);
      expect(model.history.last.correct, isTrue);
    });

    testWidgets('Next after a check shows a new question and adds no row', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      await submit(tester, model.current.result + 1);
      final checked = model.current;

      await nextQuestion(tester);

      expect(model.current, isNot(same(checked)));
      expect(model.draftInput, isEmpty);
      expect(find.text('Not quite. Try another answer.'), findsNothing);
      expect(find.text('Let’s work it out'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(revealStepButtonKey),
          matching: find.text('Hint'),
        ),
        findsOneWidget,
      );
      expect(model.history, hasLength(1));
    });

    testWidgets('Next without an answer is saved as skipped', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final skipped = model.current;

      await nextQuestion(tester);

      expect(model.history, hasLength(1));
      expect(model.history.single.skipped, isTrue);
      expect(model.history.single.problem.question, skipped.question);
      final saved = await waitForSaved((p) => p.history.length == 1);
      expect(saved.history.single.skipped, isTrue);
    });

    testWidgets('answers from play are kept in order: wrong, right, skipped', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);

      await submit(tester, model.current.result + 1);
      await nextQuestion(tester);
      await submit(tester, model.current.result);
      await nextQuestion(tester);
      await nextQuestion(tester);

      expect(model.history, hasLength(3));
      expect(
        model.history.map(
          (attempt) => attempt.skipped
              ? 'Skipped'
              : attempt.correct
              ? 'Correct'
              : 'Incorrect',
        ),
        ['Incorrect', 'Correct', 'Skipped'],
      );
    });

    testWidgets('an empty answer asks for a number and records nothing', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);

      await tapKey(tester, checkAnswerButtonKey);

      expect(find.text('Enter a number first.'), findsOneWidget);
      expect(model.history, isEmpty);
    });

    testWidgets('typing after feedback clears it', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      await submit(tester, model.current.result + 1);
      expect(find.text('Not quite. Try another answer.'), findsOneWidget);

      await typeAnswer(tester, '7');
      await tester.pumpAndSettle();

      expect(find.text('Not quite. Try another answer.'), findsNothing);
      expect(model.answerCorrect, isNull);
    });
  });
}

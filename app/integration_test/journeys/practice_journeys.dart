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

    testWidgets('Enter checks the answer and a second Enter shows the next '
        'question', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final first = model.current;
      await typeAnswer(tester, formatNumber(first.result));

      await pressEnter(tester);

      expect(find.text('You got it!'), findsOneWidget);
      expect(model.history.single.correct, isTrue);
      expect(await answerFocused(tester), isTrue);

      await pressEnter(tester);

      expect(model.current, isNot(same(first)));
      expect(questionOnScreen(tester), model.current.question);
      expect(model.draftInput, isEmpty);
      expect(find.text('You got it!'), findsNothing);
      expect(model.history, hasLength(1), reason: 'no skip is recorded');
      expect(await answerFocused(tester), isTrue);
    });

    testWidgets('a new answer after a wrong check is checked, not skipped', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final first = model.current;
      await typeAnswer(tester, formatNumber(first.result + 1));
      await pressEnter(tester);
      expect(find.text('Not quite. Try another answer.'), findsOneWidget);

      await typeAnswer(tester, formatNumber(first.result));
      await pressEnter(tester);

      expect(model.current, same(first));
      expect(find.text('You got it!'), findsOneWidget);
      expect(model.history, hasLength(1));
      expect(model.history.single.firstAnswer, first.result + 1);
    });

    testWidgets('the answer field keeps the focus after a check and after '
        'Skip or Next', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      expect(await answerFocused(tester), isTrue, reason: 'on start');

      await nextQuestion(tester);
      expect(await answerFocused(tester), isTrue, reason: 'after Skip');

      await submit(tester, model.current.result + 1);
      expect(await answerFocused(tester), isTrue, reason: 'after a check');

      await nextQuestion(tester);
      expect(await answerFocused(tester), isTrue, reason: 'after Next');
    });

    testWidgets('the button says Skip before a check and Next question after', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      expect(nextButtonText('Skip'), findsOneWidget);
      expect(semanticsNodesLabelled(tester, 'Skip'), 1);
      expect(semanticsNodesLabelled(tester, 'Next question'), 0);

      await submit(tester, model.current.result + 1);

      // A phone docks a short "Next" in the feedback strip; its label still
      // reads "Next question".
      expect(nextButtonText('Skip'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(nextQuestionButtonKey),
          matching: find.textContaining('Next'),
        ),
        findsOneWidget,
      );
      expect(semanticsNodesLabelled(tester, 'Skip'), 0);
      expect(semanticsNodesLabelled(tester, 'Next question'), greaterThan(0));

      await nextQuestion(tester);
      expect(nextButtonText('Skip'), findsOneWidget);
    });

    testWidgets('typing after feedback clears it', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final wrong = formatNumber(model.current.result + 1);
      await submit(tester, model.current.result + 1);
      expect(find.text('Not quite. Try another answer.'), findsOneWidget);

      // Appending a digit always changes the text; a fixed '7' did not when
      // the wrong answer was already 7.
      await typeAnswer(tester, '${wrong}1');
      await tester.pumpAndSettle();

      expect(find.text('Not quite. Try another answer.'), findsNothing);
      expect(model.answerCorrect, isNull);
    });
  });
}

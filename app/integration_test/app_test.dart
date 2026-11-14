import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart' as app;
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real app solution and history journeys', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(homePageKey));
    final model = context.read<MathTesterModel>();

    String currentQuestion() => model.current.question;

    Future<void> submit(num answer) async {
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '$answer');
      await tester.ensureVisible(find.byKey(checkAnswerButtonKey));
      await tester.tap(find.byKey(checkAnswerButtonKey));
      await tester.pumpAndSettle();
    }

    Future<void> nextQuestion() async {
      await tester.ensureVisible(find.byKey(nextQuestionButtonKey));
      await tester.tap(find.byKey(nextQuestionButtonKey));
      await tester.pumpAndSettle();
    }

    Future<void> openHistory() async {
      await tester.ensureVisible(find.text('My answers').last);
      await tester.tap(find.text('My answers').last);
      await tester.pumpAndSettle();
    }

    // History rows are built lazily, so on a phone-sized screen a later row
    // does not exist until the list is scrolled to it. Each visit starts at
    // the top, so rows are checked top to bottom.
    Future<Finder> inHistory(Finder finder) async {
      final list = find.descendant(
        of: find.byKey(resultsPageKey),
        matching: find.byType(Scrollable),
      );
      for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -100));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      return finder;
    }

    Future<void> returnToPractice() async {
      await tester.ensureVisible(find.text('Practice').first);
      await tester.tap(find.text('Practice').first);
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    int visibleSteps() => model.steps
        .where((step) => find.text(step).evaluate().isNotEmpty)
        .length;

    final firstQuestion = currentQuestion();
    final correctAnswer = model.current.result;
    await submit(correctAnswer + 1);
    expect(find.text('Not quite. Try another answer.'), findsOneWidget);
    expect(find.text('Let’s work it out'), findsOneWidget);
    expect(visibleSteps(), 1);
    // The first valid check is recorded at once, before "Next question".
    expect(model.history, hasLength(1));
    expect(model.history.single.firstAnswer, correctAnswer + 1);

    await submit(correctAnswer);
    expect(model.draftInput, '$correctAnswer');
    expect(model.answerCorrect, isTrue);
    expect(find.text('You got it!'), findsOneWidget);
    expect(visibleSteps(), 1);

    // After a valid check every step, the answer included, can be opened.
    while (tester
        .widget<ButtonStyleButton>(find.byKey(revealStepButtonKey))
        .enabled) {
      await tapKey(revealStepButtonKey);
    }
    expect(visibleSteps(), model.steps.length);
    expect(find.text(model.steps.last), findsOneWidget);

    await openHistory();
    expect(find.text('1 question completed.'), findsOneWidget);
    expect(await inHistory(find.text('Incorrect')), findsOneWidget);
    expect(await inHistory(find.text(firstQuestion)), findsWidgets);
    expect(
      await inHistory(
        find.text('Your answer: ${formatNumber(correctAnswer + 1)}'),
      ),
      findsWidgets,
    );
    expect(
      await inHistory(
        find.text('Expected answer: ${formatNumber(correctAnswer)}'),
      ),
      findsWidgets,
    );

    await returnToPractice();
    expect(currentQuestion(), firstQuestion);
    await nextQuestion();
    expect(find.text('Let’s work it out'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(revealStepButtonKey),
        matching: find.text('Hint'),
      ),
      findsOneWidget,
    );
    expect(model.history, hasLength(1));

    final secondQuestion = currentQuestion();
    final secondAnswer = model.current.result;
    await submit(secondAnswer);
    expect(model.answerCorrect, isTrue);
    expect(model.history.last.firstAnswer, secondAnswer);

    // Practise multiplication only, from the next question on.
    for (final name in ['Addition', 'Subtraction', 'Division']) {
      final chip = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == name,
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    expect(model.selectedOperations, {OperationType.multiply});
    expect(currentQuestion(), secondQuestion);
    expect(model.history, hasLength(2));
    await nextQuestion();
    await openHistory();
    expect(find.text('2 questions completed.'), findsOneWidget);
    expect(await inHistory(find.text('Incorrect')), findsOneWidget);
    expect(await inHistory(find.text('Correct')), findsOneWidget);
    expect(await inHistory(find.text(secondQuestion)), findsWidgets);
    expect(
      await inHistory(find.text('Your answer: ${formatNumber(secondAnswer)}')),
      findsWidgets,
    );

    await returnToPractice();
    final thirdQuestion = currentQuestion();
    expect(model.current.kind, OperationType.multiply);
    await tapKey(revealStepButtonKey);
    await tapKey(revealStepButtonKey);
    expect(visibleSteps(), 2);
    expect(
      tester.widget<ButtonStyleButton>(find.byKey(revealStepButtonKey)).enabled,
      isFalse,
    );
    await nextQuestion();
    expect(model.current.kind, OperationType.multiply);
    expect(model.history.last.hintsUsed, 2);
    await openHistory();
    expect(find.text('3 questions completed.'), findsOneWidget);
    expect(await inHistory(find.text('Skipped')), findsOneWidget);
    expect(await inHistory(find.text(thirdQuestion)), findsWidgets);
    expect(await inHistory(find.text('No answer entered')), findsOneWidget);
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart' as app;
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Each test writes its own starting document through the real plugin, so
  // test order and data left by earlier runs do not matter.
  Future<void> startWith(WidgetTester tester, Progress progress) async {
    await SharedPreferencesStore().write(progressKey, progress.encode());
    await app.main();
    await tester.pumpAndSettle();
  }

  testWidgets('restart shows the saved history and selection', (tester) async {
    await startWith(
      tester,
      Progress(
        selectedOperations: {OperationType.multiply},
        history: [
          for (final lhs in [3, 4, 5])
            Attempt(
              Problem(lhs, 6, OperationType.multiply, lhs * 6),
              firstAnswer: lhs * 6,
              elapsedMs: 1500,
              answeredAt: DateTime(2026, 11, 13, 18),
            ),
        ],
      ),
    );
    final model = tester
        .element(find.byKey(homePageKey))
        .read<MathTesterModel>();
    expect(model.canSave, isTrue);
    expect(model.selectedOperations, {OperationType.multiply});
    expect(model.history, hasLength(3));

    // The next problem follows the saved selection.
    await tester.ensureVisible(find.byKey(nextQuestionButtonKey));
    await tester.tap(find.byKey(nextQuestionButtonKey));
    await tester.pumpAndSettle();
    expect(model.current.kind, OperationType.multiply);

    await tester.ensureVisible(find.text('My answers').last);
    await tester.tap(find.text('My answers').last);
    await tester.pumpAndSettle();
    expect(find.text('4 questions completed.'), findsOneWidget);
    expect(find.text('3 × 6'), findsWidgets);

    // The skip is saved through the plugin.
    final saved = await SharedPreferencesStore().read(progressKey);
    expect(Progress.decode(saved!).history, hasLength(4));
  });

  testWidgets('real app solution and history journeys', (tester) async {
    await startWith(tester, Progress());

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
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text(firstQuestion), findsWidgets);
    expect(
      find.text('Your answer: ${formatNumber(correctAnswer + 1)}'),
      findsWidgets,
    );
    expect(
      find.text('Expected answer: ${formatNumber(correctAnswer)}'),
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
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text(secondQuestion), findsWidgets);
    expect(
      find.text('Your answer: ${formatNumber(secondAnswer)}'),
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
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text(thirdQuestion), findsWidgets);
    expect(find.text('No answer entered'), findsOneWidget);
    expect(model.history, hasLength(3));
  });
}

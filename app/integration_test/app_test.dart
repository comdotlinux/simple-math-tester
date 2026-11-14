import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart' as app;
import 'package:simple_math_tester/math_tester_model.dart';

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

    Future<void> returnToPractice() async {
      await tester.ensureVisible(find.text('Practice').first);
      await tester.tap(find.text('Practice').first);
      await tester.pumpAndSettle();
    }

    final firstQuestion = currentQuestion();
    final correctAnswer = model.current.result;
    await submit(correctAnswer + 1);
    expect(find.text('Not quite. Try another answer.'), findsOneWidget);
    expect(find.text('Let’s work it out'), findsOneWidget);
    // The first valid check is recorded at once, before "Next question".
    expect(model.history, hasLength(1));
    final incorrectInput = model.history.single.firstAnswer;

    await submit(correctAnswer);
    expect(model.draftInput, '$correctAnswer');
    expect(model.answerCorrect, isTrue);
    expect(find.text('You got it!'), findsOneWidget);
    expect(find.text('Let’s work it out'), findsNothing);

    await tester.ensureVisible(find.text('Show steps'));
    await tester.tap(find.text('Show steps'));
    await tester.pumpAndSettle();
    expect(find.text('Let’s work it out'), findsOneWidget);

    await openHistory();
    expect(find.text('1 question completed.'), findsOneWidget);
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text(firstQuestion), findsWidgets);
    expect(find.text('Your answer: $incorrectInput'), findsWidgets);
    expect(find.text('Expected answer: $correctAnswer'), findsWidgets);

    await returnToPractice();
    expect(currentQuestion(), firstQuestion);
    await nextQuestion();
    expect(find.text('Let’s work it out'), findsNothing);
    expect(find.text('Show steps'), findsNothing);
    expect(model.history, hasLength(1));

    final secondQuestion = currentQuestion();
    final secondAnswer = model.current.result;
    await submit(secondAnswer);
    expect(model.answerCorrect, isTrue);
    final correctInput = model.history.last.firstAnswer;
    await nextQuestion();
    await openHistory();
    expect(find.text('2 questions completed.'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text(secondQuestion), findsWidgets);
    expect(find.text('Your answer: $correctInput'), findsWidgets);

    await returnToPractice();
    final thirdQuestion = currentQuestion();
    await nextQuestion();
    await openHistory();
    expect(find.text('3 questions completed.'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text(thirdQuestion), findsWidgets);
    expect(find.text('No answer entered'), findsOneWidget);
    expect(model.history, hasLength(3));
  });
}

import 'package:flutter/rendering.dart' show SemanticsNode;
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
import 'package:simple_math_tester/rules.dart';

// History rows are built lazily, so on a phone-sized screen a row below the
// header, the stats card or earlier rows does not exist until the list is
// scrolled to it. Each visit starts at the top, so rows are checked top to
// bottom.
Future<Finder> inHistory(WidgetTester tester, Finder finder) async {
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

// find.bySemanticsLabel reads RenderObject.debugSemantics, which is always
// null in release builds, so it never matches there. This counts the nodes
// of the live semantics tree, which exists in every build mode.
int semanticsNodesLabelled(WidgetTester tester, String label) {
  var count = 0;
  bool visit(SemanticsNode node) {
    if (node.label == label) count++;
    node.visitChildren(visit);
    return true;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return count;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Each test writes its own starting document through the real plugin, so
  // test order and data left by earlier runs do not matter. Both choose a
  // tier, so the tier picker does not cover the practice page.
  Future<void> startWith(WidgetTester tester, Progress progress) async {
    await SharedPreferencesStore().write(progressKey, progress.encode());
    await app.main();
    await tester.pumpAndSettle();
  }

  testWidgets('restart shows the saved history and selection', (tester) async {
    final today = localDate(DateTime.now());
    await startWith(
      tester,
      Progress(
        tier: Tier.easy,
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
        game: GameState(
          xp: 250,
          combo: 2,
          streak: 3,
          bestStreak: 5,
          lastActiveDate: today,
          lastGoalDate: today,
        ),
      ),
    );
    final model = tester
        .element(find.byKey(homePageKey))
        .read<MathTesterModel>();
    expect(model.canSave, isTrue);
    expect(model.selectedOperations, {OperationType.multiply});
    expect(model.history, hasLength(3));
    expect(model.game.xp, 250);
    expect(model.shownStreak, 3);
    expect(semanticsNodesLabelled(tester, 'Daily streak: 3'), 1);
    expect(find.text('Level 2 · 250 XP'), findsOneWidget);
    // The first problem and the next both follow the saved selection.
    expect(model.current.kind, OperationType.multiply);
    expect(
      tester.widget<Text>(find.byKey(questionOnProblemsPageKey)).data,
      contains('×'),
    );

    await tester.ensureVisible(find.byKey(nextQuestionButtonKey));
    await tester.tap(find.byKey(nextQuestionButtonKey));
    await tester.pumpAndSettle();
    expect(model.current.kind, OperationType.multiply);

    await tester.ensureVisible(find.text('My answers').last);
    await tester.tap(find.text('My answers').last);
    await tester.pumpAndSettle();
    expect(find.text('4 questions completed.'), findsOneWidget);
    expect(await inHistory(tester, find.text('3 × 6')), findsWidgets);

    // The skip is saved through the plugin.
    final saved = Progress.decode(
      (await SharedPreferencesStore().read(progressKey))!,
    );
    expect(saved.history, hasLength(4));
    // A skip awards no XP and ends the combo; the streak is kept.
    expect([saved.game.xp, saved.game.combo], [250, 0]);
    expect([saved.game.streak, saved.game.bestStreak], [3, 5]);
  });

  testWidgets('real app solution and history journeys', (tester) async {
    await startWith(tester, Progress(tier: Tier.easy));

    final context = tester.element(find.byKey(homePageKey));
    final model = context.read<MathTesterModel>();

    String currentQuestion() => model.current.question;

    Future<void> submit(num answer) async {
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      // Types through the same entry point the platform's keyboard uses.
      // tester.enterText cannot be used: integration tests have no fake text
      // input, and the framework drops its client id -1 message when asserts
      // are off, so in release and profile builds the field stayed empty.
      // The answer is formatted as the app shows numbers, so 4.0 is typed 4.
      final text = formatNumber(answer);
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .updateEditingValue(
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            ),
          );
      await tester.pump();
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
    expect(model.draftInput, formatNumber(correctAnswer));
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
    expect(await inHistory(tester, find.text('Incorrect')), findsOneWidget);
    expect(await inHistory(tester, find.text(firstQuestion)), findsWidgets);
    expect(
      await inHistory(
        tester,
        find.text('Your answer: ${formatNumber(correctAnswer + 1)}'),
      ),
      findsWidgets,
    );
    expect(
      await inHistory(
        tester,
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
    expect(await inHistory(tester, find.text('Incorrect')), findsOneWidget);
    expect(await inHistory(tester, find.text('Correct')), findsOneWidget);
    expect(await inHistory(tester, find.text(secondQuestion)), findsWidgets);
    expect(
      await inHistory(
        tester,
        find.text('Your answer: ${formatNumber(secondAnswer)}'),
      ),
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
    expect(await inHistory(tester, find.text('Skipped')), findsOneWidget);
    expect(await inHistory(tester, find.text(thirdQuestion)), findsWidgets);
    expect(
      await inHistory(tester, find.text('No answer entered')),
      findsOneWidget,
    );
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

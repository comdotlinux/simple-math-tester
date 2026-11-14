import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';

void main() {
  Future<MathTesterModel> launch(
    WidgetTester tester, {
    Size size = const Size(1000, 900),
    double scale = 1,
    double keyboardInset = 0,
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final model = MathTesterModel(
      initialProblem: const Problem(12, 3, OperationType.plus, 15),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
            disableAnimations: disableAnimations,
          ),
          child: const MathTesterApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(model.dispose);
    return model;
  }

  testWidgets('Practice and results remain navigable', (tester) async {
    await launch(tester);
    expect(find.byKey(questionOnProblemsPageKey), findsOneWidget);
    await tester.tap(find.text('My answers').last);
    await tester.pumpAndSettle();
    expect(find.byKey(noResultsOnResultsPageKey), findsOneWidget);
    await tester.tap(find.text('Practice').first);
    await tester.pumpAndSettle();
    expect(find.byKey(questionOnProblemsPageKey), findsOneWidget);
  });

  for (final useKeyboard in [false, true]) {
    testWidgets(
      'Submit visible answer via ${useKeyboard ? 'keyboard' : 'button'}',
      (tester) async {
        final model = await launch(tester);
        await tester.enterText(find.byType(TextField), '15');
        if (useKeyboard) {
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          await tester.tap(find.byKey(checkAnswerButtonKey));
        }
        await tester.pumpAndSettle();
        expect(model.history.single.correct, isTrue);
        expect(find.text('You got it!'), findsOneWidget);
        await tester.tap(find.byKey(nextQuestionButtonKey));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
        await tester.tap(find.byKey(checkAnswerButtonKey));
        await tester.pumpAndSettle();
        expect(model.history, hasLength(1));
        expect(find.text('Enter a number first.'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Draft survives navigation and results distinguish skipped answers',
    (tester) async {
      final model = await launch(tester);
      await tester.enterText(find.byType(TextField), '42');
      await tester.tap(find.text('My answers').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practice').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '42',
      );
      await tester.tap(find.byKey(nextQuestionButtonKey));
      await tester.pumpAndSettle();
      expect(model.history.length, 1);
      await tester.tap(find.text('My answers').last);
      await tester.pumpAndSettle();
      expect(find.text('Skipped'), findsOneWidget);
    },
  );

  for (final width in [390.0, 1000.0]) {
    testWidgets('Results at width $width show the first answer', (
      tester,
    ) async {
      final model = await launch(tester, size: Size(width, 900));
      model.setDraftInput('14');
      model.submitAnswer();
      model.setDraftInput('15');
      model.submitAnswer();
      model.setCurrentPage(1);
      await tester.pumpAndSettle();
      expect(find.text('1 question completed.'), findsOneWidget);
      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('Your answer: 14.0'), findsOneWidget);
      expect(find.text('Expected answer: 15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Short viewport and keyboard inset keep practice usable', (
    tester,
  ) async {
    final model = await launch(
      tester,
      size: const Size(390, 500),
      scale: 2,
      keyboardInset: 180,
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('You got it!'), findsOneWidget);
    await tester.ensureVisible(find.byKey(nextQuestionButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(nextQuestionButtonKey));
    await tester.pumpAndSettle();
    expect(model.history.length, 1);
    expect(tester.takeException(), isNull);
  });

  group('hints', () {
    const steps = [
      'Break 12 into 10 + 2 and 3 into 3.',
      'Add matching places: 10 + 0 = 10; 2 + 3 = 5.',
      'Combine the parts: 10 + 5 = 15.',
    ];

    int visibleSteps() =>
        steps.where((step) => find.text(step).evaluate().isNotEmpty).length;

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    Future<void> check(WidgetTester tester, String answer) async {
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), answer);
      await tapKey(tester, checkAnswerButtonKey);
    }

    Future<MathTesterModel> launchNarrow(WidgetTester tester) => launch(
      tester,
      size: const Size(320, 500),
      scale: 2,
      keyboardInset: 180,
    );

    testWidgets('criterion 7: steps reveal one at a time', (tester) async {
      final model = await launchNarrow(tester);
      expect(model.steps, steps);
      expect(visibleSteps(), 0);
      expect(find.text('Let’s work it out'), findsNothing);
      expect(find.byKey(nextStepButtonKey), findsNothing);

      await tapKey(tester, hintButtonKey);
      expect(visibleSteps(), 1);
      expect(find.text(steps[0]), findsOneWidget);
      expect(find.text('Let’s work it out'), findsOneWidget);
      expect(find.byKey(hintButtonKey), findsNothing);

      await tapKey(tester, nextStepButtonKey);
      expect(visibleSteps(), 2);
      // The final step states the answer and needs a valid check first.
      expect(find.byKey(nextStepButtonKey), findsNothing);
      expect(find.text(steps.last), findsNothing);

      await check(tester, '15');
      expect(find.text('You got it!'), findsOneWidget);
      expect(visibleSteps(), 2);
      await tapKey(tester, nextStepButtonKey);
      expect(visibleSteps(), 3);
      expect(find.text(steps.last), findsOneWidget);
      expect(find.byKey(nextStepButtonKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('criterion 8: a wrong first check without hints shows 1 step', (
      tester,
    ) async {
      await launchNarrow(tester);
      await check(tester, '14');
      expect(find.text('Not quite. Try another answer.'), findsOneWidget);
      expect(visibleSteps(), 1);
      expect(find.text(steps[0]), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('criterion 8: a wrong first check keeps 2 opened steps', (
      tester,
    ) async {
      await launchNarrow(tester);
      await tapKey(tester, hintButtonKey);
      await tapKey(tester, nextStepButtonKey);
      await check(tester, '14');
      expect(find.text('Not quite. Try another answer.'), findsOneWidget);
      expect(visibleSteps(), 2);
      expect(find.text(steps.last), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Reduced motion suppresses feedback animation', (tester) async {
    await launch(tester, disableAnimations: true);
    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.byKey(checkAnswerButtonKey));
    await tester.pumpAndSettle();
    final feedback = find.ancestor(
      of: find.text('You got it!'),
      matching: find.byType(AnimatedSwitcher),
    );
    expect(feedback, findsOneWidget);
    expect(tester.widget<AnimatedSwitcher>(feedback).duration, Duration.zero);
  });

  testWidgets('Practice controls meet 48px touch targets', (tester) async {
    await launch(tester, size: const Size(390, 844));
    for (final finder in [
      find.byKey(checkAnswerButtonKey),
      find.byKey(nextQuestionButtonKey),
      find.byKey(hintButtonKey),
      find.byType(TextField),
      ...find
          .byType(FilterChip)
          .evaluate()
          .map((chip) => find.byWidget(chip.widget)),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  for (final width in [320.0, 390.0, 600.0, 768.0, 800.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Responsive $width at text scale $scale', (tester) async {
        final model = await launch(
          tester,
          size: Size(width, 900),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        model.generateNextProblem();
        model.setCurrentPage(1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

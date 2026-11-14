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

  testWidgets('Wrong answers show steps and correct answers offer them', (
    tester,
  ) async {
    await launch(
      tester,
      size: const Size(320, 500),
      scale: 2,
      keyboardInset: 180,
    );
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '14');
    await tester.ensureVisible(find.byKey(checkAnswerButtonKey));
    await tester.tap(find.byKey(checkAnswerButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Let’s work it out'), findsOneWidget);
    expect(find.textContaining('Combine the parts: 10 + 5 = 15.'), findsOne);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '15');
    await tester.ensureVisible(find.byKey(checkAnswerButtonKey));
    await tester.tap(find.byKey(checkAnswerButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('You got it!'), findsOneWidget);
    expect(find.text('Let’s work it out'), findsNothing);

    await tester.ensureVisible(find.text('Show steps'));
    await tester.tap(find.text('Show steps'));
    await tester.pumpAndSettle();
    expect(find.text('Let’s work it out'), findsOneWidget);
    expect(find.textContaining('Combine the parts: 10 + 5 = 15.'), findsOne);

    await tester.ensureVisible(find.text('Hide steps'));
    await tester.tap(find.text('Hide steps'));
    await tester.pumpAndSettle();
    expect(find.text('Let’s work it out'), findsNothing);
    expect(tester.takeException(), isNull);
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
      find.byType(TextField),
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

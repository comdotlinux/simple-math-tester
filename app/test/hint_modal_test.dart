import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/figure_view.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/labels.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';
import 'package:simple_math_tester/solution_steps.dart';

import 'en.dart';
import 'hint_style_test.dart' show everyProblemByFamily, longestByFamily;

/// The hint after a wrong answer: Try again or Show a hint, then the steps
/// in the app's own modal. Measured with the bundled Roboto, because the
/// test font draws every glyph a full em wide.
void main() {
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(family['family'] as String);
      for (final font in (family['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  const sum = ArithmeticProblem(48, 27, OperationType.plus, 75);
  final geometry = OperationType.geometry.source as GeometrySource;
  final perimeter = geometry.build(
    OperationType.geometry,
    'rectanglePerimeter',
    [5, 3],
  )!;
  final equation = (OperationType.algebra.source as AlgebraSource)
      .problems(OperationType.algebra, 1)
      .first;

  Future<MathTesterModel> launch(
    WidgetTester tester, {
    Problem problem = sum,
    Size size = const Size(360, 640),
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool usePad = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: problem,
      progress: Progress(
        tier: Tier.easy,
        seenKinds: [for (final kind in OperationType.values) kind.name],
      ),
    );
    addTearDown(model.dispose);
    // A fresh page for each launch in one test.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            platformBrightness: brightness,
          ),
          child: const MathTesterApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (usePad) {
      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
    }
    return model;
  }

  Future<void> answer(WidgetTester tester, String text) async {
    final model = tester
        .element(find.byKey(problemsPageKey))
        .read<MathTesterModel>();
    model.setDraftInput(text);
    model.submitAnswer();
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  TextField field(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));
  bool fieldFocused(WidgetTester tester) => field(tester).focusNode!.hasFocus;
  int shownSteps(MathTesterModel model) => model.steps
      .where((step) => find.text(step(en)).evaluate().isNotEmpty)
      .length;
  final modal = find.byKey(solutionStepsKey);
  Finder revealLabel(String label) => find.descendant(
    of: find.byKey(revealStepButtonKey),
    matching: find.text(label),
  );

  testWidgets('a wrong answer shows no hint, only Try again and Show a hint', (
    tester,
  ) async {
    final model = await launch(tester);
    await answer(tester, '65');
    expect(model.answerCorrect, isFalse);
    expect(find.text('Not quite. Try another answer.'), findsOneWidget);
    expect(shownSteps(model), 0);
    expect(modal, findsNothing);
    expect(find.byKey(tryAgainButtonKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(hintButtonKey),
        matching: find.text('Show a hint'),
      ),
      findsOneWidget,
    );
    // Try again is the main action: a filled button.
    expect(
      find.ancestor(
        of: find.text('Try again'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Try again puts the focus back in the field with the answer '
      'selected', (tester) async {
    final model = await launch(tester, size: const Size(1280, 900));
    await answer(tester, '65');
    // As a keyboard player does: focus on the button, Enter.
    Focus.of(
      tester.element(
        find.descendant(
          of: find.byKey(tryAgainButtonKey),
          matching: find.text('Try again'),
        ),
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    expect(fieldFocused(tester), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fieldFocused(tester), isTrue);
    final controller = field(tester).controller!;
    expect(controller.text, '65');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    // The next answer replaces it, and the choices go with the result.
    tester.testTextInput.enterText('75');
    await tester.pumpAndSettle();
    expect(find.byKey(tryAgainButtonKey), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(model.answerCorrect, isTrue);
  });

  testWidgets('open, step through, show the answer, close and reopen', (
    tester,
  ) async {
    final model = await launch(tester);
    final steps = [for (final step in model.steps) step(en)];
    expect(steps.length, greaterThanOrEqualTo(3));
    await answer(tester, '65');
    expect(model.hintOpened, isFalse);

    await tapKey(tester, hintButtonKey);
    expect(modal, findsOneWidget);
    expect(model.hintOpened, isTrue);
    expect(model.answerShown, isFalse);
    expect(shownSteps(model), 1);
    expect(find.text(steps.first), findsOneWidget);
    expect(fieldFocused(tester), isFalse, reason: 'focus is in the modal');

    while (model.revealedSteps < steps.length - 1) {
      expect(revealLabel('Next step'), findsOneWidget);
      await tapKey(tester, revealStepButtonKey);
    }
    expect(find.text(steps.last), findsNothing);
    expect(revealLabel('Show the answer'), findsOneWidget);
    await tapKey(tester, revealStepButtonKey);
    expect(find.text(steps.last), findsOneWidget);
    expect(model.answerShown, isTrue);
    expect(find.byKey(revealStepButtonKey), findsNothing);
    // The in-memory attempt carries the hint use made after its check.
    expect(model.history.last.hintOpened, isTrue);
    expect(model.history.last.answerShown, isTrue);
    expect(model.history.last.hintsUsed, 0);

    await tapKey(tester, hintCloseKey);
    expect(modal, findsNothing);
    expect(fieldFocused(tester), isTrue);
    expect(shownSteps(model), 0, reason: 'nothing on the page');

    await tapKey(tester, hintButtonKey);
    expect(shownSteps(model), steps.length, reason: 'progress is kept');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape and the dimmed area close the modal, focus back on the '
      'field', (tester) async {
    await launch(tester, size: const Size(1280, 900));
    await answer(tester, '65');
    await tapKey(tester, hintButtonKey);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(modal, findsNothing);
    expect(fieldFocused(tester), isTrue);

    await tapKey(tester, hintButtonKey);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(modal, findsNothing);
    expect(fieldFocused(tester), isTrue);
  });

  testWidgets('Tab stays inside the modal', (tester) async {
    await launch(tester, size: const Size(1280, 900));
    await answer(tester, '65');
    await tapKey(tester, hintButtonKey);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.descendant(of: modal, matching: find.byWidget(focused.widget)),
        findsWidgets,
        reason: 'tab $i',
      );
    }
  });

  testWidgets('before a check the hint opens from the quiet Hint button and '
      'keeps the answer back', (tester) async {
    final model = await launch(tester);
    expect(
      find.descendant(
        of: find.byKey(hintButtonKey),
        matching: find.text('Hint'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(tryAgainButtonKey), findsNothing);
    await tapKey(tester, hintButtonKey);
    while (find.byKey(revealStepButtonKey).evaluate().isNotEmpty) {
      await tapKey(tester, revealStepButtonKey);
    }
    expect(model.revealedSteps, model.steps.length - 1);
    expect(find.text(model.steps.last(en)), findsNothing);
    expect(
      find.text('Check an answer first. Then you can see the answer.'),
      findsOneWidget,
    );
    expect(model.answerShown, isFalse);
  });

  testWidgets('a correct answer after a hint advances as before: half the XP', (
    tester,
  ) async {
    final model = await launch(tester);
    await tapKey(tester, hintButtonKey);
    await tapKey(tester, hintCloseKey);
    await answer(tester, '75');
    expect(model.answerCorrect, isTrue);
    // Level 1, no combo: half of 1 × 10.
    expect(model.game.xp, 5);
    expect(model.history.single.hintsUsed, 1);
    expect(model.history.single.hintOpened, isTrue);
    expect(model.history.single.answerShown, isFalse);
    await tapKey(tester, nextQuestionButtonKey);
    expect(model.current, isNot(same(sum)));
    expect(model.hintOpened, isFalse);
    expect(model.answerShown, isFalse);
    expect(model.revealedSteps, 0);
  });

  testWidgets('a hint after a wrong first check changes no reward', (
    tester,
  ) async {
    final model = await launch(tester);
    await answer(tester, '65');
    await tapKey(tester, hintButtonKey);
    await tapKey(tester, hintCloseKey);
    await answer(tester, '75');
    expect(model.answerCorrect, isTrue);
    expect(model.game.xp, 0, reason: 'only the first check counts');
    expect(model.history, hasLength(1));
    expect(model.history.single.correct, isFalse);
  });

  testWidgets('a sprint has no hint', (tester) async {
    final model = await launch(tester);
    await tapKey(tester, sprintButtonKey);
    expect(find.byKey(hintButtonKey), findsNothing);
    model.openHint();
    expect(model.hintOpened, isFalse);
  });

  testWidgets('an equation hint shows in the modal under the question', (
    tester,
  ) async {
    final model = await launch(tester, problem: equation);
    await answer(tester, '999');
    await tapKey(tester, hintButtonKey);
    expect(find.text(model.steps.first(en)), findsOneWidget);
    // The question stays at the top of the modal.
    expect(
      find.descendant(
        of: modal,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.semanticsLabel == 'Math question: ${equation.spoken(en)}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(hintFigureKey), findsNothing);
  });

  testWidgets('the figure in the modal highlights the newest step', (
    tester,
  ) async {
    final model = await launch(tester, problem: perimeter);
    await answer(tester, '15');
    await tapKey(tester, hintButtonKey);
    final hints = figureHint(perimeter.figure);
    for (var shown = 1; shown <= model.steps.length; shown++) {
      expect(model.revealedSteps, shown);
      final figure = find.descendant(
        of: modal,
        matching: find.byKey(hintFigureKey),
      );
      expect(figure, findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: figure,
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as FigurePainter;
      expect(painter.highlight!.edges, hints[shown - 1].parts.edges);
      expect(painter.highlight!.outline, hints[shown - 1].parts.outline);
      if (shown < model.steps.length) {
        await tapKey(tester, revealStepButtonKey);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone gets a panel anchored to the bottom, a wide screen a '
      'centred card', (tester) async {
    await launch(tester);
    await answer(tester, '65');
    await tapKey(tester, hintButtonKey);
    var rect = tester.getRect(modal);
    expect(rect.bottom, moreOrLessEquals(640 - 13, epsilon: 1));
    expect(rect.height, greaterThan(640 * .8));

    await launch(tester, size: const Size(1280, 900));
    await answer(tester, '65');
    await tapKey(tester, hintButtonKey);
    rect = tester.getRect(modal);
    expect(rect.width, lessThanOrEqualTo(560));
    expect(rect.center.dx, moreOrLessEquals(640, epsilon: 1));
    for (final key in [revealStepButtonKey, hintCloseKey]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('the report flag stays reachable beside the choices', (
    tester,
  ) async {
    await launch(tester, problem: equation);
    await answer(tester, '999');
    final flag = tester.getRect(find.byKey(reportFlagKey));
    for (final key in [tryAgainButtonKey, hintButtonKey]) {
      expect(
        tester.getRect(find.byKey(key)).overlaps(flag),
        isFalse,
        reason: '$key',
      );
    }
    await tapKey(tester, reportFlagKey);
    expect(find.byKey(reportDialogKey), findsOneWidget);
  });

  // Found in #155: Next beside the docked feedback left the message a few
  // words a line, and the dock grew taller than the page.
  for (final brightness in Brightness.values) {
    for (final usePad in [false, true]) {
      testWidgets('no overflow after a wrong answer at 320x568, text scale '
          '2, ${usePad ? 'pad' : 'keyboard'}, ${brightness.name}', (
        tester,
      ) async {
        for (final problem in [sum, equation, perimeter]) {
          await launch(
            tester,
            problem: problem,
            size: const Size(320, 568),
            scale: 2,
            brightness: brightness,
            usePad: usePad,
          );
          await answer(tester, '999');
          expect(tester.takeException(), isNull, reason: problem.question);
          expect(find.byKey(nextQuestionButtonKey), findsOneWidget);
          expect(find.byKey(tryAgainButtonKey), findsOneWidget);
        }
      });
    }
  }

  group('the longest hint of each family', () {
    final longest = longestByFamily(everyProblemByFamily());
    final random = Random(1);
    final arithmetic = [
      for (final kind in arithmeticKinds)
        for (var i = 0; i < 50; i++) kind.generate(random, kind.highestLevel),
    ];
    final problems = {
      ...longest,
      'arithmetic': arithmetic.reduce(
        (a, b) =>
            solutionSteps(a).map((s) => s(en)).join().length >=
                solutionSteps(b).map((s) => s(en)).join().length
            ? a
            : b,
      ),
    };
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      for (final scale in const [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets('fits the modal at ${size.width.toInt()}x'
              '${size.height.toInt()}, text $scale, ${brightness.name}', (
            tester,
          ) async {
            for (final MapEntry(key: family, value: problem)
                in problems.entries) {
              final model = await launch(
                tester,
                problem: problem,
                size: size,
                scale: scale,
                brightness: brightness,
              );
              await answer(tester, '999');
              expect(tester.takeException(), isNull, reason: family);
              await tapKey(tester, hintButtonKey);
              while (model.canRevealStep) {
                await tapKey(tester, revealStepButtonKey);
              }
              expect(tester.takeException(), isNull, reason: family);
              expect(
                find.text(model.steps.last(en)),
                findsOneWidget,
                reason: family,
              );
              await tapKey(tester, hintCloseKey);
            }
          });
        }
      }
    }
  });
}

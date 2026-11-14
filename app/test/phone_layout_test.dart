import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

/// What a phone player sees after a check with the pad docked. Measured
/// with the bundled Roboto, because the test font draws every glyph a full
/// em wide and would wrap text that fits on a device.
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

  final pad = find.byKey(numberPadKey);
  Finder padKey(String label) => find.descendant(
    of: pad,
    matching: find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    ),
  );

  void expectOnScreen(WidgetTester tester, Finder finder, Size screen) {
    final rect = tester.getRect(finder);
    var shown = rect.intersect(Offset.zero & screen);
    final element = finder.evaluate().single;
    if (Scrollable.maybeOf(element) case final scrollable?) {
      final view = scrollable.context.findRenderObject()! as RenderBox;
      shown = shown.intersect(view.localToGlobal(Offset.zero) & view.size);
    }
    expect(
      shown.width * shown.height,
      moreOrLessEquals(rect.width * rect.height, epsilon: .5),
      reason: '$finder: $shown of $rect',
    );
  }

  for (final brightness in Brightness.values) {
    for (final size in const [Size(320, 568), Size(360, 640), Size(390, 844)]) {
      final tag =
          '${size.width.toInt()}x${size.height.toInt()}, '
          '${brightness.name} theme';

      Future<MathTesterModel> launchAndCheck(
        WidgetTester tester,
        String answer,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = MathTesterModel(
          initialProblem: const Problem(48, 27, OperationType.plus, 75),
          progress: Progress(tier: Tier.easy),
        );
        addTearDown(model.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: model,
            child: MediaQuery(
              data: MediaQueryData(size: size, platformBrightness: brightness),
              child: const MathTesterApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(pad, findsOneWidget);
        expect(
          Scrollable.maybeOf(tester.element(pad)),
          isNull,
          reason: 'the pad is docked, outside the page scroll',
        );
        for (final digit in answer.split('')) {
          await tester.tap(padKey(digit));
          await tester.pump();
        }
        await tester.tap(find.byKey(checkAnswerButtonKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        return model;
      }

      List<Finder> mustShow(String answer, String feedback) => [
        find.byKey(questionOnProblemsPageKey),
        find.byType(TextField),
        find.descendant(
          of: find.byType(TextField),
          matching: find.text(answer),
        ),
        find.text(feedback),
        find.byKey(nextQuestionButtonKey),
        find.byKey(checkAnswerButtonKey),
      ];

      testWidgets('after a wrong check with a hint open, the question, the '
          'answer, the feedback and Next are on screen at $tag', (
        tester,
      ) async {
        final model = await launchAndCheck(tester, '65');
        expect(model.revealedSteps, 1);
        expect(find.text('Let’s work it out'), findsOneWidget);
        for (final finder in mustShow('65', 'Not quite. Try another answer.')) {
          expectOnScreen(tester, finder, size);
        }
        expect(find.byKey(nextQuestionButtonKey), findsOneWidget);
        await tester.tap(find.byKey(nextQuestionButtonKey));
        await tester.pumpAndSettle();
        expect(model.history, hasLength(1));
        expect(find.text('Not quite. Try another answer.'), findsNothing);
        expect(find.byKey(nextQuestionButtonKey), findsOneWidget);
      });

      testWidgets('with two and with every hint step open, the question, '
          'the answer, the feedback and Next stay on screen at $tag', (
        tester,
      ) async {
        final model = await launchAndCheck(tester, '65');
        // As a player reads the steps: tap Next step, then scroll to it.
        Future<void> revealStep() async {
          await tester.ensureVisible(find.byKey(revealStepButtonKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(revealStepButtonKey));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(revealStepButtonKey));
          await tester.pumpAndSettle();
        }

        void expectQuestionShown() {
          // The card's question, or the dock's copy once the card scrolls
          // away.
          final pinned = find.byKey(pinnedQuestionKey);
          final question = pinned.evaluate().isEmpty
              ? find.byKey(questionOnProblemsPageKey)
              : pinned;
          expect(tester.widget<Text>(question).data, '48 + 27');
          expectOnScreen(tester, question, size);
          for (final finder in mustShow(
            '65',
            'Not quite. Try another answer.',
          ).skip(1)) {
            expectOnScreen(tester, finder, size);
          }
        }

        await revealStep();
        expect(model.revealedSteps, 2);
        expectQuestionShown();
        while (model.canRevealStep) {
          await revealStep();
        }
        expect(model.revealedSteps, model.steps.length);
        expectQuestionShown();
        expect(tester.takeException(), isNull);
      });

      testWidgets('after a correct check, the question, the answer, the '
          'feedback and Next are on screen at $tag', (tester) async {
        await launchAndCheck(tester, '75');
        for (final finder in mustShow('75', 'You got it!')) {
          expectOnScreen(tester, finder, size);
        }
      });
    }
  }
}

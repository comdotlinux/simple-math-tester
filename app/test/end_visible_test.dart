import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

/// While practising, End and the menu are on screen without any scroll:
/// not under the header, not under the docked pad or field, not under the
/// system keyboard (issue #200). Measured with the bundled Roboto.
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

  final geometry = OperationType.geometry.source as GeometrySource;
  final pad = find.byKey(numberPadKey);
  final field = find.byType(TextField);
  // A phone's number keyboard, as in phone_layout_test.dart.
  const inset = 260.0;

  Future<void> launch(
    WidgetTester tester, {
    required Size size,
    required double scale,
    required bool usePad,
    String? language,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    if (!usePad) tester.view.viewInsets = const FakeViewPadding(bottom: inset);
    addTearDown(tester.view.reset);
    final model = MathTesterModel(
      // The owner's case: a figure, the tallest kind of question card.
      initialProblem: geometry.build(
        OperationType.geometry,
        'rectanglePerimeter',
        [5, 3],
      ),
      progress: Progress(
        tier: Tier.easy,
        language: language,
        selectedOperations: {OperationType.geometry},
        seenKinds: [for (final k in OperationType.values) k.name],
      ),
    );
    addTearDown(model.dispose);
    model.startPractice();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: usePad ? 0 : inset),
          ),
          child: const MathTesterApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (pad.evaluate().isNotEmpty != usePad) {
      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
    }
    expect(pad, usePad ? findsOneWidget : findsNothing);
  }

  Future<void> answerWrong(WidgetTester tester, bool usePad) async {
    if (usePad) {
      // Too short to dock, the pad sits under the field in the page.
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pump();
      }

      for (final d in ['1', '5']) {
        await tap(
          find.descendant(of: pad, matching: find.byKey(padDigitKey(d))),
        );
      }
      await tap(find.byKey(checkAnswerButtonKey));
    } else {
      tester.testTextInput.enterText('15');
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(tryAgainButtonKey), findsOneWidget);
  }

  void expectEndAndMenuShown(WidgetTester tester, Size size, bool usePad) {
    final screen =
        Offset.zero & Size(size.width, size.height - (usePad ? 0 : inset));
    final hud = tester.getRect(find.byKey(hudKey));
    // The docked pad, or the docked field above it or above the keyboard.
    final docked = [
      if (usePad && Scrollable.maybeOf(tester.element(pad)) == null) pad,
      if (Scrollable.maybeOf(tester.element(field)) == null) field,
    ];
    final pinned = find.byKey(pinnedQuestionKey);
    for (final key in [endPracticeButtonKey, settingsButtonKey]) {
      final finder = find.byKey(key);
      final rect = tester.getRect(finder);
      expect(
        screen.intersect(rect),
        rect,
        reason: '$key $rect on the screen $screen',
      );
      // In the page, or repeated over its top once the page scrolls.
      if (Scrollable.maybeOf(tester.element(finder)) case final scrollable?) {
        final view = scrollable.context.findRenderObject()! as RenderBox;
        final shown = view.localToGlobal(Offset.zero) & view.size;
        expect(shown.intersect(rect), rect, reason: '$key in $shown');
      }
      expect(rect.top, greaterThanOrEqualTo(hud.bottom), reason: '$key');
      expect(rect.shortestSide, greaterThanOrEqualTo(48), reason: '$key');
      for (final other in [
        ...docked,
        if (pinned.evaluate().isNotEmpty) pinned,
      ]) {
        final overlap = rect.intersect(tester.getRect(other));
        expect(
          overlap.width <= 0 || overlap.height <= 0,
          isTrue,
          reason: '$key overlaps $other',
        );
      }
    }
    final menu = tester.getRect(find.byKey(settingsButtonKey));
    final end = tester.getRect(find.byKey(endPracticeButtonKey));
    expect(menu.center.dx, lessThan(end.center.dx), reason: 'menu left');
    // End stays far from Check.
    final check = tester.getRect(find.byKey(checkAnswerButtonKey));
    expect(check.top - end.bottom, greaterThan(48));
  }

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(411, 874),
    Size(1280, 900),
  ]) {
    for (final scale in const [1.0, 1.15, 1.3, 2.0]) {
      for (final usePad in const [true, false]) {
        final tag =
            '${size.width.toInt()}x${size.height.toInt()}, text $scale, '
            '${usePad ? 'pad' : 'keyboard'}';
        testWidgets('End and the menu are on screen after Start and after a '
            'wrong answer at $tag', (tester) async {
          await launch(tester, size: size, scale: scale, usePad: usePad);
          expectEndAndMenuShown(tester, size, usePad);
          await answerWrong(tester, usePad);
          expectEndAndMenuShown(tester, size, usePad);
          // One Next only: the pad's big key, or one on the page.
          expect(
            find.text('Next').evaluate().length +
                find.text('Next question').evaluate().length,
            1,
          );
          if (usePad) {
            expect(
              find.descendant(
                of: pad,
                matching: find.byKey(nextQuestionButtonKey),
              ),
              findsOneWidget,
            );
          }
        });
      }
    }
  }

  testWidgets('a figure prompt keeps its word and "?" together on the '
      'smallest phone at text 2', (tester) async {
    await launch(tester, size: const Size(320, 568), scale: 2, usePad: false);
    final prompt = tester.renderObject<RenderParagraph>(
      find.text('Perimeter?'),
    );
    final lines = prompt
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 'Perimeter?'.length),
        )
        .map((box) => box.top)
        .toSet();
    expect(lines, hasLength(1));
  });

  // Overflow is reported as an error, which fails the test.
  for (final locale in AppLocalizations.supportedLocales) {
    final code = locale.toString();
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      for (final usePad in const [true, false]) {
        testWidgets('$code ${size.width.toInt()}x${size.height.toInt()} '
            'text x2 ${usePad ? 'pad' : 'keyboard'}: End and the menu are '
            'on screen', (tester) async {
          await launch(
            tester,
            size: size,
            scale: 2,
            usePad: usePad,
            language: code,
          );
          expectEndAndMenuShown(tester, size, usePad);
          await answerWrong(tester, usePad);
          expectEndAndMenuShown(tester, size, usePad);
        });
      }
    }
  }
}

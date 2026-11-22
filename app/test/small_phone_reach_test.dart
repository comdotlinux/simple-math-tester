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

/// On the smallest phone (320x640, the Android emulator's screen), after a
/// wrong answer, a child can scroll Show a hint and Report to where a tap
/// reaches them: not under the pinned End header, not under the dock
/// (issue #205). With the pad and with the system keyboard up.
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
  const size = Size(320, 640);
  for (final inset in const [0.0, 260.0]) {
    for (final usePad in const [true, false]) {
      if (usePad && inset > 0) continue;
      final tag = usePad ? 'pad' : 'keyboard $inset';
      testWidgets('after a wrong answer Show a hint and Report take a tap '
          'at 320x640, $tag', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final model = MathTesterModel(
          // A figure, the tallest card, and reportable.
          initialProblem: geometry.build(
            OperationType.geometry,
            'rectanglePerimeter',
            [5, 3],
          ),
          progress: Progress(
            tier: Tier.easy,
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
                viewInsets: EdgeInsets.only(bottom: inset),
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
        model
          ..setDraftInput('15')
          ..submitAnswer();
        await tester.pumpAndSettle();
        expect(model.answerCorrect, isFalse);

        for (final key in [hintButtonKey, reportFlagKey]) {
          final finder = find.byKey(key);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(
            finder.hitTestable(),
            findsOneWidget,
            reason: '$key at ${tester.getRect(finder)}',
          );
        }
      });
    }
  }
}

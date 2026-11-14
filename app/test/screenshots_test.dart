import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
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

/// Writes PNGs of every screen in both themes for review. Runs only with
/// SCREENSHOT_DIR set: `SCREENSHOT_DIR=/some/dir flutter test
/// test/screenshots_test.dart`.
void main() {
  final dir = Platform.environment['SCREENSHOT_DIR'];
  final boundary = GlobalKey();
  final now = DateTime(2026, 11, 14, 9);
  const game = GameState(
    xp: 340,
    combo: 4,
    dailyCount: 6,
    lastActiveDate: '2026-11-14',
    lastGoalDate: '2026-11-13',
    streak: 5,
    bestStreak: 9,
    bestSprint: 70,
  );

  // Without the real fonts the test engine draws every glyph as a box.
  setUpAll(() async {
    if (dir == null) return;
    // The release build has no debug banner.
    WidgetsApp.debugAllowBannerOverride = false;
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

  Future<MathTesterModel> launch(
    WidgetTester tester,
    Size size,
    Brightness brightness, {
    Tier? tier = Tier.easy,
    StreamController<void>? ticks,
    GameState game = game,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: const Problem(48, 27, OperationType.plus, 75, level: 3),
      progress: Progress(tier: tier, game: game),
      clock: () => now,
      ticker: ticks == null ? null : () => ticks.stream,
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ChangeNotifierProvider.value(
          // A new key per model, so no state carries over between launches.
          key: ObjectKey(model),
          value: model,
          child: MediaQuery(
            data: MediaQueryData(size: size, platformBrightness: brightness),
            child: const MathTesterApp(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return model;
  }

  /// [settle] false keeps a running animation in the picture.
  Future<void> shoot(
    WidgetTester tester,
    String name, {
    bool settle = true,
  }) async {
    if (settle) await tester.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> check(WidgetTester tester, String answer) async {
    await tester.enterText(find.byType(TextField), answer);
    await tester.ensureVisible(find.byKey(checkAnswerButtonKey));
    await tester.tap(find.byKey(checkAnswerButtonKey));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final size in const [
      Size(360, 640),
      Size(360, 800),
      Size(800, 1000),
      Size(1280, 900),
    ]) {
      final tag =
          '${brightness.name}-${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('screenshots $tag', skip: dir == null, (tester) async {
        final practice = await launch(tester, size, brightness);
        // Shows a switched-off operation next to the switched-on ones.
        practice.toggleOperation(OperationType.divide);
        await shoot(tester, '$tag-1-practice');

        await tester.tap(find.byKey(keyboardSwitchKey));
        await shoot(tester, '$tag-1b-keyboard');
        await tester.tap(find.byKey(keyboardSwitchKey));
        await tester.pumpAndSettle();

        // The page itself keeps the feedback in view.
        await check(tester, '75');
        await shoot(tester, '$tag-2-correct');

        final wrong = await launch(tester, size, brightness);
        await check(tester, '65');
        wrong.revealStep();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(revealStepButtonKey));
        await shoot(tester, '$tag-3-wrong-hints');

        // One answer short of the daily goal: the next correct one bursts.
        final goal = await launch(
          tester,
          size,
          brightness,
          game: const GameState(
            xp: 340,
            dailyCount: 9,
            lastActiveDate: '2026-11-14',
          ),
        );
        goal.setDraftInput('75');
        goal.submitAnswer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 350));
        await shoot(tester, '$tag-2b-celebration', settle: false);
        await tester.pumpAndSettle();

        await launch(tester, size, brightness, tier: null);
        await shoot(tester, '$tag-4-tier-picker');

        final ticks = StreamController<void>.broadcast(sync: true);
        addTearDown(ticks.close);
        final sprint = await launch(tester, size, brightness, ticks: ticks);
        sprint.startSprint();
        await tester.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          sprint.setDraftInput(formatNumber(sprint.current.result));
          sprint.submitAnswer();
        }
        await shoot(tester, '$tag-5-sprint');

        sprint.endSprint();
        await shoot(tester, '$tag-6-sprint-result');

        final history = await launch(tester, size, brightness);
        for (final answer in ['75', 'skip', 'wrong', 'right']) {
          switch (answer) {
            case 'skip':
              history.generateNextProblem();
            case 'wrong':
              history.setDraftInput('${history.current.result + 2}');
              history.submitAnswer();
              history.generateNextProblem();
            default:
              history.setDraftInput('${history.current.result}');
              history.submitAnswer();
              history.generateNextProblem();
          }
        }
        history.setCurrentPage(1);
        await shoot(tester, '$tag-7-answers');

        final empty = await launch(tester, size, brightness);
        empty.setCurrentPage(1);
        await shoot(tester, '$tag-8-answers-empty');
      });
    }
  }
}

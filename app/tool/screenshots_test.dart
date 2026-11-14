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

/// Writes PNGs of every screen in both themes for review. A tool, not part of
/// the test suite (`flutter test` only runs `test/`); run it by hand:
/// `SCREENSHOT_DIR=/some/dir flutter test tool/screenshots_test.dart`.
void main() {
  final dir = Platform.environment['SCREENSHOT_DIR'];
  if (dir == null) {
    throw StateError(
      'Set SCREENSHOT_DIR: SCREENSHOT_DIR=/some/dir '
      'flutter test tool/screenshots_test.dart',
    );
  }
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
    // A simulated system keyboard this tall covers the bottom, drawn as a
    // plain block.
    double keyboard = 0,
    LayoutMode layout = LayoutMode.comfortable,
    List<Attempt> history = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final model = MathTesterModel(
      initialProblem: const Problem(48, 27, OperationType.plus, 75, level: 3),
      progress: Progress(
        tier: tier,
        game: game,
        layoutMode: layout,
        history: history,
      ),
      clock: () => now,
      ticker: ticks == null ? null : () => ticks.stream,
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: Stack(
          textDirection: TextDirection.ltr,
          children: [
            ChangeNotifierProvider.value(
              // A new key per model, so no state carries over between
              // launches.
              key: ObjectKey(model),
              value: model,
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  platformBrightness: brightness,
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                ),
                child: const MathTesterApp(),
              ),
            ),
            if (keyboard > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: keyboard,
                child: const ColoredBox(color: Color(0xFF9E9E9E)),
              ),
          ],
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
      // SCREENSHOT_PIXEL_RATIO=2.4 at 450x800 gives Play's 1080x1920.
      final image = await render.toImage(
        pixelRatio: double.parse(
          Platform.environment['SCREENSHOT_PIXEL_RATIO'] ?? '1',
        ),
      );
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

  /// Four answers: right, skipped, wrong, right; then [more] alternating.
  void answer(MathTesterModel model, {int more = 0}) {
    for (final answer in ['75', 'skip', 'wrong', 'right']) {
      switch (answer) {
        case 'skip':
          model.generateNextProblem();
        case 'wrong':
          model.setDraftInput('${model.current.result + 2}');
          model.submitAnswer();
          model.generateNextProblem();
        default:
          model.setDraftInput('${model.current.result}');
          model.submitAnswer();
          model.generateNextProblem();
      }
    }
    for (var i = 0; i < more; i++) {
      model.setDraftInput('${model.current.result + i % 2}');
      model.submitAnswer();
      model.generateNextProblem();
    }
  }

  void scrollAnswers(WidgetTester tester, double offset) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byKey(resultsPageKey),
          matching: find.byType(Scrollable),
        ),
      )
      .position
      .jumpTo(offset);

  // SCREENSHOT_SIZE=450x800 (with SCREENSHOT_PIXEL_RATIO=2.4) shoots only
  // that size: the Play Store phone screenshots, 1080x1920.
  final only = Platform.environment['SCREENSHOT_SIZE']?.split('x');
  for (final brightness in Brightness.values) {
    for (final size
        in only != null
            ? [Size(double.parse(only[0]), double.parse(only[1]))]
            : const [
                Size(360, 640),
                Size(412, 720),
                Size(360, 800),
                Size(800, 1000),
                Size(1280, 900),
              ]) {
      final tag =
          '${brightness.name}-${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('screenshots $tag', (tester) async {
        final practice = await launch(tester, size, brightness);
        // Shows a switched-off operation next to the switched-on ones.
        practice.toggleOperation(OperationType.divide);
        await shoot(tester, '$tag-1-practice');

        // Phones start with the system keyboard, so there this shows the pad.
        await tester.tap(find.byKey(keyboardSwitchKey));
        await shoot(tester, '$tag-1b-switched');
        await tester.tap(find.byKey(keyboardSwitchKey));
        await tester.pumpAndSettle();

        // The page itself keeps the feedback in view.
        await check(tester, '75');
        await shoot(tester, '$tag-2-correct');

        final wrong = await launch(tester, size, brightness);
        await check(tester, '65');
        // As the player sees it: one hint open, the page where it stopped.
        await shoot(tester, '$tag-3-wrong');
        wrong.revealStep();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(revealStepButtonKey));
        await shoot(tester, '$tag-3b-wrong-hints');

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
        answer(history);
        history.setCurrentPage(1);
        await shoot(tester, '$tag-7-answers');

        // Scrolled down a long list, the stats are a pinned compact bar.
        answer(history, more: 22);
        await tester.pumpAndSettle();
        scrollAnswers(tester, 1200);
        await shoot(tester, '$tag-7b-answers-scrolled');

        final empty = await launch(tester, size, brightness);
        empty.setCurrentPage(1);
        await shoot(tester, '$tag-8-answers-empty');

        await launch(tester, size, brightness);
        await tester.ensureVisible(find.byKey(settingsButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(settingsButtonKey));
        await tester.pumpAndSettle();
        await shoot(tester, '$tag-9-settings');
        await tester.ensureVisible(find.byKey(themeModeKey(ThemeMode.dark)));
        await shoot(tester, '$tag-9b-settings-theme');

        // The compact layout setting.
        const compact = LayoutMode.compact;
        // Long numbers, so the "said" part is cut short on a small phone.
        Attempt big(int lhs, int rhs, OperationType kind, int result, int? a) =>
            Attempt(
              Problem(lhs, rhs, kind, result, level: 5),
              firstAnswer: a,
              elapsedMs: 12000,
              answeredAt: now,
            );
        final dense = await launch(
          tester,
          size,
          brightness,
          layout: compact,
          history: [
            big(9876, 8765, OperationType.plus, 18641, 18651),
            big(4321, 1234, OperationType.minus, 3087, null),
            big(29, 87, OperationType.multiply, 2523, 2523),
            big(8642, 9753, OperationType.plus, 18395, 18359),
          ],
        );
        dense.toggleOperation(OperationType.divide);
        await shoot(tester, '$tag-11-compact-practice');
        dense.setCurrentPage(1);
        await shoot(tester, '$tag-11b-compact-answers');
        // The long rows just under the pinned bar.
        await tester.pumpAndSettle();
        scrollAnswers(tester, 300);
        await shoot(tester, '$tag-11b2-compact-answers-long');
        scrollAnswers(tester, 0);
        answer(dense, more: 22);
        await tester.pumpAndSettle();
        scrollAnswers(tester, 600);
        await shoot(tester, '$tag-11c-compact-answers-scrolled');
        await launch(tester, size, brightness, layout: compact);
        await tester.ensureVisible(find.byKey(settingsButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(settingsButtonKey));
        await tester.pumpAndSettle();
        await shoot(tester, '$tag-11d-compact-settings');
        await tester.ensureVisible(find.byKey(layoutModeKey(compact)));
        await shoot(tester, '$tag-11e-compact-settings-layout');

        // A phone with its own number keyboard up.
        if (size.shortestSide < 600 && size.height < 800) {
          await launch(tester, size, brightness, keyboard: 260);
          await shoot(tester, '$tag-10-system-keyboard');
          await check(tester, '65');
          await shoot(tester, '$tag-10b-system-keyboard-wrong');
          await check(tester, '75');
          await shoot(tester, '$tag-10c-system-keyboard-correct');
        }
      });
    }
  }
}

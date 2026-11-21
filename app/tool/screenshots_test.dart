import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/legal.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/report.dart';
import 'package:simple_math_tester/report_dialog.dart';
import 'package:simple_math_tester/rules.dart';

/// Writes PNGs of every screen in both themes for review. A tool, not part of
/// the test suite (`flutter test` only runs `test/`); run it by hand:
/// `SCREENSHOT_DIR=/some/dir flutter test tool/screenshots_test.dart`.
/// SCREENSHOT_LANGUAGES=de,hi shoots those languages (default: English).
void main() {
  final dir = Platform.environment['SCREENSHOT_DIR'];
  if (dir == null) {
    throw StateError(
      'Set SCREENSHOT_DIR: SCREENSHOT_DIR=/some/dir '
      'flutter test tool/screenshots_test.dart',
    );
  }
  final languages = Platform.environment['SCREENSHOT_LANGUAGES']?.split(',');
  String? language;
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
    // The test binding registers no licences: give the Licences page the
    // NOTICES that `flutter test` generates, and cache the attribution files.
    final notices = utf8.decode(
      gzip.decode((await rootBundle.load('NOTICES.Z')).buffer.asUint8List()),
    );
    final entries = [
      for (final license in notices.split('\n${'-' * 80}\n'))
        if (license.indexOf('\n\n') case final split when split >= 0)
          LicenseEntryWithLineBreaks(
            license.substring(0, split).split('\n'),
            license.substring(split + 2),
          ),
    ];
    LicenseRegistry.addLicense(() => Stream.fromIterable(entries));
    for (final (:licenseAsset, name: _, credit: _) in attributions) {
      if (licenseAsset != null) await rootBundle.loadString(licenseAsset);
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
    AppPalette palette = AppPalette.sunny,
    // Every new-kind card already seen, so only its own shot shows one.
    bool newKindCard = false,
    Problem problem = const ArithmeticProblem(
      48,
      27,
      OperationType.plus,
      75,
      level: 3,
    ),
    double scale = 1,
    ReportOutcome reportOutcome = ReportOutcome.sent,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final model = MathTesterModel(
      initialProblem: problem,
      progress: Progress(
        tier: tier,
        game: game,
        layoutMode: layout,
        history: history,
        palette: palette,
        language: language,
        seenKinds: [
          if (!newKindCard)
            for (final kind in OperationType.values) kind.name,
        ],
      ),
      clock: () => now,
      ticker: ticks == null ? null : () => ticks.stream,
      // Nothing is sent from a screenshot.
      reportClient: _ShotReports(reportOutcome),
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
                  textScaler: TextScaler.linear(scale),
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
  for (final code in languages ?? const [null]) {
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
            '${code == null ? '' : '$code-'}${brightness.name}-'
            '${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('screenshots $tag', (tester) async {
          language = code;
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
          await tester.ensureVisible(find.byKey(languageTileKey));
          await shoot(tester, '$tag-9c-settings-language');
          await tester.tap(find.byKey(languageTileKey));
          await shoot(tester, '$tag-9d-language-list');

          // The hints when the phone's touch feedback and volume are off
          // (Android).
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            deviceSettingsChannel,
            (call) async => switch (call.method) {
              'touchFeedbackEnabled' => false,
              'mediaVolume' => 0,
              _ => true,
            },
          );
          await launch(tester, size, brightness);
          await tester.ensureVisible(find.byKey(settingsButtonKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(settingsButtonKey));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(touchFeedbackHintKey));
          // Scrolled back so the Sound and Vibration switches show above it.
          await tester.ensureVisible(find.byKey(soundSwitchKey));
          await shoot(tester, '$tag-9e-settings-phone-settings-off');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            deviceSettingsChannel,
            null,
          );

          // Settings > Licences: the packages, then the other attributions.
          await launch(tester, size, brightness);
          await tester.ensureVisible(find.byKey(settingsButtonKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(settingsButtonKey));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(licencesTileKey));
          await shoot(tester, '$tag-9f-settings-licences');
          await tester.tap(find.byKey(licencesTileKey));
          await shoot(tester, '$tag-9g-licences');
          final licences = find.descendant(
            of: find.byKey(licencesPageKey),
            matching: find.byType(Scrollable),
          );
          await tester.scrollUntilVisible(
            find.text('provider'),
            200,
            scrollable: licences,
          );
          await tester.tap(find.text('provider'));
          await shoot(tester, '$tag-9h-licences-package');
          final roboto = find.text(attributions.first.name);
          await tester.scrollUntilVisible(roboto, 200, scrollable: licences);
          // The heading and the fonts near the top, the opened text below.
          await tester.drag(
            licences,
            Offset(0, 160 - tester.getTopLeft(roboto).dy),
          );
          await tester.pumpAndSettle();
          await tester.tap(roboto);
          await tester.pumpAndSettle();
          // The cached file completes on the real event loop.
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          await shoot(tester, '$tag-9i-licences-attributions');

          // Every colour theme: the practice page and the chosen swatch.
          for (final palette in AppPalette.values) {
            final themed = await launch(
              tester,
              size,
              brightness,
              palette: palette,
            );
            themed.toggleOperation(OperationType.divide);
            await shoot(tester, '$tag-12-${palette.name}-practice');
            await tester.ensureVisible(find.byKey(settingsButtonKey));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(settingsButtonKey));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byKey(paletteKey(palette)));
            await shoot(tester, '$tag-12-${palette.name}-settings-colours');
          }

          // The compact layout setting.
          const compact = LayoutMode.compact;
          // Long numbers, so the "said" part is cut short on a small phone.
          Attempt big(
            int lhs,
            int rhs,
            OperationType kind,
            int result,
            int? a,
          ) => Attempt(
            ArithmeticProblem(lhs, rhs, kind, result, level: 5),
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

        testWidgets('report screenshots $tag', (tester) async {
          language = code;
          final geometry = OperationType.geometry.source as GeometrySource;
          final rectangle = geometry.build(
            OperationType.geometry,
            'rectanglePerimeter',
            [5, 3],
          )!;
          Future<void> tap(Key key) async {
            await tester.ensureVisible(find.byKey(key));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(key));
            await tester.pumpAndSettle();
          }

          Future<void> typeShown({int offset = 0}) async {
            final l = AppLocalizations.of(
              tester.element(find.byKey(reportDialogKey)),
            );
            final word = tester
                .widget<Text>(find.byKey(reportCheckWordKey))
                .data;
            final number = checkNumbers(l).firstWhere((n) => n.$2 == word).$1;
            await tester.enterText(
              find.byKey(reportCheckFieldKey),
              '${number + offset}',
            );
          }

          for (final outcome in ReportOutcome.values) {
            final practice = await launch(
              tester,
              size,
              brightness,
              problem: rectangle,
              reportOutcome: outcome,
            );
            practice.toggleOperation(OperationType.geometry);
            await tester.pumpAndSettle();
            if (outcome == ReportOutcome.sent) {
              await shoot(tester, '$tag-16a-report-flag');
            }
            await tap(reportFlagKey);
            if (outcome == ReportOutcome.sent) {
              await shoot(tester, '$tag-16b-report-ask-a-grown-up');
            }
            await tap(reportContinueKey);
            await tap(reportOptionKey('wrongDrawing'));
            if (outcome == ReportOutcome.sent) {
              await shoot(tester, '$tag-16c-report-pick-list');
            }
            await tap(reportContinueKey);
            if (outcome == ReportOutcome.sent) {
              await shoot(tester, '$tag-16d-report-grown-up-check');
              await typeShown(offset: 1);
              await tap(reportSendKey);
              await shoot(tester, '$tag-16e-report-check-wrong');
            }
            await typeShown();
            await tap(reportSendKey);
            await shoot(
              tester,
              outcome == ReportOutcome.sent
                  ? '$tag-16f-report-sent'
                  : '$tag-16g-report-could-not-send',
            );
            await tap(reportCloseKey);
            await shoot(
              tester,
              outcome == ReportOutcome.sent
                  ? '$tag-16h-report-flag-sent'
                  : '$tag-16i-report-flag-marked',
            );
          }
          await launch(tester, size, brightness);
          await tap(settingsButtonKey);
          await tap(sendProblemReportTileKey);
          await shoot(tester, '$tag-16j-problem-report-ask');
          await tap(reportContinueKey);
          await tap(reportOptionKey('display'));
          await shoot(tester, '$tag-16k-problem-report-pick-list');
        });

        testWidgets('new kind card screenshots $tag', (tester) async {
          language = code;
          await launch(tester, size, brightness, newKindCard: true);
          await tester.ensureVisible(find.byKey(newKindCardKey));
          await shoot(tester, '$tag-14-new-kind-card');
        });

        testWidgets('algebra screenshots $tag', (tester) async {
          language = code;
          final algebra = OperationType.algebra.source as AlgebraSource;
          EquationProblem equation(String variant, int a, int b) =>
              algebra.build(OperationType.algebra, variant, [a, b])!;
          final practice = await launch(
            tester,
            size,
            brightness,
            problem: equation('missingSecondAddend', 3, 4),
          );
          practice.toggleOperation(OperationType.algebra);
          await shoot(tester, '$tag-13-algebra-practice');
          await check(tester, '5');
          practice.revealStep();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(revealStepButtonKey));
          await shoot(tester, '$tag-13b-algebra-wrong-hints');

          final level2 = await launch(
            tester,
            size,
            brightness,
            problem: equation('missingDivisor', 6, 3),
          );
          level2.toggleOperation(OperationType.algebra);
          await shoot(tester, '$tag-13d-algebra-level-2-practice');
          await check(tester, '4');
          level2.revealStep();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(revealStepButtonKey));
          await shoot(tester, '$tag-13e-algebra-level-2-hints');

          // The blank next to a minus sign: a longer line, on the baseline.
          for (final (name, variant, a, b) in [
            ('13j-algebra-minus-blank', 'missingSubtrahend', 4, 6),
            ('13k-algebra-blank-minus', 'missingMinuend', 3, 5),
          ]) {
            final minus = await launch(
              tester,
              size,
              brightness,
              problem: equation(variant, a, b),
            );
            minus.toggleOperation(OperationType.algebra);
            await shoot(tester, '$tag-$name');
          }

          // Levels 3 to 5 with the letter n, every hint step shown; level 5
          // with an answer below zero and one in tenths. The pad has the
          // minus and decimal keys whenever algebra is on.
          for (final (name, variant, params, level, wrong) in [
            ('13f-algebra-level-3', 'aTimesN', [3, 5], 3, '6'),
            ('13g-algebra-level-4', 'anPlusB', [2, 3, 4], 4, '5'),
            (
              '13h-algebra-level-5-negative',
              'anPlusBNegativeN',
              [3, 9, -2],
              5,
              '2',
            ),
            ('13i-algebra-level-5-tenths', 'anTenths', [4, 25], 5, '2'),
          ]) {
            final model = await launch(
              tester,
              size,
              brightness,
              problem: algebra.build(
                OperationType.algebra,
                variant,
                params,
                level: level,
              )!,
            );
            model.toggleOperation(OperationType.algebra);
            await shoot(tester, '$tag-$name-practice');
            await check(tester, wrong);
            while (model.canRevealStep) {
              model.revealStep();
            }
            await tester.pumpAndSettle();
            final reveal = find.byKey(revealStepButtonKey);
            if (reveal.evaluate().isNotEmpty) {
              await tester.ensureVisible(reveal);
            }
            await shoot(tester, '$tag-$name-hints');
          }

          Attempt solved(EquationProblem problem, int? answer) => Attempt(
            problem,
            firstAnswer: answer,
            elapsedMs: 6000,
            answeredAt: now,
          );
          final history = [
            solved(equation('missingSecondAddend', 3, 4), 4),
            solved(equation('missingFirstAddend', 6, 2), 3),
            solved(equation('missingSubtrahend', 5, 4), null),
            solved(equation('missingMinuend', 7, 8), 15),
          ];
          for (final layout in LayoutMode.values) {
            final answers = await launch(
              tester,
              size,
              brightness,
              layout: layout,
              history: history,
            );
            answers.setCurrentPage(1);
            await tester.pumpAndSettle();
            // The first rows, just under the stats.
            scrollAnswers(tester, 400);
            await shoot(tester, '$tag-13c-algebra-answers-${layout.name}');
          }
        });

        testWidgets('squares screenshots $tag', (tester) async {
          language = code;
          final algebra = OperationType.algebra.source as AlgebraSource;
          // One question of each square and root family, then every hint
          // step, at text scale 1 and 2.
          for (final scale in [1.0, 2.0]) {
            for (final (variant, params, level, wrong) in [
              ('missingSquare', [7], 2, '48'),
              ('missingSquareRoot', [7], 2, '6'),
              ('aSquared', [12], 3, '140'),
              ('squareRootOfC', [17], 4, '16'),
              ('nSquared', [7], 5, '6'),
              ('anSquared', [2, 5], 5, '4'),
            ]) {
              final name = '$tag-15-squares-$variant-x$scale';
              final model = await launch(
                tester,
                size,
                brightness,
                scale: scale,
                problem: algebra.build(
                  OperationType.algebra,
                  variant,
                  params,
                  level: level,
                )!,
              );
              model.toggleOperation(OperationType.algebra);
              await shoot(tester, '$name-practice');
              await check(tester, wrong);
              while (model.canRevealStep) {
                model.revealStep();
              }
              await tester.pumpAndSettle();
              final reveal = find.byKey(revealStepButtonKey);
              if (reveal.evaluate().isNotEmpty) {
                await tester.ensureVisible(reveal);
              }
              await shoot(tester, '$name-hints');
            }
          }
        });

        testWidgets('geometry screenshots $tag', (tester) async {
          language = code;
          final geometry = OperationType.geometry.source as GeometrySource;
          FigureProblem figure(String variant, List<int> params) =>
              geometry.build(OperationType.geometry, variant, params)!;
          final families = [
            figure('squarePerimeter', [7]),
            figure('rectanglePerimeter', [12, 3]),
            figure('trianglePerimeter', [12, 5, 9]),
            figure('rectangleArea', [5, 3]),
            figure('rectangleArea', [3, 10]),
          ];
          for (final scale in [1.0, 2.0]) {
            for (final layout in LayoutMode.values) {
              for (final problem in families) {
                final name =
                    '$tag-14-geometry-${problem.variant}-'
                    '${problem.params.join('x')}-${layout.name}-x$scale';
                final practice = await launch(
                  tester,
                  size,
                  brightness,
                  problem: problem,
                  layout: layout,
                  scale: scale,
                );
                practice.toggleOperation(OperationType.geometry);
                await shoot(tester, name);
              }
            }
          }
          final wrong = await launch(
            tester,
            size,
            brightness,
            problem: families[1],
          );
          await check(tester, '29');
          wrong.revealStep();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(revealStepButtonKey));
          await shoot(tester, '$tag-14b-geometry-wrong-hints');

          final history = [
            for (final (i, problem) in families.indexed)
              Attempt(
                problem,
                firstAnswer: i == 2 ? null : problem.result + i % 2,
                elapsedMs: 6000,
                answeredAt: now,
              ),
          ];
          for (final layout in LayoutMode.values) {
            final answers = await launch(
              tester,
              size,
              brightness,
              layout: layout,
              history: history,
            );
            answers.setCurrentPage(1);
            await tester.pumpAndSettle();
            scrollAnswers(tester, 400);
            await shoot(tester, '$tag-14c-geometry-answers-${layout.name}');
          }
        });

        testWidgets('geometry levels 3 to 5 screenshots $tag', (tester) async {
          language = code;
          final geometry = OperationType.geometry.source as GeometrySource;
          FigureProblem figure(String variant, List<int> params, int level) =>
              geometry.build(
                OperationType.geometry,
                variant,
                params,
                level: level,
              )!;
          // One problem of each family of levels 3 to 5.
          final families = [
            figure('squareSideFromPerimeter', [7], 3),
            figure('squareSideFromArea', [6], 3),
            figure('rectangleSideFromPerimeter', [9, 4], 3),
            figure('rectangleSideFromArea', [3, 8], 3),
            figure('triangleAngle', [50, 60], 4),
            figure('triangleAngle', [20, 125], 4),
            figure('straightAngle', [35], 4),
            figure('rightAngle', [10], 4),
            figure('rightTriangleArea', [7, 5], 5),
            figure('lShapePerimeter', [10, 7, 4, 3], 5),
            figure('lShapeArea', [8, 6, 3, 2], 5),
            figure('halvesRectanglePerimeter', [5, 12], 5),
            figure('halvesRectangleArea', [7, 4], 5),
            figure('circleCircumference', [18], 5),
            figure('circleArea', [5], 5),
          ];
          for (final scale in [1.0, 2.0]) {
            for (final problem in families) {
              final name =
                  '$tag-15-geometry-${problem.variant}-'
                  '${problem.params.join('x')}-x$scale';
              final practice = await launch(
                tester,
                size,
                brightness,
                problem: problem,
                scale: scale,
              );
              practice.toggleOperation(OperationType.geometry);
              await shoot(tester, name);
              // A wrong answer opens the first hint; the second follows.
              await check(tester, '1');
              practice.revealStep();
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.byKey(revealStepButtonKey));
              await shoot(tester, '$name-hints');
            }
          }
        });
      }
    }
  }
}

/// Answers every report with one outcome and sends nothing.
class _ShotReports implements ReportClient {
  const _ShotReports(this.outcome);

  final ReportOutcome outcome;

  @override
  Future<ReportOutcome> send(String body) async => outcome;
}

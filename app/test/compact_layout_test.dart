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
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import 'fake_store.dart';

/// The Comfortable / Compact layout setting. Measured with the bundled
/// Roboto, because the test font draws every glyph a full em wide. Answer
/// lines and semantics stay literal: the wording is the behaviour.
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

  final at = DateTime(2026, 11, 14, 9);
  // Oldest first: right, wrong, skipped, right, then a wrong one with
  // numbers long enough to fill a phone's line.
  final history = [
    Attempt(
      const Problem(80, 36, OperationType.plus, 116),
      firstAnswer: 116,
      elapsedMs: 7000,
      answeredAt: at,
    ),
    Attempt(
      const Problem(75, 46, OperationType.plus, 121),
      firstAnswer: 125,
      elapsedMs: 8000,
      answeredAt: at,
    ),
    Attempt(
      const Problem(9, 3, OperationType.minus, 6),
      firstAnswer: null,
      elapsedMs: 2000,
      answeredAt: at,
    ),
    Attempt(
      const Problem(4, 5, OperationType.multiply, 20),
      firstAnswer: 20,
      elapsedMs: 3000,
      answeredAt: at,
    ),
    Attempt(
      const Problem(9876, 8765, OperationType.plus, 18641, level: 5),
      firstAnswer: 18651,
      elapsedMs: 12000,
      answeredAt: at,
    ),
  ];

  Future<MathTesterModel> launch(
    WidgetTester tester, {
    Size size = const Size(412, 720),
    double scale = 1,
    Brightness brightness = Brightness.light,
    LayoutMode layout = LayoutMode.comfortable,
    Progress? progress,
    ProgressStore? store,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: const Problem(48, 27, OperationType.plus, 75),
      progress:
          progress ??
          Progress(tier: Tier.easy, history: history, layoutMode: layout),
      store: store,
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        // A new key per model, so no state carries over between launches.
        key: ObjectKey(model),
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
    return model;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
  }

  // The list is lazy: a row below the stats is built once scrolled to.
  Future<double> rowHeight(WidgetTester tester, int index) async {
    final row = find.byKey(historyRowKey(index));
    await tester.scrollUntilVisible(
      row,
      100,
      scrollable: find.descendant(
        of: find.byKey(resultsPageKey),
        matching: find.byType(Scrollable),
      ),
    );
    return tester.getSize(row).height;
  }

  test('the layout round trips and defaults to comfortable', () {
    for (final mode in LayoutMode.values) {
      final json = jsonDecode(
        Progress().withLayoutMode(mode).encode(),
      ) as Map<String, Object?>;
      expect(json['layoutMode'], mode.name);
      final decoded = Progress.decode(jsonEncode(json));
      expect(decoded.layoutMode, mode);
      expect(decoded.extra, isEmpty);
    }
    expect(Progress().layoutMode, LayoutMode.comfortable);
    expect(Progress.decode('{}').layoutMode, LayoutMode.comfortable);
    expect(
      Progress.decode('{"layoutMode":"cosy"}').layoutMode,
      LayoutMode.comfortable,
    );
    expect(
      () => Progress.decode('{"layoutMode":1}'),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('the layout choice is saved and restored on the next start', (
    tester,
  ) async {
    final store = FakeStore();
    final model = await launch(tester, store: store);
    await openSettings(tester);
    SegmentedButton<LayoutMode> choice() =>
        tester.widget(find.byType(SegmentedButton<LayoutMode>));
    await tester.ensureVisible(find.byKey(layoutModeKey(LayoutMode.compact)));
    await tester.pumpAndSettle();
    expect(choice().selected, {LayoutMode.comfortable});

    await tester.tap(find.byKey(layoutModeKey(LayoutMode.compact)));
    await tester.pumpAndSettle();
    expect(model.layoutMode, LayoutMode.compact);
    expect(choice().selected, {LayoutMode.compact});
    final saved = Progress.decode((await store.read(progressKey))!);
    expect(saved.layoutMode, LayoutMode.compact);

    // A restart: a new model from what the store holds.
    final loaded = await loadProgress(store);
    final restarted = await launch(tester, progress: loaded.progress);
    expect(restarted.layoutMode, LayoutMode.compact);
    restarted.setCurrentPage(1);
    await tester.pumpAndSettle();
    expect(await rowHeight(tester, 3), lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a compact row is heard with the same facts as the card', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final model = await launch(tester, layout: LayoutMode.compact);
    model.setCurrentPage(1);
    await tester.pumpAndSettle();
    void heard(int index, String label) => expect(
      find.descendant(
        of: find.byKey(historyRowKey(index)),
        matching: find.bySemanticsLabel(label),
      ),
      findsOneWidget,
    );
    heard(
      3,
      'Question 4, 4 × 5, Correct, Your answer: 20, Expected answer: 20, '
      'Time: 3 seconds',
    );
    heard(
      2,
      'Question 3, 9 − 3, Skipped, No answer entered, Expected answer: 6, '
      'Time: Not Available',
    );
    heard(
      1,
      'Question 2, 75 + 46, Incorrect, Your answer: 125, '
      'Expected answer: 121, Time: 8 seconds',
    );
    // What a sighted player reads on the rows.
    Finder inRow(int index, Finder finder) =>
        find.descendant(of: find.byKey(historyRowKey(index)), matching: finder);
    expect(
      inRow(1, find.text('75 + 46 = 121   said 125', findRichText: true)),
      findsOneWidget,
    );
    expect(
      inRow(2, find.text('9 − 3 = 6   no answer', findRichText: true)),
      findsOneWidget,
    );
    // The full words, on long press or hover.
    expect(inRow(1, find.byTooltip('You said 125')), findsOneWidget);
    expect(inRow(2, find.byTooltip('No answer entered')), findsOneWidget);
    expect(inRow(3, find.byType(Tooltip)), findsNothing);
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.3]) {
      for (final size in const [Size(360, 640), Size(412, 720)]) {
        final tag =
            '${brightness.name}, ${size.width.toInt()}x'
            '${size.height.toInt()}, text $scale';

        testWidgets('compact answers are one line each, 3x shorter, $tag', (
          tester,
        ) async {
          final comfortable = await launch(
            tester,
            size: size,
            scale: scale,
            brightness: brightness,
          );
          comfortable.setCurrentPage(1);
          await tester.pumpAndSettle();
          final card = await rowHeight(tester, 3);
          expect(tester.takeException(), isNull);

          final compact = await launch(
            tester,
            size: size,
            scale: scale,
            brightness: brightness,
            layout: LayoutMode.compact,
          );
          compact.setCurrentPage(1);
          await tester.pumpAndSettle();
          // Newest first: long wrong, right, skipped, wrong, right.
          final heights = [
            for (var i = history.length - 1; i >= 0; i--)
              await rowHeight(tester, i),
          ];
          expect(heights.toSet(), hasLength(1), reason: '$heights');
          expect(heights.first * 3, lessThanOrEqualTo(card));
          expect(tester.takeException(), isNull);
        });

        testWidgets('compact pages keep 48 px targets, $tag', (tester) async {
          await launch(
            tester,
            size: size,
            scale: scale,
            brightness: brightness,
            layout: LayoutMode.compact,
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          for (final key in [
            settingsButtonKey,
            nextQuestionButtonKey,
            sprintButtonKey,
            for (final type in OperationType.values) operationToggleKey(type),
          ]) {
            await tester.ensureVisible(find.byKey(key));
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byKey(key)).height,
              greaterThanOrEqualTo(48),
              reason: '$key',
            );
          }
          expect(tester.takeException(), isNull);

          await openSettings(tester);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          for (final key in [
            tierSettingKey(Tier.medium),
            soundSwitchKey,
            hapticsSwitchKey,
            privacyTileKey,
            impressumTileKey,
          ]) {
            await tester.ensureVisible(find.byKey(key));
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byKey(key)).height,
              greaterThanOrEqualTo(48),
              reason: '$key',
            );
          }
          final choice = find.byType(SegmentedButton<LayoutMode>);
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('the comfortable stats header is taller than the compact one', (
    tester,
  ) async {
    Future<double> header(LayoutMode layout) async {
      final model = await launch(tester, layout: layout);
      model.setCurrentPage(1);
      await tester.pumpAndSettle();
      return tester.getSize(find.byKey(statsCardKey)).height;
    }

    final comfortable = await header(LayoutMode.comfortable);
    expect(await header(LayoutMode.compact), lessThan(comfortable));
  });

  testWidgets('scrolled down, the compact pinned bar is smaller too', (
    tester,
  ) async {
    final long = [
      for (var i = 0; i < 30; i++)
        Attempt(
          Problem(i, 2, OperationType.plus, i + 2),
          firstAnswer: i + 2,
          elapsedMs: 1000,
          answeredAt: at,
        ),
    ];
    Future<double> bar(LayoutMode layout) async {
      final model = await launch(
        tester,
        progress: Progress(tier: Tier.easy, history: long, layoutMode: layout),
      );
      model.setCurrentPage(1);
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(resultsPageKey), const Offset(0, -1500));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(compactStatsKey));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
      return rect.height;
    }

    final comfortable = await bar(LayoutMode.comfortable);
    expect(await bar(LayoutMode.compact), lessThan(comfortable));
  });
}

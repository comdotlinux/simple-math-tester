import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import 'fake_store.dart';

/// The colour theme setting: a row of swatches in the settings sheet.
void main() {
  Future<MathTesterModel> launch(
    WidgetTester tester, {
    // Practice starts as after a tap on Start; false stays before it.
    bool start = true,
    Progress? progress,
    ProgressStore? store,
  }) async {
    tester.view.physicalSize = const Size(412, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: const ArithmeticProblem(48, 27, OperationType.plus, 75),
      progress: progress ?? Progress(tier: Tier.easy),
      store: store,
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        key: ObjectKey(model),
        value: model,
        child: const MathTesterApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (start) {
      model.startPractice();
      await tester.pumpAndSettle();
    }
    return model;
  }

  Color pageColour(WidgetTester tester) =>
      Theme.of(tester.element(find.byKey(problemsPageKey)))
          .scaffoldBackgroundColor;

  test('the colour theme round trips and defaults to sunny', () {
    for (final palette in AppPalette.values) {
      final json = jsonDecode(
        Progress().withPalette(palette).encode(),
      ) as Map<String, Object?>;
      expect(json['palette'], palette.name);
      final decoded = Progress.decode(jsonEncode(json));
      expect(decoded.palette, palette);
      expect(decoded.extra, isEmpty);
    }
    expect(Progress().palette, AppPalette.sunny);
    expect(Progress.decode('{}').palette, AppPalette.sunny);
    expect(Progress.decode('{"palette":"plaid"}').palette, AppPalette.sunny);
    expect(
      () => Progress.decode('{"palette":1}'),
      throwsA(isA<FormatException>()),
    );
  });

  testWidgets('choosing a swatch recolours the app and survives a restart', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = FakeStore();
    final model = await launch(tester, start: false, store: store);
    expect(pageColour(tester), AppTokens.light.surface);

    await tester.tap(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
    final ocean = find.byKey(paletteKey(AppPalette.ocean));
    await tester.ensureVisible(ocean);
    await tester.pumpAndSettle();
    for (final palette in AppPalette.values) {
      final swatch = find.byKey(paletteKey(palette));
      final size = tester.getSize(swatch);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(swatch),
        isSemantics(
          label: _name(palette),
          isButton: true,
          isSelected: palette == AppPalette.sunny,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    }
    expect(
      find.descendant(
        of: find.byKey(paletteKey(AppPalette.sunny)),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    await tester.tap(ocean);
    await tester.pumpAndSettle();
    expect(model.palette, AppPalette.ocean);
    final oceanSurface = AppTokens.of(
      AppPalette.ocean,
      Brightness.light,
    ).surface;
    expect(pageColour(tester), oceanSurface);
    expect(
      find.descendant(of: ocean, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    final saved = Progress.decode((await store.read(progressKey))!);
    expect(saved.palette, AppPalette.ocean);

    // A restart: a new model from what the store holds.
    final loaded = await loadProgress(store);
    final restarted = await launch(tester, progress: loaded.progress);
    expect(restarted.palette, AppPalette.ocean);
    expect(pageColour(tester), oceanSurface);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

String _name(AppPalette palette) =>
    '${palette.name[0].toUpperCase()}${palette.name.substring(1)}';

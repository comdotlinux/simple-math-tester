import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

/// The menu sheet (issue #179): shorter than the screen, closed by a drag
/// down or a tap outside, and holding the kinds as well as the settings.
void main() {
  Future<MathTesterModel> launch(
    WidgetTester tester, {
    Size size = const Size(360, 640),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: const ArithmeticProblem(2, 3, OperationType.plus, 5),
      progress: Progress(
        tier: Tier.easy,
        seenKinds: [for (final k in OperationType.values) k.name],
      ),
      ticker: () => const Stream.empty(),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: const MathTesterApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return model;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) =>
      tap(tester, find.byKey(settingsButtonKey));

  final sheet = find.byKey(settingsSheetKey);
  Finder inSheet(Key key) =>
      find.descendant(of: sheet, matching: find.byKey(key));

  testWidgets('the button shows the menu icon and keeps its label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    expect(
      find.descendant(
        of: find.byKey(settingsButtonKey),
        matching: find.byIcon(Icons.menu),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(settingsButtonKey)),
      isSemantics(label: 'Settings', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(1280, 900)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('at ${size.width.toInt()}x${size.height.toInt()}, text '
          'scale $scale, the page shows above the sheet and every setting is '
          'reached by scrolling', (tester) async {
        await launch(tester, size: size, scale: scale);
        await openMenu(tester);
        final rect = tester.getRect(find.byType(BottomSheet));
        expect(rect.height, lessThan(size.height));
        expect(rect.top, greaterThan(size.height * 0.15));

        for (final key in [
          for (final kind in OperationType.values) operationToggleKey(kind),
          for (final tier in Tier.values) tierSettingKey(tier),
          soundSwitchKey,
          hapticsSwitchKey,
          for (final mode in ThemeMode.values) themeModeKey(mode),
          for (final palette in AppPalette.values) paletteKey(palette),
          for (final mode in LayoutMode.values) layoutModeKey(mode),
          languageTileKey,
          privacyTileKey,
          licencesTileKey,
          impressumTileKey,
          sendProblemReportTileKey,
          reportProblemTileKey,
          appVersionTileKey,
        ]) {
          // A finger's drag up, as a child would scroll.
          for (
            var i = 0;
            i < 40 && inSheet(key).hitTestable().evaluate().isEmpty;
            i++
          ) {
            await tester.drag(sheet, const Offset(0, -80));
            await tester.pumpAndSettle();
          }
          expect(inSheet(key).hitTestable(), findsOneWidget, reason: '$key');
        }
        expect(sheet, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a drag down that starts on the list at its top closes the '
      'sheet', (tester) async {
    await launch(tester);
    await openMenu(tester);
    // A drag up scrolls the list and keeps the sheet.
    await tester.drag(sheet, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    await tester.drag(sheet, const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);

    await tester.drag(sheet, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('a tap outside the sheet closes it', (tester) async {
    await launch(tester);
    await openMenu(tester);
    final rect = tester.getRect(find.byType(BottomSheet));
    await tester.tapAt(Offset(rect.center.dx, rect.top / 2));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  // Issue #237: beside the navigation rail the sheet lines up with the page
  // column, not the whole window; a phone keeps the full-width sheet.
  testWidgets('on a wide window the sheet sits over the page column', (
    tester,
  ) async {
    await launch(tester, size: const Size(1280, 900));
    final page = tester.getRect(find.byKey(problemsPageKey));
    expect(page.left, greaterThan(0), reason: 'the rail is beside the page');
    await openMenu(tester);
    final rect = tester.getRect(find.byType(BottomSheet));
    expect(rect.center.dx, moreOrLessEquals(page.center.dx));
    expect(rect.width, lessThanOrEqualTo(page.width));

    // A tap on the dimmed rail still closes it.
    await tester.tapAt(Offset(page.left / 2, rect.top + 40));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('on a phone the sheet keeps the full width', (tester) async {
    await launch(tester);
    await openMenu(tester);
    final rect = tester.getRect(find.byType(BottomSheet));
    expect(rect.left, 0);
    expect(rect.width, 360);
  });

  testWidgets('a kind changed in the menu during practice applies from the '
      'next question and shows before Start after End', (tester) async {
    final semantics = tester.ensureSemantics();
    final model = await launch(tester);
    model.startPractice();
    await tester.pumpAndSettle();
    final question = model.current;

    await openMenu(tester);
    await tap(tester, inSheet(operationToggleKey(OperationType.algebra)));
    await tap(tester, inSheet(operationToggleKey(OperationType.plus)));
    expect(model.selectedOperations, {
      OperationType.minus,
      OperationType.multiply,
      OperationType.divide,
      OperationType.algebra,
    });
    expect(model.current, question);
    expect(model.practising, isTrue);

    // One slow drag: the list scrolls back to its top, then the sheet closes.
    await tester.timedDrag(
      sheet,
      const Offset(0, 500),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(endPracticeButtonKey));
    for (final (kind, selected) in [
      (OperationType.algebra, true),
      (OperationType.plus, false),
    ]) {
      expect(
        tester.getSemantics(find.byKey(operationToggleKey(kind))),
        isSemantics(isSelected: selected),
        reason: '$kind',
      );
    }
    semantics.dispose();
  });
}

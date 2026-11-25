import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/home_page.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

/// Right-to-left pages (issue #271, before Arabic and Urdu, #273): the page
/// mirrors, but the number pad and the equations keep their left-to-right
/// order, and nothing overflows. The app has no right-to-left language yet,
/// so the page is forced right-to-left here.
void main() {
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(family['family'] as String);
      for (final font
          in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  Future<MathTesterModel> pumpRtl(
    WidgetTester tester, {
    bool start = true,
    List<Attempt> history = const [],
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      progress: Progress(tier: Tier.easy, history: history),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(Brightness.light),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const MyHomePage(key: homePageKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (start) {
      model.startPractice();
      await tester.pumpAndSettle();
    }
    return model;
  }

  double left(WidgetTester tester, Key key) =>
      tester.getTopLeft(find.byKey(key)).dx;

  testWidgets('the number pad keeps 1-5 and 6-0 left to right', (tester) async {
    await pumpRtl(tester);
    await tester.tap(find.byKey(keyboardSwitchKey));
    await tester.pumpAndSettle();
    for (final row in [
      ['1', '2', '3', '4', '5'],
      ['6', '7', '8', '9', '0'],
    ]) {
      final lefts = [for (final d in row) left(tester, padDigitKey(d))];
      expect(lefts, [...lefts]..sort(), reason: row.join());
    }
    expect(
      left(tester, padDeleteKey),
      lessThan(left(tester, checkAnswerButtonKey)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the practice page mirrors but its equation reads left to '
      'right, after a wrong answer too', (tester) async {
    final model = await pumpRtl(tester);
    await tester.tap(find.byKey(keyboardSwitchKey));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byKey(questionOnProblemsPageKey))),
      TextDirection.ltr,
    );
    expect(
      Directionality.of(tester.element(find.byKey(numberPadKey))),
      TextDirection.rtl,
    );
    model
      ..setDraftInput('${model.current.result + 1}')
      ..submitAnswer();
    await tester.pumpAndSettle();
    expect(model.answerCorrect, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings do not overflow', (tester) async {
    await pumpRtl(tester, start: false);
    await tester.ensureVisible(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(settingsSheetKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('answers keep each equation left to right', (tester) async {
    final model = await pumpRtl(
      tester,
      history: [
        Attempt(
          const ArithmeticProblem(48, 27, OperationType.plus, 75),
          firstAnswer: 74,
          elapsedMs: 65000,
          answeredAt: DateTime(2026, 11, 14, 9),
        ),
      ],
    );
    model.setCurrentPage(1);
    // Tall, so the row is built below the stats card.
    tester.view.physicalSize = const Size(360, 1600);
    await tester.pumpAndSettle();
    final row = find.byKey(historyRowKey(0));
    expect(row, findsOneWidget);
    final islands = find.descendant(
      of: row,
      matching: find.byType(Directionality),
    );
    expect([
      for (final e in islands.evaluate()) Directionality.of(e),
    ], contains(TextDirection.ltr));
    expect(tester.takeException(), isNull);
  });
}

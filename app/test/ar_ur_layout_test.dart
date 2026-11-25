import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

/// Arabic and Urdu (issue #273): the real locale, so the page mirrors, and
/// no overflow on the key screens. Urdu is set in Nastaliq, whose lines are
/// tall: it gets no fixed text height. The texts are still English stubs
/// until the Translate workflow runs, so tall real glyphs are drawn too.
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

  Future<MathTesterModel> pumpApp(
    WidgetTester tester, {
    String? language,
    bool start = true,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(progress: Progress(tier: Tier.easy));
    addTearDown(model.dispose);
    if (language != null) model.setLanguage(language);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const MathTesterApp()),
    );
    await tester.pumpAndSettle();
    if (start) {
      model.startPractice();
      await tester.pumpAndSettle();
    }
    return model;
  }

  for (final code in ['ar', 'ur']) {
    testWidgets(
      '$code mirrors, and practice, a wrong answer and settings fit',
      (tester) async {
        final model = await pumpApp(tester, language: code);
        await tester.tap(find.byKey(keyboardSwitchKey));
        await tester.pumpAndSettle();
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
        await tester.tap(find.byKey(settingsButtonKey));
        await tester.pumpAndSettle();
        expect(find.byKey(settingsSheetKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Urdu text styles get tall lines', (tester) async {
    final urdu = buildAppTheme(Brightness.light, AppPalette.sunny, 'ur');
    final english = buildAppTheme(Brightness.light);
    expect(urdu.textTheme.displayLarge?.height, urduLineHeight);
    expect(urdu.textTheme.titleLarge?.height, urduLineHeight);
    expect(urdu.textTheme.bodyMedium?.height, urduLineHeight);
    expect(english.textTheme.displayLarge?.height, 1.05);
    expect(
      urdu.textTheme.bodyMedium?.fontFamilyFallback?.first,
      'NotoNastaliqUrdu',
    );
  });

  testWidgets('real Urdu and Arabic lines fit their tall line box', (
    tester,
  ) async {
    const lines = [
      'درست جواب! آپ نے بہت اچھا کیا',
      'غلط جواب، دوبارہ کوشش کریں',
      'مثلث کا رقبہ معلوم کریں',
      'الإجابة صحيحة، أحسنت!',
      'حاول مرة أخرى',
    ];
    final theme = buildAppTheme(Brightness.light, AppPalette.sunny, 'ur');
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  for (final style in [
                    theme.textTheme.displayLarge!,
                    theme.textTheme.headlineMedium!,
                    theme.textTheme.titleLarge!,
                    theme.textTheme.bodyMedium!,
                    theme.textTheme.labelLarge!,
                  ])
                    for (final line in lines) Text(line, style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 16 px body text in a line box of 1.9: room for the stacked marks.
    final body = tester.getSize(find.text(lines[0]).at(3));
    expect(body.height, greaterThanOrEqualTo(16 * urduLineHeight));
  });

  testWidgets('a system language of Urdu gets Nastaliq', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ur')];
    tester.platformDispatcher.localeTestValue = const Locale('ur');
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await pumpApp(tester, start: false);
    final theme = Theme.of(tester.element(find.byKey(homePageKey)));
    expect(
      theme.textTheme.bodyMedium?.fontFamilyFallback?.first,
      'NotoNastaliqUrdu',
    );
    expect(theme.textTheme.bodyMedium?.height, urduLineHeight);
  });
}

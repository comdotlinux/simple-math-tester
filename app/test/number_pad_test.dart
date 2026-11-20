import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/hundredths.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/number_pad.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

/// The number pad's minus and decimal keys. Measured with the bundled
/// Roboto, because the test font draws every glyph a full em wide.
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

  final pad = find.byKey(numberPadKey);
  final todaysKeys = [
    for (var digit = 0; digit <= 9; digit++) padDigitKey('$digit'),
    padDeleteKey,
    checkAnswerButtonKey,
  ];

  /// The pad alone at the bottom of a [width] wide screen; returns the
  /// controller it edits.
  Future<TextEditingController> pumpPad(
    WidgetTester tester, {
    bool signedDecimal = true,
    Locale locale = const Locale('en'),
    double width = 412,
    double scale = 1,
    bool dense = false,
    bool next = false,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final size = Size(width, 800);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NumberPad(
                  controller: controller,
                  onEdited: (_) {},
                  onCheck: () {},
                  dense: dense,
                  next: next,
                  signedDecimal: signedDecimal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> press(WidgetTester tester, List<Key> keys) async {
    for (final key in keys) {
      await tester.tap(find.byKey(key));
      await tester.pump();
    }
  }

  testWidgets('arithmetic-only play shows exactly today\'s keys', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(progress: Progress(tier: Tier.easy));
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const MathTesterApp()),
    );
    await tester.pumpAndSettle();
    expect(model.signedDecimalInput, isFalse);
    expect(pad, findsOneWidget);
    for (final key in todaysKeys) {
      expect(
        find.descendant(of: pad, matching: find.byKey(key)),
        findsOneWidget,
      );
    }
    expect(find.byKey(padMinusKey), findsNothing);
    expect(find.byKey(padDecimalKey), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.inputFormatters, [FilteringTextInputFormatter.digitsOnly]);
  });

  test('no arithmetic kind asks for the minus and decimal keys', () {
    for (final kind in [
      OperationType.plus,
      OperationType.minus,
      OperationType.multiply,
      OperationType.divide,
    ]) {
      expect(kind.signedDecimalAnswers, isFalse, reason: kind.name);
    }
  });

  testWidgets('the two keys join the third row; the pad keeps its rows', (
    tester,
  ) async {
    await pumpPad(tester, signedDecimal: false);
    final plain = tester.getSize(pad);
    await pumpPad(tester);
    // Three rows of the usual key height (today's Check key, two lines of
    // icon and label tall, can add a few pixels).
    expect(tester.getSize(pad).width, plain.width);
    expect(tester.getSize(pad).height, NumberPad.height(TextScaler.noScaling));
    expect(tester.getSize(pad).height, lessThanOrEqualTo(plain.height));
    for (final key in [...todaysKeys, padMinusKey, padDecimalKey]) {
      expect(find.byKey(key), findsOneWidget);
    }
    final delete = tester.getRect(find.byKey(padDeleteKey));
    final minus = tester.getRect(find.byKey(padMinusKey));
    final decimal = tester.getRect(find.byKey(padDecimalKey));
    final check = tester.getRect(find.byKey(checkAnswerButtonKey));
    // Delete stays first and Check last, on the row below the digits.
    expect(delete.top, tester.getRect(find.byKey(padDigitKey('0'))).bottom + 8);
    for (final rect in [minus, decimal, check]) {
      expect(rect.top, delete.top);
    }
    expect(delete.left, lessThan(minus.left));
    expect(minus.left, lessThan(decimal.left));
    expect(decimal.left, lessThan(check.left));
    expect(check.right, tester.getRect(find.byKey(padDigitKey('0'))).right);
  });

  testWidgets('the keys are heard as minus, decimal point and Check answer', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpPad(tester);
    expect(
      tester.getSemantics(find.byKey(padMinusKey)),
      isSemantics(label: 'Minus', isButton: true),
    );
    expect(
      tester.getSemantics(find.byKey(padDecimalKey)),
      isSemantics(label: 'Decimal point', isButton: true),
    );
    expect(
      tester.getSemantics(find.byKey(checkAnswerButtonKey)),
      isSemantics(label: 'Check answer', isButton: true),
    );
    handle.dispose();
  });

  for (final (locale, typed) in const [
    (Locale('en'), '−2.5'),
    (Locale('de'), '−2,5'),
    (Locale('pt', 'PT'), '−2,5'),
    (Locale('hi'), '−2.5'),
  ]) {
    testWidgets('$locale: the pad types $typed', (tester) async {
      final controller = await pumpPad(tester, locale: locale);
      final separator = typed.substring(2, 3);
      expect(
        find.descendant(
          of: find.byKey(padDecimalKey),
          matching: find.text(separator),
        ),
        findsOne,
      );
      await press(tester, [
        padDigitKey('2'),
        padDecimalKey,
        padDigitKey('5'),
        padMinusKey,
      ]);
      expect(controller.text, typed);
      expect(parseHundredths(controller.text), -250);
    });
  }

  testWidgets('minus toggles; a second separator and a third decimal place '
      'are refused', (tester) async {
    final controller = await pumpPad(tester);
    await press(tester, [padMinusKey]);
    expect(controller.text, '−');
    await press(tester, [padMinusKey]);
    expect(controller.text, '');
    await press(tester, [
      padDigitKey('1'),
      padDecimalKey,
      padDecimalKey,
      padDigitKey('2'),
      padDigitKey('5'),
      padDigitKey('7'),
    ]);
    expect(controller.text, '1.25');
    await press(tester, [padMinusKey]);
    expect(controller.text, '−1.25');
    expect(controller.selection, const TextSelection.collapsed(offset: 5));
    await press(tester, [padDeleteKey, padDeleteKey, padDeleteKey]);
    expect(controller.text, '−1');
    await press(tester, [padMinusKey]);
    expect(controller.text, '1');
    // The separator goes where the cursor is, also before the digits.
    controller.selection = const TextSelection.collapsed(offset: 0);
    await press(tester, [padDecimalKey]);
    expect(controller.text, '.1');
  });

  testWidgets('arithmetic pad keys still type freely', (tester) async {
    final controller = await pumpPad(tester, signedDecimal: false);
    await press(tester, [padDigitKey('1'), padDigitKey('2')]);
    expect(controller.text, '12');
    expect(find.text('Check answer'), findsOne);
  });

  // The narrowest phone in the compact (dense) layout at 200% text.
  for (final locale in AppLocalizations.supportedLocales) {
    for (final next in [false, true]) {
      testWidgets('$locale: no overflow at 320 dp and text 2.0 with the '
          'extra keys${next ? ', Next' : ''}', (tester) async {
        await pumpPad(
          tester,
          locale: locale,
          width: 320,
          scale: 2,
          dense: true,
          next: next,
        );
        expect(tester.takeException(), isNull);
        final keyHeight = NumberPad.keyHeight(
          const TextScaler.linear(2),
          dense: true,
        );
        for (final key in [
          padDigitKey('1'),
          padDeleteKey,
          padMinusKey,
          padDecimalKey,
          checkAnswerButtonKey,
        ]) {
          expect(tester.getSize(find.byKey(key)).height, keyHeight);
          expect(tester.getSize(find.byKey(key)).width, greaterThan(40));
        }
      });
    }
  }
}

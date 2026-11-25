import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/digits.dart';
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
      for (final font
          in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
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
    List<Widget>? actions,
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
          builder: (context, child) => DigitScope(
            language: digitsLanguage(locale.languageCode),
            child: child!,
          ),
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
                  actions: actions,
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

  testWidgets('pad shows native and 0-9 digits for bn and mr, 0-9 only for '
      'en and hi; a tap enters 0-9; no overflow at 360', (tester) async {
    for (final (code, native) in [
      ('bn', true),
      ('mr', true),
      ('en', false),
      ('hi', false),
    ]) {
      final controller = await pumpPad(
        tester,
        locale: Locale(code),
        width: 360,
      );
      final key = find.byKey(padDigitKey('5'));
      expect(
        find.descendant(of: key, matching: find.text('5')),
        findsOneWidget,
      );
      if (native) {
        expect(
          find.descendant(of: key, matching: find.text(localDigits('5', code))),
          findsOneWidget,
          reason: code,
        );
      }
      expect(
        find.descendant(of: key, matching: find.byType(Text)),
        findsNWidgets(native ? 2 : 1),
        reason: code,
      );
      await tester.tap(key);
      expect(controller.text, '5');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('arithmetic-only play shows exactly today\'s keys', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(progress: Progress(tier: Tier.easy));
    addTearDown(model.dispose);
    model.startPractice();
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
    expect(field.inputFormatters, [
      nativeDigitsToAscii,
      FilteringTextInputFormatter.digitsOnly,
    ]);
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

  testWidgets('geometry shows the minus and decimal keys: its level 5 has '
      'decimal answers', (tester) async {
    expect(OperationType.geometry.signedDecimalAnswers, isTrue);
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      progress: Progress(
        tier: Tier.easy,
        selectedOperations: {OperationType.geometry},
      ),
    );
    addTearDown(model.dispose);
    model.startPractice();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const MathTesterApp()),
    );
    await tester.pumpAndSettle();
    expect(model.signedDecimalInput, isTrue);
    expect(find.byKey(padMinusKey), findsOneWidget);
    expect(find.byKey(padDecimalKey), findsOneWidget);
  });

  // The page docks the pad by this height, so it must match the pad drawn.
  for (final dense in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the actions row sits above the digits, a key tall and '
          'sharing the width, dense $dense, text $scale', (tester) async {
        const first = Key('first');
        const second = Key('second');
        await pumpPad(
          tester,
          dense: dense,
          scale: scale,
          actions: [
            TextButton(key: first, onPressed: () {}, child: const Text('A')),
            TextButton(key: second, onPressed: () {}, child: const Text('B')),
          ],
        );
        final scaler = TextScaler.linear(scale);
        expect(
          tester.getSize(pad).height,
          moreOrLessEquals(
            NumberPad.height(scaler, dense: dense, actions: true),
          ),
        );
        final a = tester.getRect(find.byKey(first));
        final b = tester.getRect(find.byKey(second));
        final one = tester.getRect(find.byKey(padDigitKey('1')));
        expect(
          a.height,
          moreOrLessEquals(NumberPad.keyHeight(scaler, dense: dense)),
        );
        expect(a.width, moreOrLessEquals(b.width));
        expect(a.bottom, lessThan(one.top));
        expect(a.left, tester.getRect(pad).left);
        expect(b.right, tester.getRect(pad).right);
      });
    }
  }

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

  group('in the app, with a kind whose answers can be negative or decimal', () {
    // Algebra stands in for such a kind: its level with negative and
    // decimal answers is not there yet, so the test switches the keys on
    // for it.
    final equation = (OperationType.algebra.source as AlgebraSource).build(
      OperationType.algebra,
      'missingSecondAddend',
      [3, 4],
    )!;

    Future<MathTesterModel> launch(
      WidgetTester tester, {
      Size size = const Size(1000, 900),
      String? language,
      bool keys = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = MathTesterModel(
        initialProblem: equation,
        random: Random(4),
        progress: Progress(
          tier: Tier.easy,
          language: language,
          selectedOperations: {OperationType.plus, OperationType.algebra},
        ),
        signedDecimalAnswers: keys
            ? (kind) => kind == OperationType.algebra
            : (kind) => kind.signedDecimalAnswers,
      );
      addTearDown(model.dispose);
      model.startPractice();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: MediaQuery(
            data: MediaQueryData(size: size),
            child: const MathTesterApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return model;
    }

    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('algebra itself asks for the keys (level 5 answers go below '
        'zero and into tenths)', (tester) async {
      expect(OperationType.algebra.signedDecimalAnswers, isTrue);
      final model = await launch(tester, keys: false);
      expect(model.signedDecimalInput, isTrue);
      expect(find.byKey(padMinusKey), findsOne);
      expect(find.byKey(padDecimalKey), findsOne);
    });

    testWidgets('the pad keeps its keys and shape from question to question', (
      tester,
    ) async {
      final model = await launch(tester);
      final kinds = <OperationType>{};
      Rect? shape;
      for (var question = 0; question < 6; question++) {
        kinds.add(model.current.kind);
        expect(find.byKey(padMinusKey), findsOne);
        expect(find.byKey(padDecimalKey), findsOne);
        shape ??= tester.getRect(pad);
        expect(tester.getRect(pad), shape, reason: model.current.question);
        await tester.tap(find.byKey(padDigitKey('9')));
        await tester.pump();
        await tester.tap(find.byKey(checkAnswerButtonKey));
        await tester.pumpAndSettle();
        expect(tester.getRect(pad), shape);
        await tester.tap(find.byKey(checkAnswerButtonKey));
        await tester.pumpAndSettle();
      }
      expect(kinds, {OperationType.plus, OperationType.algebra});
    });

    testWidgets('an answer typed on the pad is checked in hundredths', (
      tester,
    ) async {
      final model = await launch(tester);
      for (final key in [
        padDigitKey('4'),
        padDecimalKey,
        padDigitKey('0'),
        padDigitKey('0'),
      ]) {
        await tester.tap(find.byKey(key));
        await tester.pump();
      }
      expect(fieldText(tester), '4.00');
      await tester.tap(find.byKey(checkAnswerButtonKey));
      await tester.pumpAndSettle();
      expect(model.answerCorrect, isTrue);
      expect(model.history.single.answerHundredths, 400);
      expect(model.history.single.firstAnswer, 4);
    });

    for (final (language, typed, refused) in const [
      ('de', '-2,5', '-2,5,'),
      ('en', '−2.5', '−2.5e'),
    ]) {
      testWidgets('$language: the system keyboard types $typed', (
        tester,
      ) async {
        // A phone starts with the system keyboard.
        final model = await launch(
          tester,
          size: const Size(390, 844),
          language: language,
        );
        expect(pad, findsNothing);
        final inputType =
            tester.testTextInput.setClientArgs!['inputType']
                as Map<String, dynamic>;
        expect(inputType['name'], 'TextInputType.number');
        expect(inputType['signed'], isTrue);
        expect(inputType['decimal'], isTrue);
        await tester.enterText(find.byType(TextField), typed);
        await tester.pump();
        expect(fieldText(tester), typed);
        await tester.enterText(find.byType(TextField), refused);
        await tester.pump();
        expect(fieldText(tester), typed);
        expect(model.draftInput, typed);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(model.answerCorrect, isFalse);
        expect(model.history.single.answerHundredths, -250);
      });
    }
  });

  group('checking an equation', () {
    final equation = (OperationType.algebra.source as AlgebraSource).build(
      OperationType.algebra,
      'missingMinuend',
      [3, 4],
    )!;

    MathTesterModel modelWith(String draft) {
      final model = MathTesterModel(initialProblem: equation);
      addTearDown(model.dispose);
      model.setDraftInput(draft);
      return model;
    }

    test('text that is not a number is the "use a number" feedback', () {
      for (final draft in ['-', '.', '-.', '1e1', '+7', '7.001', '7..']) {
        final model = modelWith(draft);
        expect(model.submitAnswer(), isFalse, reason: draft);
        expect(model.inputProblem, InputProblem.notANumber, reason: draft);
        expect(model.history, isEmpty);
      }
      final empty = modelWith('  ');
      expect(empty.submitAnswer(), isFalse);
      expect(empty.inputProblem, InputProblem.empty);
    });

    test('equal hundredths are right, however they are written', () {
      for (final draft in ['7', '7.', '7,0', '07.00', ' 7 ']) {
        final model = modelWith(draft);
        expect(model.submitAnswer(), isTrue, reason: draft);
        expect(model.answerCorrect, isTrue, reason: draft);
        expect(model.history.single.answerHundredths, 700);
      }
      for (final draft in ['-7', '7.01', '6,99', '70']) {
        final model = modelWith(draft);
        expect(model.submitAnswer(), isTrue, reason: draft);
        expect(model.answerCorrect, isFalse, reason: draft);
      }
    });
  });
}

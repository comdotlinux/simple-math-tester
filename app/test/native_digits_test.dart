import 'package:flutter/widgets.dart' as w;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/digits.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

/// Native digits (issues #275, #277): shown by default in Bengali, 0-9 by
/// choice, and never a 0-9 in a visible text while native.
void main() {
  Future<MathTesterModel> pump(
    WidgetTester tester, {
    String language = 'bn',
    bool? nativeDigits,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      progress: Progress(
        tier: Tier.easy,
        language: language,
        nativeDigits: nativeDigits,
      ),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: model, child: const MathTesterApp()),
    );
    await tester.pumpAndSettle();
    return model;
  }

  /// Every visible text outside the number pad (its digits are #276).
  List<String> visibleTexts(WidgetTester tester) {
    final pad = find.byKey(numberPadKey);
    return [
      for (final text in tester.widgetList<w.Text>(find.byType(w.Text)))
        if (find
            .descendant(of: pad, matching: find.byWidget(text))
            .evaluate()
            .isEmpty)
          text.textSpan?.toPlainText() ?? text.data ?? '',
    ];
  }

  final ascii = RegExp('[0-9]');

  testWidgets('practice page, wrong answer, hint and summary show no 0-9', (
    tester,
  ) async {
    final model = await pump(tester);
    model.startPractice();
    await tester.pumpAndSettle();
    expect(visibleTexts(tester).where(ascii.hasMatch), isEmpty);
    model
      ..setDraftInput('${model.current.result + 1}')
      ..submitAnswer();
    await tester.pumpAndSettle();
    expect(model.answerCorrect, isFalse);
    expect(visibleTexts(tester).where(ascii.hasMatch), isEmpty);
    await tester.ensureVisible(find.byKey(hintButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(hintButtonKey));
    await tester.pumpAndSettle();
    expect(visibleTexts(tester).where(ascii.hasMatch), isEmpty);
    await tester.tap(find.byKey(hintCloseKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(endPracticeButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(endPracticeButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(roundSummaryKey), findsOneWidget);
    expect(visibleTexts(tester).where(ascii.hasMatch), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed answers are drawn native but stay ASCII', (tester) async {
    final model = await pump(tester);
    model.startPractice();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '42');
    await tester.pump();
    expect(model.draftInput, '42');
    final field = find.byType(EditableText);
    final drawn = tester
        .widget<EditableText>(field)
        .controller
        .buildTextSpan(context: tester.element(field), withComposing: false);
    expect(drawn.toPlainText(), '৪২');
  });

  testWidgets('0-9 by choice, and by default in Hindi', (tester) async {
    final model = await pump(tester, nativeDigits: false);
    model.startPractice();
    await tester.pumpAndSettle();
    expect(visibleTexts(tester).any(ascii.hasMatch), isTrue);
    await pump(tester, language: 'hi');
    expect(find.text('०'), findsNothing);
  });

  testWidgets('the Numbers setting shows for Bengali and saves', (
    tester,
  ) async {
    final model = await pump(tester);
    await tester.tap(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
    final ascii09 = find.byKey(numbersModeKey(native: false));
    await tester.ensureVisible(ascii09);
    await tester.pumpAndSettle();
    expect(find.text('123'), findsOneWidget);
    expect(find.text('১২৩'), findsOneWidget);
    await tester.tap(ascii09);
    await tester.pumpAndSettle();
    expect(model.nativeDigits, isFalse);
  });

  testWidgets('no Numbers setting for a language that writes 0-9', (
    tester,
  ) async {
    await pump(tester, language: 'de');
    await tester.tap(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(numbersModeKey(native: true)), findsNothing);
  });

  test('defaults: native for ar ur bn gu mr, 0-9 for the rest', () {
    for (final code in ['ar', 'ur', 'bn', 'gu', 'mr']) {
      expect(showsNativeDigits(null, code), isTrue, reason: code);
    }
    for (final code in ['hi', 'te', 'ta', 'ml', 'pa', 'en', 'de']) {
      expect(showsNativeDigits(null, code), isFalse, reason: code);
    }
    expect(showsNativeDigits(false, 'bn'), isFalse);
    expect(showsNativeDigits(true, 'hi'), isTrue);
    expect(showsNativeDigits(true, 'en'), isFalse);
  });

  test('the setting is an additive field; old saves load with the default', () {
    expect(Progress.decode(Progress().encode()).nativeDigits, isNull);
    expect(Progress().encode(), isNot(contains('nativeDigits')));
    final saved = Progress().withNativeDigits(false).encode();
    expect(Progress.decode(saved).nativeDigits, isFalse);
  });
}

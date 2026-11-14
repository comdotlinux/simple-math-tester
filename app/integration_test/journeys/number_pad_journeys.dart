import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart' show formatNumber;
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

// Feedback, button and semantics wording stays literal: it is the behaviour.

/// The keyboard switch's tooltip, which is also its accessible name.
String? _switchTooltip(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(keyboardSwitchKey)).tooltip;

void numberPadJourneys() {
  group('number pad', () {
    testWidgets('each digit key types its digit', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openPad(tester);

      for (final digit in '1234567890'.split('')) {
        await tapVisible(tester, padKey(digit));
      }

      expect(answerFieldText(tester), '1234567890');
      expect(modelOf(tester).draftInput, '1234567890');
    });

    testWidgets('Delete removes the last digit', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openPad(tester);
      await tapVisible(tester, padKey('4'));
      await tapVisible(tester, padKey('2'));

      await tapVisible(tester, padDelete);

      expect(answerFieldText(tester), '4');
      await tapVisible(tester, padDelete);
      await tapVisible(tester, padDelete);
      expect(answerFieldText(tester), isEmpty);
    });

    testWidgets('Check with nothing typed says enter a number first', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openPad(tester);

      await tapVisible(
        tester,
        find.descendant(
          of: find.byKey(numberPadKey),
          matching: find.byKey(checkAnswerButtonKey),
        ),
      );

      expect(find.text('Enter a number first.'), findsOneWidget);
      expect(modelOf(tester).history, isEmpty);
    });

    testWidgets('an answer typed on the pad is checked from the pad', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openPad(tester);
      final model = modelOf(tester);

      for (final digit in formatNumber(model.current.result).split('')) {
        await tapVisible(tester, padKey(digit));
      }
      await tapVisible(
        tester,
        find.descendant(
          of: find.byKey(numberPadKey),
          matching: find.byKey(checkAnswerButtonKey),
        ),
      );

      expect(find.text('You got it!'), findsOneWidget);
      expect(model.history.single.correct, isTrue);
    });

    testWidgets('pressing Check twice checks, then moves on', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openPad(tester);
      final model = modelOf(tester);
      final first = model.current;
      final check = find.descendant(
        of: find.byKey(numberPadKey),
        matching: find.byKey(checkAnswerButtonKey),
      );
      for (final digit in formatNumber(first.result).split('')) {
        await tapVisible(tester, padKey(digit));
      }

      await tapVisible(tester, check);

      expect(find.text('You got it!'), findsOneWidget);
      expect(find.descendant(of: check, matching: find.text('Next')), findsOne);
      expect(await answerFocused(tester), isTrue);

      await tapVisible(tester, check);

      expect(model.current, isNot(same(first)));
      expect(model.history, hasLength(1));
      expect(
        find.descendant(of: check, matching: find.text('Check answer')),
        findsOne,
      );
      expect(await answerFocused(tester), isTrue);
    });

    testWidgets('the keyboard button swaps the pad for the keyboard and back', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openPad(tester);
      expect(_switchTooltip(tester), 'Use the keyboard');

      await tapKey(tester, keyboardSwitchKey);

      expect(find.byKey(numberPadKey), findsNothing);
      expect(_switchTooltip(tester), 'Use the number pad');
      // The page's own Check button takes the pad's place.
      expect(find.byKey(checkAnswerButtonKey), findsOneWidget);
      final model = modelOf(tester);
      await submit(tester, model.current.result);
      expect(find.text('You got it!'), findsOneWidget);

      await tapKey(tester, keyboardSwitchKey);

      expect(find.byKey(numberPadKey), findsOneWidget);
      expect(_switchTooltip(tester), 'Use the keyboard');
    });

    testWidgets('with the keyboard, Enter checks the typed answer', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await closePad(tester);
      final model = modelOf(tester);
      await typeAnswer(tester, formatNumber(model.current.result));

      // The field's action is done; Enter on a keyboard sends the same one.
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .performAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('You got it!'), findsOneWidget);
      expect(model.history.single.correct, isTrue);
    });

    // What each CI device proves here: everywhere, the field asks for no
    // keyboard (TextInputType.none) with the pad and a number keyboard
    // without it. The zero keyboard-height check only means something on the
    // Android emulator, which shows a soft keyboard; Linux and Chrome have
    // none, and the iOS simulator uses the Mac's hardware keyboard by default,
    // so there it holds trivially.
    testWidgets('with the pad, tapping the answer field opens no system '
        'keyboard; the keyboard button asks for one', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openPad(tester);
      EditableText editable() =>
          tester.widget<EditableText>(find.byType(EditableText));
      // A soft keyboard takes a moment to slide in; real time, not frames.
      Future<void> settleKeyboard() async {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }

      await tapVisible(tester, find.byType(TextField));
      await settleKeyboard();

      expect(editable().focusNode.hasFocus, isTrue);
      expect(editable().keyboardType, TextInputType.none);
      expect(tester.view.viewInsets.bottom, 0);
      expect(find.byKey(numberPadKey), findsOneWidget);

      await tapKey(tester, keyboardSwitchKey);
      await settleKeyboard();

      expect(editable().focusNode.hasFocus, isTrue);
      expect(editable().keyboardType, TextInputType.number);
      expect(find.byKey(numberPadKey), findsNothing);
    });

    testWidgets('only digits reach the answer field', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));

      await typeAnswer(tester, '-1a2.5');

      expect(answerFieldText(tester), '125');
      expect(modelOf(tester).draftInput, '125');
    });

    testWidgets('a phone starts with the system keyboard, a larger screen '
        'with the pad', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final phone = isPhone(tester);

      expect(find.byKey(numberPadKey), phone ? findsNothing : findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).keyboardType,
        phone ? TextInputType.number : TextInputType.none,
      );
      expect(await answerFocused(tester), isTrue);
    });

    testWidgets('on a phone with the system keyboard, Enter checks, Enter '
        'again moves on, and question, answer, feedback and Next stay above '
        'the keyboard', (tester) async {
      // A 360 x 640 phone, as below; the keyboard is the device's own where
      // it has a soft one (the Android emulator and the iOS simulator), else
      // no inset. The iOS simulator keeps its own screen: its keyboard is the
      // simulated iPhone's (308 px on an iPhone 17 Pro), and no iPhone pairs
      // a keyboard that tall with a 640 px screen.
      if (defaultTargetPlatform != TargetPlatform.iOS) {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3;
        const insets = FakeViewPadding(top: 20 * 3);
        tester.view.padding = insets;
        tester.view.viewPadding = insets;
        addTearDown(tester.view.reset);
      }
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final first = model.current;
      expect(find.byKey(numberPadKey), findsNothing);

      await typeAnswer(tester, formatNumber(first.result + 1));
      await pressEnter(tester);
      // A soft keyboard takes a moment to slide in; real time, not frames.
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final ratio = tester.view.devicePixelRatio;
      final size = tester.view.physicalSize / ratio;
      final above =
          Offset.zero &
          Size(size.width, size.height - tester.view.viewInsets.bottom / ratio);
      for (final finder in [
        find.byKey(questionOnProblemsPageKey),
        find.byType(TextField),
        find.text('Not quite. Try another answer.'),
        find.byKey(nextQuestionButtonKey),
        find.byKey(checkAnswerButtonKey),
      ]) {
        final rect = tester.getRect(finder);
        expect(
          above.intersect(rect).size,
          rect.size,
          reason: '$finder at $rect is not fully above the keyboard: $above',
        );
      }
      expect(await answerFocused(tester), isTrue);

      await typeAnswer(tester, formatNumber(first.result));
      await pressEnter(tester);
      expect(find.text('You got it!'), findsOneWidget);
      await pressEnter(tester);
      expect(model.current, isNot(same(first)));
      expect(model.history, hasLength(1));
      expect(await answerFocused(tester), isTrue);
    });

    testWidgets('on a phone a check keeps question, answer, feedback and Next '
        'on screen', (tester) async {
      // A 360 x 640 phone: below 700 px the field, the feedback and a dense
      // pad dock at the bottom.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      // A real phone of this size has a status bar and no notch or home bar.
      // Fixed insets keep the device's own (the iOS simulator's notch and home
      // bar on a 640 px screen no phone has) out of the layout.
      const insets = FakeViewPadding(top: 20 * 3);
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
      addTearDown(tester.view.reset);
      await startWith(tester, Progress(tier: Tier.easy));
      await openPad(tester);
      final model = modelOf(tester);

      await submit(tester, model.current.result + 1);

      final screen = Offset.zero & tester.view.physicalSize / 3;
      final question = find.byKey(questionOnProblemsPageKey);
      expect(
        tester.widget<Text>(question).data,
        model.current.question,
        reason: 'the question shown is the current one',
      );
      for (final finder in [
        question,
        find.byType(TextField),
        find.text('Not quite. Try another answer.'),
        find.byKey(nextQuestionButtonKey),
        find.byKey(numberPadKey),
      ]) {
        final rect = tester.getRect(finder);
        expect(
          screen.intersect(rect).size,
          rect.size,
          reason: '$finder at $rect is not fully on the $screen screen',
        );
      }
    });
  });
}

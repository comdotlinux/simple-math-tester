import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart' show formatNumber;
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

void numberPadJourneys() {
  group('number pad', () {
    testWidgets('each digit key types its digit', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));

      for (final digit in '1234567890'.split('')) {
        await tapVisible(tester, padKey(digit));
      }

      expect(answerFieldText(tester), '1234567890');
      expect(modelOf(tester).draftInput, '1234567890');
    });

    testWidgets('Delete removes the last digit', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
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

    testWidgets('the keyboard button swaps the pad for the keyboard and back', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      expect(find.byKey(numberPadKey), findsOneWidget);
      expect(find.byTooltip('Use the keyboard'), findsOneWidget);

      await tapKey(tester, keyboardSwitchKey);

      expect(find.byKey(numberPadKey), findsNothing);
      expect(find.byTooltip('Use the number pad'), findsOneWidget);
      // The page's own Check button takes the pad's place.
      expect(find.byKey(checkAnswerButtonKey), findsOneWidget);
      final model = modelOf(tester);
      await submit(tester, model.current.result);
      expect(find.text('You got it!'), findsOneWidget);

      await tapKey(tester, keyboardSwitchKey);

      expect(find.byKey(numberPadKey), findsOneWidget);
      expect(find.byTooltip('Use the keyboard'), findsOneWidget);
    });

    testWidgets('with the pad, tapping the answer field opens no system '
        'keyboard; the keyboard button asks for one', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
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

    testWidgets('on a phone a check keeps question, answer, feedback and Next '
        'on screen', (tester) async {
      // A 360 x 640 phone: below 700 px the field, the feedback and a dense
      // pad dock at the bottom.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);

      await submit(tester, model.current.result + 1);

      final screen = Offset.zero & tester.view.physicalSize / 3;
      for (final finder in [
        find.byKey(questionOnProblemsPageKey),
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

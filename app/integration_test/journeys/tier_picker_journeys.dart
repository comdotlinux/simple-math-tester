import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

void tierPickerJourneys() {
  group('tier picker', () {
    testWidgets('a first start asks how hard to start and hides practice', (
      tester,
    ) async {
      await startWith(tester, Progress());

      expect(find.byKey(tierPickerKey), findsOneWidget);
      expect(find.text('How hard should it start?'), findsOneWidget);
      for (final tier in Tier.values) {
        expect(find.text(tier.label), findsOneWidget);
      }
      expect(find.byKey(questionOnProblemsPageKey), findsNothing);
      expect(find.byKey(numberPadKey), findsNothing);
      expect(find.byKey(nextQuestionButtonKey), findsNothing);
    });

    testWidgets('choosing a tier starts every operation at its level', (
      tester,
    ) async {
      await startWith(tester, Progress());

      await tapVisible(tester, find.text(Tier.medium.label));

      final model = modelOf(tester);
      expect(find.byKey(tierPickerKey), findsNothing);
      expect(find.byKey(questionOnProblemsPageKey), findsOneWidget);
      expect(model.tier, Tier.medium);
      for (final type in OperationType.values) {
        expect(model.difficulty[type]!.level, Tier.medium.level);
      }
      expect(model.current.level, Tier.medium.level);
      final saved = await waitForSaved((p) => p.tier == Tier.medium);
      expect(saved.difficulty[OperationType.plus]!.level, 3);
    });

    testWidgets('a start without saving shows the can’t-be-saved notice', (
      tester,
    ) async {
      await startWithRaw(tester, '{"schemaVersion": 99}');

      expect(find.byKey(tierPickerKey), findsOneWidget);
      expect(
        find.text('Progress can’t be saved on this device right now'),
        findsOneWidget,
      );
    });
  });
}

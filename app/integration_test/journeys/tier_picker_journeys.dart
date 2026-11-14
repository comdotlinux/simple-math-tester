import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
      // The lineup itself is the behaviour: Easy, Medium, Hard, Harder.
      expect(Tier.values.map((tier) => tier.label), [
        'Easy',
        'Medium',
        'Hard',
        'Harder',
      ]);
      for (final tier in Tier.values) {
        expect(
          find.descendant(
            of: find.byKey(tierOptionKey(tier)),
            matching: find.text(tier.label),
          ),
          findsOneWidget,
        );
      }
      expect(find.byKey(questionOnProblemsPageKey), findsNothing);
      expect(find.byKey(numberPadKey), findsNothing);
      expect(find.byKey(nextQuestionButtonKey), findsNothing);
    });

    testWidgets('choosing a tier starts every operation at its level', (
      tester,
    ) async {
      await startWith(tester, Progress());

      await tapKey(tester, tierOptionKey(Tier.medium));

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

    for (final (tier, level) in [(Tier.hard, 4), (Tier.harder, 5)]) {
      testWidgets('choosing ${tier.label} starts every operation at level '
          '$level', (tester) async {
        await startWith(tester, Progress());

        await tapKey(tester, tierOptionKey(tier));

        final model = modelOf(tester);
        expect(find.byKey(tierPickerKey), findsNothing);
        expect(model.tier, tier);
        for (final type in OperationType.values) {
          expect(model.difficulty[type]!.level, level);
        }
        expect(model.current.level, level);
        await waitForSaved((p) => p.tier == tier);
      });
    }

    testWidgets('a saved old Hard tier restarts as Harder with levels kept', (
      tester,
    ) async {
      // Before schema 2, `hard` was level 5, which is now Harder.
      await startWithRaw(
        tester,
        '{"schemaVersion": 1, "tier": "hard", '
        '"operations": {"plus": {"level": 2}, "minus": {"level": 5}}}',
      );

      final model = modelOf(tester);
      expect(find.byKey(tierPickerKey), findsNothing);
      expect(model.tier, Tier.harder);
      expect(model.difficulty[OperationType.plus]!.level, 2);
      expect(model.difficulty[OperationType.minus]!.level, 5);
      await openSettings(tester);
      expect(
        tester
            .widget<ListTile>(find.byKey(tierSettingKey(Tier.harder)))
            .selected,
        isTrue,
      );
      await closeSettings(tester);
    });

    testWidgets('a start without saving shows the can’t-be-saved notice', (
      tester,
    ) async {
      await startWithRaw(tester, '{"schemaVersion": 99}');

      expect(find.byKey(tierPickerKey), findsOneWidget);
      expect(find.byKey(cantSaveNoticeKey), findsOneWidget);
    });
  });
}

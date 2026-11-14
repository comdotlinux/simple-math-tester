import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

void settingsJourneys() {
  group('settings', () {
    testWidgets(
      'the gear opens the settings sheet and a tap outside closes it, '
      'focusing the answer again',
      (tester) async {
        await startWith(tester, Progress(tier: Tier.easy));

        await openSettings(tester);

        expect(find.byKey(settingsSheetKey), findsOneWidget);
        expect(find.text('Starting difficulty'), findsOneWidget);
        expect(find.textContaining('Now: Easy.'), findsOneWidget);
        for (final tier in Tier.values) {
          expect(
            find.descendant(
              of: find.byKey(tierSettingKey(tier)),
              matching: find.text(tier.label),
            ),
            findsOneWidget,
          );
        }
        expect(find.text('Vibration'), findsOneWidget);

        await closeSettings(tester);
        expect(find.byKey(settingsSheetKey), findsNothing);
        expect(
          await answerFocused(tester),
          isTrue,
          reason: 'the answer comes first',
        );
      },
    );

    testWidgets(
      'choosing another tier resets levels and draws a new question',
      (tester) async {
        await startWith(
          tester,
          Progress(
            tier: Tier.easy,
            difficulty: {OperationType.plus: const Difficulty(level: 2)},
          ),
        );
        final model = modelOf(tester);
        final shown = model.current;
        await openSettings(tester);

        await tapKey(tester, tierSettingKey(Tier.hard));

        expect(find.byKey(settingsSheetKey), findsNothing);
        expect(model.tier, Tier.hard);
        for (final type in OperationType.values) {
          expect(model.difficulty[type]!.level, Tier.hard.level);
        }
        expect(model.current, isNot(same(shown)));
        expect(model.current.level, Tier.hard.level);
        // The replaced question is not recorded.
        expect(model.history, isEmpty);
        await waitForSaved((p) => p.tier == Tier.hard);
      },
    );

    testWidgets('tapping the current tier only closes the sheet', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          difficulty: {
            OperationType.plus: const Difficulty(level: 2, upCount: 1),
          },
        ),
      );
      final model = modelOf(tester);
      final shown = model.current;
      await openSettings(tester);

      await tapKey(tester, tierSettingKey(Tier.easy));

      expect(find.byKey(settingsSheetKey), findsNothing);
      expect(model.tier, Tier.easy);
      expect(model.difficulty[OperationType.plus]!.level, 2);
      expect(model.difficulty[OperationType.plus]!.upCount, 1);
      expect(model.current, same(shown));
    });

    testWidgets('the Vibration switch is saved', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      expect(model.haptics, isTrue);
      await openSettings(tester);

      await tapVisible(tester, find.byKey(hapticsSwitchKey));

      expect(model.haptics, isFalse);
      expect(
        tester.widget<SwitchListTile>(find.byKey(hapticsSwitchKey)).value,
        isFalse,
      );
      await waitForSaved((p) => !p.haptics);
    });

    testWidgets('with Vibration off the pad keys stop buzzing', (tester) async {
      final buzzes = <Haptic>[];
      await startHarness(
        tester,
        progress: Progress(tier: Tier.easy),
        clock: DateTime.now,
        haptic: buzzes.add,
      );
      await tapVisible(tester, padKey('5'));
      expect(buzzes, [Haptic.key]);

      await openSettings(tester);
      await tapVisible(tester, find.byKey(hapticsSwitchKey));
      await closeSettings(tester);
      await tapVisible(tester, padKey('5'));

      expect(buzzes, [Haptic.key]);
    });

    testWidgets('the app follows the system light or dark setting', (
      tester,
    ) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await startWith(tester, Progress(tier: Tier.easy));
      Brightness shown() =>
          Theme.of(tester.element(find.byKey(problemsPageKey))).brightness;

      for (final brightness in [Brightness.dark, Brightness.light]) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.pumpAndSettle();
        expect(shown(), brightness);
      }
    });
  });
}

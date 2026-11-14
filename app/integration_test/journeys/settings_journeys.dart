import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/legal.dart';
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
        expect(
          textOf(tester, currentTierNoteKey),
          contains(modelOf(tester).tier!.label),
        );
        expect(
          tester
              .widget<ListTile>(find.byKey(tierSettingKey(Tier.easy)))
              .selected,
          isTrue,
        );
        for (final tier in Tier.values) {
          expect(
            find.descendant(
              of: find.byKey(tierSettingKey(tier)),
              matching: find.text(tier.label),
            ),
            findsOneWidget,
          );
        }
        expect(find.byKey(hapticsSwitchKey), findsOneWidget);

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
      await openPad(tester);
      await tapVisible(tester, padKey('5'));
      expect(buzzes, [Haptic.key]);

      await openSettings(tester);
      await tapVisible(tester, find.byKey(hapticsSwitchKey));
      await closeSettings(tester);
      await tapVisible(tester, padKey('5'));

      expect(buzzes, [Haptic.key]);
    });

    testWidgets('Privacy shows the privacy policy inside the app', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openSettings(tester);

      await tapKey(tester, privacyTileKey);

      expect(find.byKey(privacyPageKey), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.textContaining('collects no personal data'), findsOneWidget);
    });

    // Never opens the real page: the opener only records the address.
    testWidgets('Impressum asks the browser for the production Impressum', (
      tester,
    ) async {
      final opened = <Uri>[];
      await startHarness(
        tester,
        progress: Progress(tier: Tier.easy),
        clock: DateTime.now,
        openLink: (uri) async => (opened..add(uri)).isNotEmpty,
      );
      await openSettings(tester);

      await tapKey(tester, impressumTileKey);

      expect(opened, [impressumUrl]);
      expect(impressumUrl.toString(), 'https://math.munich-tech.de/impressum');
      expect(find.byKey(settingsSheetKey), findsNothing);
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

    testWidgets('choosing Dark makes the app dark and survives a restart; '
        'System follows the device again', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await startWith(tester, Progress(tier: Tier.easy));
      Brightness shown() =>
          Theme.of(tester.element(find.byKey(problemsPageKey))).brightness;
      expect(shown(), Brightness.light);

      await openSettings(tester);
      await tapKey(tester, themeModeKey(ThemeMode.dark));
      await closeSettings(tester);
      expect(shown(), Brightness.dark);

      await restartWhenSaved(tester, (p) => p.themeMode == ThemeMode.dark);
      expect(modelOf(tester).themeMode, ThemeMode.dark);
      expect(shown(), Brightness.dark);

      await openSettings(tester);
      await tapKey(tester, themeModeKey(ThemeMode.system));
      await closeSettings(tester);
      expect(shown(), Brightness.light);
      for (final brightness in [Brightness.dark, Brightness.light]) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.pumpAndSettle();
        expect(shown(), brightness);
      }
      await waitForSaved((p) => p.themeMode == ThemeMode.system);
    });

    // A history row's answer lines stay literal: the wording is the
    // behaviour.
    testWidgets('choosing Compact shows dense answer rows and survives a '
        'restart; Comfortable brings the cards back', (tester) async {
      const problem = Problem(75, 46, OperationType.plus, 121);
      await startWith(
        tester,
        Progress(tier: Tier.easy, history: [attempt(problem, 125)]),
      );
      Finder inRow(String text) => find.descendant(
        of: find.byKey(historyRowKey(0)),
        matching: find.text(text),
      );
      Future<double> rowHeight() async => tester
          .getSize(await inHistory(tester, find.byKey(historyRowKey(0))))
          .height;

      await openHistory(tester);
      final card = await rowHeight();
      expect(inRow('Your answer: 125'), findsOneWidget);

      await returnToPractice(tester);
      await openSettings(tester);
      await tapKey(tester, layoutModeKey(LayoutMode.compact));
      await closeSettings(tester);
      await openHistory(tester);
      expect(await rowHeight() * 3, lessThanOrEqualTo(card));
      expect(inRow('75 + 46 = 121'), findsOneWidget);
      expect(inRow('You said 125'), findsOneWidget);

      await restartWhenSaved(tester, (p) => p.layoutMode == LayoutMode.compact);
      expect(modelOf(tester).layoutMode, LayoutMode.compact);
      await openHistory(tester);
      expect(await rowHeight() * 3, lessThanOrEqualTo(card));

      await returnToPractice(tester);
      await openSettings(tester);
      await tapKey(tester, layoutModeKey(LayoutMode.comfortable));
      await closeSettings(tester);
      await openHistory(tester);
      expect(inRow('Your answer: 125'), findsOneWidget);
      await waitForSaved((p) => p.layoutMode == LayoutMode.comfortable);
    });
  });
}

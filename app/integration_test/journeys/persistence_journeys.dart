import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

void persistenceJourneys() {
  group('saving', () {
    testWidgets('restart shows the saved history and selection', (
      tester,
    ) async {
      final date = today();
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          selectedOperations: {OperationType.multiply},
          history: [
            for (final lhs in [3, 4, 5])
              attempt(
                Problem(lhs, 6, OperationType.multiply, lhs * 6),
                lhs * 6,
              ),
          ],
          game: GameState(
            xp: 250,
            combo: 2,
            streak: 3,
            bestStreak: 5,
            lastActiveDate: date,
            lastGoalDate: date,
          ),
        ),
      );
      final model = modelOf(tester);
      expect(model.canSave, isTrue);
      expect(model.selectedOperations, {OperationType.multiply});
      expect(model.history, hasLength(3));
      expect(model.game.xp, 250);
      expect(model.shownStreak, 3);
      expect(semanticsNodesLabelled(tester, 'Daily streak: 3'), 1);
      expect(find.text('Level 2 · 250 XP'), findsOneWidget);
      // The first problem and the next both follow the saved selection.
      expect(model.current.kind, OperationType.multiply);
      expect(questionOnScreen(tester), contains('×'));

      await nextQuestion(tester);
      expect(model.current.kind, OperationType.multiply);

      await openHistory(tester);
      expect(find.text('4 questions completed.'), findsOneWidget);
      expect(await inHistory(tester, find.text('3 × 6')), findsWidgets);

      // The skip is saved through the plugin.
      final saved = await waitForSaved((p) => p.history.length == 4);
      expect(saved.history, hasLength(4));
      // A skip awards no XP and ends the combo; the streak is kept.
      expect([saved.game.xp, saved.game.combo], [250, 0]);
      expect([saved.game.streak, saved.game.bestStreak], [3, 5]);
    });

    testWidgets('a restart keeps answers, selection, tier and switches', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      var model = modelOf(tester);
      final question = model.current.question;
      await submit(tester, model.current.result);
      final xp = model.game.xp;
      await tapVisible(tester, operationToggle(OperationType.minus));
      await openSettings(tester);
      await tapVisible(tester, find.byKey(hapticsSwitchKey));
      await tapVisible(tester, find.text(Tier.medium.label));

      await restartWhenSaved(
        tester,
        (p) => p.tier == Tier.medium && !p.haptics && p.history.length == 1,
      );

      model = modelOf(tester);
      expect(model.history.single.problem.question, question);
      expect(model.history.single.correct, isTrue);
      expect(model.game.xp, xp);
      expect(model.selectedOperations, {
        OperationType.plus,
        OperationType.multiply,
        OperationType.divide,
      });
      expect(model.tier, Tier.medium);
      expect(model.haptics, isFalse);
      expect(model.current.kind, isNot(OperationType.minus));
    });

    testWidgets('the operation selection survives a restart', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      for (final type in [OperationType.plus, OperationType.minus]) {
        await tapVisible(tester, operationToggle(type));
      }

      await restartWhenSaved(tester, (p) => p.selectedOperations.length == 2);

      final model = modelOf(tester);
      expect(model.selectedOperations, {
        OperationType.multiply,
        OperationType.divide,
      });
      expect([
        OperationType.multiply,
        OperationType.divide,
      ], contains(model.current.kind));
    });

    testWidgets('unreadable saved data is backed up and the app starts fresh', (
      tester,
    ) async {
      final broken = 'not a progress document ${DateTime.now()}';
      // The app reports the decode failure; that report is expected here.
      final reported = <FlutterErrorDetails>[];
      final onError = FlutterError.onError;
      FlutterError.onError = reported.add;
      try {
        await startWithRaw(tester, broken);
      } finally {
        FlutterError.onError = onError;
      }

      expect(reported.single.exception, isFormatException);
      final model = modelOf(tester);
      expect(model.canSave, isTrue);
      expect(model.tier, isNull);
      expect(model.history, isEmpty);
      expect(find.byKey(tierPickerKey), findsOneWidget);
      final all = await SharedPreferencesAsync().getAll();
      expect(
        all.entries.where(
          (entry) =>
              entry.key.startsWith(unreadableKeyPrefix) &&
              entry.value == broken,
        ),
        hasLength(1),
      );
    });

    testWidgets('data from a newer version is kept and not overwritten', (
      tester,
    ) async {
      final newer = '{"schemaVersion": 99, "note": "${DateTime.now()}"}';
      await startWithRaw(tester, newer);
      final model = modelOf(tester);
      expect(model.canSave, isFalse);
      expect(
        find.text('Progress can’t be saved on this device right now'),
        findsOneWidget,
      );

      // Play goes on, but nothing replaces the newer document.
      await tapVisible(tester, find.text(Tier.easy.label));
      await nextQuestion(tester);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(await SharedPreferencesStore().read(progressKey), newer);
    });
  });
}

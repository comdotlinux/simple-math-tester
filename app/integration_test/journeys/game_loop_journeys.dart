import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/celebration.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

final _confetti = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is CelebrationPainter,
);

void gameLoopJourneys() {
  group('game loop', () {
    testWidgets('a correct first answer adds XP to the header', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      expect(find.text('Level 1 · 0 XP'), findsOneWidget);

      await submit(tester, modelOf(tester).current.result);

      // Level 1, no combo yet: 1 × (10 + 0).
      expect(modelOf(tester).game.xp, 10);
      expect(find.text('Level 1 · 10 XP'), findsOneWidget);
    });

    testWidgets('a correct answer after a hint earns half the XP', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await tapKey(tester, revealStepButtonKey);

      await submit(tester, modelOf(tester).current.result);

      expect(modelOf(tester).game.xp, 5);
      expect(find.text('Level 1 · 5 XP'), findsOneWidget);
    });

    testWidgets('the combo grows with right answers and a wrong one ends it', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, game: const GameState(combo: 2)),
      );
      final model = modelOf(tester);
      expect(semanticsNodesLabelled(tester, 'Combo: 2'), 1);

      await submit(tester, model.current.result);
      expect(model.game.xp, 12);
      expect(semanticsNodesLabelled(tester, 'Combo: 3'), 1);
      expect(find.text('×3'), findsOneWidget);

      await nextQuestion(tester);
      await submit(tester, model.current.result + 1);
      expect(semanticsNodesLabelled(tester, 'Combo: 0'), 1);
    });

    testWidgets('reaching the next level plays the celebration', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, game: const GameState(xp: 95)),
      );
      final model = modelOf(tester);
      await typeAnswer(tester, formatNumber(model.current.result));
      await tester.ensureVisible(find.byKey(checkAnswerButtonKey));

      await tester.tap(find.byKey(checkAnswerButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(model.celebrations, 1);
      // With reduced motion (CI's Android emulators set the animation scales
      // to 0) the celebration is counted but no confetti is drawn.
      final reduceMotion = MediaQuery.disableAnimationsOf(
        tester.element(find.byKey(checkAnswerButtonKey)),
      );
      expect(_confetti, reduceMotion ? findsNothing : findsOneWidget);
      await tester.pumpAndSettle();
      expect(_confetti, findsNothing);
      expect(find.text('Level 2 · 105 XP'), findsOneWidget);
    });

    testWidgets('the tenth right answer of the day fills the goal and grows '
        'the streak', (tester) async {
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          game: GameState(
            dailyCount: 9,
            lastActiveDate: today(),
            lastGoalDate: daysAgo(1),
            streak: 2,
            bestStreak: 2,
          ),
        ),
      );
      expect(semanticsNodesLabelled(tester, 'Daily goal: 9 of 10'), 1);
      expect(semanticsNodesLabelled(tester, 'Daily streak: 2'), 1);

      await submit(tester, modelOf(tester).current.result);

      expect(semanticsNodesLabelled(tester, 'Daily goal: 10 of 10'), 1);
      expect(semanticsNodesLabelled(tester, 'Daily streak: 3'), 1);
      expect(modelOf(tester).celebrations, 1);
      final saved = await waitForSaved((p) => p.game.streak == 3);
      expect([saved.game.bestStreak, saved.game.lastGoalDate], [3, today()]);
    });

    testWidgets('a new day empties the goal ring and a missed day ends the '
        'streak', (tester) async {
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          game: GameState(
            dailyCount: 7,
            lastActiveDate: daysAgo(2),
            lastGoalDate: daysAgo(2),
            streak: 4,
            bestStreak: 4,
          ),
        ),
      );

      expect(semanticsNodesLabelled(tester, 'Daily goal: 0 of 10'), 1);
      expect(semanticsNodesLabelled(tester, 'Daily streak: 0'), 1);
      expect(find.text('0/10'), findsOneWidget);
    });

    testWidgets('a goal reached yesterday keeps the streak today', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          game: GameState(
            dailyCount: 10,
            lastActiveDate: daysAgo(1),
            lastGoalDate: daysAgo(1),
            streak: 4,
            bestStreak: 4,
          ),
        ),
      );

      expect(semanticsNodesLabelled(tester, 'Daily streak: 4'), 1);
      expect(semanticsNodesLabelled(tester, 'Daily goal: 0 of 10'), 1);
    });

    testWidgets('right answers raise the operation’s level', (tester) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, selectedOperations: {OperationType.plus}),
      );
      final model = modelOf(tester);

      for (var i = 0; i < levelUpAfter; i++) {
        await submit(tester, model.current.result);
        await nextQuestion(tester);
      }

      expect(model.difficulty[OperationType.plus]!.level, 2);
      expect(model.current.level, 2);
    });
  });
}

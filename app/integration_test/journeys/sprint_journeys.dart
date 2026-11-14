import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart' show formatNumber;
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

// Feedback and the round's mix sentence stay literal: their wording is the
// behaviour.

void sprintJourneys() {
  group('sprint', () {
    testWidgets('starting a sprint shows the countdown and hides practice '
        'extras', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));

      await tapKey(tester, sprintButtonKey);

      final model = modelOf(tester);
      expect(model.inSprint, isTrue);
      expect(find.byKey(sprintCountdownKey), findsOneWidget);
      expect(textOf(tester, sprintScoreKey), showsNumber(0));
      expect(find.byKey(nextQuestionButtonKey), findsNothing);
      expect(find.byKey(settingsButtonKey), findsNothing);
      expect(find.byKey(revealStepButtonKey), findsNothing);
    });

    testWidgets('a sprint answer moves straight on and adds to the score', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await tapKey(tester, sprintButtonKey);
      final model = modelOf(tester);
      final first = model.current;

      await submit(tester, first.result);

      expect(model.current, isNot(same(first)));
      expect(model.history.single.sprint, isTrue);
      expect(model.history.single.correct, isTrue);
      expect(model.sprintScore, greaterThan(0));
      expect(textOf(tester, sprintScoreKey), showsNumber(model.sprintScore));
      expect(find.text('You got it!'), findsNothing);
    });

    testWidgets('in a sprint Enter checks and moves on once', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await tapKey(tester, sprintButtonKey);
      final model = modelOf(tester);
      final first = model.current;
      await typeAnswer(tester, formatNumber(first.result));

      await pressEnter(tester);

      final second = model.current;
      expect(second, isNot(same(first)));
      expect(model.history, hasLength(1));
      expect(model.draftInput, isEmpty);
      expect(await answerFocused(tester), isTrue);

      // A second Enter on the empty field only asks for a number.
      await pressEnter(tester);

      expect(model.current, same(second));
      expect(model.history, hasLength(1));
      expect(find.text('Enter a number first.'), findsOneWidget);
    });

    testWidgets('leaving for My answers ends the round, shows the result and '
        'saves the best', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await tapKey(tester, sprintButtonKey);
      final model = modelOf(tester);
      await submit(tester, model.current.result);
      final score = model.sprintScore;

      await openHistory(tester);
      await returnToPractice(tester);

      expect(model.inSprint, isFalse);
      expect(find.byKey(sprintResultKey), findsOneWidget);
      expect(textOf(tester, sprintResultScoreKey), showsNumber(score));
      expect(textOf(tester, sprintResultBestKey), showsNumber(score));
      expect(find.text('Answers by difficulty: level 1: 1'), findsOneWidget);
      final saved = await waitForSaved((p) => p.game.bestSprint == score);
      expect(saved.game.combo, 0);
    });

    testWidgets('a lower score keeps the saved personal best', (tester) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, game: const GameState(bestSprint: 500)),
      );
      await tapKey(tester, sprintButtonKey);

      await openHistory(tester);
      await returnToPractice(tester);

      expect(textOf(tester, sprintResultScoreKey), showsNumber(0));
      expect(textOf(tester, sprintResultBestKey), showsNumber(500));
      expect(find.text('No answers this round.'), findsOneWidget);
    });

    testWidgets('when the time runs out the round ends with its result', (
      tester,
    ) async {
      // The real app widget on a test clock, so a minute passes at once.
      var now = DateTime(2026, 11, 14, 9);
      final ticks = StreamController<void>.broadcast();
      addTearDown(ticks.close);
      final store = MemoryProgressStore();
      final model = await startHarness(
        tester,
        progress: Progress(tier: Tier.easy),
        clock: () => now,
        ticker: () => ticks.stream,
        store: store,
      );
      await tapKey(tester, sprintButtonKey);
      expect(textOf(tester, sprintCountdownKey), showsNumber(60));

      now = now.add(const Duration(seconds: 30));
      ticks.add(null);
      await tester.pumpAndSettle();
      expect(textOf(tester, sprintCountdownKey), showsNumber(30));
      await submit(tester, model.current.result);
      final score = model.sprintScore;

      now = now.add(const Duration(seconds: 31));
      ticks.add(null);
      await tester.pumpAndSettle();

      expect(model.inSprint, isFalse);
      expect(find.byKey(sprintCountdownKey), findsNothing);
      expect(find.byKey(sprintResultKey), findsOneWidget);
      expect(textOf(tester, sprintResultBestKey), showsNumber(score));
      expect(find.byKey(nextQuestionButtonKey), findsOneWidget);
      expect(
        Progress.decode(store.values[progressKey]!).game.bestSprint,
        score,
      );
    });
  });
}

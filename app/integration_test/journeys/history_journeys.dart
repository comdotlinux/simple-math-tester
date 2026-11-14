import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Scrollable, ScrollableState, Table;
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/results_page.dart' show statsColumns;
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

// A row's verdict and answer wording stays literal: it is what the row tells
// the player about their answer.

/// [text] inside [row].
Finder _inRow(Finder row, String text) =>
    find.descendant(of: row, matching: find.text(text));

void historyJourneys() {
  group('my answers', () {
    testWidgets('with no answers it shows the empty state and no stats', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));

      await openHistory(tester);

      expect(find.byKey(noResultsOnResultsPageKey), findsOneWidget);
      expect(find.byKey(statsCardKey), findsNothing);
    });

    testWidgets('the empty state’s Practice button returns to the question', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final question = modelOf(tester).current.question;
      await openHistory(tester);

      await tapKey(tester, emptyStatePracticeButtonKey);

      expect(find.byKey(problemsPageKey), findsOneWidget);
      expect(modelOf(tester).current.question, question);
    });

    testWidgets('the stats card shows saved totals once there are answers', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          history: [attempt(Problem(2, 3, OperationType.plus, 5), 5)],
          game: const GameState(xp: 250, bestStreak: 4, bestSprint: 70),
        ),
      );

      await openHistory(tester);

      final game = modelOf(tester).game;
      expect(find.byKey(statsCardKey), findsOneWidget);
      expect(textOf(tester, totalXpStatKey), showsNumber(game.xp));
      expect(
        textOf(tester, playerLevelStatKey),
        showsNumber(playerLevel(game.xp)),
      );
      expect(textOf(tester, bestStreakStatKey), showsNumber(game.bestStreak));
      expect(textOf(tester, bestSprintStatKey), showsNumber(game.bestSprint));
    });

    testWidgets('the stats table shows each operation’s accuracy and level', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          history: [attempt(Problem(2, 3, OperationType.plus, 5), 5)],
          difficulty: {
            OperationType.plus: const Difficulty(
              level: 3,
              answered: 3,
              correct: 2,
            ),
            OperationType.minus: const Difficulty(
              level: 2,
              answered: 4,
              correct: 1,
            ),
            OperationType.divide: const Difficulty(
              level: 4,
              answered: 5,
              correct: 5,
            ),
          },
        ),
      );

      await openHistory(tester);

      final table = find.byType(Table);
      await tester.ensureVisible(table);
      await tester.pumpAndSettle();
      Finder inTable(String text) =>
          find.descendant(of: table, matching: find.text(text));
      // Every cell value below is unique in the table. Texts of one row
      // overlap vertically; texts of different rows never do.
      void expectRow(String operation, String accuracy, String level) {
        final row = tester.getRect(inTable(operation));
        for (final cell in [accuracy, level]) {
          final rect = tester.getRect(inTable(cell));
          expect(
            rect.top < row.bottom && row.top < rect.bottom,
            isTrue,
            reason: 'the $operation row has no "$cell" cell',
          );
        }
      }

      for (final column in statsColumns) {
        expect(inTable(column), findsOneWidget);
      }
      expectRow(OperationType.plus.label, '67%', '3');
      expectRow(OperationType.minus.label, '25%', '2');
      // Never answered: a dash, at the tier's level.
      expectRow(OperationType.multiply.label, '–', '1');
      expectRow(OperationType.divide.label, '100%', '4');
    });

    testWidgets('an incorrect row shows your answer and the expected one', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final question = model.current.question;
      final answer = model.current.result;
      await submit(tester, answer + 1);

      await openHistory(tester);

      expect(textOf(tester, historyCountKey), showsNumber(1));
      final row = await inHistory(tester, find.byKey(historyRowKey(0)));
      expect(_inRow(row, 'Incorrect'), findsOneWidget);
      expect(_inRow(row, question), findsOneWidget);
      expect(
        _inRow(row, 'Your answer: ${formatNumber(answer + 1)}'),
        findsOneWidget,
      );
      expect(
        _inRow(row, 'Expected answer: ${formatNumber(answer)}'),
        findsOneWidget,
      );
    });

    testWidgets('a correct row shows your answer', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      await submit(tester, model.current.result + 1);
      await nextQuestion(tester);
      final question = model.current.question;
      final answer = model.current.result;
      await submit(tester, answer);
      await nextQuestion(tester);

      await openHistory(tester);

      expect(textOf(tester, historyCountKey), showsNumber(2));
      final wrong = await inHistory(tester, find.byKey(historyRowKey(0)));
      expect(_inRow(wrong, 'Incorrect'), findsOneWidget);
      final right = await inHistory(tester, find.byKey(historyRowKey(1)));
      expect(_inRow(right, 'Correct'), findsOneWidget);
      expect(_inRow(right, question), findsOneWidget);
      expect(
        _inRow(right, 'Your answer: ${formatNumber(answer)}'),
        findsOneWidget,
      );
    });

    testWidgets('a skipped row says no answer was entered', (tester) async {
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          history: [
            attempt(Problem(2, 3, OperationType.plus, 5), 6),
            attempt(Problem(4, 3, OperationType.plus, 7), 7),
          ],
        ),
      );
      final model = modelOf(tester);
      final question = model.current.question;
      await nextQuestion(tester);

      await openHistory(tester);

      expect(textOf(tester, historyCountKey), showsNumber(3));
      final row = await inHistory(tester, find.byKey(historyRowKey(2)));
      expect(_inRow(row, 'Skipped'), findsOneWidget);
      expect(_inRow(row, question), findsOneWidget);
      expect(_inRow(row, 'No answer entered'), findsOneWidget);
      expect(
        _inRow(
          row,
          'Expected answer: ${formatNumber(model.history[2].problem.result)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a long history loads more on scroll and keeps stats pinned', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(
          tier: Tier.easy,
          history: [
            attempt(Problem(77, 23, OperationType.plus, 100), 100),
            for (var i = 0; i < 44; i++)
              attempt(Problem(1, 1, OperationType.plus, 2), 2),
          ],
        ),
      );

      await openHistory(tester);

      final count = modelOf(tester).history.length;
      expect(textOf(tester, historyCountKey), showsNumber(count));
      expect(find.byKey(statsCardKey), findsOneWidget);
      // Newest first: the oldest answer, index 0, is in the third page of
      // 20, after two loads.
      expect(find.byKey(historyRowKey(0)), findsNothing);
      final row = await inHistory(tester, find.byKey(historyRowKey(0)));
      expect(_inRow(row, '77 + 23'), findsOneWidget);
      expect(
        await inHistory(tester, find.byKey(answersEndKey)),
        findsOneWidget,
      );
      expect(find.byKey(answersLoadingKey), findsNothing);
      // Scrolled down, the stats are a compact bar still on screen.
      final bar = find.byKey(compactStatsKey);
      expect(bar, findsOneWidget);
      expect(find.byKey(statsCardKey), findsNothing);
      final screen = tester.getRect(find.byKey(resultsPageKey));
      expect(tester.getRect(bar).top, greaterThanOrEqualTo(screen.top));
      expect(tester.getRect(bar).bottom, lessThan(screen.bottom));
      // The bar shows numbers only; screen readers hear the full labels.
      expect(semanticsNodesLabelled(tester, 'Total XP: 0'), 1);
      expect(semanticsNodesLabelled(tester, 'Player level: 1'), 1);
      expect(semanticsNodesLabelled(tester, "That's all your answers"), 1);

      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(resultsPageKey),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();

      expect(find.byKey(statsCardKey), findsOneWidget);
      expect(bar, findsNothing);
    });

    testWidgets(
      'going back to Practice keeps the current question, the answer focused',
      (tester) async {
        await startWith(tester, Progress(tier: Tier.easy));
        final model = modelOf(tester);
        final question = model.current.question;
        await submit(tester, model.current.result + 1);
        await openHistory(tester);

        await returnToPractice(tester);

        expect(model.current.question, question);
        expect(questionOnScreen(tester), question);
        expect(await answerFocused(tester), isTrue);
      },
    );
  });
}

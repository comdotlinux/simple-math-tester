import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/figure_view.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/labels.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

/// Every non-empty selection of the four operations, smallest first.
final _subsets = [
  for (var mask = 1; mask < 1 << arithmeticKinds.length; mask++)
    {
      for (final type in arithmeticKinds)
        if (mask & 1 << type.index != 0) type,
    },
]..sort((a, b) => a.length.compareTo(b.length));

/// With two kinds the chance that 20 draws show only one is 2 in 2^20.
const _draws = 20;

String _signs(Set<OperationType> subset) =>
    subset.map((type) => type.displayString).join(' and ');

void operationsJourneys() {
  group('operations', () {
    for (final subset in _subsets) {
      final signs = _signs(subset);
      testWidgets('only $signs: Next shows only $signs questions', (
        tester,
      ) async {
        await startWith(tester, Progress(tier: Tier.easy));
        final model = modelOf(tester);

        for (final type in arithmeticKinds) {
          if (!subset.contains(type)) {
            await tapVisible(tester, operationToggle(type));
          }
        }

        expect(model.selectedOperations, subset);
        // Changing the kinds records no attempt; Start asks from them.
        expect(model.history, isEmpty);
        await pressStart(tester);
        expect(subset, contains(model.current.kind));

        final kinds = <OperationType>{};
        final questions = <String>{};
        for (var i = 0; i < _draws; i++) {
          // One frame shows the new question; settling after each of the
          // 300 draws would add minutes on a device.
          await tester.ensureVisible(find.byKey(nextQuestionButtonKey));
          await tester.tap(find.byKey(nextQuestionButtonKey));
          await tester.pump();
          final kind = model.current.kind;
          expect(subset, contains(kind), reason: 'draw $i');
          expect(questionOnScreen(tester), contains(kind.displayString));
          expect(questionOnScreen(tester), model.current.question);
          kinds.add(kind);
          questions.add(model.current.question);
        }
        if (subset.length > 1) {
          expect(kinds.length, greaterThan(1), reason: 'kinds drawn: $kinds');
        }
        expect(questions.length, greaterThan(1));
      });
    }

    testWidgets('the last selected operation cannot be turned off', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, selectedOperations: {OperationType.plus}),
      );
      final model = modelOf(tester);

      await tapVisible(tester, operationToggle(OperationType.plus));

      expect(model.selectedOperations, {OperationType.plus});
      await pressStart(tester);
      await nextQuestion(tester);
      expect(model.current.kind, OperationType.plus);
    });

    testWidgets('turning an operation back on adds it to the draws', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, selectedOperations: {OperationType.plus}),
      );
      final model = modelOf(tester);

      await tapVisible(tester, operationToggle(OperationType.divide));

      expect(model.selectedOperations, {
        OperationType.plus,
        OperationType.divide,
      });
      final saved = await waitForSaved((p) => p.selectedOperations.length == 2);
      expect(saved.selectedOperations, model.selectedOperations);
    });

    testWidgets('with only Algebra on, a missing-number question is answered', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, selectedOperations: {OperationType.plus}),
      );
      final model = modelOf(tester);

      await tapVisible(tester, operationToggle(OperationType.algebra));
      await tapVisible(tester, operationToggle(OperationType.plus));
      // Start asks from the new selection at once.
      await pressStart(tester);

      expect(model.current.kind, OperationType.algebra);
      // The blank is a drawn box, a placeholder in the text, not a glyph.
      expect(
        questionOnScreen(tester),
        model.current.question.replaceAll(EquationProblem.blank, '\ufffc'),
      );
      await submit(tester, model.current.result);
      expect(model.history.last.correct, isTrue);
      expect(model.history.last.problem.kind, OperationType.algebra);
    });

    testWidgets('with only Geometry on, a figure question is answered', (
      tester,
    ) async {
      await startWith(
        tester,
        Progress(tier: Tier.easy, selectedOperations: {OperationType.plus}),
      );
      final model = modelOf(tester);

      await tapVisible(tester, operationToggle(OperationType.geometry));
      await tapVisible(tester, operationToggle(OperationType.plus));
      // Start asks from the new selection at once.
      await pressStart(tester);

      expect(model.current.kind, OperationType.geometry);
      // A drawn figure stands where the question text would be.
      expect(
        find.descendant(
          of: find.byKey(questionOnProblemsPageKey),
          matching: find.byType(FigureView),
        ),
        findsOneWidget,
      );
      await submit(tester, model.current.result);
      expect(model.history.last.correct, isTrue);
      expect(model.history.last.problem.kind, OperationType.geometry);
    });

    testWidgets('practice hides the kinds, settings, the sprint and the '
        'navigation; End brings them back with the summary and records '
        'nothing for the open question', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      expect(find.byKey(questionOnProblemsPageKey), findsNothing);
      await pressStart(tester);
      expect(await answerFocused(tester), isTrue);
      for (final key in [
        settingsButtonKey,
        sprintButtonKey,
        startPracticeButtonKey,
        myAnswersNavKey,
        operationToggleKey(OperationType.plus),
      ]) {
        expect(find.byKey(key), findsNothing, reason: '$key');
      }

      await submit(tester, model.current.result);
      await typeAnswer(tester, '1');
      final history = model.history.length;
      final xp = model.game.xp;
      await pressEnd(tester);

      expect(model.history, hasLength(history));
      expect(model.game.xp, xp);
      expect(find.byKey(roundSummaryKey), findsOneWidget);
      expect(textOf(tester, summaryAnsweredKey), showsNumber(1));
      expect(textOf(tester, summaryCorrectKey), showsNumber(1));
      expect(find.byKey(questionOnProblemsPageKey), findsNothing);
      expect(operationToggle(OperationType.plus), findsOneWidget);
      expect(find.byKey(myAnswersNavKey), findsOneWidget);
      expect(startFocused(tester), isTrue);

      await tapKey(tester, roundSummaryDoneKey);
      expect(find.byKey(roundSummaryKey), findsNothing);
      expect(model.history, hasLength(history));
    });

    testWidgets('after End the kinds change, and the next Start asks only '
        'from the new kinds', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      await pressStart(tester);
      await submit(tester, model.current.result);
      await pressEnd(tester);

      for (final type in arithmeticKinds.skip(1)) {
        await tapVisible(tester, operationToggle(type));
      }
      await pressStart(tester);

      for (var i = 0; i < 5; i++) {
        expect(model.current.kind, arithmeticKinds.first, reason: 'draw $i');
        await nextQuestion(tester);
      }
    });

    testWidgets('the new-kind card switches Algebra on once and stays away '
        'after Algebra is off again and the app restarts; Geometry then has '
        'its own card', (tester) async {
      await startWith(tester, Progress(tier: Tier.easy));
      final model = modelOf(tester);
      final card = find.byKey(newKindCardKey);
      // The title names the kind; the wording is the behaviour.
      Finder titled(OperationType kind) => find.descendant(
        of: card,
        matching: find.text(en.newKindTitle(kind.label(en))),
      );
      expect(titled(OperationType.algebra), findsOneWidget);

      await tapVisible(tester, card);
      expect(model.selectedOperations, contains(OperationType.algebra));
      expect(titled(OperationType.algebra), findsNothing);
      expect(titled(OperationType.geometry), findsOneWidget);

      await tapVisible(tester, operationToggle(OperationType.algebra));
      await restartWhenSaved(
        tester,
        (p) =>
            p.seenKinds.contains(OperationType.algebra.name) &&
            !p.selectedOperations.contains(OperationType.algebra),
      );
      expect(modelOf(tester).selectedOperations, arithmeticKinds);
      expect(titled(OperationType.algebra), findsNothing);
      expect(titled(OperationType.geometry), findsOneWidget);
    });
  });
}

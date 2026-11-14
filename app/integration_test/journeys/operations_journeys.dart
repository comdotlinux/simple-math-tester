import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

/// Every non-empty selection of the four operations, smallest first.
final _subsets = [
  for (var mask = 1; mask < 1 << OperationType.values.length; mask++)
    {
      for (final type in OperationType.values)
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
        final shown = model.current;

        for (final type in OperationType.values) {
          if (!subset.contains(type)) {
            await tapVisible(tester, operationToggle(type));
          }
        }

        expect(model.selectedOperations, subset);
        // The selection applies from the next question on, and changing it
        // records no attempt.
        expect(model.current, same(shown));
        expect(model.history, isEmpty);

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
  });
}

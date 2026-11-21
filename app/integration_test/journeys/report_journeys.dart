import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import '../support/helpers.dart';

void reportJourneys() {
  group('report', () {
    testWidgets('marking a question keeps the mark on the device, and '
        'cancelling at the grown-up check sends nothing', (tester) async {
      // A recorder instead of the network: this journey must never reach
      // the real report function, even if it went one step too far.
      final reports = RecordedReports();
      final store = MemoryProgressStore();
      final model = await startHarness(
        tester,
        progress: Progress(
          tier: Tier.easy,
          selectedOperations: {OperationType.algebra},
          seenKinds: [for (final kind in OperationType.values) kind.name],
        ),
        clock: DateTime.now,
        reportClient: reports,
        store: store,
      );
      final question = model.current;

      await tapKey(tester, reportFlagKey);
      expect(find.byKey(reportDialogKey), findsOneWidget);
      expect(model.suspectOf(question), isNotNull);
      await tapKey(tester, reportContinueKey);
      await tapKey(tester, reportOptionKey('wrongAnswer'));
      await tapKey(tester, reportContinueKey);
      expect(find.byKey(reportCheckWordKey), findsOneWidget);
      await tapKey(tester, reportCancelKey);

      expect(find.byKey(reportDialogKey), findsNothing);
      expect(reports.bodies, isEmpty);
      expect(model.suspectOf(question)?.sent, isFalse);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(reportFlagKey),
                matching: find.byType(Icon),
              ),
            )
            .icon,
        Icons.flag,
      );
      await tester.pumpAndSettle();
      final saved = Progress.decode((await store.read(progressKey))!);
      expect(saved.suspects.single.sent, isFalse);
    });
  });
}

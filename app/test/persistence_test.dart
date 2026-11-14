import 'dart:math';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import 'fake_store.dart';

Attempt attempt(int lhs) => Attempt(
  Problem(lhs, 2, OperationType.multiply, lhs * 2),
  firstAnswer: lhs * 2,
  elapsedMs: 900,
  answeredAt: DateTime(2026, 11, 13, 18),
);

List<Object?> storedHistory(FakeStore store) =>
    (jsonDecode(store.values[progressKey]!) as Map)['history'] as List;

void main() {
  group('model', () {
    Future<MathTesterModel> loadModel(FakeStore store) async {
      final loaded = await loadProgress(store);
      final model = MathTesterModel(
        store: store,
        progress: loaded.progress,
        canSave: loaded.canSave,
        initialProblem: const Problem(2, 3, OperationType.plus, 5),
        nextProblem: () => const Problem(6, 3, OperationType.minus, 3),
      );
      addTearDown(model.dispose);
      return model;
    }

    Future<void> answerFive(MathTesterModel model) async {
      for (var i = 0; i < 5; i++) {
        model.setDraftInput('${model.current.result}');
        model.submitAnswer();
        model.generateNextProblem();
      }
      await pumpEventQueue();
    }

    for (final type in OperationType.values) {
      test('the first problem is a saved-selection $type, over 20 seeds', () {
        for (var seed = 0; seed < 20; seed++) {
          final model = MathTesterModel(
            progress: Progress(selectedOperations: {type}),
            random: Random(seed),
          );
          expect(model.current.kind, type, reason: 'seed $seed');
          model.dispose();
        }
      });

      test(
        'a successful retry shows a saved-selection $type problem',
        () async {
          final previous = FlutterError.onError;
          FlutterError.onError = (_) {};
          addTearDown(() => FlutterError.onError = previous);
          for (var seed = 0; seed < 20; seed++) {
            final store = FakeStore({
              progressKey: Progress(selectedOperations: {type}).encode(),
            })..readFailures = 1;
            final loaded = await loadProgress(store);
            final model = MathTesterModel(
              store: store,
              progress: loaded.progress,
              canSave: loaded.canSave,
              random: Random(seed),
            );
            model.handleLifecycle(AppLifecycleState.resumed);
            await pumpEventQueue();
            expect(model.canSave, isTrue);
            expect(model.current.kind, type, reason: 'seed $seed');
            model.dispose();
          }
        },
      );
    }

    test('answers and selection changes are saved', () async {
      final store = FakeStore();
      final model = await loadModel(store);
      await answerFive(model);
      model.toggleOperation(OperationType.plus);
      await pumpEventQueue();

      final saved = Progress.decode(store.values[progressKey]!);
      expect(saved.history, hasLength(5));
      expect(saved.selectedOperations, model.selectedOperations);
      expect(saved.selectedOperations, isNot(contains(OperationType.plus)));
    });

    test('pause and hide flush a write that failed', () async {
      final previous = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = previous);
      final store = FakeStore()..writeFailures = 3;
      final model = await loadModel(store);
      await answerFive(model);
      expect(store.values[progressKey], isNull);

      model.handleLifecycle(AppLifecycleState.hidden);
      await pumpEventQueue();
      expect(store.values[progressKey], isNull);
      model.handleLifecycle(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(Progress.decode(store.values[progressKey]!).history, hasLength(5));
    });

    test(
      'criterion 11: a failed backup keeps "not json" after 5 answers',
      () async {
        final previous = FlutterError.onError;
        FlutterError.onError = (_) {};
        addTearDown(() => FlutterError.onError = previous);
        final store = FakeStore({progressKey: 'not json'})..failBackups = true;
        final model = await loadModel(store);
        expect(model.canSave, isFalse);
        await answerFive(model);
        expect(store.values[progressKey], 'not json');
        expect(store.writes, hasLength(1), reason: 'only the backup attempt');
      },
    );

    test(
      'criterion 11: schemaVersion 99 is unchanged after 5 answers',
      () async {
        const newer = '{"schemaVersion":99,"history":[{"kind":"power"}]}';
        final store = FakeStore({progressKey: newer});
        final model = await loadModel(store);
        expect(model.history, isEmpty);
        await answerFive(model);
        model.handleLifecycle(AppLifecycleState.paused);
        await pumpEventQueue();
        expect(store.values[progressKey], newer);
        expect(store.writes, isEmpty);
      },
    );

    test(
      'criterion 13: history never exceeds 200 in memory or stored',
      () async {
        final store = FakeStore();
        final model = await loadModel(store);
        for (var i = 0; i < 205; i++) {
          model.generateNextProblem();
          expect(model.history.length, lessThanOrEqualTo(200));
        }
        await pumpEventQueue();
        expect(model.history, hasLength(200));
        expect(storedHistory(store), hasLength(200));
      },
    );

    test(
      'changes made in no-write mode give way to a successful retry',
      () async {
        final previous = FlutterError.onError;
        FlutterError.onError = (_) {};
        addTearDown(() => FlutterError.onError = previous);
        final saved = Progress(
          selectedOperations: {OperationType.divide},
          history: [attempt(4)],
        ).encode();
        final store = FakeStore({progressKey: saved})..readFailures = 1;
        final model = await loadModel(store);
        expect(model.canSave, isFalse);

        model.toggleOperation(OperationType.plus);
        await answerFive(model);
        expect(model.history, hasLength(5));
        expect(store.writes, isEmpty);

        model.handleLifecycle(AppLifecycleState.resumed);
        await pumpEventQueue();
        expect(model.canSave, isTrue);
        expect(model.selectedOperations, {OperationType.divide});
        expect(model.history.single.problem.lhs, 4);
        expect(store.values[progressKey], saved);
      },
    );

    test('no-write mode retries the read once, on the first resume', () async {
      final previous = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = previous);
      final saved = Progress(history: [attempt(4)]).encode();
      final store = FakeStore({progressKey: saved})..readFailures = 2;
      final model = await loadModel(store);
      expect(model.canSave, isFalse);

      model.handleLifecycle(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(model.canSave, isFalse, reason: 'the retry failed too');
      model.handleLifecycle(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(store.log.where((call) => call.startsWith('read')), hasLength(2));
      expect(model.canSave, isFalse);
      expect(store.writes, isEmpty);
    });
  });

  group('bootstrap', () {
    testWidgets(
      'criterion 15: saved selection and history in the first frame',
      (tester) async {
        final store = FakeStore({
          progressKey: Progress(
            tier: Tier.easy,
            selectedOperations: {OperationType.minus, OperationType.divide},
            history: [attempt(3), attempt(4), attempt(5)],
          ).encode(),
        });

        await bootstrap(store);
        await tester.pump();

        for (final type in OperationType.values) {
          final selected =
              type == OperationType.minus || type == OperationType.divide;
          expect(
            tester.getSemantics(find.bySemanticsLabel(type.label)),
            matchesSemantics(
              label: type.label,
              isButton: true,
              hasTapAction: true,
              hasFocusAction: true,
              isFocusable: true,
              hasEnabledState: true,
              isEnabled: true,
              hasSelectedState: true,
              isSelected: selected,
            ),
          );
        }
        // The results page is one tap away; its count is there in that frame.
        await tester.tap(find.byKey(myAnswersNavKey));
        await tester.pump();
        expect(
          tester.widget<Text>(find.byKey(historyCountKey)).data,
          startsWith('3 '),
        );
        expect(store.log.first, 'read $progressKey');
        expect(store.writes, isEmpty);
      },
    );

    testWidgets('a second bootstrap shows the second store\'s history', (
      tester,
    ) async {
      await bootstrap(
        FakeStore({
          progressKey: Progress(
            tier: Tier.easy,
            history: [attempt(3)],
          ).encode(),
        }),
      );
      await tester.pump();
      await bootstrap(
        FakeStore({
          progressKey: Progress(
            tier: Tier.easy,
            history: [attempt(8), attempt(9)],
          ).encode(),
        }),
      );
      await tester.pump();

      final model = tester
          .element(find.byKey(homePageKey))
          .read<MathTesterModel>();
      expect(model.history.map((a) => a.problem.lhs), [8, 9]);
      await tester.tap(find.byKey(myAnswersNavKey));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(historyCountKey)).data,
        startsWith('2 '),
      );
    });

    testWidgets('criterion 11: the backup is written before the first frame', (
      tester,
    ) async {
      final store = FakeStore({progressKey: 'not json'});
      await bootstrap(store);
      expect(
        store.values.keys.where((k) => k.startsWith(unreadableKeyPrefix)),
        hasLength(1),
      );
      expect(tester.takeException(), isA<FormatException>());
      await tester.pump();
      expect(find.byKey(cantSaveNoticeKey), findsNothing);
    });

    testWidgets(
      'criterion 12: a failing read shows the notice; a resume loads',
      (tester) async {
        final store = FakeStore({
          progressKey: Progress(
            tier: Tier.easy,
            history: [attempt(7)],
          ).encode(),
        })..readFailures = 1;

        await bootstrap(store);
        await tester.pump();
        expect(tester.takeException(), isA<StateError>());
        expect(find.byKey(cantSaveNoticeKey), findsOneWidget);

        final model = tester
            .element(find.byKey(homePageKey))
            .read<MathTesterModel>();
        expect(model.history, isEmpty);
        model.generateNextProblem();
        await tester.pump();
        expect(store.writes, isEmpty);

        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        expect(find.byKey(cantSaveNoticeKey), findsNothing);
        expect(model.history.single.problem.lhs, 7);

        model.generateNextProblem();
        await tester.pump();
        expect(store.writes, hasLength(1));
        expect(storedHistory(store), hasLength(2));
      },
    );
  });
}

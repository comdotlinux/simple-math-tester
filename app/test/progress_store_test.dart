import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';

import 'fake_store.dart';

List<FlutterErrorDetails> captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}

void main() {
  DateTime clock() => DateTime.utc(2026, 11, 14, 9);

  Iterable<String> backupKeys(FakeStore store) =>
      store.values.keys.where((key) => key.startsWith(unreadableKeyPrefix));

  test('an empty store loads defaults and allows saving', () async {
    final loaded = await loadProgress(FakeStore());
    expect(loaded.canSave, isTrue);
    expect(loaded.progress.history, isEmpty);
  });

  test('a saved document loads', () async {
    final saved = Progress(selectedOperations: {OperationType.plus});
    final loaded = await loadProgress(FakeStore({progressKey: saved.encode()}));
    expect(loaded.canSave, isTrue);
    expect(loaded.progress.selectedOperations, {OperationType.plus});
  });

  group('criterion 11:', () {
    test('"not json" is backed up to a new key each time', () async {
      final errors = captureErrors();
      final store = FakeStore({progressKey: 'not json'});

      final loaded = await loadProgress(store, clock: clock);
      expect(loaded.canSave, isTrue);
      expect(loaded.progress.history, isEmpty);
      expect(errors, hasLength(1));
      final first = backupKeys(store).single;
      expect(store.values[first], 'not json');

      // A second failure in the same millisecond still gets its own key.
      store.values[progressKey] = 'not json either';
      await loadProgress(store, clock: clock);
      expect(backupKeys(store), hasLength(2));
      expect(store.values[first], 'not json');
      expect(store.values[backupKeys(store).last], 'not json either');
    });

    test('a known field of the wrong type takes the backup path', () async {
      captureErrors();
      const source = '{"schemaVersion": 1, "history": "abc"}';
      final store = FakeStore({progressKey: source});
      final loaded = await loadProgress(store, clock: clock);
      expect(loaded.canSave, isTrue);
      expect(store.values[backupKeys(store).single], source);
    });

    test('a failed backup write enters no-write mode', () async {
      final errors = captureErrors();
      final store = FakeStore({progressKey: 'not json'})..failBackups = true;
      final loaded = await loadProgress(store, clock: clock);
      expect(loaded.canSave, isFalse);
      expect(errors, hasLength(1));
      expect(store.values[progressKey], 'not json');
    });

    test(
      'a newer schemaVersion enters no-write mode and reports nothing',
      () async {
        final errors = captureErrors();
        final store = FakeStore({progressKey: '{"schemaVersion":99}'});
        final loaded = await loadProgress(store, clock: clock);
        expect(loaded.canSave, isFalse);
        expect(loaded.progress.history, isEmpty);
        expect(errors, isEmpty);
        expect(store.writes, isEmpty);
      },
    );
  });

  test('criterion 12: a read that throws is reported; no-write mode', () async {
    final errors = captureErrors();
    final store = FakeStore()..readFailures = 1;
    final loaded = await loadProgress(store);
    expect(loaded.canSave, isFalse);
    expect(loaded.progress.history, isEmpty);
    expect(errors, hasLength(1));
    expect(store.writes, isEmpty);
  });

  group('criterion 14:', () {
    test(
      'ten saves during a held write give 2 writes, the last snapshot',
      () async {
        final store = FakeStore()..holdWrites = Completer();
        final writer = ProgressWriter(store);
        for (var i = 1; i <= 10; i++) {
          writer.save('snapshot $i');
        }
        await pumpEventQueue();
        expect(store.writes, hasLength(1));
        expect(store.values, isEmpty);

        store.holdWrites!.complete();
        await pumpEventQueue();
        expect(store.writes, hasLength(2));
        expect(store.values[progressKey], 'snapshot 10');
      },
    );

    test(
      'a write that throws once is reported once; the next save writes',
      () async {
        final errors = captureErrors();
        final store = FakeStore()..writeFailures = 1;
        final writer = ProgressWriter(store);
        writer.save('snapshot 1');
        await pumpEventQueue();
        expect(errors, hasLength(1));
        writer.save('snapshot 2');
        await pumpEventQueue();
        expect(store.values[progressKey], 'snapshot 2');
        expect(errors, hasLength(1));
      },
    );

    test(
      'failures are reported once per session and retried by a flush',
      () async {
        final errors = captureErrors();
        final store = FakeStore()..writeFailures = 2;
        final writer = ProgressWriter(store);

        writer.save('snapshot 1');
        await pumpEventQueue();
        expect(errors, hasLength(1));
        expect(store.values, isEmpty);

        writer.save('snapshot 2');
        await pumpEventQueue();
        expect(errors, hasLength(1), reason: 'reported once per session');
        expect(store.values, isEmpty);

        writer.flush();
        await pumpEventQueue();
        expect(store.values[progressKey], 'snapshot 2');
        expect(store.writes, hasLength(3));
      },
    );

    test(
      'a newer snapshot waiting behind a failed write is written at once',
      () async {
        final errors = captureErrors();
        final store = FakeStore()
          ..holdWrites = Completer()
          ..writeFailures = 1;
        final writer = ProgressWriter(store);
        writer.save('A');
        await pumpEventQueue();
        writer.save('B');
        store.holdWrites!.complete();
        await pumpEventQueue();
        expect(store.values[progressKey], 'B');
        expect(store.writes, hasLength(2));
        expect(errors, hasLength(1));
      },
    );

    test('a store whose every write throws is not retried in a loop', () async {
      final errors = captureErrors();
      final store = FakeStore()
        ..holdWrites = Completer()
        ..writeFailures = 1000;
      final writer = ProgressWriter(store);
      writer.save('A');
      await pumpEventQueue();
      writer.save('B');
      store.holdWrites!.complete();
      await pumpEventQueue();
      expect(store.writes, hasLength(2), reason: 'A, then B once');
      expect(errors, hasLength(1));

      writer.flush();
      await pumpEventQueue();
      expect(store.writes, hasLength(3), reason: 'B once more, then stop');
      expect(store.values, isEmpty);
    });

    test('a flush retries the waiting snapshot of a failed write', () async {
      captureErrors();
      final store = FakeStore()..writeFailures = 1;
      final writer = ProgressWriter(store);
      writer.save('snapshot 1');
      await pumpEventQueue();
      writer.flush();
      await pumpEventQueue();
      expect(store.values[progressKey], 'snapshot 1');
    });
  });
}

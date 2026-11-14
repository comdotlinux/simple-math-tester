import 'dart:async';

import 'package:simple_math_tester/progress_store.dart';

/// A memory store whose reads and writes can fail or be held open, and
/// which logs every call in order.
class FakeStore extends MemoryProgressStore {
  FakeStore([super.values]);

  final log = <String>[];
  int readFailures = 0;
  int writeFailures = 0;
  bool failBackups = false;
  Completer<void>? holdWrites;

  List<String> get writes =>
      log.where((call) => call.startsWith('write ')).toList();

  @override
  Future<String?> read(String key) async {
    log.add('read $key');
    if (readFailures > 0) {
      readFailures--;
      throw StateError('read failed');
    }
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    log.add('write $key');
    await holdWrites?.future;
    if (writeFailures > 0) {
      writeFailures--;
      throw StateError('write failed');
    }
    if (failBackups && key.startsWith(unreadableKeyPrefix)) {
      throw StateError('backup failed');
    }
    await super.write(key, value);
  }
}

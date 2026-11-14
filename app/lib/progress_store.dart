import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';

const progressKey = 'progress';
const unreadableKeyPrefix = 'progress.unreadable.';

abstract class ProgressStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesStore implements ProgressStore {
  // Created on first use: the constructor needs the platform plugin.
  late final _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore([Map<String, String>? values]) : values = values ?? {};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// The result of reading saved progress at start-up or on a retry.
/// [canSave] false is no-write mode: the stored data must not be replaced.
typedef LoadedProgress = ({Progress progress, bool canSave});

/// Reads and decodes the saved progress. An undecodable document is first
/// copied to a new `progress.unreadable.<epochMs>` key, so it is never lost.
Future<LoadedProgress> loadProgress(
  ProgressStore store, {
  DateTime Function() clock = DateTime.now,
}) async {
  final String? raw;
  try {
    raw = await store.read(progressKey);
  } catch (error, stack) {
    _report(error, stack, 'reading saved progress');
    return (progress: Progress(), canSave: false);
  }
  if (raw == null) return (progress: Progress(), canSave: true);

  try {
    return (progress: Progress.decode(raw), canSave: true);
  } on NewerProgressException {
    return (progress: Progress(), canSave: false);
  } catch (error, stack) {
    try {
      var ms = clock().millisecondsSinceEpoch;
      while (await store.read('$unreadableKeyPrefix$ms') != null) {
        ms++;
      }
      await store.write('$unreadableKeyPrefix$ms', raw);
    } catch (backupError, backupStack) {
      _report(backupError, backupStack, 'backing up unreadable progress');
      return (progress: Progress(), canSave: false);
    }
    _report(error, stack, 'decoding saved progress');
    return (progress: Progress(), canSave: true);
  }
}

/// Writes one snapshot at a time. A snapshot saved while a write is in
/// flight replaces any waiting one, so only the latest is written next.
class ProgressWriter {
  ProgressWriter(this._store);

  final ProgressStore _store;
  String? _waiting;
  bool _writing = false;
  bool _reported = false;

  void save(String snapshot) {
    _waiting = snapshot;
    flush();
  }

  /// Writes the waiting snapshot, if any; also retries a failed write.
  Future<void> flush() async {
    if (_writing) return;
    _writing = true;
    try {
      while (_waiting != null) {
        final snapshot = _waiting!;
        _waiting = null;
        try {
          await _store.write(progressKey, snapshot);
        } catch (error, stack) {
          if (!_reported) {
            _reported = true;
            _report(error, stack, 'saving progress');
          }
          // A newer snapshot gets one attempt now; a failed one waits for
          // the next save or flush, so a broken store cannot spin.
          if (_waiting != null) continue;
          _waiting = snapshot;
          return;
        }
      }
    } finally {
      _writing = false;
    }
  }
}

void _report(Object error, StackTrace stack, String context) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'simple_math_tester',
      context: ErrorDescription('while $context'),
    ),
  );
}

import 'dart:convert';

import 'operations.dart';

/// The stored document was written by a newer build; it must not be replaced.
class NewerProgressException implements Exception {
  const NewerProgressException(this.schemaVersion);

  final int schemaVersion;

  @override
  String toString() =>
      'Saved progress has schema version $schemaVersion, '
      'newer than ${Progress.schemaVersion}.';
}

/// Everything the app saves, as one immutable JSON document.
///
/// Decoding never drops data written by another build: unknown top-level
/// fields, unknown operation names in the selection and history entries of
/// an unknown kind are kept and encoded again unchanged.
class Progress {
  Progress({
    Set<OperationType>? selectedOperations,
    List<Attempt> history = const [],
  }) : this._(
         selectedOperations ?? OperationType.values.toSet(),
         const [],
         history,
         const {},
       );

  Progress._(
    Set<OperationType> selected,
    List<String> unknownSelected,
    List<Object> entries,
    Map<String, Object?> extra,
  ) : selectedOperations = Set.unmodifiable(
        selected.isEmpty ? OperationType.values : selected,
      ),
      _unknownSelected = List.unmodifiable(unknownSelected),
      _entries = List.unmodifiable(_capped(entries)),
      extra = Map.unmodifiable(extra) {
    history = List.unmodifiable(_entries.whereType<Attempt>());
  }

  static const schemaVersion = 1;
  static const historyCap = 200;

  /// Never empty: a selection with no known operation falls back to all.
  final Set<OperationType> selectedOperations;

  /// The last [historyCap] attempts this build knows, oldest first.
  late final List<Attempt> history;

  /// Top-level fields this build does not know, written back unchanged.
  final Map<String, Object?> extra;

  final List<String> _unknownSelected;

  /// [Attempt]s and raw history entries of unknown kinds, in stored order.
  final List<Object> _entries;

  Progress withAttempt(Attempt attempt) => Progress._(
    selectedOperations,
    _unknownSelected,
    [..._entries, attempt],
    extra,
  );

  Progress withSelectedOperations(Set<OperationType> selected) =>
      Progress._(selected, _unknownSelected, _entries, extra);

  /// Drops the oldest attempts beyond [historyCap]; unknown entries stay.
  static List<Object> _capped(List<Object> entries) {
    var excess = entries.whereType<Attempt>().length - historyCap;
    if (excess <= 0) return entries;
    return [
      for (final entry in entries)
        if (entry is! Attempt || excess-- <= 0) entry,
    ];
  }

  String encode() => jsonEncode({
    ...extra,
    'schemaVersion': schemaVersion,
    'selectedOperations': [
      for (final type in OperationType.values)
        if (selectedOperations.contains(type)) type.name,
      ..._unknownSelected,
    ],
    'history': [
      for (final entry in _entries)
        entry is Attempt ? _encodeAttempt(entry) : entry,
    ],
  });

  /// Throws [NewerProgressException] for a document of a newer schema and
  /// [FormatException] for anything else this build cannot read.
  static Progress decode(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, Object?>) {
      throw FormatException('Saved progress is not a JSON object', source);
    }
    final version = _field<int>(json, 'schemaVersion') ?? schemaVersion;
    if (version > schemaVersion) throw NewerProgressException(version);

    final selected = <OperationType>{};
    final unknownSelected = <String>[];
    for (final name
        in _field<List<Object?>>(json, 'selectedOperations') ??
            OperationType.values.map((type) => type.name)) {
      if (name is! String) {
        throw FormatException('selectedOperations holds a non-string', name);
      }
      final type = _kinds[name];
      type == null ? unknownSelected.add(name) : selected.add(type);
    }

    final entries = <Object>[];
    for (final entry in _field<List<Object?>>(json, 'history') ?? const []) {
      if (entry is! Map<String, Object?>) {
        throw FormatException('history holds a non-object', entry);
      }
      final kind = _kinds[_required<String>(entry, 'kind')];
      entries.add(kind == null ? entry : _decodeAttempt(entry, kind));
    }

    const known = {'schemaVersion', 'selectedOperations', 'history'};
    return Progress._(selected, unknownSelected, entries, {
      for (final MapEntry(:key, :value) in json.entries)
        if (!known.contains(key)) key: value,
    });
  }

  static final _kinds = OperationType.values.asNameMap();

  static Map<String, Object?> _encodeAttempt(Attempt attempt) => {
    'lhs': attempt.problem.lhs,
    'rhs': attempt.problem.rhs,
    'kind': attempt.problem.kind.name,
    'result': attempt.problem.result,
    'level': attempt.problem.level,
    'firstAnswer': attempt.firstAnswer,
    'elapsedMs': attempt.elapsedMs,
    'hintsUsed': attempt.hintsUsed,
    'answeredAt': attempt.answeredAt.toUtc().toIso8601String(),
    'sprint': attempt.sprint,
  };

  static Attempt _decodeAttempt(Map<String, Object?> json, OperationType kind) {
    final answeredAt = DateTime.parse(_required<String>(json, 'answeredAt'));
    return Attempt(
      Problem(
        _required<int>(json, 'lhs'),
        _required<int>(json, 'rhs'),
        kind,
        _required<num>(json, 'result'),
        level: _field<int>(json, 'level') ?? 1,
      ),
      firstAnswer: _field<num>(json, 'firstAnswer'),
      elapsedMs: _field<int>(json, 'elapsedMs') ?? 0,
      hintsUsed: _field<int>(json, 'hintsUsed') ?? 0,
      answeredAt: answeredAt.toLocal(),
      sprint: _field<bool>(json, 'sprint') ?? false,
    );
  }

  /// Null when absent; a value of another type is a decode failure.
  static T? _field<T extends Object>(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null || value is T) return value as T?;
    throw FormatException('$key is not a $T', value);
  }

  static T _required<T extends Object>(Map<String, Object?> json, String key) =>
      _field<T>(json, key) ?? (throw FormatException('$key is missing'));
}

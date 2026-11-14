import 'dart:convert';

import 'operations.dart';
import 'rules.dart';

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
/// fields, unknown operation names in the selection, per-operation entries
/// and history entries of an unknown kind are kept and encoded again
/// unchanged.
class Progress {
  Progress({
    Set<OperationType>? selectedOperations,
    List<Attempt> history = const [],
    Tier? tier,
    Map<OperationType, Difficulty> difficulty = const {},
  }) : this._(
         selectedOperations ?? OperationType.values.toSet(),
         const [],
         history,
         tier,
         difficulty,
         const {},
         const {},
       );

  Progress._(
    Set<OperationType> selected,
    List<String> unknownSelected,
    List<Object> entries,
    this.tier,
    Map<OperationType, Difficulty> difficulty,
    Map<String, Object?> unknownOperations,
    Map<String, Object?> extra,
  ) : selectedOperations = Set.unmodifiable(
        selected.isEmpty ? OperationType.values : selected,
      ),
      _unknownSelected = List.unmodifiable(unknownSelected),
      _entries = List.unmodifiable(_capped(entries)),
      difficulty = Map.unmodifiable({
        for (final type in OperationType.values)
          type: difficulty[type] ?? const Difficulty(),
      }),
      _unknownOperations = Map.unmodifiable(unknownOperations),
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

  /// Absent until the player picks one.
  final Tier? tier;

  /// Every known operation's level, counters and totals.
  final Map<OperationType, Difficulty> difficulty;

  final List<String> _unknownSelected;

  /// [Attempt]s and raw history entries of unknown kinds, in stored order.
  final List<Object> _entries;

  /// Raw per-operation entries of unknown kinds, by kind name.
  final Map<String, Object?> _unknownOperations;

  Progress withAttempt(Attempt attempt) =>
      _copy(entries: [..._entries, attempt]);

  Progress withSelectedOperations(Set<OperationType> selected) =>
      _copy(selected: selected);

  Progress withDifficulty(OperationType type, Difficulty value) =>
      _copy(difficulty: {...difficulty, type: value});

  /// Sets [tier] and resets every known operation to its level.
  Progress withTier(Tier tier) => _copy(
    tier: tier,
    difficulty: difficulty.map(
      (type, value) => MapEntry(type, value.atTier(tier)),
    ),
  );

  Progress _copy({
    Set<OperationType>? selected,
    List<Object>? entries,
    Tier? tier,
    Map<OperationType, Difficulty>? difficulty,
  }) => Progress._(
    selected ?? selectedOperations,
    _unknownSelected,
    entries ?? _entries,
    tier ?? this.tier,
    difficulty ?? this.difficulty,
    _unknownOperations,
    extra,
  );

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
    'operations': {
      for (final MapEntry(:key, :value) in difficulty.entries)
        key.name: _encodeDifficulty(value),
      ..._unknownOperations,
    },
    'tier': ?tier?.name,
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

    final difficulty = <OperationType, Difficulty>{};
    final unknownOperations = <String, Object?>{};
    for (final MapEntry(:key, :value)
        in (_field<Map<String, Object?>>(json, 'operations') ?? const {})
            .entries) {
      final kind = _kinds[key];
      if (kind == null) {
        unknownOperations[key] = value;
      } else if (value is Map<String, Object?>) {
        difficulty[kind] = _decodeDifficulty(value);
      } else {
        throw FormatException('operations.$key is not an object', value);
      }
    }

    // A tier name this build does not know asks the player again.
    final tier = Tier.values.asNameMap()[_field<String>(json, 'tier')];

    const known = {
      'schemaVersion',
      'selectedOperations',
      'history',
      'operations',
      'tier',
    };
    return Progress._(
      selected,
      unknownSelected,
      entries,
      tier,
      difficulty,
      unknownOperations,
      {
        for (final MapEntry(:key, :value) in json.entries)
          if (!known.contains(key)) key: value,
      },
    );
  }

  static Map<String, Object?> _encodeDifficulty(Difficulty value) => {
    'level': value.level,
    'upCount': value.upCount,
    'downCount': value.downCount,
    'answered': value.answered,
    'correct': value.correct,
  };

  static Difficulty _decodeDifficulty(Map<String, Object?> json) => Difficulty(
    // A level outside the table would have no ranges to draw from.
    level: (_field<int>(json, 'level') ?? 1).clamp(1, maxLevel),
    upCount: _field<int>(json, 'upCount') ?? 0,
    downCount: _field<int>(json, 'downCount') ?? 0,
    answered: _field<int>(json, 'answered') ?? 0,
    correct: _field<int>(json, 'correct') ?? 0,
  );

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

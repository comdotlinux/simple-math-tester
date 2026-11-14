import 'dart:math';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';

import 'operations.dart';
import 'progress.dart';
import 'progress_store.dart';
import 'rules.dart';
import 'solution_steps.dart';

class MathTesterModel extends ChangeNotifier {
  MathTesterModel({
    Problem? initialProblem,
    this.nextProblem,
    Random? random,
    DateTime Function()? clock,
    ProgressStore? store,
    Progress? progress,
    this._canSave = true,
  }) : _random = random ?? Random(),
       _clock = clock ?? DateTime.now,
       _store = store ?? MemoryProgressStore(),
       _progress = progress ?? Progress() {
    _show(initialProblem ?? _draw());
  }

  final Random _random;
  final DateTime Function() _clock;
  final ProgressStore _store;
  late final _writer = ProgressWriter(_store);
  Progress _progress;
  bool _canSave;
  bool _retried = false;
  @visibleForTesting
  final Problem Function()? nextProblem;

  late Problem _current;
  late List<String> _steps;
  late DateTime _shownAt;
  late bool _checked;
  late int _revealed;
  String _draftInput = '';
  String? _validationMessage;
  bool? _answerCorrect;
  int _currentPage = 0;

  Problem get current => _current;

  /// Solution steps of the current problem; the first [revealedSteps] show.
  List<String> get steps => _steps;
  int get revealedSteps => _revealed;
  bool get canRevealStep => _nextRevealed(HintEvent.reveal) > _revealed;

  /// Replaced, never mutated, so `context.select` sees every change.
  List<Attempt> get history => _progress.history;
  Set<OperationType> get selectedOperations => _progress.selectedOperations;

  /// Null until the player picks a starting tier.
  Tier? get tier => _progress.tier;
  Map<OperationType, Difficulty> get difficulty => _progress.difficulty;

  /// False in no-write mode: saved data could not be read, so it is kept.
  bool get canSave => _canSave;
  String get draftInput => _draftInput;
  String? get validationMessage => _validationMessage;
  bool? get answerCorrect => _answerCorrect;
  int get currentPage => _currentPage;

  void setDraftInput(String value) {
    _draftInput = value;
    _validationMessage = null;
    _answerCorrect = null;
    notifyListeners();
  }

  bool submitAnswer() {
    final input = double.tryParse(_draftInput.trim());
    if (input == null || !input.isFinite) {
      _validationMessage = _draftInput.trim().isEmpty
          ? 'Enter a number first.'
          : 'Use a number for your answer.';
      _answerCorrect = null;
      notifyListeners();
      return false;
    }

    final firstCheck = !_checked;
    _record(input);
    _validationMessage = null;
    _answerCorrect = input == _current.result;
    if (firstCheck && !_answerCorrect!) {
      _revealed = _nextRevealed(HintEvent.wrongFirstCheck);
    }
    notifyListeners();
    return true;
  }

  void generateNextProblem() {
    _record(null);
    _showNext();
    notifyListeners();
  }

  /// The "Hint" and "Next step" controls.
  void revealStep() {
    if (!canRevealStep) return;
    _revealed = _nextRevealed(HintEvent.reveal);
    notifyListeners();
  }

  /// Refuses to deselect the last selected operation. The problem on screen
  /// is kept; the selection applies from the next problem.
  void toggleOperation(OperationType type) {
    final selected = selectedOperations;
    if (!selected.contains(type)) {
      _progress = _progress.withSelectedOperations({...selected, type});
    } else if (selected.length > 1) {
      _progress = _progress.withSelectedOperations(
        selected.where((kind) => kind != type).toSet(),
      );
    } else {
      return;
    }
    _save();
    notifyListeners();
  }

  /// Sets every operation to the tier's level and shows a new problem at
  /// that level; the replaced problem is not recorded.
  void chooseTier(Tier tier) {
    _progress = _progress.withTier(tier);
    _save();
    _showNext();
    notifyListeners();
  }

  void setCurrentPage(int value) {
    RangeError.checkValueInInterval(value, 0, 1, 'page');
    _currentPage = value;
    notifyListeners();
  }

  /// Flushes saves when the app goes to the background; in no-write mode
  /// the first resume tries to read the saved progress once more.
  void handleLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        if (_canSave) _writer.flush();
      case AppLifecycleState.resumed when !_canSave && !_retried:
        _retried = true;
        _retryLoad();
      default:
    }
  }

  Future<void> _retryLoad() async {
    final loaded = await loadProgress(_store, clock: _clock);
    if (!loaded.canSave) return;
    _progress = loaded.progress;
    _canSave = true;
    // The problem on screen came from the default selection; it is not
    // recorded, as after any reload.
    _showNext();
    notifyListeners();
  }

  void _save() {
    if (_canSave) _writer.save(_progress.encode());
  }

  /// A problem of one of the selected operations, at that operation's level.
  Problem _draw() {
    if (nextProblem case final next?) return next();
    final kinds = OperationType.values.where(selectedOperations.contains);
    final kind = kinds.elementAt(_random.nextInt(kinds.length));
    return kind.generate(_random, difficulty[kind]!.level);
  }

  void _showNext() {
    _show(_draw());
    _draftInput = '';
    _validationMessage = null;
    _answerCorrect = null;
  }

  void _show(Problem problem) {
    _current = problem;
    _steps = solutionSteps(problem);
    _shownAt = _clock();
    _checked = false;
    _revealed = 0;
  }

  int _nextRevealed(HintEvent event) => nextRevealed(
    revealed: _revealed,
    event: event,
    stepCount: _steps.length,
    checked: _checked,
  );

  void _record(num? answer) {
    final now = _clock();
    final attempt = historyEntry(
      problem: _current,
      alreadyChecked: _checked,
      answer: answer,
      hintsUsed: _revealed,
      elapsedMs: now.difference(_shownAt).inMilliseconds,
      at: now,
    );
    _checked = true;
    if (attempt == null) return;
    final kind = attempt.problem.kind;
    _progress = _progress
        .withAttempt(attempt)
        .withDifficulty(kind, difficultyAfter(difficulty[kind]!, attempt));
    _save();
  }
}

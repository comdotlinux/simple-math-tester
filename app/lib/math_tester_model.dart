import 'dart:math';

import 'package:flutter/foundation.dart';

import 'operations.dart';
import 'rules.dart';
import 'solution_steps.dart';

class MathTesterModel extends ChangeNotifier {
  MathTesterModel({
    Problem? initialProblem,
    this.nextProblem,
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random(),
       _clock = clock ?? DateTime.now {
    _show(initialProblem ?? OperationType.plus.generate(_random));
  }

  final Random _random;
  final DateTime Function() _clock;
  @visibleForTesting
  final Problem Function()? nextProblem;

  late Problem _current;
  late List<String> _steps;
  late DateTime _shownAt;
  late bool _checked;
  late int _revealed;
  List<Attempt> _history = List.unmodifiable(const <Attempt>[]);
  Set<OperationType> _selectedOperations = Set.unmodifiable(
    OperationType.values,
  );
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
  List<Attempt> get history => _history;
  Set<OperationType> get selectedOperations => _selectedOperations;
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
    final kinds = OperationType.values.where(_selectedOperations.contains);
    _show(
      nextProblem?.call() ??
          kinds.elementAt(_random.nextInt(kinds.length)).generate(_random),
    );
    _draftInput = '';
    _validationMessage = null;
    _answerCorrect = null;
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
    if (!_selectedOperations.contains(type)) {
      _selectedOperations = Set.unmodifiable({..._selectedOperations, type});
    } else if (_selectedOperations.length > 1) {
      _selectedOperations = Set.unmodifiable(
        _selectedOperations.where((selected) => selected != type),
      );
    } else {
      return;
    }
    notifyListeners();
  }

  void setCurrentPage(int value) {
    RangeError.checkValueInInterval(value, 0, 1, 'page');
    _currentPage = value;
    notifyListeners();
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
    if (attempt != null) _history = List.unmodifiable([..._history, attempt]);
  }
}

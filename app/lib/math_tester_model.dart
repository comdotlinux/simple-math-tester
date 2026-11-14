import 'dart:math';

import 'package:flutter/foundation.dart';

import 'operations.dart';
import 'rules.dart';

class MathTesterModel extends ChangeNotifier {
  MathTesterModel({
    Problem? initialProblem,
    this.nextProblem,
    Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? Random(),
       _clock = clock ?? DateTime.now {
    _current = initialProblem ?? OperationType.plus.generate(_random);
    _shownAt = _clock();
  }

  final Random _random;
  final DateTime Function() _clock;
  @visibleForTesting
  final Problem Function()? nextProblem;

  late Problem _current;
  late DateTime _shownAt;
  bool _checked = false;
  List<Attempt> _history = List.unmodifiable(const <Attempt>[]);
  String _draftInput = '';
  String? _validationMessage;
  bool? _answerCorrect;
  int _currentPage = 0;

  Problem get current => _current;

  /// Replaced, never mutated, so `context.select` sees every change.
  List<Attempt> get history => _history;
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

    _record(input);
    _validationMessage = null;
    _answerCorrect = input == _current.result;
    notifyListeners();
    return true;
  }

  void generateNextProblem() {
    _record(null);
    _current =
        nextProblem?.call() ??
        OperationType.values[_random.nextInt(OperationType.values.length)]
            .generate(_random);
    _shownAt = _clock();
    _checked = false;
    _draftInput = '';
    _validationMessage = null;
    _answerCorrect = null;
    notifyListeners();
  }

  void setCurrentPage(int value) {
    RangeError.checkValueInInterval(value, 0, 1, 'page');
    _currentPage = value;
    notifyListeners();
  }

  void _record(num? answer) {
    final now = _clock();
    final attempt = historyEntry(
      problem: _current,
      alreadyChecked: _checked,
      answer: answer,
      elapsedMs: now.difference(_shownAt).inMilliseconds,
      at: now,
    );
    _checked = true;
    if (attempt != null) _history = List.unmodifiable([..._history, attempt]);
  }
}

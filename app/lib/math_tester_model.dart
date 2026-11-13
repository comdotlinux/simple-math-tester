import 'dart:math';

import 'package:flutter/foundation.dart';

import 'operations.dart';

class MathTesterModel extends ChangeNotifier {
  MathTesterModel({Operation? initialOperation, this.nextOperation})
    : current = initialOperation ?? Addition().create();

  final Map<OperationType, Operator> operators = {
    OperationType.plus: Addition(),
    OperationType.minus: Subtraction(),
    OperationType.multiply: Multiplication(),
    OperationType.divide: Division(),
  };
  final _random = Random();
  @visibleForTesting
  final Operation Function()? nextOperation;
  final completedProblems = <Operation>{};

  Operation current;
  String _draftInput = '';
  String? _validationMessage;
  bool? _answerCorrect;
  int _currentPage = 0;

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

    current.input = input;
    _validationMessage = null;
    _answerCorrect = current.inputCorrect();
    notifyListeners();
    return true;
  }

  void generateNextProblem() {
    completedProblems.add(current);
    current =
        nextOperation?.call() ??
        operators[OperationType.of(_random.nextInt(operators.length))]!
            .create();
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
}

import 'dart:math';

import 'package:duration/duration.dart';
import 'package:flutter/material.dart';

enum OperationType {
  plus('+', 0),
  minus('-', 1),
  multiply('*', 2),
  divide('/', 3);

  final String displayString;
  final int operationIndex;

  const OperationType(this.displayString, this.operationIndex);

  static OperationType of(int index) => OperationType.values.firstWhere((ot) => ot.operationIndex == index);

  static Operator operator(OperationType operationType) {
    switch (operationType) {
      case OperationType.plus:
        return Addition();
      case OperationType.minus:
        return Subtraction();
      case OperationType.multiply:
        return Multiplication();
      case OperationType.divide:
        return Division();
    }
  }
}

class Operation {
  final double lhs;
  final double rhs;
  final OperationType operationType;
  final double result;
  double? _input;

  String? _elapsed;

  final Stopwatch stopwatch = Stopwatch()..start();

  Operation(this.lhs, this.rhs, this.operationType, this.result);

  double? get input => _input;

  set input(double? value) {
    _input = value;
    stopwatch.stop();
    _elapsed = prettyDuration(stopwatch.elapsed);
  }

  String get left => lhs.toString();

  String get right => rhs.toString();

  bool inputEntered() => _input != null;

  bool inputCorrect() => result == _input;

  String get userInput => (_input?.toString() ?? 'Not Entered');

  String get elapsed => (_elapsed?.toString() ?? 'Not Available');

  List<String> get output => toString().split(' ');

  @override
  String toString() =>
      '$lhs ${operationType.displayString} $rhs Gives $result ${inputCorrect() ? 'and' : 'but'} you entered ${input?.toInt() ?? 'nothing'}. Took ${prettyDuration(stopwatch.elapsed)}';
}

abstract class Operator {
  OperationType operationType();

  double minOperandValue();

  double maxOperandValue();

  double minResultValue();

  double maxResultValue();

  double calculateResult(double lhs, double rhs);

  bool acceptable(Operation operation);

  final _random = Random();

  double _nextValue() {
    double nextValue;
    do {
      nextValue = minOperandValue() + _random.nextInt(maxOperandValue().toInt());
    } while (nextValue > maxOperandValue() || nextValue < minOperandValue());

    return nextValue;
  }

  Operation create() {
    Operation operation;
    do {
      final lhs = _nextValue();
      final rhs = _nextValue();
      operation = Operation(lhs, rhs, operationType(), calculateResult(lhs, rhs));
    } while (operation.result > maxResultValue() ||
        operation.result < minResultValue() ||
        !acceptable(operation));
    debugPrint(operation.toString());
    return operation;
  }
}

class Addition extends Operator {
  @override
  OperationType operationType() => OperationType.plus;

  @override
  double minOperandValue() => 2;

  @override
  double maxOperandValue() => 10000;

  @override
  double minResultValue() => 3;

  @override
  double maxResultValue() => 10000;

  @override
  bool acceptable(Operation operation) => operation.result <= maxResultValue() && operation.result >= minResultValue();

  @override
  double calculateResult(double lhs, double rhs) => lhs + rhs;
}

class Subtraction extends Operator {

  @override
  bool acceptable(Operation operation) => operation.result == operation.result.abs();

  @override
  double calculateResult(double lhs, double rhs) => lhs - rhs;

  @override
  double maxOperandValue() => 10000;

  @override
  double minOperandValue() => 2;

  @override
  double minResultValue() => 0;

  @override
  double maxResultValue() => 10000;

  @override
  OperationType operationType() => OperationType.minus;

}

class Multiplication extends Operator {
  @override
  bool acceptable(Operation operation) => true;

  @override
  double calculateResult(double lhs, double rhs) => lhs * rhs;

  @override
  double minOperandValue() => 2;

  @override
  double maxOperandValue() => 500;

  @override
  double maxResultValue() => 1000;

  @override
  double minResultValue() => 10;

  @override
  OperationType operationType() => OperationType.multiply;
}

class Division extends Operator {
  @override
  bool acceptable(Operation operation) => operation.result is! int;

  @override
  double calculateResult(double lhs, double rhs) => lhs / rhs;

  @override
  double minOperandValue() => 3;

  @override
  double maxOperandValue() => 1000;

  @override
  double minResultValue() => 2;

  @override
  double maxResultValue() => 1000;

  @override
  OperationType operationType() => OperationType.divide;
}

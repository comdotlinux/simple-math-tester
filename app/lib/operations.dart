import 'dart:math';

import 'package:duration/duration.dart';

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

class Operation<P extends num, R extends num> {
  final P lhs;
  final P rhs;
  final OperationType operationType;
  final R result;
  R? _input;

  String? _elapsed;

  final Stopwatch stopwatch = Stopwatch()..start();

  Operation(this.lhs, this.rhs, this.operationType, this.result);

  R? get input => _input;

  set input(R? value) {
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

abstract class Operator<P extends num, R extends num> {
  OperationType operationType();

  P minOperandValue();

  P maxOperandValue();

  R minResultValue();

  R maxResultValue();

  R calculateResult(P lhs, P rhs);

  bool acceptable(Operation<P, R> operation);

  final _random = Random();

  P _nextValue() {
    P nextValue;
    do {
      nextValue = (minOperandValue() + _random.nextInt(maxOperandValue().toInt())) as P;
    } while (nextValue > maxOperandValue() || nextValue < minOperandValue());

    return nextValue;
  }

  Operation<P, R> create() {
    Operation<P, R> operation;
    do {
      final lhs = _nextValue();
      final rhs = _nextValue();
      operation = Operation(lhs, rhs, operationType(), calculateResult(lhs, rhs));
    } while (operation.result > maxResultValue() ||
        operation.result < minResultValue() ||
        !acceptable(operation));
    // debugPrint(operation.toString());
    return operation;
  }
}

class Addition extends Operator<int, int> {
  @override
  OperationType operationType() => OperationType.plus;

  @override
  int minOperandValue() => 2;

  @override
  int maxOperandValue() => 10000;

  @override
  int minResultValue() => 3;

  @override
  int maxResultValue() => 10000;

  @override
  bool acceptable(Operation operation) => operation.result <= maxResultValue() && operation.result >= minResultValue();

  @override
  int calculateResult(int lhs, int rhs) => lhs + rhs;
}

class Subtraction extends Operator<int, int> {

  @override
  bool acceptable(Operation operation) => operation.result == operation.result.abs();

  @override
  int calculateResult(int lhs, int rhs) => lhs - rhs;

  @override
  int maxOperandValue() => 10000;

  @override
  int minOperandValue() => 2;

  @override
  int minResultValue() => 0;

  @override
  int maxResultValue() => 10000;

  @override
  OperationType operationType() => OperationType.minus;

}

class Multiplication extends Operator<int, int> {
  @override
  bool acceptable(Operation operation) => true;

  @override
  int calculateResult(int lhs, int rhs) => lhs * rhs;

  @override
  int minOperandValue() => 2;

  @override
  int maxOperandValue() => 500;

  @override
  int maxResultValue() => 1000;

  @override
  int minResultValue() => 10;

  @override
  OperationType operationType() => OperationType.multiply;
}

class Division extends Operator<int, double> {
  @override
  bool acceptable(Operation operation) => operation.result is int || operation.result == operation.result.toInt();

  @override
  double calculateResult(int lhs, int rhs) => lhs / rhs;

  @override
  int minOperandValue() => 3;

  @override
  int maxOperandValue() => 1000;

  @override
  double minResultValue() => 2;

  @override
  double maxResultValue() => 1000;

  @override
  OperationType operationType() => OperationType.divide;
}

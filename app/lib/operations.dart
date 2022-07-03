import 'dart:math';

import 'package:duration/duration.dart';

enum OperationType {
  plus('+'),
  minus('-'),
  multiply('*'),
  divide('/');

  final String displayString;

  const OperationType(this.displayString);
}

class Operation {
  final int lhs;
  final int rhs;
  final OperationType operationType;
  final double result;
  double? _input;

  late Stopwatch stopwatch = Stopwatch()..start();

  Operation(this.lhs, this.rhs, this.operationType, this.result);

  double? get input => _input;

  set input(double? value) {
    _input = value;
    stopwatch.stop();
  }

  String get left => lhs.toString();

  String get right => rhs.toString();

  bool inputEntered() => _input != null;

  bool inputCorrect() => result == _input;

  List<String> get output => toString().split(' ');

  @override
  String toString() => '$lhs ${operationType.displayString} $rhs Gives $result ${inputCorrect() ? 'and' : 'but'} you entered ${input?.toInt() ?? 'nothing'}. Took ${prettyDuration(stopwatch.elapsed)}';

  @override
  bool operator ==(Object other) => identical(this, other) || other is Operation && runtimeType == other.runtimeType && lhs == other.lhs && rhs == other.rhs && operationType == other.operationType && result == other.result;

  @override
  int get hashCode => lhs.hashCode ^ rhs.hashCode ^ operationType.hashCode ^ result.hashCode;
}

abstract class Operator {
  Operation create();
}

class Addition implements Operator {
  final minValue = 0;
  final maxValue = 100;
  final random = Random();

  @override
  Operation create() {
    Operation operation;
    do {
      final lhs = random.nextInt(maxValue);
      final rhs = random.nextInt(maxValue);
      final result = lhs + rhs;
      operation = Operation(lhs, rhs, OperationType.plus, result.toDouble());
    } while (operation.result > maxValue || operation.result < minValue);
    return operation;
  }
}

class Subtraction implements Operator {
  final minValue = 0;
  final maxValue = 100;
  final random = Random();

  @override
  Operation create() {
    Operation operation;
    do {
      final lhs = random.nextInt(maxValue);
      final rhs = random.nextInt(maxValue);
      final result = lhs - rhs;
      operation = Operation(lhs, rhs, OperationType.minus, result.toDouble());
    } while (operation.result > maxValue || operation.result < minValue);
    return operation;
  }
}

class Multiplication implements Operator {
  final minValue = 0;
  final maxValue = 100;
  final random = Random();

  @override
  Operation create() {
    Operation operation;
    do {
      final lhs = random.nextInt(maxValue);
      final rhs = random.nextInt(maxValue);
      final result = lhs * rhs;
      operation = Operation(lhs, rhs, OperationType.multiply, result.toDouble());
    } while (operation.result > maxValue || operation.result < minValue);
    return operation;
  }
}

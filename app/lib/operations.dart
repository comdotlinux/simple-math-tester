import 'dart:math';

import 'solution_steps.dart';

num _add(int lhs, int rhs) => lhs + rhs;
num _subtract(int lhs, int rhs) => lhs - rhs;
num _multiply(int lhs, int rhs) => lhs * rhs;
num _divide(int lhs, int rhs) => lhs / rhs;

/// The registry of operation kinds: each kind declares its generator ranges,
/// its calculation and its step writer here and nowhere else.
enum OperationType {
  plus('+', 'Addition', 2, 10000, 3, 10000, _add, additionSteps),
  minus('−', 'Subtraction', 2, 10000, 0, 10000, _subtract, subtractionSteps),
  multiply(
    '×',
    'Multiplication',
    2,
    500,
    10,
    1000,
    _multiply,
    multiplicationSteps,
  ),
  divide('÷', 'Division', 3, 1000, 2, 1000, _divide, divisionSteps);

  final String displayString;
  final String label;
  final int minOperand;
  final int maxOperand;
  final num minResult;
  final num maxResult;
  final num Function(int lhs, int rhs) calculate;
  final List<String> Function(Problem problem) steps;

  const OperationType(
    this.displayString,
    this.label,
    this.minOperand,
    this.maxOperand,
    this.minResult,
    this.maxResult,
    this.calculate,
    this.steps,
  );

  /// Draws operands uniformly until the result is a whole number in range.
  Problem generate(Random random) {
    while (true) {
      final lhs = minOperand + random.nextInt(maxOperand - minOperand + 1);
      final rhs = minOperand + random.nextInt(maxOperand - minOperand + 1);
      final result = calculate(lhs, rhs);
      if (result >= minResult &&
          result <= maxResult &&
          result == result.truncate()) {
        return Problem(lhs, rhs, this, result);
      }
    }
  }
}

class Problem {
  const Problem(this.lhs, this.rhs, this.kind, this.result, {this.level = 1});

  final int lhs;
  final int rhs;
  final OperationType kind;
  final num result;
  final int level;

  String get question => '$lhs ${kind.displayString} $rhs';
}

class Attempt {
  const Attempt(
    this.problem, {
    required this.firstAnswer,
    required this.elapsedMs,
    required this.answeredAt,
    this.hintsUsed = 0,
    this.sprint = false,
  });

  final Problem problem;

  /// Null means the problem was skipped.
  final num? firstAnswer;
  final int elapsedMs;
  final DateTime answeredAt;
  final int hintsUsed;
  final bool sprint;

  bool get skipped => firstAnswer == null;

  bool get correct => firstAnswer == problem.result;
}

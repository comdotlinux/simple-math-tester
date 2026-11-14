import 'dart:math';

import 'solution_steps.dart';

num _add(int lhs, int rhs) => lhs + rhs;
num _subtract(int lhs, int rhs) => lhs - rhs;
num _multiply(int lhs, int rhs) => lhs * rhs;
num _divide(int lhs, int rhs) => lhs / rhs;

typedef Range = (int, int);

const maxLevel = 5;

/// The level table, levels 1 to 5: the two operand ranges of addition and
/// subtraction, and the smaller and larger factor ranges of multiplication
/// and division (divisor by quotient).
const List<(Range, Range)> _sumLevels = [
  ((1, 10), (1, 10)),
  ((1, 20), (1, 20)),
  ((10, 100), (10, 100)),
  ((100, 1000), (100, 1000)),
  ((1000, 10000), (1000, 10000)),
];
const List<(Range, Range)> _productLevels = [
  ((2, 5), (2, 5)),
  ((2, 10), (2, 10)),
  ((2, 12), (2, 20)),
  ((2, 20), (11, 50)),
  ((11, 30), (11, 99)),
];

/// The registry of operation kinds: each kind declares its level-table row,
/// its calculation and its step writer here and nowhere else.
enum OperationType {
  plus('+', 'Addition', _sumLevels, _add, additionSteps),
  minus('−', 'Subtraction', _sumLevels, _subtract, subtractionSteps),
  multiply(
    '×',
    'Multiplication',
    _productLevels,
    _multiply,
    multiplicationSteps,
  ),
  divide('÷', 'Division', _productLevels, _divide, divisionSteps);

  final String displayString;
  final String label;

  /// The two ranges drawn from at each level; index 0 is level 1.
  final List<(Range, Range)> levels;
  final num Function(int lhs, int rhs) calculate;
  final List<String> Function(Problem problem) steps;

  const OperationType(
    this.displayString,
    this.label,
    this.levels,
    this.calculate,
    this.steps,
  );

  /// One problem at [level]: subtraction puts the larger operand first and
  /// division is built as divisor times quotient, so every answer is a
  /// whole number of 0 or more.
  Problem generate(Random random, int level) {
    final ((aMin, aMax), (bMin, bMax)) = levels[level - 1];
    final a = aMin + random.nextInt(aMax - aMin + 1);
    final b = bMin + random.nextInt(bMax - bMin + 1);
    final (lhs, rhs) = switch (this) {
      plus => (a, b),
      minus => (max(a, b), min(a, b)),
      multiply => random.nextBool() ? (a, b) : (b, a),
      divide => (a * b, a),
    };
    return Problem(lhs, rhs, this, calculate(lhs, rhs), level: level);
  }
}

/// A whole number without a decimal part ("4", not "4.0"); others as is.
String formatNumber(num value) =>
    value == value.toInt() ? value.toInt().toString() : value.toString();

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

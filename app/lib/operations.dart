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

/// The registry of operation kinds: each kind declares its symbol and the
/// [ProblemSource] that makes and explains its problems, here and nowhere
/// else.
enum OperationType {
  plus('+', ArithmeticSource(_sumLevels, _asDrawn, _add, additionSteps)),
  minus(
    '−',
    ArithmeticSource(_sumLevels, _largerFirst, _subtract, subtractionSteps),
  ),
  multiply(
    '×',
    ArithmeticSource(
      _productLevels,
      _eitherOrder,
      _multiply,
      multiplicationSteps,
    ),
  ),
  divide(
    '÷',
    ArithmeticSource(_productLevels, _productFirst, _divide, divisionSteps),
  );

  final String displayString;
  final ProblemSource<Problem> source;

  const OperationType(this.displayString, this.source);

  /// One problem of this kind at [level], 1 to [maxLevel].
  Problem generate(Random random, int level) =>
      source.generate(this, random, level);

  /// The hint steps of [problem], a problem of this kind.
  List<SolutionStep> steps(Problem problem) => source.steps(problem);
}

/// How one kind makes its problems and explains them. A kind with its own
/// [Problem] subtype brings its own source for that subtype.
abstract class ProblemSource<P extends Problem> {
  const ProblemSource();

  P generate(OperationType kind, Random random, int level);

  List<SolutionStep> steps(P problem);
}

/// Two operands drawn from a level table and combined by one calculation.
class ArithmeticSource extends ProblemSource<ArithmeticProblem> {
  const ArithmeticSource(this.levels, this._order, this.calculate, this._steps);

  /// The two ranges drawn from at each level; index 0 is level 1.
  final List<(Range, Range)> levels;

  /// Turns the two drawn numbers into the operands, in order.
  final (int, int) Function(int a, int b, Random random) _order;
  final num Function(int lhs, int rhs) calculate;
  final List<SolutionStep> Function(ArithmeticProblem problem) _steps;

  /// Subtraction puts the larger operand first and division is built as
  /// divisor times quotient, so every answer is a whole number of 0 or more.
  @override
  ArithmeticProblem generate(OperationType kind, Random random, int level) {
    final ((aMin, aMax), (bMin, bMax)) = levels[level - 1];
    final a = aMin + random.nextInt(aMax - aMin + 1);
    final b = bMin + random.nextInt(bMax - bMin + 1);
    final (lhs, rhs) = _order(a, b, random);
    return ArithmeticProblem(lhs, rhs, kind, calculate(lhs, rhs), level: level);
  }

  @override
  List<SolutionStep> steps(ArithmeticProblem problem) => _steps(problem);
}

(int, int) _asDrawn(int a, int b, Random random) => (a, b);
(int, int) _largerFirst(int a, int b, Random random) => (max(a, b), min(a, b));
(int, int) _eitherOrder(int a, int b, Random random) =>
    random.nextBool() ? (a, b) : (b, a);
(int, int) _productFirst(int a, int b, Random random) => (a * b, a);

/// A whole number without a decimal part ("4", not "4.0"); others as is.
String formatNumber(num value) =>
    value == value.toInt() ? value.toInt().toString() : value.toString();

/// One question. Code that needs a subtype's own fields switches over the
/// subtypes without a default, so a new subtype breaks every such place at
/// compile time.
sealed class Problem {
  const Problem(this.kind, this.result, {this.level = 1});

  final OperationType kind;
  final num result;
  final int level;

  /// The question as text, shown in the history and read by screen readers.
  String get question;
}

class ArithmeticProblem extends Problem {
  const ArithmeticProblem(
    this.lhs,
    this.rhs,
    super.kind,
    super.result, {
    super.level,
  });

  final int lhs;
  final int rhs;

  @override
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

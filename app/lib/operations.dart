import 'dart:math';

import 'figure.dart';
import 'geometry.dart';
import 'hundredths.dart';
import 'solution_steps.dart';

num _add(int lhs, int rhs) => lhs + rhs;
num _subtract(int lhs, int rhs) => lhs - rhs;
num _multiply(int lhs, int rhs) => lhs * rhs;
num _divide(int lhs, int rhs) => lhs / rhs;

typedef Range = (int, int);

/// The highest level of any kind; [OperationType.highestLevel] is each
/// kind's own.
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
  ),

  /// Its sign is the letter n, not a drawn box, which would look like an
  /// empty check box on a toggle.
  algebra('n', AlgebraSource(_algebraLevels, _equations, equationSteps)),

  /// Its sign is the increment sign ∆ (U+2206), a triangle that bundled
  /// Roboto has, so the web build fetches no font for it.
  geometry('∆', GeometrySource(figureSteps));

  final String displayString;
  final ProblemSource<Problem> source;

  const OperationType(this.displayString, this.source);

  /// The highest level this kind has; its difficulty never goes above it.
  int get highestLevel => source.highestLevel;

  /// One problem of this kind at [level], 1 to [highestLevel].
  Problem generate(Random random, int level) =>
      source.generate(this, random, level);

  /// The hint steps of [problem], a problem of this kind.
  List<SolutionStep> steps(Problem problem) => source.steps(problem);

  /// Whether an answer of this kind can be negative or decimal.
  bool get signedDecimalAnswers => source.signedDecimalAnswers;
}

/// The four arithmetic kinds. Only they are on by default (also for a saved
/// selection that is missing or names no known kind), a tier sets only
/// their levels, and a sprint draws only from them.
const arithmeticKinds = {
  OperationType.plus,
  OperationType.minus,
  OperationType.multiply,
  OperationType.divide,
};

/// How one kind makes its problems and explains them. A kind with its own
/// [Problem] subtype brings its own source for that subtype.
sealed class ProblemSource<P extends Problem> {
  const ProblemSource();

  int get highestLevel;

  P generate(OperationType kind, Random random, int level);

  List<SolutionStep> steps(P problem);

  /// Whether an answer can be negative or decimal, at any level. Such a
  /// kind gets the pad's minus and decimal keys whenever it is selected, so
  /// the pad keeps its shape between questions. The four arithmetic kinds
  /// answer with whole numbers of 0 or more.
  bool get signedDecimalAnswers;
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

  @override
  int get highestLevel => levels.length;

  @override
  bool get signedDecimalAnswers => false;

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

/// What one family's pure build makes of its params: the question's tokens,
/// with [EquationProblem.blank] or the letter n for the unknown, and the
/// answer as a whole number of hundredths; null when the params do not make
/// a valid question of the family.
typedef EquationBuild = (List<String>, int)? Function(List<int> params);

/// Each family by its variant name, which is saved with every attempt and
/// so must never change.
const Map<String, EquationBuild> _equations = {
  'missingSecondAddend': _missingSecondAddend,
  'missingFirstAddend': _missingFirstAddend,
  'missingSubtrahend': _missingSubtrahend,
  'missingMinuend': _missingMinuend,
  'missingFirstFactor': _missingFirstFactor,
  'missingSecondFactor': _missingSecondFactor,
  'missingDivisor': _missingDivisor,
  'missingDividend': _missingDividend,
  'nPlusA': _nPlusA,
  'nMinusA': _nMinusA,
  'aTimesN': _aTimesN,
  'nDividedByA': _nDividedByA,
  'anPlusB': _anPlusB,
  'anMinusB': _anMinusB,
  'aBracketNMinusB': _aBracketNMinusB,
  'aBracketNPlusB': _aBracketNPlusB,
  'nDividedByAPlusB': _nDividedByAPlusB,
  'anPlusBNegativeN': _anPlusBNegativeN,
  'anTenths': _anTenths,
};

/// The families of each level, index 0 is level 1, with the range of each
/// param. Adding a level here raises [OperationType.algebra]'s highest level.
const List<List<(String, List<Range>)>> _algebraLevels = [
  [
    ('missingSecondAddend', [(0, 10), (0, 10)]),
    ('missingFirstAddend', [(0, 10), (0, 10)]),
    ('missingSubtrahend', [(0, 10), (0, 10)]),
    ('missingMinuend', [(0, 10), (0, 10)]),
  ],
  [
    ('missingFirstFactor', [(2, 10), (1, 10)]),
    ('missingSecondFactor', [(2, 10), (1, 10)]),
    ('missingDivisor', [(2, 10), (1, 10)]),
    ('missingDividend', [(2, 10), (1, 10)]),
  ],
  [
    ('nPlusA', [(2, 12), (0, 20)]),
    ('nMinusA', [(2, 12), (0, 20)]),
    ('aTimesN', [(2, 12), (0, 20)]),
    ('nDividedByA', [(2, 12), (0, 20)]),
  ],
  [
    ('anPlusB', [(2, 9), (1, 20), (1, 20)]),
    ('anMinusB', [(2, 9), (1, 20), (1, 20)]),
  ],
  [
    ('aBracketNMinusB', [(2, 9), (1, 10), (-10, 10)]),
    ('aBracketNPlusB', [(2, 9), (1, 10), (-10, 10)]),
    ('nDividedByAPlusB', [(2, 9), (1, 10), (-10, 10)]),
    ('anPlusBNegativeN', [(2, 9), (1, 10), (-10, -1)]),
    ('anTenths', [(2, 9), (-100, 100)]),
  ],
];

const _blank = EquationProblem.blank;

// Level 1: params are the two smaller numbers a and b, each 0 or more; the
// third number is their sum.

/// a + □ = a + b, answer b.
(List<String>, int)? _missingSecondAddend(List<int> params) => switch (params) {
  [final a, final b] when a >= 0 && b >= 0 => (
    ['$a', '+', _blank, '=', '${a + b}'],
    b * 100,
  ),
  _ => null,
};

/// □ + a = a + b, answer b.
(List<String>, int)? _missingFirstAddend(List<int> params) => switch (params) {
  [final a, final b] when a >= 0 && b >= 0 => (
    [_blank, '+', '$a', '=', '${a + b}'],
    b * 100,
  ),
  _ => null,
};

/// a + b − □ = a, answer b.
(List<String>, int)? _missingSubtrahend(List<int> params) => switch (params) {
  [final a, final b] when a >= 0 && b >= 0 => (
    ['${a + b}', '−', _blank, '=', '$a'],
    b * 100,
  ),
  _ => null,
};

/// □ − a = b, answer a + b.
(List<String>, int)? _missingMinuend(List<int> params) => switch (params) {
  [final a, final b] when a >= 0 && b >= 0 => (
    [_blank, '−', '$a', '=', '$b'],
    (a + b) * 100,
  ),
  _ => null,
};

// Level 2: params are the factors a and b, a never 0, and the third number is
// their product a × b. The blank is never 0 where it divides.

/// □ × a = a × b, answer b.
(List<String>, int)? _missingFirstFactor(List<int> params) => switch (params) {
  [final a, final b] when a > 0 && b >= 0 => (
    [_blank, '×', '$a', '=', '${a * b}'],
    b * 100,
  ),
  _ => null,
};

/// a × □ = a × b, answer b.
(List<String>, int)? _missingSecondFactor(List<int> params) => switch (params) {
  [final a, final b] when a > 0 && b >= 0 => (
    ['$a', '×', _blank, '=', '${a * b}'],
    b * 100,
  ),
  _ => null,
};

/// a × b ÷ □ = a, answer b.
(List<String>, int)? _missingDivisor(List<int> params) => switch (params) {
  [final a, final b] when a > 0 && b > 0 => (
    ['${a * b}', '÷', _blank, '=', '$a'],
    b * 100,
  ),
  _ => null,
};

/// □ ÷ a = b, answer a × b.
(List<String>, int)? _missingDividend(List<int> params) => switch (params) {
  [final a, final b] when a > 0 && b >= 0 => (
    [_blank, '÷', '$a', '=', '$b'],
    a * b * 100,
  ),
  _ => null,
};

/// [value] as the question shows it: a number below zero with [minusSign].
String signedText(int value) => value < 0 ? '$minusSign${-value}' : '$value';

// Level 3: the unknown is the letter n, with an explicit ×. Params are a and
// a small number 0 or more; the largest number is computed.

/// n + a = n + a, answer n.
(List<String>, int)? _nPlusA(List<int> params) => switch (params) {
  [final a, final n] when a >= 0 && n >= 0 => (
    ['n', '+', '$a', '=', '${n + a}'],
    n * 100,
  ),
  _ => null,
};

/// n − a = b, answer a + b.
(List<String>, int)? _nMinusA(List<int> params) => switch (params) {
  [final a, final b] when a >= 0 && b >= 0 => (
    ['n', '−', '$a', '=', '$b'],
    (a + b) * 100,
  ),
  _ => null,
};

/// a × n = a × n, answer n; a is never 0.
(List<String>, int)? _aTimesN(List<int> params) => switch (params) {
  [final a, final n] when a > 0 && n >= 0 => (
    ['$a', '×', 'n', '=', '${a * n}'],
    n * 100,
  ),
  _ => null,
};

/// n ÷ a = b, answer a × b.
(List<String>, int)? _nDividedByA(List<int> params) => switch (params) {
  [final a, final b] when a > 0 && b >= 0 => (
    ['n', '÷', '$a', '=', '$b'],
    a * b * 100,
  ),
  _ => null,
};

// Level 4: an means a × n. Params a (2 or more), b (1 or more) and the
// answer n (1 or more, so no hint step before the last shows it); every
// number shown is 0 or more.

/// an + b = c, answer n.
(List<String>, int)? _anPlusB(List<int> params) => switch (params) {
  [final a, final b, final n] when a >= 2 && b >= 1 && n >= 1 => (
    ['${a}n', '+', '$b', '=', '${a * n + b}'],
    n * 100,
  ),
  _ => null,
};

/// an − b = c with c at least 0, answer n.
(List<String>, int)? _anMinusB(List<int> params) => switch (params) {
  [final a, final b, final n] when a >= 2 && b >= 1 && n >= 1 && a * n >= b => (
    ['${a}n', '−', '$b', '=', '${a * n - b}'],
    n * 100,
  ),
  _ => null,
};

// Level 5: numbers below zero (shown with [minusSign]) and tenths. Params a
// (2 or more) and b (1 or more) as before; the answer may be below zero.

/// a(n − b) = c, answer n.
(List<String>, int)? _aBracketNMinusB(List<int> params) => switch (params) {
  [final a, final b, final n] when a >= 2 && b >= 1 => (
    ['$a(n', '−', '$b)', '=', signedText(a * (n - b))],
    n * 100,
  ),
  _ => null,
};

/// a(n + b) = c, answer n.
(List<String>, int)? _aBracketNPlusB(List<int> params) => switch (params) {
  [final a, final b, final n] when a >= 2 && b >= 1 => (
    ['$a(n', '+', '$b)', '=', signedText(a * (n + b))],
    n * 100,
  ),
  _ => null,
};

/// n ÷ a + b = k + b, answer a × k. The third param is the quotient k,
/// never 0, so no hint step before the last shows the answer.
(List<String>, int)? _nDividedByAPlusB(List<int> params) => switch (params) {
  [final a, final b, final k] when a >= 2 && b >= 1 && k != 0 => (
    ['n', '÷', '$a', '+', '$b', '=', signedText(k + b)],
    a * k * 100,
  ),
  _ => null,
};

/// an + b = c with the answer n below zero.
(List<String>, int)? _anPlusBNegativeN(List<int> params) => switch (params) {
  [final a, final b, final n] when a >= 2 && b >= 1 && n < 0 => (
    ['${a}n', '+', '$b', '=', signedText(a * n + b)],
    n * 100,
  ),
  _ => null,
};

/// an = c with c whole and the answer n in tenths, never whole; the second
/// param is n in tenths (25 is 2.5).
(List<String>, int)? _anTenths(List<int> params) => switch (params) {
  [final a, final tenths]
      when a >= 2 && tenths % 10 != 0 && a * tenths % 10 == 0 =>
    (['${a}n', '=', signedText(a * tenths ~/ 10)], tenths * 10),
  _ => null,
};

/// Equations with one unknown, built answer first by pure family builds.
class AlgebraSource extends ProblemSource<EquationProblem> {
  const AlgebraSource(this.levels, this.families, this._steps);

  /// Level 5 has answers below zero and in tenths. The keys are on for the
  /// whole kind, so the pad does not change shape between levels.
  @override
  bool get signedDecimalAnswers => true;

  /// The families of each level with the range of each param; index 0 is
  /// level 1.
  final List<List<(String, List<Range>)>> levels;
  final Map<String, EquationBuild> families;
  final List<SolutionStep> Function(EquationProblem problem) _steps;

  @override
  int get highestLevel => levels.length;

  /// The problem [variant] builds from [params], or null for a variant this
  /// build does not know or params that do not fit it.
  EquationProblem? build(
    OperationType kind,
    String variant,
    List<int> params, {
    int level = 1,
  }) {
    final built = families[variant]?.call(params);
    if (built == null) return null;
    final (tokens, answer) = built;
    return EquationProblem(
      variant,
      List.unmodifiable(params),
      List.unmodifiable(tokens),
      kind,
      answer,
      level: level,
    );
  }

  /// Every problem of [level]: each family over the whole range of its
  /// params, so tests can check them all.
  Iterable<EquationProblem> problems(OperationType kind, int level) sync* {
    for (final (variant, ranges) in levels[level - 1]) {
      // build copies the params, so one list counts through them all.
      final params = [for (final (low, _) in ranges) low];
      while (true) {
        if (build(kind, variant, params, level: level) case final problem?) {
          yield problem;
        }
        // The next params, counting up like an odometer.
        var i = ranges.length - 1;
        while (i >= 0 && params[i] == ranges[i].$2) {
          params[i] = ranges[i].$1;
          i--;
        }
        if (i < 0) break;
        params[i]++;
      }
    }
  }

  /// A family drawn uniformly, then each param uniformly from its range;
  /// params the family rejects are drawn again within that family, so a
  /// family that rejects many still comes as often as the others.
  @override
  EquationProblem generate(OperationType kind, Random random, int level) {
    final families = levels[level - 1];
    final (variant, ranges) = families[random.nextInt(families.length)];
    while (true) {
      final params = [
        for (final (low, high) in ranges) low + random.nextInt(high - low + 1),
      ];
      if (build(kind, variant, params, level: level) case final problem?) {
        return problem;
      }
    }
  }

  @override
  List<SolutionStep> steps(EquationProblem problem) => _steps(problem);
}

/// Figures drawn to scale; each family is a pure build in geometry.dart.
class GeometrySource extends ProblemSource<FigureProblem> {
  const GeometrySource(this._steps);

  final List<SolutionStep> Function(Figure figure) _steps;

  /// Raised by adding families of the next level in geometry.dart.
  @override
  int get highestLevel => maxGeometryLevel;

  /// Level 5 has decimal answers (circles, halves, half a rectangle); no
  /// answer is negative.
  @override
  bool get signedDecimalAnswers => true;

  /// The problem the family named [variant] builds from [params], or null
  /// for a variant this build does not know or params that do not fit it.
  FigureProblem? build(
    OperationType kind,
    String variant,
    List<int> params, {
    int level = 1,
  }) {
    final family = GeometryFamily.values.asNameMap()[variant];
    if (family == null) return null;
    final FigureQuestion question;
    try {
      question = family.build(params);
    } on ArgumentError {
      return null;
    }
    return FigureProblem(
      variant,
      List.unmodifiable(params),
      question.figure,
      kind,
      question.answer,
      level: level,
    );
  }

  @override
  FigureProblem generate(OperationType kind, Random random, int level) {
    final (family, params) = drawGeometry(random, level);
    return build(kind, family.name, params, level: level)!;
  }

  @override
  List<SolutionStep> steps(FigureProblem problem) => _steps(problem.figure);
}

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

/// An equation with one unknown, made by the family [variant] from
/// [params]. The pair is what is saved; [tokens] and the result follow from
/// them.
class EquationProblem extends Problem {
  EquationProblem(
    this.variant,
    this.params,
    this.tokens,
    OperationType kind,
    this.resultHundredths, {
    super.level,
  }) : super(kind, numberOfHundredths(resultHundredths));

  /// The answer as a whole number of hundredths, which decides whether an
  /// answer is right; [result] is the same number for display and saving.
  final int resultHundredths;

  /// The unknown in [tokens] and [question]. No bundled font has this
  /// glyph, so the screen draws a box in its place and screen readers say
  /// "blank".
  static const blank = '□';

  final String variant;
  final List<int> params;

  /// Numbers, signs and [blank], in reading order.
  final List<String> tokens;

  @override
  String get question => tokens.join(' ');
}

/// A figure question, made by the geometry family [variant] from [params].
/// The pair is what is saved; [figure] and the result follow from them.
class FigureProblem extends Problem {
  FigureProblem(
    this.variant,
    this.params,
    this.figure,
    OperationType kind,
    this.resultHundredths, {
    super.level,
  }) : super(kind, numberOfHundredths(resultHundredths));

  /// The answer as a whole number of hundredths, which decides whether an
  /// answer is right; [result] is the same number for display and saving.
  final int resultHundredths;

  final String variant;
  final List<int> params;
  final Figure figure;

  /// The labels and the given numbers only, free of language; screens show
  /// the localised sentence instead (`ProblemLabel.shown` in labels.dart).
  @override
  String get question => [
    for (final label in figure.labels) label.text(),
    for (final angle in figure.angles) angle.text,
    if (figure.total case final total?) formatHundredths(total, 'en'),
    if (figure.pi case final pi?) formatHundredths(pi, 'en'),
  ].join(', ');
}

class Attempt {
  const Attempt(
    this.problem, {
    required this.firstAnswer,
    required this.elapsedMs,
    required this.answeredAt,
    this.hintsUsed = 0,
    this.sprint = false,
    this._answerHundredths,
  });

  final Problem problem;

  /// Null means the problem was skipped.
  final num? firstAnswer;

  final int? _answerHundredths;

  /// [firstAnswer] as a whole number of hundredths, for an equation: as the
  /// check parsed it from the typed text, or else read from the number's
  /// text (an entry saved by an older build), never by double arithmetic.
  int? get answerHundredths =>
      _answerHundredths ??
      switch (firstAnswer) {
        final answer? => parseHundredths(formatNumber(answer)),
        null => null,
      };
  final int elapsedMs;
  final DateTime answeredAt;
  final int hintsUsed;
  final bool sprint;

  bool get skipped => firstAnswer == null;

  bool get correct => switch (problem) {
    ArithmeticProblem() => firstAnswer == problem.result,
    EquationProblem(:final resultHundredths) ||
    FigureProblem(
      :final resultHundredths,
    ) => answerHundredths == resultHundredths,
  };
}

/// An independent check of a question and its claimed answer, for tests only.
///
/// It reads only the displayed English question text, never a `Problem`'s
/// fields, and parses and evaluates it with the `math_expressions` package
/// (a dev dependency), which shares no code with the generators in `lib/`.
library;

import 'dart:math' show sqrt;

import 'package:math_expressions/math_expressions.dart';

/// The text form of the drawn blank, U+25A1. The screen draws a line on the
/// baseline; the question text (history, review, screen readers) uses this
/// character.
const box = '□';

/// The oracle's answer: [ok], or why the question or answer is wrong.
enum Verdict {
  ok,

  /// A character outside the table, or text the evaluator cannot parse.
  unparsable,

  /// An arithmetic question whose value is not the claimed answer.
  wrongResult,

  /// An equation whose unknown does not occur exactly once.
  unknownNotOnce,

  /// Left minus right is not a straight line in the unknown, nor, with a
  /// square in it, a parabola.
  notLinear,

  /// The unknown changes nothing: no number or every number solves it.
  zeroSlope,

  /// The equation's one solution is not the claimed answer.
  wrongRoot,

  /// An equation in n² with two solutions that meet its condition (`n² = 49`
  /// without `n > 0`).
  twoSolutions,

  /// An equation with no real solution, or none that meets its condition.
  noSolution,

  /// `c ÷ □ = a` with `c` or the answer 0.
  zeroDivisor,

  /// The answer put back in does not make both sides equal in exact
  /// hundredths.
  substituteBack,
}

/// The fixed character table from the app's text to the evaluator's syntax.
/// Digits, `.`, brackets, `+`, `=` and spaces pass unchanged; any other
/// character is rejected. `√` must stand straight before a number.
const _table = {
  '−': '-',
  '×': '*',
  '÷': '/',
  '²': '^2',
  '√': '√',
  box: 'n',
  'n': 'n',
};

/// The condition line of an equation in n², as its text form ends.
const _positive = ', n > 0';

/// Steps between the points where left minus right is evaluated.
const _step = 2520;
const _unchanged = '0123456789.()+= ';

final _parser = GrammarParser();

/// [text] in the evaluator's syntax, the unknown written `n`. Throws a
/// [FormatException] for a character outside the table.
///
/// The one structural rule: a digit directly before a letter or an opening
/// bracket multiplies (`2n` is `2*n`, `3(n − 2)` is `3*(n-2)`). `7²` is
/// `7^2` and `√49` is `sqrt(49)`.
String toEvaluatorSyntax(String text) {
  final mapped = text
      .split('')
      .map((char) {
        if (_unchanged.contains(char)) return char;
        return _table[char] ??
            (throw FormatException('not in the table', text));
      })
      .join()
      .replaceAllMapped(RegExp(r'√(\d+(\.\d+)?)'), (m) => 'sqrt(${m[1]})');
  if (mapped.contains('√')) throw FormatException('√ without a number', text);
  return mapped
      .replaceAllMapped(RegExp(r'(\d)(?=[n(])'), (m) => '${m[1]}*')
      .replaceAll(' ', '');
}

/// Checks [question], the displayed English text, against [answer].
///
/// An arithmetic question (`lhs op rhs`) must evaluate to [answer]. An
/// equation must hold its unknown (`□` or `n`) exactly once and have
/// [answer] as its only solution; one that ends in the condition `, n > 0`
/// counts only solutions above zero.
Verdict check(String question, num answer) {
  final positive = question.endsWith(_positive);
  final String text;
  final List<Expression> sides;
  try {
    text = toEvaluatorSyntax(
      positive
          ? question.substring(0, question.length - _positive.length)
          : question,
    );
    sides = text.split('=').map(_parser.parse).toList();
  } on FormatException {
    return Verdict.unparsable;
  }
  final unknowns = 'n'.allMatches(text).length;
  if (sides.length == 1) {
    if (unknowns > 0 || positive) return Verdict.unparsable;
    return _value(sides.single, 0) == answer ? Verdict.ok : Verdict.wrongResult;
  }
  if (sides.length != 2) return Verdict.unparsable;
  if (unknowns != 1) return Verdict.unknownNotOnce;

  final [left, right] = sides;
  final claimed = _hundredths(answer);
  if (claimed == null) return Verdict.wrongRoot;
  if (text.contains('/n')) {
    // Only `c ÷ □ = a` is linear with the unknown as a divisor.
    final side = text.indexOf('n') < text.indexOf('=') ? 0 : 1;
    final match = RegExp(r'^\d+(\.\d\d?)?(?=/n$)');
    final c = match.stringMatch(text.split('=')[side]);
    if (c == null) return Verdict.notLinear;
    final cHundredths = _hundredths(double.parse(c))!;
    final a = _hundredths(_value(sides[1 - side], 0));
    if (cHundredths == 0 || claimed == 0) return Verdict.zeroDivisor;
    if (a == null || a * claimed != cHundredths * 100) return Verdict.wrongRoot;
  } else {
    // 2520 is divisible by every coefficient 2 to 9, so each division is
    // exact in floating point.
    num difference(num n) => _value(left, n) - _value(right, n);
    final (at0, at2520, at5040) = (
      difference(0),
      difference(_step),
      difference(2 * _step),
    );
    // Constants with decimals (13.68) are not exact in floating point; at
    // these sizes the noise is about 1e-11, while a real curve such as
    // 1 ÷ (n + 1000) bends by more than 1e-4 across 0, 2520 and 5040. The
    // root is then checked in exact hundredths below.
    final bend = (at5040 - at2520) - (at2520 - at0);
    if (bend.abs() <= 1e-6) {
      final slope = (at2520 - at0) / _step;
      if (slope == 0) return Verdict.zeroSlope;
      if (_hundredths(-at0 / slope) != claimed) return Verdict.wrongRoot;
    } else if (text.contains('^')) {
      // With a square: a parabola a·n² + b·n + c bends the same at every
      // step, so a fourth point must lie on the one through the first
      // three. Its real roots come from the quadratic formula, not from
      // the app's builds.
      final at7560 = difference(3 * _step);
      if ((at7560 - 3 * at5040 + 3 * at2520 - at0).abs() > 1e-6) {
        return Verdict.notLinear;
      }
      final a = bend / (2 * _step * _step);
      final b = (at2520 - at0) / _step - a * _step;
      final discriminant = b * b - 4 * a * at0;
      if (discriminant < 0) return Verdict.noSolution;
      final roots = {
        for (final sign in [1, -1])
          if ((-b + sign * sqrt(discriminant)) / (2 * a) case final root
              when !positive || root > 0)
            root,
      };
      if (roots.isEmpty) return Verdict.noSolution;
      if (roots.length > 1) return Verdict.twoSolutions;
      if (_hundredths(roots.single) != claimed) return Verdict.wrongRoot;
    } else {
      return Verdict.notLinear;
    }
  }
  // The condition line rules out the one solution itself.
  if (positive && claimed <= 0) return Verdict.noSolution;
  try {
    return _exact(left, claimed) == _exact(right, claimed)
        ? Verdict.ok
        : Verdict.substituteBack;
  } on FormatException {
    return Verdict.substituteBack;
  }
}

num _value(Expression expression, num n) =>
    RealEvaluator(ContextModel()..bindVariableName('n', Number(n)))
        .evaluate(expression);

/// [value] as a whole number of hundredths, or null if it has more decimals.
int? _hundredths(num value) {
  final scaled = value * 100;
  final whole = scaled.round();
  return (scaled - whole).abs() < 1e-6 ? whole : null;
}

/// [expression] in whole hundredths with the unknown set to [n] hundredths.
///
/// This exact arithmetic is hand-written by the same author as the
/// generators, so it is the weaker part of the guard; the parse it walks
/// comes from `math_expressions`.
int _exact(Expression expression, int n) => switch (expression) {
  Number() =>
    _hundredths(expression.getConstantValue()) ??
        (throw const FormatException('more than two decimals')),
  // The evaluator boxes a function's argument (`sqrt(49)`) in a
  // BoundVariable, which is a Variable but not the unknown.
  BoundVariable() => _exact(expression.value as Expression, n),
  Variable() => n,
  UnaryMinus() => -_exact(expression.exp, n),
  Plus() => _exact(expression.first, n) + _exact(expression.second, n),
  Minus() => _exact(expression.first, n) - _exact(expression.second, n),
  Times() => _divide(
    _exact(expression.first, n) * _exact(expression.second, n),
    100,
  ),
  Divide() => _divide(
    _exact(expression.first, n) * 100,
    _exact(expression.second, n),
  ),
  // Squares only: `n²`, `7²`.
  Power() when _exact(expression.second, n) == 200 => _divide(
    _exact(expression.first, n) * _exact(expression.first, n),
    100,
  ),
  // √x in hundredths is √(x × 100) hundredths; only an exact square root.
  Sqrt() => _squareRoot(_exact(expression.arg, n) * 100),
  _ => throw FormatException('unsupported: $expression'),
};

int _squareRoot(int value) {
  final root = value < 0 ? -1 : sqrt(value).round();
  return root >= 0 && root * root == value
      ? root
      : throw const FormatException('not an exact square root');
}

int _divide(int dividend, int divisor) =>
    divisor != 0 && dividend % divisor == 0
    ? dividend ~/ divisor
    : throw const FormatException('not a whole number of hundredths');

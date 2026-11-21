/// An independent check of a question and its claimed answer, for tests only.
///
/// It reads only the displayed English question text, never a `Problem`'s
/// fields, and parses and evaluates it with the `math_expressions` package
/// (a dev dependency), which shares no code with the generators in `lib/`.
library;

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

  /// Left minus right is not a straight line in the unknown.
  notLinear,

  /// The unknown changes nothing: no number or every number solves it.
  zeroSlope,

  /// The equation's one solution is not the claimed answer.
  wrongRoot,

  /// `c ÷ □ = a` with `c` or the answer 0.
  zeroDivisor,

  /// The answer put back in does not make both sides equal in exact
  /// hundredths.
  substituteBack,
}

/// The fixed character table from the app's text to the evaluator's syntax.
/// Digits, `.`, brackets, `+`, `=` and spaces pass unchanged; any other
/// character is rejected.
const _table = {'−': '-', '×': '*', '÷': '/', box: 'n', 'n': 'n'};
const _unchanged = '0123456789.()+= ';

final _parser = GrammarParser();

/// [text] in the evaluator's syntax, the unknown written `n`. Throws a
/// [FormatException] for a character outside the table.
///
/// The one structural rule: a digit directly before a letter or an opening
/// bracket multiplies (`2n` is `2*n`, `3(n − 2)` is `3*(n-2)`).
String toEvaluatorSyntax(String text) {
  final mapped = text.split('').map((char) {
    if (_unchanged.contains(char)) return char;
    return _table[char] ?? (throw FormatException('not in the table', text));
  }).join();
  return mapped
      .replaceAllMapped(RegExp(r'(\d)(?=[n(])'), (m) => '${m[1]}*')
      .replaceAll(' ', '');
}

/// Checks [question], the displayed English text, against [answer].
///
/// An arithmetic question (`lhs op rhs`) must evaluate to [answer]. An
/// equation must hold its unknown (`□` or `n`) exactly once and have
/// [answer] as its only solution.
Verdict check(String question, num answer) {
  final String text;
  final List<Expression> sides;
  try {
    text = toEvaluatorSyntax(question);
    sides = text.split('=').map(_parser.parse).toList();
  } on FormatException {
    return Verdict.unparsable;
  }
  final unknowns = 'n'.allMatches(text).length;
  if (sides.length == 1) {
    if (unknowns > 0) return Verdict.unparsable;
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
      difference(2520),
      difference(5040),
    );
    // Constants with decimals (13.68) are not exact in floating point; at
    // these sizes the noise is about 1e-11, while a real curve such as
    // 1 ÷ (n + 1000) bends by more than 1e-4 across 0, 2520 and 5040. The
    // root is then checked in exact hundredths below.
    if (((at5040 - at2520) - (at2520 - at0)).abs() > 1e-6) {
      return Verdict.notLinear;
    }
    final slope = (at2520 - at0) / 2520;
    if (slope == 0) return Verdict.zeroSlope;
    if (_hundredths(-at0 / slope) != claimed) return Verdict.wrongRoot;
  }
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
  _ => throw FormatException('unsupported: $expression'),
};

int _divide(int dividend, int divisor) =>
    divisor != 0 && dividend % divisor == 0
    ? dividend ~/ divisor
    : throw const FormatException('not a whole number of hundredths');

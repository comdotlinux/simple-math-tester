import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart' show immutable;

import 'figure.dart';
import 'hundredths.dart';
import 'l10n/app_localizations.dart';
import 'operations.dart';

// Every writer returns at least 2 steps, and only the last one states the
// result: no earlier step contains it as a number unless that number is shown
// in the question.

/// One step, written in the language of [AppLocalizations]. The number of
/// steps never depends on the language; a step may still pick its wording by
/// the translated text.
typedef SolutionStep = String Function(AppLocalizations l);

List<SolutionStep> solutionSteps(Problem problem) =>
    problem.kind.steps(problem);

List<SolutionStep> additionSteps(ArithmeticProblem problem) {
  final left = problem.lhs;
  final right = problem.rhs;
  final result = formatNumber(problem.result);
  final bigger = left >= right ? left : right;
  final smaller = left >= right ? right : left;
  if (bigger <= 10) {
    // Every number counted is below the sum, so none is the answer.
    final counted = [for (var i = 1; i < smaller && i <= 3; i++) bigger + i];
    return [
      (l) => counted.isEmpty
          ? l.stepAddCountOn('$bigger', '$smaller')
          : l.stepAddCountOnList('$bigger', '$smaller', counted.join(', ')),
      (l) => l.stepSoResult('$left', '+', '$right', result),
    ];
  }
  final calculations = <String>[];
  final totals = <int>[];
  for (var place = _highestPlace(bigger); place >= 1; place ~/= 10) {
    final leftPart = (left ~/ place) % 10 * place;
    final rightPart = (right ~/ place) % 10 * place;
    calculations.add('$leftPart + $rightPart = ${leftPart + rightPart}');
    totals.add(leftPart + rightPart);
  }
  if (totals.where((total) => total > 0).length > 1) {
    // Each place total is smaller than the sum because another one is not 0.
    return [
      (l) => l.stepAddBreak(
        '$left',
        _placeParts(left).join(' + '),
        '$right',
        _placeParts(right).join(' + '),
      ),
      (l) => l.stepAddMatching(calculations.join('; ')),
      (l) => l.stepAddCombine(totals.join(' + '), result),
    ];
  }
  // One place only, so its total would be the answer itself.
  final place = _highestPlace(bigger);
  return [
    (l) => l.stepAddOnePlace(
      '$left',
      _count(l, left, place),
      '$right',
      _count(l, right, place),
      '${left ~/ place}',
      '${right ~/ place}',
      _placeName(l, place),
    ),
    (l) => l.stepSoResult('$left', '+', '$right', result),
  ];
}

List<SolutionStep> subtractionSteps(ArithmeticProblem problem) {
  final left = problem.lhs;
  final right = problem.rhs;
  final result = problem.result;
  final shown = formatNumber(result);
  if (left == right) {
    return [
      (l) => l.stepSubSameFind('$left', '$right'),
      (l) => l.stepSubSame,
      (l) => l.stepSoResult('$left', '−', '$right', shown),
    ];
  }
  final firstTen = (right + 9) ~/ 10 * 10;
  final lastTen = left ~/ 10 * 10;
  final hops = <(int, int)>[
    if (firstTen <= lastTen) ...[
      (right, firstTen),
      (firstTen, lastTen),
      (lastTen, left),
    ],
  ].where((hop) => hop.$1 < hop.$2).toList();
  String hopText(AppLocalizations l) => l.stepSubHops(
    hops
        .map(
          (hop) => l.stepSubHop('${hop.$1}', '${hop.$2}', '${hop.$2 - hop.$1}'),
        )
        .join('; '),
  );
  bool useHops(AppLocalizations l) =>
      hops.length > 1 && !_mentions(hopText(l), result);
  // Two round numbers have a single hop; take away in the largest place
  // they share instead.
  var place = 1;
  while (_placeNames.contains(place * 10) &&
      left % (place * 10) == 0 &&
      right % (place * 10) == 0) {
    place *= 10;
  }
  String roundText(AppLocalizations l) => l.stepSubRound(
    '$left',
    _count(l, left, place),
    '$right',
    _count(l, right, place),
    '${left ~/ place}',
    '${right ~/ place}',
    _placeName(l, place),
  );
  // A result equal to [right] is already in the question, so it may appear.
  bool useRound(AppLocalizations l) =>
      place > 1 && (result == right || !_mentions(roundText(l), result));
  return [
    (l) => l.stepSubFind('$left', '$right'),
    (l) => useHops(l)
        ? hopText(l)
        : useRound(l)
        ? roundText(l)
        : firstTen > lastTen
        // No round number lies between them, so there is no ten to hop to.
        ? l.stepSubCountOnes('$right', '$left')
        : l.stepSubCountHops('$right', '$left'),
    (l) => useHops(l)
        ? l.stepSubAddHops(
            hops.map((hop) => hop.$2 - hop.$1).join(' + '),
            shown,
            '$left',
            '$right',
          )
        : l.stepSubCheck('$left', '$right', shown),
  ];
}

List<SolutionStep> multiplicationSteps(ArithmeticProblem problem) {
  final left = problem.lhs;
  final right = problem.rhs;
  final result = formatNumber(problem.result);
  final bigger = left >= right ? left : right;
  final smaller = left >= right ? right : left;
  // Split a factor that has more than one place, the bigger one if both do.
  final splitBigger =
      _placeParts(bigger).length > 1 || _placeParts(smaller).length == 1;
  final split = splitBigger ? bigger : smaller;
  final multiplier = splitBigger ? smaller : bigger;
  final parts = _placeParts(split);
  if (parts.length == 1 && multiplier >= 10) {
    // Both are a digit followed by zeros, such as 20 × 30. The digit product
    // is below 100 and the result ends in at least two zeros.
    final (leftDigit, leftZeros) = _digitAndZeros(left);
    final (rightDigit, rightZeros) = _digitAndZeros(right);
    final zeros = leftZeros + rightZeros;
    final product = '${leftDigit * rightDigit}';
    return [
      (l) => l.stepMulZeros('$leftDigit', '$rightDigit', product),
      (l) => l.stepMulZerosWrite(zeros, '$left', '$right', product),
      (l) => l.stepSoResult('$left', '×', '$right', result),
    ];
  }
  if (parts.length == 1) {
    // Every listed count is a smaller multiple, so it stays below the result.
    final counted = [for (var i = 1; i < multiplier && i <= 3; i++) split * i];
    return [
      (l) => l.stepMulGroups('$left', '$right', '$multiplier', '$split'),
      (l) => l.stepMulCountIn('$split', '$multiplier', counted.join(', ')),
      (l) => l.stepSoResult('$left', '×', '$right', result),
    ];
  }
  // Each product is smaller than the result because the other parts add more.
  final products = parts.map((part) => multiplier * part).toList();
  return [
    (l) => l.stepMulSplit('$split', parts.join(' + ')),
    (l) => l.stepMulEach(
      '$multiplier',
      parts
          .map((part) => '$multiplier × $part = ${multiplier * part}')
          .join('; '),
    ),
    (l) => l.stepMulAdd(products.join(' + '), result),
  ];
}

List<SolutionStep> divisionSteps(ArithmeticProblem problem) {
  final left = problem.lhs;
  final right = problem.rhs;
  final result = problem.result;
  final shown = formatNumber(result);
  final tens = result ~/ 10 * 10;
  final SolutionStep middle;
  if (tens > 0) {
    // Counting to a quotient of 10 or more is too long; take tens first.
    middle = (l) {
      final tensText = l.stepDivTens(
        '$right',
        '$tens',
        '${right * tens}',
        '$left',
        '${left - right * tens}',
      );
      return _mentions(tensText, result)
          ? l.stepDivRoundTens('$right', '$left')
          : tensText;
    };
  } else {
    final counted = [for (var i = 1; i < result && i <= 3; i++) right * i]
        .join(', ');
    middle = (l) {
      final countText = l.stepDivCountList('$right', counted, '$left');
      return _mentions(countText, result)
          ? l.stepDivCount('$right', '$left')
          : countText;
    };
  }
  return [
    (l) => l.stepDivHowMany('$right', '$left'),
    middle,
    (l) => l.stepDivResult('$right', shown, '$left'),
  ];
}

/// What one step of an equation hint does; it picks the step's sentence.
enum EquationMove {
  /// The first step: what the question asks, the number in the blank or
  /// the number n stands for.
  ask,

  /// The second step, the idea the working uses: adding and taking away
  /// undo each other ([addAndTakeAway]), the part taken away and the part
  /// left can swap ([swapTakeAway]), the same two for multiplying and
  /// dividing, what squared and a square root mean, and from level 3 that
  /// doing the same to both sides keeps them equal ([balance]).
  addAndTakeAway,
  swapTakeAway,
  multiplyAndDivide,
  swapDivide,
  squared,
  squareRoot,
  balance,

  /// `a + □ = c` or `□ + a = c`: take a away from c.
  undoAdd,

  /// `c − □ = a`: take a away from c.
  takenAway,

  /// `□ − a = b`: add a back to b.
  undoSubtract,

  /// `□ × a = c` or `a × □ = c`: divide c by a.
  undoMultiply,

  /// `c ÷ □ = a`: divide c by a.
  dividedBy,

  /// `□ ÷ a = b`: multiply b by a.
  undoDivide,

  /// From level 3, `2n` or `3(n − 2)`: a number written straight before
  /// the letter or a bracket multiplies. Also `7²`, which means `7 × 7`.
  means,

  /// `√right`: which number times itself makes right.
  whichRoot,

  /// `n² = right` with n positive: which number above zero times itself
  /// makes right.
  whichPositiveRoot,

  /// From level 3, the first step when the answer is below zero: such a
  /// number is written with a minus sign.
  belowZero,

  /// From level 3, `… + right`: take right away from both sides.
  subtractBoth,

  /// `… − right`: add right to both sides.
  addBoth,

  /// `right × …` or `right(…)`: divide both sides by right.
  divideBoth,

  /// `… ÷ right`: multiply both sides by right.
  multiplyBoth,

  /// The last step: the calculation with its value, which is the answer,
  /// and the check.
  answer,

  /// The last step of a root: `left × right`, the root times itself, makes
  /// the square the step before named; its value is the root, the answer.
  rootAnswer,
}

/// One step of an equation hint as data, before a sentence wraps it, so
/// tests can recompute it: the [move] it makes and the calculation it shows,
/// `left sign right` in the question's signs.
///
/// A step with a [valueHundredths] does its calculation: the last step
/// ([EquationMove.answer]), whose value is the answer and which has the
/// [check], and from level 4 the undo before it, which has the [equation]
/// it leaves. A step without a value names the calculation the next step
/// does.
class EquationStep {
  const EquationStep(
    this.move, {
    this.left = 0,
    this.sign = '',
    this.right = 0,
    this.valueHundredths,
    this.equation,
    this.shorthand,
    this.meaning,
    this.check,
  });

  final EquationMove move;

  /// Whole numbers; [EquationMove.ask], the ideas, [EquationMove.means] and
  /// [EquationMove.belowZero] have no calculation and leave these at 0 and
  /// ''.
  final int left;
  final String sign;
  final int right;

  /// The calculation's value as a whole number of hundredths.
  final int? valueHundredths;

  /// The equation an undo before the last leaves, such as `2n = 8`.
  final String? equation;

  /// [EquationMove.means] only: the short form the question shows, such as
  /// `2n`, and what it means, `2 × n`.
  final String? shorthand;
  final String? meaning;

  /// The last step only: the question with the answer in place of the
  /// unknown, in English text form (`.` before tenths).
  final String? check;

  String get calculation => '${signedText(left)} $sign ${signedText(right)}';
}

/// The hint of an equation as data. It starts with what the question asks
/// and the idea the working uses. With the blank (levels 1 and 2) the next
/// step names the operation around the blank and the calculation that
/// undoes it, using only numbers the question shows; the last does that
/// calculation, states the answer and puts it back in place of the blank.
///
/// With the letter n (from level 3) the steps undo one operation at a time
/// on both sides: a step first says what a short form such as `2n` means
/// and, when the answer is below zero, explains its minus sign; an undo
/// before the last is done at once and shows the equation it leaves; the
/// last undo is named, then done in the answer step.
List<EquationStep> equationHint(EquationProblem problem) {
  final work = _equationWork(problem);
  final idea = switch (problem.variant) {
    'missingSquare' || 'aSquared' || 'nSquared' => EquationMove.squared,
    'missingSquareRoot' || 'squareRootOfC' => EquationMove.squareRoot,
    _ => switch (work.first.move) {
      EquationMove.undoAdd ||
      EquationMove.undoSubtract => EquationMove.addAndTakeAway,
      EquationMove.takenAway => EquationMove.swapTakeAway,
      EquationMove.undoMultiply ||
      EquationMove.undoDivide => EquationMove.multiplyAndDivide,
      EquationMove.dividedBy => EquationMove.swapDivide,
      _ => EquationMove.balance,
    },
  };
  return [const EquationStep(EquationMove.ask), EquationStep(idea), ...work];
}

/// The steps of [equationHint] after the question and the idea.
List<EquationStep> _equationWork(EquationProblem problem) {
  final answer = problem.resultHundredths;
  // Squares and roots: what a² means, or which number times itself makes c;
  // an² = c divides by a first.
  EquationStep root(int r, String check) => EquationStep(
    EquationMove.rootAnswer,
    left: r,
    sign: '×',
    right: r,
    valueHundredths: answer,
    check: check,
  );
  switch ((problem.variant, problem.params)) {
    case ('missingSquare' || 'aSquared', [final a]):
      return [
        EquationStep(EquationMove.means, shorthand: '$a²', meaning: '$a × $a'),
        EquationStep(
          EquationMove.answer,
          left: a,
          sign: '×',
          right: a,
          valueHundredths: answer,
          check: '$a² = ${a * a}',
        ),
      ];
    case ('missingSquareRoot' || 'squareRootOfC', [final r]):
      return [
        EquationStep(EquationMove.whichRoot, right: r * r),
        root(r, '√${r * r} = $r'),
      ];
    case ('nSquared', [final n]):
      return [
        EquationStep(EquationMove.whichPositiveRoot, right: n * n),
        root(n, '$n² = ${n * n}'),
      ];
    case ('anSquared', [final a, final n]):
      return [
        EquationStep(
          EquationMove.means,
          shorthand: '${a}n²',
          meaning: '$a × n²',
        ),
        EquationStep(
          EquationMove.divideBoth,
          left: a * n * n,
          sign: '÷',
          right: a,
          valueHundredths: n * n * 100,
          equation: 'n² = ${n * n}',
        ),
        EquationStep(EquationMove.whichPositiveRoot, right: n * n),
        root(n, '$a × $n² = ${a * n * n}'),
      ];
  }
  if (problem.tokens.contains(EquationProblem.blank)) {
    final (move, left, sign, right) = switch ((
      problem.variant,
      problem.params,
    )) {
      ('missingSecondAddend' || 'missingFirstAddend', [final a, final b]) => (
        EquationMove.undoAdd,
        a + b,
        '−',
        a,
      ),
      ('missingSubtrahend', [final a, final b]) => (
        EquationMove.takenAway,
        a + b,
        '−',
        a,
      ),
      ('missingMinuend', [final a, final b]) => (
        EquationMove.undoSubtract,
        b,
        '+',
        a,
      ),
      ('missingFirstFactor' || 'missingSecondFactor', [final a, final b]) => (
        EquationMove.undoMultiply,
        a * b,
        '÷',
        a,
      ),
      ('missingDivisor', [final a, final b]) => (
        EquationMove.dividedBy,
        a * b,
        '÷',
        a,
      ),
      ('missingDividend', [final a, final b]) => (
        EquationMove.undoDivide,
        b,
        '×',
        a,
      ),
      _ => throw ArgumentError.value(problem.variant, 'variant'),
    };
    final shown = formatHundredths(answer, 'en');
    return [
      EquationStep(move, left: left, sign: sign, right: right),
      EquationStep(
        EquationMove.answer,
        left: left,
        sign: sign,
        right: right,
        valueHundredths: answer,
        check: problem.tokens
            .map((token) => token == EquationProblem.blank ? shown : token)
            .join(' '),
      ),
    ];
  }

  const subtract = EquationMove.subtractBoth;
  const add = EquationMove.addBoth;
  const divide = EquationMove.divideBoth;
  const multiply = EquationMove.multiplyBoth;
  // The short form and its meaning, the undos in order, the side with the
  // letter after the first of two undos, and the check.
  final (
    (String, String)? means,
    List<(EquationMove, int, String, int)> undos,
    String? rest,
    String check,
  ) = switch ((problem.variant, problem.params)) {
    ('nPlusA', [final a, final n]) => (
      null,
      [(subtract, n + a, '−', a)],
      null,
      '$n + $a = ${n + a}',
    ),
    ('nMinusA', [final a, final b]) => (
      null,
      [(add, b, '+', a)],
      null,
      '${a + b} − $a = $b',
    ),
    ('aTimesN', [final a, final n]) => (
      null,
      [(divide, a * n, '÷', a)],
      null,
      '$a × $n = ${a * n}',
    ),
    ('nDividedByA', [final a, final b]) => (
      null,
      [(multiply, b, '×', a)],
      null,
      '${a * b} ÷ $a = $b',
    ),
    ('anPlusB' || 'anPlusBNegativeN', [final a, final b, final n]) => (
      ('${a}n', '$a × n'),
      [(subtract, a * n + b, '−', b), (divide, a * n, '÷', a)],
      '${a}n',
      '$a × ${_factor(n * 100)} + $b = ${signedText(a * n + b)}',
    ),
    ('anMinusB', [final a, final b, final n]) => (
      ('${a}n', '$a × n'),
      [(add, a * n - b, '+', b), (divide, a * n, '÷', a)],
      '${a}n',
      '$a × $n − $b = ${a * n - b}',
    ),
    ('aBracketNMinusB', [final a, final b, final n]) => (
      ('$a(n − $b)', '$a × (n − $b)'),
      [(divide, a * (n - b), '÷', a), (add, n - b, '+', b)],
      'n − $b',
      '$a(${signedText(n)} − $b) = ${signedText(a * (n - b))}',
    ),
    ('aBracketNPlusB', [final a, final b, final n]) => (
      ('$a(n + $b)', '$a × (n + $b)'),
      [(divide, a * (n + b), '÷', a), (subtract, n + b, '−', b)],
      'n + $b',
      '$a(${signedText(n)} + $b) = ${signedText(a * (n + b))}',
    ),
    ('nDividedByAPlusB', [final a, final b, final k]) => (
      null,
      [(subtract, k + b, '−', b), (multiply, k, '×', a)],
      'n ÷ $a',
      '${signedText(a * k)} ÷ $a + $b = ${signedText(k + b)}',
    ),
    ('anTenths', [final a, final tenths]) => (
      ('${a}n', '$a × n'),
      [(divide, a * tenths ~/ 10, '÷', a)],
      null,
      '$a × ${_factor(tenths * 10)} = ${signedText(a * tenths ~/ 10)}',
    ),
    _ => throw ArgumentError.value(problem.variant, 'variant'),
  };
  final (lastMove, lastLeft, lastSign, lastRight) = undos.last;
  return [
    if (answer < 0) const EquationStep(EquationMove.belowZero),
    if (means case (final shorthand, final meaning))
      EquationStep(EquationMove.means, shorthand: shorthand, meaning: meaning),
    for (final (move, left, sign, right) in undos.take(undos.length - 1))
      if (_calculate(left, sign, right) case final value)
        EquationStep(
          move,
          left: left,
          sign: sign,
          right: right,
          valueHundredths: value * 100,
          equation: '$rest = ${signedText(value)}',
        ),
    EquationStep(lastMove, left: lastLeft, sign: lastSign, right: lastRight),
    EquationStep(
      EquationMove.answer,
      left: lastLeft,
      sign: lastSign,
      right: lastRight,
      valueHundredths: answer,
      check: check,
    ),
  ];
}

/// An undo before the last; its numbers are whole, so is its value.
int _calculate(int left, String sign, int right) => switch (sign) {
  '−' => left - right,
  '+' => left + right,
  '×' => left * right,
  _ => left ~/ right,
};

/// [hundredths] as a factor in a check, bracketed below zero: `3 × (−2)`.
String _factor(int hundredths) {
  final text = formatHundredths(hundredths, 'en');
  return hundredths < 0 ? '($text)' : text;
}

/// The sentences of [equationHint]; each only wraps its step's numbers.
List<SolutionStep> equationSteps(EquationProblem problem) {
  final letter = !problem.tokens.contains(EquationProblem.blank);
  return [
    for (final step in equationHint(problem))
      _equationSentence(step, letter: letter),
  ];
}

SolutionStep _equationSentence(EquationStep step, {required bool letter}) {
  final left = '${step.left}';
  final right = '${step.right}';
  // English text in the language: only a number has a `.`.
  String local(AppLocalizations l, String text) =>
      text.replaceAll('.', decimalSeparator(l.localeName));
  String value(AppLocalizations l) =>
      formatHundredths(step.valueHundredths!, l.localeName);
  // A root's last step multiplies the root by itself to make the square.
  String calculation(AppLocalizations l) => step.move == EquationMove.rootAnswer
      ? '${step.calculation} = ${step.left * step.right}'
      : '${step.calculation} = ${value(l)}';
  String undo(AppLocalizations l) => switch (step.move) {
    EquationMove.subtractBoth => l.stepEquationSubtractBoth(right),
    EquationMove.addBoth => l.stepEquationAddBoth(right),
    EquationMove.divideBoth => l.stepEquationDivideBoth(right),
    _ => l.stepEquationMultiplyBoth(right),
  };
  return switch (step.move) {
    EquationMove.ask => (l) => letter ? l.hintAskLetter : l.hintAskBlank,
    EquationMove.addAndTakeAway => (l) => l.hintIdeaAddAndTakeAway,
    EquationMove.swapTakeAway => (l) => l.hintIdeaSwapTakeAway,
    EquationMove.multiplyAndDivide => (l) => l.hintIdeaMultiplyAndDivide,
    EquationMove.swapDivide => (l) => l.hintIdeaSwapDivide,
    EquationMove.squared => (l) => l.hintIdeaSquared,
    EquationMove.squareRoot => (l) => l.hintIdeaSquareRoot,
    EquationMove.balance => (l) => l.hintIdeaBalance,
    EquationMove.undoAdd => (l) => l.stepEquationUndoAdd(right, left),
    EquationMove.takenAway => (l) => l.stepEquationTakenAway(left, right),
    EquationMove.undoSubtract => (l) => l.stepEquationUndoSubtract(right, left),
    EquationMove.undoMultiply => (l) => l.stepEquationUndoMultiply(right, left),
    EquationMove.dividedBy => (l) => l.stepEquationDividedBy(left, right),
    EquationMove.undoDivide => (l) => l.stepEquationUndoDivide(right, left),
    EquationMove.means => (l) => l.stepEquationMeans(
      step.shorthand!,
      step.meaning!,
    ),
    EquationMove.belowZero => (l) => l.stepEquationBelowZero,
    EquationMove.whichRoot => (l) => l.stepEquationWhichRoot(right),
    EquationMove.whichPositiveRoot => (l) => l.stepEquationWhichPositiveRoot(
      right,
    ),
    EquationMove.subtractBoth ||
    EquationMove.addBoth ||
    EquationMove.divideBoth ||
    EquationMove.multiplyBoth =>
      (l) => step.equation == null
          ? undo(l)
          : '${undo(l)} ${l.stepEquationSoNow(calculation(l), step.equation!)}',
    EquationMove.answer ||
    EquationMove.rootAnswer when letter => (l) => l.stepEquationLetterIs(
      calculation(l),
      value(l),
      local(l, step.check!),
    ),
    EquationMove.answer || EquationMove.rootAnswer => (
      l,
    ) => l.stepEquationBlankIs(calculation(l), value(l), local(l, step.check!)),
  };
}

const _placeNames = {10, 100, 1000, 10000};

/// The plural name of [place], as in "then make it hundreds".
String _placeName(AppLocalizations l, int place) => switch (place) {
  10 => l.placeTens,
  100 => l.placeHundreds,
  1000 => l.placeThousands,
  _ => l.placeTenThousands,
};

/// [value] counted in [place]s, such as "5 thousands" or "1 ten".
String _count(AppLocalizations l, int value, int place) => switch (place) {
  10 => l.countTens(value ~/ place),
  100 => l.countHundreds(value ~/ place),
  1000 => l.countThousands(value ~/ place),
  _ => l.countTenThousands(value ~/ place),
};

bool _mentions(String text, num value) =>
    RegExp('(?<!\\d)${formatNumber(value)}(?!\\d)').hasMatch(text);

int _highestPlace(int value) {
  var place = 1;
  while (place <= value ~/ 10) {
    place *= 10;
  }
  return place;
}

List<int> _placeParts(int value) {
  final parts = <int>[];
  for (var place = _highestPlace(value); place >= 1; place ~/= 10) {
    final part = (value ~/ place) % 10 * place;
    if (part > 0) parts.add(part);
  }
  return parts;
}

/// For a number with one non-zero digit: that digit and the zeros after it.
(int, int) _digitAndZeros(int value) {
  final place = _highestPlace(value);
  return (value ~/ place, '$place'.length - 1);
}

/// What one step of a figure hint says; it picks the step's sentence.
enum FigureMove {
  /// The first step: what the question asks.
  askPerimeter,
  askArea,
  askSideFromPerimeter,
  askSideFromArea,
  askAngle,
  askCircumference,
  askLength,

  /// The second step: the rule the working uses, and why.
  squareSides,
  rectangleSides,
  perimeterAdds,
  gridArea,
  rectangleArea,
  halfPerimeter,
  squareArea,
  triangleAngles,
  straightAngle,
  rightAngle,
  rightTriangle,
  lShapePerimeter,
  lShapeArea,
  circumference,
  circleArea,
  verticallyOpposite,
  aroundPoint,
  pythagoras,
  diagonalTriangles,

  /// The working: a number read from the figure, or one small calculation.
  everySide,
  oppositeTop,
  oppositeLeft,
  threeSides,
  oneRow,
  rows,
  shareFour,
  whichSquare,
  halfOf,
  undoTimes,
  takeFirstAngle,
  knownAngle,
  knownPart,
  legsRectangle,
  lBottom,
  lStep,
  wholeRectangle,
  cutCorner,
  twoSides,
  diameter,
  radius,
  radiusSquared,
  halveThenTakeAway,
  betweenAngle,
  addKnownAngles,
  squareSide,
  addSquares,
  takeSquare,

  /// The last step: the calculation whose value is the answer, and the
  /// check. [rootSide] and [rootLength] multiply the answer by itself to
  /// make the square the step before names, so their value is that square.
  perimeterIs,
  areaIs,
  sideIs,
  rootSide,
  rootLength,
  angleIs,
  circumferenceIs,
}

/// How the last step of a figure hint checks the answer.
enum FigureCheck {
  /// [FigureStep.check] is a calculation with the answer in it whose value
  /// is a number the figure shows.
  calculation,

  /// The sides added, one for every side of the shape: as many as the
  /// last calculation has terms.
  sides,

  /// The answer is a bit more than [FigureStep.check], with 3 for π.
  aBitMore,

  /// Count the grid squares one by one.
  countSquares,
}

/// One step of a figure hint as data, before a sentence wraps it, so tests
/// can recompute it: the [move] it makes, the [numbers] it reads from the
/// figure, the calculation `terms[0] signs[0] terms[1] …` and its value, all
/// in hundredths, the [parts] of the figure it uses, and for the last step
/// how it checks the answer.
@immutable
class FigureStep {
  const FigureStep(
    this.move, {
    this.numbers = const [],
    this.terms = const [],
    this.signs = const [],
    this.valueHundredths,
    this.checkKind,
    this.check,
    this.parts = const FigureParts(),
  });

  final FigureMove move;
  final List<int> numbers;
  final List<int> terms;
  final List<String> signs;
  final int? valueHundredths;
  final FigureCheck? checkKind;

  /// [FigureCheck.calculation] and [FigureCheck.aBitMore]: `left = right`
  /// in English text form (`.` before decimals).
  final String? check;
  final FigureParts parts;

  /// The calculation in English text form, or null for a step without one.
  String? get calculation => terms.isEmpty ? null : _terms(terms, signs, 'en');
}

String _terms(List<int> terms, List<String> signs, String localeName) => [
  formatHundredths(terms.first, localeName),
  for (final (i, sign) in signs.indexed) ...[
    sign,
    formatHundredths(terms[i + 1], localeName),
  ],
].join(' ');

/// The hint of a figure question as data, read from what the figure shows
/// (its labels, the given total and π), never from its family: what is
/// asked, the rule, the working one number or calculation at a time, then
/// the answer and its check. The answer appears only in the last step.
List<FigureStep> figureHint(Figure figure) {
  final byEdge = {
    for (final label in figure.labels) label.edge: label.hundredths,
  };
  final every = {for (var i = 0; i < figure.vertices.length; i++) i};
  final total = figure.total;
  const outline = FigureParts(outline: true);
  const inside = FigureParts(inside: true);
  FigureStep sum(FigureMove move, List<int> terms, FigureParts parts) =>
      FigureStep(
        move,
        terms: terms,
        signs: [for (var i = 1; i < terms.length; i++) '+'],
        valueHundredths: terms.reduce((a, b) => a + b),
        checkKind: FigureCheck.sides,
        parts: parts,
      );
  String en(int hundredths) => formatHundredths(hundredths, 'en');

  switch (figure.prompt) {
    case FigurePrompt.angle:
      final known = [
        for (final angle in figure.angles)
          if (angle.degrees != null) angle,
      ];
      final asked = figure.angles.firstWhere((a) => a.degrees == null).corner;
      final sizes = [for (final angle in known) angle.degrees!];
      if (figure.shape == FigureShape.triangle) {
        final [first, second] = known;
        final rest = 180 - sizes[0] - sizes[1];
        return [
          FigureStep(FigureMove.askAngle, parts: FigureParts(angles: {asked})),
          FigureStep(
            FigureMove.triangleAngles,
            numbers: const [18000],
            parts: FigureParts(
              angles: {for (final a in figure.angles) a.corner},
            ),
          ),
          FigureStep(
            FigureMove.takeFirstAngle,
            terms: [18000, sizes[0] * 100],
            signs: const ['−'],
            valueHundredths: (180 - sizes[0]) * 100,
            parts: FigureParts(angles: {first.corner}),
          ),
          FigureStep(
            FigureMove.angleIs,
            terms: [(180 - sizes[0]) * 100, sizes[1] * 100],
            signs: const ['−'],
            valueHundredths: rest * 100,
            checkKind: FigureCheck.calculation,
            check: '${sizes[0]} + ${sizes[1]} + $rest = 180',
            parts: FigureParts(angles: {second.corner, asked}),
          ),
        ];
      }
      final ask = FigureStep(
        FigureMove.askAngle,
        parts: FigureParts(angles: {asked}),
      );
      if (figure.shape == FigureShape.aroundPoint) {
        final sum = sizes.reduce((a, b) => a + b);
        return [
          ask,
          FigureStep(
            FigureMove.aroundPoint,
            numbers: const [36000],
            parts: FigureParts(
              angles: {for (final a in figure.angles) a.corner},
            ),
          ),
          FigureStep(
            FigureMove.addKnownAngles,
            terms: [for (final size in sizes) size * 100],
            signs: [for (var i = 1; i < sizes.length; i++) '+'],
            valueHundredths: sum * 100,
            parts: FigureParts(angles: {for (final a in known) a.corner}),
          ),
          FigureStep(
            FigureMove.angleIs,
            terms: [36000, sum * 100],
            signs: const ['−'],
            valueHundredths: (360 - sum) * 100,
            checkKind: FigureCheck.calculation,
            check: '${[...sizes, 360 - sum].join(' + ')} = 360',
            parts: FigureParts(angles: {asked}),
          ),
        ];
      }
      final given = known.single.corner;
      final count = figure.vertices.length;
      if (figure.shape == FigureShape.crossingLines &&
          asked == nextRay(nextRay(given, count), count)) {
        // Opposite angles: the angle between them, which has no mark, lies
        // between the rays to the two corners after the given one's (edge
        // i is the ray to corner i + 1).
        final a = sizes.single;
        final next = nextRay(given, count);
        final between = FigureParts(edges: {next - 1, asked - 1});
        return [
          ask,
          FigureStep(
            FigureMove.verticallyOpposite,
            numbers: const [18000],
            parts: FigureParts(angles: {given, asked}),
          ),
          FigureStep(
            FigureMove.betweenAngle,
            terms: [18000, a * 100],
            signs: const ['−'],
            valueHundredths: (180 - a) * 100,
            parts: FigureParts(angles: {given}, edges: between.edges),
          ),
          FigureStep(
            FigureMove.angleIs,
            terms: [18000, (180 - a) * 100],
            signs: const ['−'],
            valueHundredths: a * 100,
            checkKind: FigureCheck.calculation,
            check: '${180 - a} + $a = 180',
            parts: FigureParts(angles: {asked}, edges: between.edges),
          ),
        ];
      }
      // Rays: the asked angle is the rest of a straight line or a corner;
      // also an angle next to the given one where two lines cross.
      final right = figure.shape == FigureShape.rightAngle;
      final whole = right ? 90 : 180;
      final rest = whole - sizes.single;
      final both = FigureParts(
        angles: {known.single.corner, asked},
        rightAngle: right,
      );
      return [
        FigureStep(FigureMove.askAngle, parts: FigureParts(angles: {asked})),
        FigureStep(
          right ? FigureMove.rightAngle : FigureMove.straightAngle,
          numbers: [whole * 100],
          parts: both,
        ),
        FigureStep(
          right ? FigureMove.knownPart : FigureMove.knownAngle,
          numbers: [sizes.single * 100],
          parts: both,
        ),
        FigureStep(
          FigureMove.angleIs,
          terms: [whole * 100, sizes.single * 100],
          signs: const ['−'],
          valueHundredths: rest * 100,
          checkKind: FigureCheck.calculation,
          check: '${sizes.single} + $rest = $whole',
          parts: both,
        ),
      ];
    case FigurePrompt.sideFromPerimeter:
      final asked = byEdge.keys.firstWhere((edge) => byEdge[edge] == null);
      final ask = FigureStep(
        FigureMove.askSideFromPerimeter,
        parts: FigureParts(outline: true, edges: {asked}),
      );
      if (figure.shape == FigureShape.square) {
        final side = total! ~/ 4;
        return [
          ask,
          FigureStep(FigureMove.squareSides, parts: FigureParts(edges: every)),
          FigureStep(FigureMove.shareFour, numbers: [total], parts: outline),
          FigureStep(
            FigureMove.sideIs,
            terms: [total, 400],
            signs: const ['÷'],
            valueHundredths: side,
            checkKind: FigureCheck.calculation,
            check:
                '${[for (var i = 0; i < 4; i++) en(side)].join(' + ')} '
                '= ${en(total)}',
            parts: FigureParts(edges: {asked}),
          ),
        ];
      }
      // A rectangle: the known side and the asked one meet at a corner.
      final known = byEdge.keys.firstWhere((edge) => byEdge[edge] != null);
      final width = byEdge[known]!;
      final half = total! ~/ 2;
      final height = half - width;
      // Halving shows a 2, which would give away an answer of 2: then the
      // working only names the two calculations and the last does both.
      final early = height == 200;
      return [
        ask,
        FigureStep(
          FigureMove.halfPerimeter,
          parts: FigureParts(edges: {known, asked}),
        ),
        if (early)
          const FigureStep(FigureMove.halveThenTakeAway, parts: outline)
        else
          FigureStep(
            FigureMove.halfOf,
            terms: [total, 200],
            signs: const ['÷'],
            valueHundredths: half,
            parts: outline,
          ),
        FigureStep(
          FigureMove.sideIs,
          terms: early ? [total, 200, width] : [half, width],
          signs: early ? const ['÷', '−'] : const ['−'],
          valueHundredths: height,
          checkKind: FigureCheck.calculation,
          check:
              '${[en(width), en(height), en(width), en(height)].join(' + ')} '
              '= ${en(total)}',
          parts: FigureParts(edges: {known, asked}),
        ),
      ];
    case FigurePrompt.sideFromArea:
      final asked = byEdge.keys.firstWhere((edge) => byEdge[edge] == null);
      final ask = FigureStep(
        FigureMove.askSideFromArea,
        parts: FigureParts(inside: true, edges: {asked}),
      );
      if (figure.shape == FigureShape.square) {
        final side = sqrt(total! * 100).round();
        return [
          ask,
          const FigureStep(FigureMove.squareArea, parts: inside),
          FigureStep(FigureMove.whichSquare, numbers: [total], parts: inside),
          FigureStep(
            FigureMove.rootSide,
            terms: [side, side],
            signs: const ['×'],
            valueHundredths: total,
            parts: FigureParts(edges: {asked}),
          ),
        ];
      }
      final known = byEdge.keys.firstWhere((edge) => byEdge[edge] != null);
      final width = byEdge[known]!;
      final height = total! * 100 ~/ width;
      final sides = FigureParts(edges: {known, asked});
      return [
        ask,
        FigureStep(FigureMove.rectangleArea, parts: sides),
        FigureStep(
          FigureMove.undoTimes,
          numbers: [width, total],
          parts: FigureParts(edges: {known, asked}, inside: true),
        ),
        FigureStep(
          FigureMove.sideIs,
          terms: [total, width],
          signs: const ['÷'],
          valueHundredths: height,
          checkKind: FigureCheck.calculation,
          check: '${en(width)} × ${en(height)} = ${en(total)}',
          parts: sides,
        ),
      ];
    case FigurePrompt.circumference:
      // shortcut: only a drawn diameter, as every circumference family
      // has; a radius needs a step that doubles it.
      final pi = figure.pi!;
      final d = byEdge[0]!;
      return [
        const FigureStep(FigureMove.askCircumference, parts: outline),
        FigureStep(FigureMove.circumference, numbers: [pi], parts: outline),
        FigureStep(
          FigureMove.diameter,
          numbers: [d],
          parts: const FigureParts(edges: {0}),
        ),
        FigureStep(
          FigureMove.circumferenceIs,
          terms: [pi, d],
          signs: const ['×'],
          valueHundredths: pi * d ~/ 100,
          checkKind: FigureCheck.aBitMore,
          check: '3 × ${en(d)} = ${en(3 * d)}',
          parts: const FigureParts(edges: {0}, outline: true),
        ),
      ];
    case FigurePrompt.length:
      return _pythagorasHint(figure, byEdge);
    case FigurePrompt.area || FigurePrompt.perimeter:
      break;
  }

  if (figure.prompt == FigurePrompt.perimeter) {
    final ask = const FigureStep(FigureMove.askPerimeter, parts: outline);
    final all = FigureParts(edges: every);
    switch (figure.shape) {
      case FigureShape.square:
        final side = byEdge.values.single!;
        return [
          ask,
          FigureStep(FigureMove.squareSides, parts: all),
          FigureStep(FigureMove.everySide, numbers: [side], parts: all),
          sum(FigureMove.perimeterIs, [side, side, side, side], all),
        ];
      case FigureShape.rectangle:
        // Labelled: the bottom (edge 2) and the right side (edge 1).
        final (width, height) = (byEdge[2]!, byEdge[1]!);
        return [
          ask,
          const FigureStep(
            FigureMove.rectangleSides,
            parts: FigureParts(edges: {0, 3}),
          ),
          FigureStep(
            FigureMove.oppositeTop,
            numbers: [width],
            parts: const FigureParts(edges: {2, 0}),
          ),
          FigureStep(
            FigureMove.oppositeLeft,
            numbers: [height],
            parts: const FigureParts(edges: {1, 3}),
          ),
          sum(FigureMove.perimeterIs, [width, height, width, height], all),
        ];
      case FigureShape.lShape:
        final (:top, :inner, :right, :left, :bottom, :step) = _lShape(byEdge);
        return [
          ask,
          const FigureStep(
            FigureMove.lShapePerimeter,
            parts: FigureParts(edges: {4, 1}),
          ),
          ..._lShapeSides(top, inner, right, left),
          sum(FigureMove.perimeterIs, [
            top,
            step,
            inner,
            right,
            bottom,
            left,
          ], all),
        ];
      default:
        final sides = [for (final edge in every) byEdge[edge]!];
        return [
          ask,
          FigureStep(FigureMove.perimeterAdds, parts: all),
          FigureStep(FigureMove.threeSides, numbers: sides, parts: all),
          sum(FigureMove.perimeterIs, sides, all),
        ];
    }
  }

  const ask = FigureStep(FigureMove.askArea, parts: inside);
  FigureStep areaIs(
    List<int> terms,
    List<String> signs,
    FigureParts parts, {
    required FigureCheck checkKind,
    String? check,
    int? value,
  }) {
    // Left to right; a calculation that needs × before − gives its [value].
    var result = terms.first;
    for (final (i, sign) in signs.indexed) {
      result = switch (sign) {
        '×' => result * terms[i + 1] ~/ 100,
        '÷' => result * 100 ~/ terms[i + 1],
        _ => result - terms[i + 1],
      };
    }
    return FigureStep(
      FigureMove.areaIs,
      terms: terms,
      signs: signs,
      valueHundredths: value ?? result,
      checkKind: checkKind,
      check: check,
      parts: parts,
    );
  }

  switch (figure.shape) {
    case FigureShape.circle:
      // shortcut: only a drawn radius, as the circle area family has.
      final pi = figure.pi!;
      final r = byEdge[0]!;
      final square = r * r ~/ 100;
      const line = FigureParts(edges: {0});
      return [
        ask,
        FigureStep(FigureMove.circleArea, numbers: [pi], parts: inside),
        FigureStep(FigureMove.radius, numbers: [r], parts: line),
        FigureStep(
          FigureMove.radiusSquared,
          terms: [r, r],
          signs: const ['×'],
          valueHundredths: square,
          parts: line,
        ),
        areaIs(
          [pi, square],
          ['×'],
          inside,
          checkKind: FigureCheck.aBitMore,
          check: '3 × ${en(square)} = ${en(3 * square)}',
        ),
      ];
    case FigureShape.rightTriangle:
      // Edge 0 is the left leg, edge 2 the bottom one.
      final (a, b) = (byEdge[2]!, byEdge[0]!);
      final whole = a * b ~/ 100;
      final half = whole ~/ 2;
      return [
        ask,
        const FigureStep(
          FigureMove.rightTriangle,
          parts: FigureParts(inside: true, rightAngle: true),
        ),
        FigureStep(
          FigureMove.legsRectangle,
          numbers: [a, b],
          terms: [a, b],
          signs: const ['×'],
          valueHundredths: whole,
          parts: const FigureParts(edges: {2, 0}, rightAngle: true),
        ),
        areaIs(
          [whole, 200],
          ['÷'],
          inside,
          checkKind: FigureCheck.calculation,
          check: '${en(half)} + ${en(half)} = ${en(whole)}',
        ),
      ];
    case FigureShape.lShape:
      final (:top, :inner, :right, :left, :bottom, :step) = _lShape(byEdge);
      final whole = bottom * left ~/ 100;
      final corner = inner * step ~/ 100;
      final area = whole - corner;
      // A corner as large as the answer would show it early: then the
      // last step takes the corner away in one go.
      final early = corner == area;
      return [
        ask,
        const FigureStep(FigureMove.lShapeArea, parts: inside),
        ..._lShapeSides(top, inner, right, left),
        FigureStep(
          FigureMove.wholeRectangle,
          terms: [bottom, left],
          signs: const ['×'],
          valueHundredths: whole,
          parts: const FigureParts(edges: {4, 5}),
        ),
        if (!early)
          FigureStep(
            FigureMove.cutCorner,
            terms: [inner, step],
            signs: const ['×'],
            valueHundredths: corner,
            parts: const FigureParts(edges: {2, 1}),
          ),
        areaIs(
          early ? [whole, inner, step] : [whole, corner],
          early ? ['−', '×'] : ['−'],
          early ? const FigureParts(edges: {2, 1}, inside: true) : inside,
          checkKind: FigureCheck.calculation,
          check: '${en(area)} + ${en(corner)} = ${en(whole)}',
          value: area,
        ),
      ];
    default:
      // A rectangle: the first label is the bottom edge, the second the
      // right one.
      final [(edge: wEdge, :width), (edge: hEdge, width: height)] = [
        for (final label in figure.labels)
          (edge: label.edge, width: label.hundredths!),
      ];
      final sides = FigureParts(edges: {wEdge, hEdge});
      if (!figure.grid) {
        return [
          ask,
          FigureStep(FigureMove.rectangleArea, parts: sides),
          FigureStep(
            FigureMove.twoSides,
            numbers: [width, height],
            parts: sides,
          ),
          areaIs(
            [width, height],
            ['×'],
            inside,
            checkKind: FigureCheck.calculation,
            check:
                '${en(height)} × ${en(width)} = ${en(width * height ~/ 100)}',
          ),
        ];
      }
      // With the grid: columns along the bottom, rows along the right side.
      final rows = height ~/ 100;
      return [
        ask,
        const FigureStep(FigureMove.gridArea, parts: inside),
        FigureStep(
          FigureMove.oneRow,
          numbers: [width],
          parts: FigureParts(edges: {wEdge}, rows: const {0}),
        ),
        FigureStep(
          FigureMove.rows,
          numbers: [height],
          parts: FigureParts(
            edges: {hEdge},
            rows: {for (var row = 0; row < rows; row++) row},
          ),
        ),
        areaIs(
          [height, width],
          ['×'],
          inside,
          checkKind: FigureCheck.countSquares,
        ),
      ];
  }
}

/// An L-shape's labelled edges, the top (edge 0), the inner horizontal
/// edge (2), the right edge (3) and the left one (5), and the two without a
/// number: the bottom (4) is the top and the inner edge together; the inner
/// vertical edge (1) is the left one less the right one.
({int top, int inner, int right, int left, int bottom, int step}) _lShape(
  Map<int, int?> byEdge,
) {
  final (top, inner, right, left) = (
    byEdge[0]!,
    byEdge[2]!,
    byEdge[3]!,
    byEdge[5]!,
  );
  return (
    top: top,
    inner: inner,
    right: right,
    left: left,
    bottom: top + inner,
    step: left - right,
  );
}

/// Pythagoras' theorem for the length marked `?`, read from the labels: a
/// right triangle's legs are edges 2 and 0 and its longest side edge 1; a
/// rectangle's diagonal is the longest side of the two right triangles it
/// cuts, whose legs are the labelled sides. Each side is squared on its
/// own, then the squares are added (or the smaller taken from the bigger),
/// and the last step finds the number that times itself makes the result.
List<FigureStep> _pythagorasHint(Figure figure, Map<int, int?> byEdge) {
  int square(int side) => side * side ~/ 100;
  // The side whose square is [area], in whole steps: no floating point.
  int root(int area) {
    var side = 100;
    while (square(side) < area) {
      side += 100;
    }
    return side;
  }

  FigureStep squared(int edge) => FigureStep(
    FigureMove.squareSide,
    numbers: [byEdge[edge]!],
    terms: [byEdge[edge]!, byEdge[edge]!],
    signs: const ['×'],
    valueHundredths: square(byEdge[edge]!),
    parts: FigureParts(edges: {edge}),
  );
  final diagonal = figure.diagonal;
  final asked = diagonal
      ? null
      : byEdge.keys.firstWhere((edge) => byEdge[edge] == null);
  final target = FigureParts(edges: {?asked}, diagonal: diagonal);
  // The two labelled sides: the legs, or the longest side first.
  final [first, second] = diagonal
      ? [for (final label in figure.labels) label.edge]
      : asked == 1
      ? [2, 0]
      : [1, asked == 0 ? 2 : 0];
  final (a, b) = (square(byEdge[first]!), square(byEdge[second]!));
  final add = asked == 1 || diagonal;
  final result = add ? a + b : a - b;
  final length = root(result);
  return [
    FigureStep(FigureMove.askLength, parts: target),
    if (diagonal) ...[
      FigureStep(
        FigureMove.diagonalTriangles,
        parts: const FigureParts(diagonal: true),
      ),
      FigureStep(
        FigureMove.pythagoras,
        parts: FigureParts(edges: {first, second}, diagonal: true),
      ),
    ] else
      const FigureStep(
        FigureMove.pythagoras,
        parts: FigureParts(edges: {0, 1, 2}, rightAngle: true),
      ),
    squared(first),
    squared(second),
    FigureStep(
      add ? FigureMove.addSquares : FigureMove.takeSquare,
      terms: [a, b],
      signs: [add ? '+' : '−'],
      valueHundredths: result,
      parts: FigureParts(edges: {first, second}),
    ),
    FigureStep(FigureMove.whichSquare, numbers: [result], parts: target),
    FigureStep(
      FigureMove.rootLength,
      terms: [length, length],
      signs: const ['×'],
      valueHundredths: result,
      parts: target,
    ),
  ];
}

/// The two working steps that find an L-shape's sides without a number.
List<FigureStep> _lShapeSides(int top, int inner, int right, int left) => [
  FigureStep(
    FigureMove.lBottom,
    terms: [top, inner],
    signs: const ['+'],
    valueHundredths: top + inner,
    parts: const FigureParts(edges: {0, 2, 4}),
  ),
  FigureStep(
    FigureMove.lStep,
    terms: [left, right],
    signs: const ['−'],
    valueHundredths: left - right,
    parts: const FigureParts(edges: {5, 3, 1}),
  ),
];

/// The sentences of [figureHint]; each only wraps its step's numbers, and
/// numbers are written in the language's own way.
List<SolutionStep> figureSteps(Figure figure) => [
  for (final step in figureHint(figure)) _figureSentence(step),
];

SolutionStep _figureSentence(FigureStep step) => (l) {
  String n(int hundredths) => formatHundredths(hundredths, l.localeName);
  final numbers = [for (final number in step.numbers) n(number)];
  final value = switch (step.valueHundredths) {
    final value? => n(value),
    null => '',
  };
  final calculation = step.terms.isEmpty
      ? ''
      : _terms(step.terms, step.signs, l.localeName);
  String check() => step.check!.replaceAll('.', decimalSeparator(l.localeName));
  final sentence = switch (step.move) {
    FigureMove.askPerimeter => l.hintAskPerimeter,
    FigureMove.askArea => l.hintAskArea,
    FigureMove.askSideFromPerimeter => l.hintAskSideFromPerimeter,
    FigureMove.askSideFromArea => l.hintAskSideFromArea,
    FigureMove.askAngle => l.hintAskAngle,
    FigureMove.askCircumference => l.hintAskCircumference,
    FigureMove.squareSides => l.hintIdeaSquareSides,
    FigureMove.rectangleSides => l.hintIdeaRectangleSides,
    FigureMove.perimeterAdds => l.hintIdeaPerimeterAdds,
    FigureMove.gridArea => l.hintIdeaGridArea,
    FigureMove.rectangleArea => l.hintIdeaRectangleArea,
    FigureMove.halfPerimeter => l.hintIdeaHalfPerimeter,
    FigureMove.squareArea => l.hintIdeaSquareArea,
    FigureMove.triangleAngles => l.hintIdeaTriangleAngles(numbers.single),
    FigureMove.straightAngle => l.hintIdeaStraightAngle(numbers.single),
    FigureMove.rightAngle => l.hintIdeaRightAngle(numbers.single),
    FigureMove.rightTriangle => l.hintIdeaRightTriangle,
    FigureMove.lShapePerimeter => l.hintIdeaLShapePerimeter,
    FigureMove.lShapeArea => l.hintIdeaLShapeArea,
    FigureMove.circumference => l.hintIdeaCircumference(numbers.single),
    FigureMove.circleArea => l.hintIdeaCircleArea(numbers.single),
    FigureMove.everySide => l.hintEverySide(numbers.single),
    FigureMove.oppositeTop => l.hintOppositeTop(numbers.single),
    FigureMove.oppositeLeft => l.hintOppositeLeft(numbers.single),
    FigureMove.threeSides => l.hintThreeSides(
      numbers[0],
      numbers[1],
      numbers[2],
    ),
    FigureMove.oneRow => l.hintOneRow(numbers.single),
    FigureMove.rows => l.hintRows(numbers.single),
    FigureMove.shareFour => l.hintShareFour(numbers.single),
    FigureMove.whichSquare => l.hintWhichSquare(numbers.single),
    FigureMove.halfOf => l.hintHalfOf(calculation, value),
    FigureMove.undoTimes => l.hintUndoTimes(numbers[0], numbers[1]),
    FigureMove.takeFirstAngle => l.hintTakeFirstAngle(calculation, value),
    FigureMove.knownAngle => l.hintKnownAngle(numbers.single),
    FigureMove.knownPart => l.hintKnownPart(numbers.single),
    FigureMove.legsRectangle => l.hintLegsRectangle(
      numbers[0],
      numbers[1],
      calculation,
      value,
    ),
    FigureMove.lBottom => l.hintLBottom(calculation, value),
    FigureMove.lStep => l.hintLStep(calculation, value),
    FigureMove.wholeRectangle => l.hintWholeRectangle(calculation, value),
    FigureMove.cutCorner => l.hintCutCorner(calculation, value),
    FigureMove.twoSides => l.hintTwoSides(numbers[0], numbers[1]),
    FigureMove.diameter => l.hintDiameter(numbers.single),
    FigureMove.radius => l.hintRadius(numbers.single),
    FigureMove.radiusSquared => l.hintRadiusSquared(calculation, value),
    FigureMove.perimeterIs => l.hintPerimeterIs(calculation, value),
    FigureMove.areaIs => l.hintAreaIs(calculation, value),
    FigureMove.sideIs => l.hintSideIs(calculation, value),
    FigureMove.rootSide => l.hintRootSide(
      calculation,
      value,
      n(step.terms.first),
    ),
    FigureMove.angleIs => l.hintAngleIs(calculation, value),
    FigureMove.circumferenceIs => l.hintCircumferenceIs(calculation, value),
    FigureMove.askLength => l.hintAskLength,
    FigureMove.halveThenTakeAway => l.hintHalveThenTakeAway,
    FigureMove.pythagoras => l.hintIdeaPythagoras,
    FigureMove.diagonalTriangles => l.hintIdeaDiagonal,
    FigureMove.verticallyOpposite => l.hintIdeaVerticallyOpposite(
      numbers.single,
    ),
    FigureMove.aroundPoint => l.hintIdeaAroundPoint(numbers.single),
    FigureMove.betweenAngle => l.hintBetweenAngle(calculation, value),
    FigureMove.addKnownAngles => l.hintAddKnownAngles(calculation, value),
    FigureMove.squareSide => l.hintSquareSide(
      numbers.single,
      calculation,
      value,
    ),
    FigureMove.addSquares => l.hintAddSquares(calculation, value),
    FigureMove.takeSquare => l.hintTakeSquare(calculation, value),
    FigureMove.rootLength => l.hintRootLength(
      calculation,
      value,
      n(step.terms.first),
    ),
  };
  final checked = switch (step.checkKind) {
    FigureCheck.calculation => l.hintCheck(check()),
    FigureCheck.sides => l.hintCheckSides('${step.terms.length}'),
    FigureCheck.aBitMore => l.hintCheckABitMore(check()),
    FigureCheck.countSquares => l.hintCheckCountSquares,
    null => null,
  };
  return checked == null ? sentence : '$sentence $checked';
};

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
  /// the letter or a bracket multiplies.
  means,

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

  /// Whole numbers; [EquationMove.means] and [EquationMove.belowZero] have
  /// no calculation and leave these at 0 and ''.
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

/// The hint of an equation as data. With the blank (levels 1 and 2) the
/// first step names the operation around the blank and the calculation that
/// undoes it, using only numbers the question shows; the last does that
/// calculation, states the answer and puts it back in place of the blank.
///
/// With the letter n (from level 3) the steps undo one operation at a time
/// on both sides: a step first says what a short form such as `2n` means
/// and, when the answer is below zero, explains its minus sign; an undo
/// before the last is done at once and shows the equation it leaves; the
/// last undo is named, then done in the answer step.
List<EquationStep> equationHint(EquationProblem problem) {
  final answer = problem.resultHundredths;
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
  String calculation(AppLocalizations l) => '${step.calculation} = ${value(l)}';
  String undo(AppLocalizations l) => switch (step.move) {
    EquationMove.subtractBoth => l.stepEquationSubtractBoth(right),
    EquationMove.addBoth => l.stepEquationAddBoth(right),
    EquationMove.divideBoth => l.stepEquationDivideBoth(right),
    _ => l.stepEquationMultiplyBoth(right),
  };
  return switch (step.move) {
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
    EquationMove.subtractBoth ||
    EquationMove.addBoth ||
    EquationMove.divideBoth ||
    EquationMove.multiplyBoth =>
      (l) => step.equation == null
          ? undo(l)
          : '${undo(l)} ${l.stepEquationSoNow(calculation(l), step.equation!)}',
    EquationMove.answer when letter => (l) => l.stepEquationLetterIs(
      calculation(l),
      value(l),
      local(l, step.check!),
    ),
    EquationMove.answer => (l) => l.stepEquationBlankIs(
      calculation(l),
      value(l),
      local(l, step.check!),
    ),
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

/// The hint of a figure question, read from its labels: name every side
/// the perimeter adds, then add them; for an area, count the rows of unit
/// squares, then multiply. The answer appears only in the last step.
List<SolutionStep> figureSteps(Figure figure) {
  final sides = [for (final label in figure.labels) label.text];
  final values = [for (final label in figure.labels) label.hundredths! ~/ 100];
  if (figure.prompt == FigurePrompt.area) {
    // The first label is the bottom edge (columns), the second the right one.
    final [columns, rows] = values;
    return [
      (l) => l.stepAreaRows('$rows', '$columns'),
      (l) => l.stepSoResult('$rows', '×', '$columns', '${rows * columns}'),
    ];
  }
  final all = switch (figure.shape) {
    FigureShape.square => [for (var i = 0; i < 4; i++) values[0]],
    FigureShape.rectangle => [...values, ...values],
    FigureShape.triangle => values,
  };
  final SolutionStep first = switch (figure.shape) {
    FigureShape.square => (l) => l.stepSquareSides(sides[0]),
    FigureShape.rectangle => (l) => l.stepRectangleSides(sides[0], sides[1]),
    FigureShape.triangle => (l) => l.stepTriangleSides(
      sides[0],
      sides[1],
      sides[2],
    ),
  };
  return [
    first,
    (l) =>
        l.stepPerimeterSum(all.join(' + '), '${all.reduce((a, b) => a + b)}'),
  ];
}

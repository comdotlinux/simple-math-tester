import 'l10n/app_localizations.dart';
import 'operations.dart';

// Every writer returns at least 2 steps, and only the last one states the
// result: no earlier step contains it as a number unless it equals an operand.

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

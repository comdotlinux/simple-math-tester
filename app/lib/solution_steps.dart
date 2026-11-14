import 'operations.dart';

// Every writer returns at least 2 steps, and only the last one states the
// result: no earlier step contains it as a number unless it equals an operand.

List<String> solutionSteps(Problem problem) => problem.kind.steps(problem);

List<String> additionSteps(Problem problem) {
  final left = problem.lhs;
  final right = problem.rhs;
  final result = formatNumber(problem.result);
  final calculations = <String>[];
  final totals = <int>[];
  for (
    var place = _highestPlace(left > right ? left : right);
    place >= 1;
    place ~/= 10
  ) {
    final leftPart = (left ~/ place) % 10 * place;
    final rightPart = (right ~/ place) % 10 * place;
    calculations.add('$leftPart + $rightPart = ${leftPart + rightPart}');
    totals.add(leftPart + rightPart);
  }
  if (totals.where((total) => total > 0).length > 1) {
    // Each place total is smaller than the sum because another one is not 0.
    return [
      'Break $left into ${_placeParts(left).join(' + ')} and $right into '
          '${_placeParts(right).join(' + ')}.',
      'Add matching places: ${calculations.join('; ')}.',
      'Combine the parts: ${totals.join(' + ')} = $result.',
    ];
  }
  // One place only, so its total would be the answer itself.
  final bigger = left >= right ? left : right;
  final smaller = left >= right ? right : left;
  final place = _highestPlace(bigger);
  if (place == 1) {
    final counted = [for (var i = 1; i < smaller && i <= 3; i++) bigger + i];
    return [
      'Start at $bigger and count on $smaller more'
          '${counted.isEmpty ? '.' : ': ${counted.join(', ')}, …'}',
      'So $left + $right = $result.',
    ];
  }
  final name = _placeNames[place]!;
  String count(int value) =>
      '${value ~/ place} $name${value ~/ place == 1 ? '' : 's'}';
  return [
    '$left is ${count(left)} and $right is ${count(right)}. '
        'Add ${left ~/ place} + ${right ~/ place}, then make it ${name}s.',
    'So $left + $right = $result.',
  ];
}

List<String> subtractionSteps(Problem problem) {
  final left = problem.lhs;
  final right = problem.rhs;
  final result = problem.result;
  if (left == right) {
    return [
      'Find the difference between $left and $right.',
      'Both numbers are the same, so taking one away from the other leaves '
          'nothing.',
      'So $left − $right = ${formatNumber(result)}.',
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
  final hopText =
      'Hop to round numbers: '
      '${hops.map((hop) => 'from ${hop.$1} up to ${hop.$2} is ${hop.$2 - hop.$1}').join('; ')}.';
  final useHops = hops.length > 1 && !_mentions(hopText, result);
  return [
    'Find the difference between $left and $right: '
        'what do you add to $right to make $left?',
    useHops
        ? hopText
        : 'Count up from $right to $left in hops, for example to the next '
              'ten, and keep track of how far you went.',
    useHops
        ? 'Add the hops: ${hops.map((hop) => hop.$2 - hop.$1).join(' + ')} = '
              '${formatNumber(result)}. So $left − $right = ${formatNumber(result)}.'
        : 'So $left − $right = ${formatNumber(result)}. '
              'Check: ${formatNumber(result)} + $right = $left.',
  ];
}

List<String> multiplicationSteps(Problem problem) {
  final left = problem.lhs;
  final right = problem.rhs;
  final result = formatNumber(problem.result);
  final split = left >= right ? left : right;
  final multiplier = left >= right ? right : left;
  final parts = _placeParts(split);
  if (parts.length == 1) {
    // Every listed count is a smaller multiple, so it stays below the result.
    final counted = [for (var i = 1; i < multiplier && i <= 3; i++) split * i];
    return [
      '$left × $right means $multiplier groups of $split.',
      'Count in ${split}s, $multiplier times: ${counted.join(', ')}, …',
      'So $left × $right = $result.',
    ];
  }
  // Each product is smaller than the result because the other parts add more.
  final products = parts.map((part) => multiplier * part).toList();
  return [
    'Split $split into ${parts.join(' + ')}.',
    'Multiply each part by $multiplier: '
        '${parts.map((part) => '$multiplier × $part = ${multiplier * part}').join('; ')}.',
    'Add the products: ${products.join(' + ')} = $result.',
  ];
}

List<String> divisionSteps(Problem problem) {
  final left = problem.lhs;
  final right = problem.rhs;
  final result = problem.result;
  final counted = [for (var i = 1; i < result && i <= 3; i++) right * i]
      .join(', ');
  final countText =
      'Count in ${right}s: $counted, … until you reach $left. '
      'How many ${right}s did you count?';
  return [
    'How many ${right}s make $left? Think: $right × ? = $left.',
    _mentions(countText, result)
        ? 'Count in ${right}s until you reach $left. '
              'How many ${right}s did you count?'
        : countText,
    '$right × ${formatNumber(result)} = $left, '
        'so $left ÷ $right = ${formatNumber(result)}.',
  ];
}

const _placeNames = {10: 'ten', 100: 'hundred', 1000: 'thousand'};

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

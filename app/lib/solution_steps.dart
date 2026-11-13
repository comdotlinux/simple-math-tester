import 'operations.dart';

List<String> solutionSteps(Operation<num, num> operation) {
  final left = operation.lhs as int;
  final right = operation.rhs as int;
  final result = _number(operation.result);

  switch (operation.operationType) {
    case OperationType.plus:
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
      return [
        'Break $left into ${_placeParts(left).join(' + ')} and $right into '
            '${_placeParts(right).join(' + ')}.',
        'Add matching places: ${calculations.join('; ')}.',
        'Combine the parts: ${totals.join(' + ')} = $result.',
      ];
    case OperationType.minus:
      return [
        'Find the difference between $left and $right.',
        'Count up from $right: $right + $result = $left.',
        'So $left - $right = $result. Check: $result + $right = $left.',
      ];
    case OperationType.multiply:
      final split = left >= right ? left : right;
      final multiplier = left >= right ? right : left;
      final parts = _placeParts(split);
      if (parts.length == 1) {
        return [
          '$left × $right means $multiplier groups of $split.',
          '${List.filled(multiplier, split).join(' + ')} = $result.',
          'So $left × $right = $result.',
        ];
      }
      final products = parts.map((part) => multiplier * part).toList();
      return [
        'Split $split into ${parts.join(' + ')}.',
        'Multiply each part by $multiplier: '
            '${parts.map((part) => '$multiplier × $part = ${multiplier * part}').join('; ')}.',
        'Add the products: ${products.join(' + ')} = $result.',
      ];
    case OperationType.divide:
      return [
        'Find the number that multiplies $right to make $left.',
        '$right × $result = $left.',
        'So $left ÷ $right = $result.',
      ];
  }
}

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

String _number(num value) =>
    value == value.toInt() ? value.toInt().toString() : value.toString();

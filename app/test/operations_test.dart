import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';

void main() {
  OperationType.values.map((operationType) => OperationType.operator(operationType)).forEach((operator) {
    test('${operator.operationType()} returns operands between ${operator.minOperandValue()} and ${operator.maxOperandValue()} as well as results between ${operator.minResultValue()} and ${operator.maxResultValue()}', () {
      for (var i = 0; i < 10000; i++) {
        var operation = operator.create();
        expect(operation.lhs, greaterThanOrEqualTo(operator.minOperandValue()));
        expect(operation.lhs, lessThanOrEqualTo(operator.maxOperandValue()));

        expect(operation.rhs, greaterThanOrEqualTo(operator.minOperandValue()));
        expect(operation.rhs, lessThanOrEqualTo(operator.maxOperandValue()));

        expect(operation.result, greaterThanOrEqualTo(operator.minResultValue()));
        expect(operation.result, lessThanOrEqualTo(operator.maxResultValue()));
      }
    });
  });
}

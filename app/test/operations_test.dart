import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';

void main() {
  test('all operations calculate correct results', () {
    expect(Addition().calculateResult(12, 3), 15);
    expect(Subtraction().calculateResult(12, 3), 9);
    expect(Multiplication().calculateResult(12, 3), 36);
    expect(Division().calculateResult(12, 3), 4);
  });

  for (final type in OperationType.values) {
    final operator = OperationType.operator(type);
    test('$type preserves operand/result ranges and acceptance rules', () {
      for (var i = 0; i < 10000; i++) {
        final operation = operator.create();
        expect(operation.lhs, greaterThanOrEqualTo(operator.minOperandValue()));
        expect(operation.lhs, lessThanOrEqualTo(operator.maxOperandValue()));
        expect(operation.rhs, greaterThanOrEqualTo(operator.minOperandValue()));
        expect(operation.rhs, lessThanOrEqualTo(operator.maxOperandValue()));
        expect(
          operation.result,
          greaterThanOrEqualTo(operator.minResultValue()),
        );
        expect(operation.result, lessThanOrEqualTo(operator.maxResultValue()));
        expect(operator.acceptable(operation), isTrue);
        expect(
          operation.result,
          operator.calculateResult(operation.lhs, operation.rhs),
        );
      }
    });
  }

  test('subtraction disallows negative results and division is integral', () {
    expect(
      Subtraction().acceptable(Operation(2, 3, OperationType.minus, -1)),
      isFalse,
    );
    expect(
      Division().acceptable(Operation(7, 3, OperationType.divide, 7 / 3)),
      isFalse,
    );
  });

  test('integer-result operations accept double input', () {
    final operation = Operation<int, int>(2, 3, OperationType.plus, 5);
    // Widen the static type to reproduce the original model's runtime boundary.
    final Operation<num, num> current = operation;
    current.input = 5.0;
    expect(current.inputCorrect(), isTrue);
  });

  test('decimal input remains exact in diagnostics', () {
    final Operation<num, num> operation = Operation(
      2,
      3,
      OperationType.plus,
      5,
    );
    operation.input = 4.5;
    expect(operation.toString(), contains('you entered 4.5.'));
  });

  test('null input does not stop the timer', () {
    final operation = Operation(2, 3, OperationType.plus, 5);
    operation.input = null;
    expect(operation.stopwatch.isRunning, isTrue);
    expect(operation.inputEntered(), isFalse);
  });

  test('non-finite input is rejected without stopping the timer', () {
    final Operation<num, num> operation = Operation(
      2,
      3,
      OperationType.plus,
      5,
    );
    expect(() => operation.input = double.nan, throwsArgumentError);
    expect(() => operation.input = double.infinity, throwsArgumentError);
    expect(operation.stopwatch.isRunning, isTrue);
    expect(operation.input, isNull);
  });
}

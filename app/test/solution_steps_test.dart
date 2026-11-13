import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/solution_steps.dart';

void main() {
  test('addition shows place values and carrying', () {
    expect(solutionSteps(Operation(19, 6, OperationType.plus, 25)), [
      'Break 19 into 10 + 9 and 6 into 6.',
      'Add matching places: 10 + 0 = 10; 9 + 6 = 15.',
      'Combine the parts: 10 + 15 = 25.',
    ]);
  });

  test('subtraction shows counting up and an addition check', () {
    expect(solutionSteps(Operation(12, 3, OperationType.minus, 9)), [
      'Find the difference between 12 and 3.',
      'Count up from 3: 3 + 9 = 12.',
      'So 12 - 3 = 9. Check: 9 + 3 = 12.',
    ]);
  });

  test('multiplication shows partial products', () {
    expect(solutionSteps(Operation(4, 223, OperationType.multiply, 892)), [
      'Split 223 into 200 + 20 + 3.',
      'Multiply each part by 4: 4 × 200 = 800; 4 × 20 = 80; 4 × 3 = 12.',
      'Add the products: 800 + 80 + 12 = 892.',
    ]);
  });

  test('division shows the inverse multiplication', () {
    expect(solutionSteps(Operation(12, 3, OperationType.divide, 4.0)), [
      'Find the number that multiplies 3 to make 12.',
      '3 × 4 = 12.',
      'So 12 ÷ 3 = 4.',
    ]);
  });
}

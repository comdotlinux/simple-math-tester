import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/rules.dart';

void main() {
  int reveal(int revealed, {bool checked = false, int stepCount = 3}) =>
      nextRevealed(
        revealed: revealed,
        event: HintEvent.reveal,
        stepCount: stepCount,
        checked: checked,
      );

  int wrongCheck(int revealed) => nextRevealed(
    revealed: revealed,
    event: HintEvent.wrongFirstCheck,
    stepCount: 3,
    checked: true,
  );

  test('Hint reveals 1 step and each Next step adds 1', () {
    expect(reveal(0), 1);
    expect(reveal(1), 2);
  });

  test('the last step needs a valid check first', () {
    expect(reveal(2), 2);
    expect(reveal(2, checked: true), 3);
    expect(reveal(3, checked: true), 3);
    expect(reveal(1, stepCount: 2), 1);
  });

  test('a wrong first check reveals at least 1 step and hides none', () {
    expect(wrongCheck(0), 1);
    expect(wrongCheck(1), 1);
    expect(wrongCheck(2), 2);
  });
}

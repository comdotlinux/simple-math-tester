import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';

void main() {
  MathTesterModel modelFor(Operation operation) => MathTesterModel(
    initialOperation: operation,
    nextOperation: () => Operation(6, 3, OperationType.minus, 3),
  );

  for (final type in OperationType.values) {
    test('accepts numeric input for $type without generic type errors', () {
      final operator = OperationType.operator(type);
      final operation = Operation(12, 3, type, operator.calculateResult(12, 3));
      final model = modelFor(operation);
      addTearDown(model.dispose);

      model.setDraftInput('${operation.result}');
      expect(model.submitAnswer(), isTrue);
      expect(model.answerCorrect, isTrue);
      expect(operation.inputCorrect(), isTrue);
      expect(model.validationMessage, isNull);
    });
  }

  test('Next archives once and cannot reuse a previous answer', () {
    final original = Operation(2, 3, OperationType.plus, 5);
    final model = modelFor(original);
    addTearDown(model.dispose);
    model.setDraftInput('5');
    model.submitAnswer();
    model.submitAnswer();
    expect(model.completedProblems, isEmpty);

    model.generateNextProblem();
    expect(model.completedProblems, [original]);
    expect(model.draftInput, isEmpty);
    expect(model.answerCorrect, isNull);
    expect(model.validationMessage, isNull);
    expect(model.current.input, isNull);
    expect(model.submitAnswer(), isFalse);
    expect(model.current.input, isNull);
    expect(model.current.stopwatch.isRunning, isTrue);
  });

  for (final text in [
    '',
    '  ',
    'hello',
    '1..2',
    'NaN',
    'Infinity',
    '-Infinity',
  ]) {
    test('invalid input "$text" does not submit or stop the timer', () {
      final operation = Operation(2, 3, OperationType.plus, 5);
      final model = modelFor(operation);
      addTearDown(model.dispose);
      model.setDraftInput(text);

      expect(model.submitAnswer(), isFalse);
      expect(model.validationMessage, isNotEmpty);
      expect(model.answerCorrect, isNull);
      expect(operation.inputEntered(), isFalse);
      expect(operation.stopwatch.isRunning, isTrue);
      expect(model.completedProblems, isEmpty);
    });
  }

  test('retry updates the answer but keeps first valid submission time', () {
    final operation = Operation(2, 3, OperationType.plus, 5);
    final model = modelFor(operation);
    addTearDown(model.dispose);
    model.setDraftInput('4');
    model.submitAnswer();
    final elapsed = operation.stopwatch.elapsed;
    final formattedElapsed = operation.elapsed;
    expect(model.answerCorrect, isFalse);

    model.setDraftInput('5.0');
    expect(model.answerCorrect, isNull);
    model.submitAnswer();
    expect(model.answerCorrect, isTrue);
    expect(operation.stopwatch.elapsed, elapsed);
    expect(operation.elapsed, formattedElapsed);
  });

  test('editing clears validation and navigation preserves the draft', () {
    final operation = Operation(2, 3, OperationType.plus, 5);
    final model = modelFor(operation);
    addTearDown(model.dispose);
    model.submitAnswer();
    model.setDraftInput(' 5 ');
    expect(model.validationMessage, isNull);
    model.setCurrentPage(1);
    model.setCurrentPage(0);
    expect(model.current, same(operation));
    expect(model.draftInput, ' 5 ');
    expect(model.submitAnswer(), isTrue);
    expect(model.answerCorrect, isTrue);
  });

  test('skipped questions remain unanswered in history', () {
    final operation = Operation(2, 3, OperationType.plus, 5);
    final model = modelFor(operation);
    addTearDown(model.dispose);
    model.setDraftInput('5');
    model.generateNextProblem();
    expect(model.completedProblems.single, same(operation));
    expect(operation.inputEntered(), isFalse);
    expect(operation.inputCorrect(), isFalse);
  });

  test('invalid navigation is rejected without changing the current page', () {
    final model = modelFor(Operation(2, 3, OperationType.plus, 5));
    addTearDown(model.dispose);
    expect(() => model.setCurrentPage(2), throwsRangeError);
    expect(model.currentPage, 0);
  });
}

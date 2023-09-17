import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/operations.dart';

class ProblemPage extends StatelessWidget {
  const ProblemPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MathTesterAppState>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(
            operation: appState.current,
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                  onPressed: () {
                    appState.checkInput(0);
                  },
                  icon: Icon(appState.current.inputEntered()
                      ? appState.current.inputCorrect()
                          ? Icons.check_rounded
                          : Icons.clear_rounded
                      : Icons.question_mark),
                  label: Text(!appState.current.inputEntered()
                      ? 'Check Input'
                      : appState.current.inputCorrect()
                          ? 'Correct'
                          : 'Incorrect')),
              const SizedBox(
                width: 60,
              ),
              ElevatedButton.icon(
                onPressed: appState.generateNextProblem,
                icon: const Icon(Icons.navigate_next),
                label: const Text('Next'),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.operation,
  });

  final Operation operation;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(color: theme.colorScheme.onPrimary);
    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('   ', style: style),
                Text(
                  operation.left,
                  style: style,
                  semanticsLabel: "First Operand is ${operation.left}",
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  operation.operationType.displayString,
                  style: style,
                  semanticsLabel: "Operation is ${operation.operationType.displayString}",
                ),
                Text(
                  ' ',
                  style: style,
                ),
                Text(
                  operation.right,
                  style: style,
                  semanticsLabel: "Second Operand is ${operation.right}",
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(' ', style: style),
                SizedBox(
                  width: 150,
                height: 100,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: style,
                    onSubmitted: (userInput) {
                      operation.input = double.tryParse(userInput.split('').reversed.join());
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

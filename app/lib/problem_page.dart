import 'dart:html';

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
    final appState = context.watch<MathTesterModel>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                  onPressed: () {
                    appState.checkInput();
                  },
                  icon: Icon(appState.current.inputEntered()
                      ? appState.current.inputCorrect()
                          ? Icons.check_rounded
                          : Icons.clear_rounded
                      : Icons.question_mark),
                  label: Text(checkButtonText(appState.current))),
              const SizedBox(width: 60),
              ElevatedButton.icon(onPressed: appState.generateNextProblem, icon: const Icon(Icons.navigate_next), label: const Text('Next')),
            ],
          )
        ],
      ),
    );
  }

  String checkButtonText(Operation currentOperation) => !currentOperation.inputEntered()
      ? 'Check Input'
      : currentOperation.inputCorrect()
          ? 'Correct'
          : 'Incorrect';
}

class BigCard extends StatefulWidget {
  const BigCard({super.key});

  @override
  State<BigCard> createState() => _BigCardState();
}

class _BigCardState extends State<BigCard> {
  var userInputController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MathTesterModel>();
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(color: theme.colorScheme.onPrimary);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Simple Math Questions.',
            style: theme.textTheme.displayMedium!.copyWith(color: theme.colorScheme.inversePrimary),
          ),
        ),
        Card(
          color: theme.colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: 300,
              height: 300,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(left: 30.0), child: Text(appState.current.left, style: style, semanticsLabel: "First Operand is ${appState.current.left}")),
                    ],
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 5.0),
                        child: Text(appState.current.operationType.displayString, style: style, semanticsLabel: "Operation is ${appState.current.operationType.displayString}"),
                      ),
                      Text(appState.current.right, style: style, semanticsLabel: "Second Operand is ${appState.current.right}"),
                    ],
                  ),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    style: style,
                    controller: userInputController,
                    onTapOutside: (_) {
                      final userInput = double.tryParse(userInputController.value.text);
                      debugPrint('changed value : $userInput');
                      appState.setInput(userInput);
                      userInputController.clear();
                    },
                    onSubmitted: (value) {
                      final userInput = double.tryParse(value);
                      debugPrint('value : $userInput');
                      appState.checkInput();
                      userInputController.clear();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
    userInputController.dispose();
  }
}

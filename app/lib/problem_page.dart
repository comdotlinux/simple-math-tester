import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/operations.dart';

import 'keys.dart';

class ProblemPage extends StatelessWidget {
  const ProblemPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MathTesterModel>();
    var screenSize = MediaQuery.of(context).size;

    return Center(
      widthFactor: 100.0,
      child: SizedBox(
        width: screenSize.width > 800 ? 600 : 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const BigCard(key: questionOnProblemsPageKey),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(onPressed: appState.checkInput, icon: checkButtonIcon(appState.current), label: Text(checkButtonText(appState.current))),
                ElevatedButton.icon(onPressed: appState.generateNextProblem, icon: const Icon(Icons.navigate_next), label: const Text('Next')),
              ],
            )
          ],
        ),
      ),
    );
  }

  Icon checkButtonIcon(Operation currentOperation) {
    if (!currentOperation.inputEntered()) {
      return const Icon(Icons.question_mark);
    }
    return Icon(currentOperation.inputCorrect() ? Icons.check_rounded : Icons.clear_rounded);
  }

  String checkButtonText(Operation currentOperation) {
    if (!currentOperation.inputEntered()) {
      return 'Check Input';
    }
    return currentOperation.inputCorrect() ? 'Correct' : 'Incorrect';
  }
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
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Simple Math Questions.',
          style: theme.textTheme.displayLarge!.copyWith(color: theme.colorScheme.onPrimaryContainer),
        ),
        Card(
          color: theme.colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  appState.current.left,
                  style: style,
                  semanticsLabel: "First Operand is ${appState.current.left}",
                ),
                Text(
                  '${appState.current.operationType.displayString} ${appState.current.right}',
                  style: style,
                  semanticsLabel: "Second Operand is ${appState.current.right}",
                ),
                TextField(
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  style: style,
                  controller: userInputController,
                  onTapOutside: (_) {
                    final userInput = double.tryParse(userInputController.value.text);
                    // debugPrint('changed value : $userInput');
                    appState.setInput(userInput);
                    userInputController.clear();
                  },
                  onSubmitted: (value) {
                    final userInput = double.tryParse(value);
                    // debugPrint('value : $userInput');
                    appState.checkInput();
                    userInputController.clear();
                  },
                ),
              ],
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

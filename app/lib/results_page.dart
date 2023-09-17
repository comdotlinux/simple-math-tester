import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/main.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MathTesterAppState>();
    var theme = Theme.of(context);
    var secondaryStyle = theme.textTheme.displayMedium!.copyWith(color: theme.colorScheme.onSecondary);
    var tertiaryStyle = theme.textTheme.displayMedium!.copyWith(color: theme.colorScheme.onTertiary);
    if (appState.completedProblems.isEmpty) {
      return Center(
        child: Card(
          color: theme.colorScheme.secondary,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'No Results yet.',
              style: secondaryStyle,
            ),
          ),
        ),
      );
    }
    return ListView(
      children: [
        Card(
          color: theme.colorScheme.tertiary,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'You have ${appState.completedProblems.length} results',
              style: tertiaryStyle,
            ),
          ),
        ),
        for (var problem in appState.completedProblems)
          Card(
            color: theme.colorScheme.secondary,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: Icon(problem.inputCorrect() ? Icons.check_rounded : Icons.clear_rounded),
                title: Text(
                  problem.toString(),
                  style: secondaryStyle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/main.dart';

import 'keys.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MathTesterModel>();
    var theme = Theme.of(context);
    var secondaryStyle = theme.textTheme.displayMedium!.copyWith(color: theme.colorScheme.onSecondary);
    var tertiaryStyle = theme.textTheme.displayMedium!.copyWith(color: theme.colorScheme.onTertiary);
    if (appState.completedProblems.isEmpty) {
      return Center(
        child: Card(
          color: theme.colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              key: noResultsOnResultsPageKey,
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
          color: theme.colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('Completed ${appState.completedProblems.length} question(s).', style: tertiaryStyle),
          ),
        ),
        DataTable(
            horizontalMargin: 10,
            columns: const [
              DataColumn(label: Text('Num')),
              DataColumn(label: Text('Question')),
              DataColumn(label: Text('Expected Vs Actual')),
              DataColumn(label: Text('Took')),
            ],
            rows: appState.completedProblems
                .mapIndexed((index, operation) => DataRow(
                      color: MaterialStateProperty.resolveWith((states) => (operation.inputCorrect() ? theme.colorScheme.primary : theme.colorScheme.error).withOpacity(0.3)),
                      cells: [
                        DataCell(Text((index + 1).toString())),
                        DataCell(Text('${operation.left} ${operation.operationType.displayString} ${operation.right}')),
                        DataCell(Text('${operation.result} Vs ${operation.userInput}')),
                        DataCell(Text(operation.elapsed)),
                      ],
                    ))
                .toList()),
      ],
    );
  }
}

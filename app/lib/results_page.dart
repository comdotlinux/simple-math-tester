import 'package:collection/collection.dart';
import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/main.dart';

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
              'You have completed ${appState.completedProblems.length} question(s).',
              style: tertiaryStyle,
            ),
          ),
        ),
        DataTable(
            columns: const [
              DataColumn(label: Text('Num')),
              DataColumn(label: Text('Question')),
              DataColumn(label: Text('Expected Result')),
              DataColumn(label: Text('Actual Result')),
              DataColumn(label: Text('Correct')),
              DataColumn(label: Text('Took')),
            ],
            rows: appState.completedProblems
                .mapIndexed((index, operation) => DataRow(cells: [
                      DataCell(Text(index.toString())),
                      DataCell(Text('${operation.left} ${operation.operationType.displayString} ${operation.right}')),
                      DataCell(Text(operation.result.toString())),
                      DataCell(Text(operation.userInput)),
                      DataCell(Icon(operation.inputCorrect() ? Icons.check_rounded : Icons.clear_rounded)),
                      DataCell(Text(operation.elapsed)),
                    ]))
                .toList()),
      ],
    );
  }
}

import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'operations.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MathTesterModel>();
    final theme = Theme.of(context);
    final operations = model.completedProblems.toList();
    final useCards = MediaQuery.sizeOf(context).width < 800;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 600 ? 16 : 24,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('My answers', style: theme.textTheme.displaySmall),
                  const SizedBox(height: 24),
                  if (operations.isEmpty)
                    _emptyState(context)
                  else ...[
                    Text(
                      operations.length == 1
                          ? '1 question completed.'
                          : '${operations.length} questions completed.',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    if (useCards)
                      ...operations.mapIndexed(
                        (index, operation) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _resultCard(context, index, operation),
                        ),
                      )
                    else
                      _resultsTable(context, operations),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final model = context.read<MathTesterModel>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.auto_awesome, size: 48, color: context.tokens.teal),
            const SizedBox(height: 16),
            Text(
              'No answers yet.',
              key: noResultsOnResultsPageKey,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Try a question, then come back to see your work here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => model.setCurrentPage(0),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Practice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context, int index, Operation operation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${index + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              _question(operation),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            _status(context, operation),
            const SizedBox(height: 12),
            _answerDetails(operation),
            const SizedBox(height: 8),
            Text('Time: ${operation.elapsed}'),
          ],
        ),
      ),
    );
  }

  Widget _resultsTable(BuildContext context, List<Operation> operations) {
    final headerStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(.55),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(2.5),
        3: FlexColumnWidth(1.35),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      border: TableBorder(
        horizontalInside: BorderSide(color: context.tokens.border),
      ),
      children: [
        TableRow(
          children: [
            _tableCell(Text('#', style: headerStyle)),
            _tableCell(Text('Question', style: headerStyle)),
            _tableCell(Text('Answer', style: headerStyle)),
            _tableCell(Text('Time', style: headerStyle)),
          ],
        ),
        ...operations.mapIndexed(
          (index, operation) => TableRow(
            children: [
              _tableCell(Text('${index + 1}')),
              _tableCell(Text(_question(operation))),
              _tableCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _status(context, operation),
                    const SizedBox(height: 8),
                    _answerDetails(operation),
                  ],
                ),
              ),
              _tableCell(Text(operation.elapsed)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableCell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    child: child,
  );

  String _question(Operation operation) =>
      '${operation.left} ${operation.operationType.displayString} '
      '${operation.right}';

  Widget _status(BuildContext context, Operation operation) {
    final skipped = !operation.inputEntered();
    final correct = !skipped && operation.inputCorrect();
    final color = skipped
        ? context.tokens.muted
        : correct
        ? context.tokens.teal
        : context.tokens.error;
    final label = skipped
        ? 'Skipped'
        : correct
        ? 'Correct'
        : 'Incorrect';
    final icon = skipped
        ? Icons.remove_circle_outline
        : correct
        ? Icons.check_circle
        : Icons.refresh;
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _answerDetails(Operation operation) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        operation.inputEntered()
            ? 'Your answer: ${operation.userInput}'
            : 'No answer entered',
      ),
      const SizedBox(height: 4),
      Text('Expected answer: ${operation.result}'),
    ],
  );
}

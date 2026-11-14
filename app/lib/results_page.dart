import 'dart:math';

import 'package:duration/duration.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'operations.dart';
import 'rules.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  static const _columnFlex = [55, 160, 250, 135];

  @override
  Widget build(BuildContext context) {
    final history = context.select((MathTesterModel model) => model.history);
    final theme = Theme.of(context);
    final useCards = MediaQuery.sizeOf(context).width < 800;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = constraints.maxWidth < 600 ? 16.0 : 24.0;
        // Centres a column of at most 1100 px, as Center + ConstrainedBox did.
        final horizontal = max(gutter, (constraints.maxWidth - 1100) / 2);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: 24,
              ),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('My answers', style: theme.textTheme.displaySmall),
                        const SizedBox(height: 24),
                        if (history.isEmpty)
                          _emptyState(context)
                        else ...[
                          const _Stats(),
                          const SizedBox(height: 24),
                          Text(
                            history.length == 1
                                ? '1 question completed.'
                                : '${history.length} questions completed.',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),
                          if (!useCards) _tableHeader(context),
                        ],
                      ],
                    ),
                  ),
                  SliverList.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) => useCards
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _resultCard(context, index, history[index]),
                          )
                        : _tableRow(context, index, history[index]),
                  ),
                ],
              ),
            ),
          ],
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

  Widget _resultCard(BuildContext context, int index, Attempt attempt) {
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
              _question(attempt),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            _status(context, attempt),
            const SizedBox(height: 12),
            _answerDetails(attempt),
            const SizedBox(height: 8),
            Text('Time: ${_elapsed(attempt)}'),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    return _tableCells([
      Text('#', style: headerStyle),
      Text('Question', style: headerStyle),
      Text('Answer', style: headerStyle),
      Text('Time', style: headerStyle),
    ]);
  }

  Widget _tableRow(BuildContext context, int index, Attempt attempt) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      child: _tableCells([
        Text('${index + 1}'),
        Text(_question(attempt)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _status(context, attempt),
            const SizedBox(height: 8),
            _answerDetails(attempt),
          ],
        ),
        Text(_elapsed(attempt)),
      ]),
    );
  }

  Widget _tableCells(List<Widget> cells) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var column = 0; column < cells.length; column++)
        Expanded(flex: _columnFlex[column], child: _tableCell(cells[column])),
    ],
  );

  Widget _tableCell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    child: child,
  );

  String _question(Attempt attempt) => attempt.problem.question;

  String _elapsed(Attempt attempt) => attempt.skipped
      ? 'Not Available'
      : prettyDuration(Duration(milliseconds: attempt.elapsedMs));

  Widget _status(BuildContext context, Attempt attempt) {
    final skipped = attempt.skipped;
    final correct = attempt.correct;
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

  Widget _answerDetails(Attempt attempt) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        attempt.skipped
            ? 'No answer entered'
            : 'Your answer: ${formatNumber(attempt.firstAnswer!)}',
      ),
      const SizedBox(height: 4),
      Text('Expected answer: ${formatNumber(attempt.problem.result)}'),
    ],
  );
}

/// Lifetime accuracy and level per operation, streaks, XP and player level.
class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    final difficulty = context.select(
      (MathTesterModel model) => model.difficulty,
    );
    final game = context.select((MathTesterModel model) => model.game);
    final streak = context.select((MathTesterModel model) => model.shownStreak);
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    Widget cell(Widget child) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your stats', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                TableRow(
                  children: [
                    for (final title in ['Operation', 'Accuracy', 'Level'])
                      cell(Text(title, style: headerStyle)),
                  ],
                ),
                for (final MapEntry(key: type, value: d) in difficulty.entries)
                  TableRow(
                    children: [
                      cell(Text(type.label)),
                      cell(
                        d.answered == 0
                            ? const Text('–', semanticsLabel: 'none yet')
                            : Text(
                                '${(100 * d.correct / d.answered).round()}%',
                              ),
                      ),
                      cell(Text('${d.level}')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Daily streak: $streak'),
            Text('Best streak: ${game.bestStreak}'),
            Text('Total XP: ${game.xp}'),
            Text('Player level: ${playerLevel(game.xp)}'),
          ],
        ),
      ),
    );
  }
}

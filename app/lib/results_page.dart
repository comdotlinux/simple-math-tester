import 'dart:math';

import 'package:duration/duration.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'operations.dart';
import 'rules.dart';
import 'slab.dart';

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
                          const SizedBox(height: 16),
                          if (!useCards) _tableHeader(context),
                        ],
                      ],
                    ),
                  ),
                  SliverList.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) => useCards
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 20),
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final signs = [
      (OperationType.plus, tokens.operation, tokens.onOperation),
      (OperationType.minus, tokens.correct, tokens.onCorrect),
      (OperationType.multiply, tokens.streak, tokens.onStreak),
      (OperationType.divide, tokens.primary, tokens.onPrimary),
    ];
    return Slab(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Decoration only: the four signs as coloured tiles.
              ExcludeSemantics(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final (type, color, onColor) in signs)
                      Container(
                        // Grows with the text up to 96, then the sign shrinks
                        // to fit.
                        constraints: const BoxConstraints(
                          minWidth: 56,
                          minHeight: 56,
                          maxWidth: 96,
                          maxHeight: 96,
                        ),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusControl,
                          ),
                          border: Border.all(
                            color: tokens.outline,
                            width: AppTokens.outlineWidth,
                          ),
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              type.displayString,
                              style: textTheme.headlineMedium?.copyWith(
                                color: onColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No answers yet.',
                key: noResultsOnResultsPageKey,
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Try a question, then come back to see your work here.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: tokens.inkMuted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Slab(
                  pressable: true,
                  radius: AppTokens.radiusControl,
                  child: FilledButton.icon(
                    onPressed: () => model.setCurrentPage(0),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Practice'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context, int index, Attempt attempt) {
    final textTheme = Theme.of(context).textTheme;
    final muted = context.tokens.inkMuted;
    return Slab(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${index + 1}',
                style: textTheme.labelMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 4),
              Text(_question(attempt), style: textTheme.headlineMedium),
              const SizedBox(height: 12),
              _status(context, attempt),
              const SizedBox(height: 12),
              _answerDetails(attempt),
              const SizedBox(height: 4),
              Text(
                'Time: ${_elapsed(attempt)}',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: context.tokens.inkMuted);
    return _tableCells([
      Text('#', style: headerStyle),
      Text('Question', style: headerStyle),
      Text('Answer', style: headerStyle),
      Text('Time', style: headerStyle),
    ]);
  }

  Widget _tableRow(BuildContext context, int index, Attempt attempt) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.tokens.surfaceSunken,
            width: AppTokens.outlineWidth,
          ),
        ),
      ),
      child: _tableCells([
        Text('${index + 1}', style: textTheme.titleMedium),
        Text(_question(attempt), style: textTheme.titleLarge),
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

  /// The verdict as a word and an icon on a block of its role colour.
  Widget _status(BuildContext context, Attempt attempt) {
    final tokens = context.tokens;
    final (background, foreground, label, icon) = attempt.skipped
        ? (
            tokens.surfaceSunken,
            tokens.ink,
            'Skipped',
            Icons.remove_circle_outline,
          )
        : attempt.correct
        ? (tokens.correct, tokens.onCorrect, 'Correct', Icons.check_circle)
        : (tokens.wrong, tokens.onWrong, 'Incorrect', Icons.refresh);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        border: Border.all(
          color: tokens.outline,
          width: AppTokens.outlineWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.labelMedium?.copyWith(color: tokens.inkMuted);

    Widget cell(Widget child) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child);

    Widget chip(String text, IconData icon, Color color, Color onColor) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
            border: Border.all(
              color: tokens.outline,
              width: AppTokens.outlineWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(icon, size: 20, color: onColor),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(color: onColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );

    return Slab(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your stats', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  chip(
                    'Daily streak: $streak',
                    Icons.local_fire_department,
                    tokens.streak,
                    tokens.onStreak,
                  ),
                  chip(
                    'Best streak: ${game.bestStreak}',
                    Icons.local_fire_department,
                    tokens.streak,
                    tokens.onStreak,
                  ),
                  chip(
                    'Best sprint: ${game.bestSprint}',
                    Icons.timer_outlined,
                    tokens.sprint,
                    tokens.onSprint,
                  ),
                  chip(
                    'Total XP: ${game.xp}',
                    Icons.star,
                    tokens.xp,
                    tokens.onXp,
                  ),
                  chip(
                    'Player level: ${playerLevel(game.xp)}',
                    Icons.military_tech,
                    tokens.xp,
                    tokens.onXp,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Table(
                columnWidths: const {0: FlexColumnWidth(2)},
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: tokens.surfaceSunken,
                    width: AppTokens.outlineWidth,
                  ),
                ),
                children: [
                  TableRow(
                    children: [
                      for (final title in ['Operation', 'Accuracy', 'Level'])
                        cell(Text(title, style: headerStyle)),
                    ],
                  ),
                  for (final MapEntry(key: type, value: d)
                      in difficulty.entries)
                    TableRow(
                      children: [
                        cell(Text(type.label)),
                        cell(
                          d.answered == 0
                              ? const Text('–', semanticsLabel: 'none yet')
                              : Text(
                                  '${(100 * d.correct / d.answered).round()}%',
                                  style: textTheme.titleMedium,
                                ),
                        ),
                        cell(Text('${d.level}', style: textTheme.titleMedium)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

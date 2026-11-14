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

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

/// Shows the answers newest first, a page at a time: the next page loads when the reader
/// scrolls to the loading row at the end of the list. The stats card is a
/// pinned header that shrinks to a compact bar as the list scrolls.
class _ResultsPageState extends State<ResultsPage> {
  static const _pageSize = 20;
  var _shown = _pageSize;
  var _loading = false;

  // The header needs fixed extents, so hidden copies of the full card and
  // the compact bar are laid out to measure them.
  final _fullMeasure = GlobalKey();
  final _compactMeasure = GlobalKey();
  Size? _fullSize;
  Size? _compactSize;

  void _measure() {
    if (!mounted) return;
    final full = _fullMeasure.currentContext?.size;
    final compact = _compactMeasure.currentContext?.size;
    if (full != _fullSize || compact != _compactSize) {
      setState(() {
        _fullSize = full;
        _compactSize = compact;
      });
    }
  }

  static const _columnFlex = [55, 160, 250, 135];

  @override
  Widget build(BuildContext context) {
    final history = context.select((MathTesterModel model) => model.history);
    final theme = Theme.of(context);
    final useCards = MediaQuery.sizeOf(context).width < 800;
    final shown = min(_shown, history.length);
    final fullSize = _fullSize;
    final compactSize = _compactSize;
    if (history.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }

    // The header: stats, the answer count and the table's column titles;
    // collapsed, the compact bar over the column titles. [keyed] is false
    // for the hidden copies that measure them.
    Widget expanded({required bool keyed}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Stats(),
        const SizedBox(height: 24),
        Text(
          history.length == 1
              ? '1 question completed.'
              : '${history.length} questions completed.',
          key: keyed ? historyCountKey : null,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (!useCards) _tableHeader(context),
      ],
    );
    Widget collapsed({required bool keyed}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompactBar(key: keyed ? compactStatsKey : null),
        if (!useCards) _tableHeader(context),
      ],
    );

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
                        else
                          // Offstage: laid out, never painted, heard or found.
                          Offstage(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                KeyedSubtree(
                                  key: _fullMeasure,
                                  child: expanded(keyed: false),
                                ),
                                KeyedSubtree(
                                  key: _compactMeasure,
                                  child: collapsed(keyed: false),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (history.isNotEmpty)
                    if (fullSize == null || compactSize == null)
                      SliverToBoxAdapter(child: expanded(keyed: true))
                    else
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StatsHeader(
                          maxExtent: max(fullSize.height, compactSize.height),
                          minExtent: compactSize.height,
                          color: theme.scaffoldBackgroundColor,
                          expanded: expanded(keyed: true),
                          collapsed: collapsed(keyed: true),
                        ),
                      ),
                  SliverList.builder(
                    // One extra row at the end: the loading row or the end
                    // marker.
                    itemCount: history.isEmpty ? 0 : shown + 1,
                    itemBuilder: (context, index) {
                      if (index == shown) {
                        return shown < history.length
                            ? _loadingRow()
                            : _endMarker(context);
                      }
                      // Newest first; each row keeps its own number, and its
                      // key is its index in the history.
                      final number = history.length - 1 - index;
                      return KeyedSubtree(
                        key: historyRowKey(number),
                        child: useCards
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: _resultCard(
                                  context,
                                  number,
                                  history[number],
                                ),
                              )
                            : _tableRow(context, number, history[number]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // The answers are already in memory, so a page loads on the next frame.
  Widget _loadingRow() {
    if (!_loading) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _shown += _pageSize;
          _loading = false;
        });
      });
    }
    return const Padding(
      key: answersLoadingKey,
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            semanticsLabel: 'Loading more answers',
          ),
        ),
      ),
    );
  }

  Widget _endMarker(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: answersEndKey,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        "That's all your answers",
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
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
                    key: emptyStatePracticeButtonKey,
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

/// The stats table's column headings.
const statsColumns = ['Operation', 'Accuracy', 'Level'];

/// Lifetime accuracy and level per operation, streaks, XP and player level.
///
/// [compact] is the pinned bar: icons and numbers only (screen readers hear
/// the full labels), no table.
class _Stats extends StatelessWidget {
  const _Stats({this.compact = false});

  final bool compact;

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

    Widget chip(
      String text,
      String value,
      Key key,
      IconData icon,
      Color color,
      Color onColor,
    ) => Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        spacing: compact ? 4 : 8,
        children: [
          Icon(icon, size: compact ? 16 : 20, color: onColor),
          Flexible(
            child: Text(
              compact ? value : text,
              key: compact ? null : key,
              semanticsLabel: text,
              style: (compact ? textTheme.labelMedium : const TextStyle())
                  ?.copyWith(color: onColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    final chips = Wrap(
      spacing: compact ? 6 : 10,
      runSpacing: compact ? 6 : 8,
      children: [
        chip(
          'Daily streak: $streak',
          '$streak',
          dailyStreakStatKey,
          Icons.local_fire_department,
          tokens.streak,
          tokens.onStreak,
        ),
        chip(
          'Best streak: ${game.bestStreak}',
          '${game.bestStreak}',
          bestStreakStatKey,
          // The compact bar has no words, so the two streaks differ by icon.
          compact ? Icons.emoji_events : Icons.local_fire_department,
          tokens.streak,
          tokens.onStreak,
        ),
        chip(
          'Best sprint: ${game.bestSprint}',
          '${game.bestSprint}',
          bestSprintStatKey,
          Icons.timer_outlined,
          tokens.sprint,
          tokens.onSprint,
        ),
        chip(
          'Total XP: ${game.xp}',
          '${game.xp}',
          totalXpStatKey,
          Icons.star,
          tokens.xp,
          tokens.onXp,
        ),
        chip(
          'Player level: ${playerLevel(game.xp)}',
          '${playerLevel(game.xp)}',
          playerLevelStatKey,
          Icons.military_tech,
          tokens.xp,
          tokens.onXp,
        ),
      ],
    );

    if (compact) {
      return Slab(
        child: Card(
          child: Padding(padding: const EdgeInsets.all(8), child: chips),
        ),
      );
    }
    return Slab(
      child: Card(
        key: statsCardKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your stats', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              chips,
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
                      for (final title in statsColumns)
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

/// The pinned stats bar, with room above and below it.
class _CompactBar extends StatelessWidget {
  const _CompactBar({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: _Stats(compact: true),
  );
}

/// The full header at the top; as the list scrolls it is cut off from the
/// bottom, then swapped for the collapsed one, which stays pinned.
class _StatsHeader extends SliverPersistentHeaderDelegate {
  _StatsHeader({
    required this.maxExtent,
    required this.minExtent,
    required this.color,
    required this.expanded,
    required this.collapsed,
  });

  @override
  final double maxExtent;
  @override
  final double minExtent;
  final Color color;
  final Widget expanded;
  final Widget collapsed;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Rows scroll under the bar, so it paints the page colour.
    return ColoredBox(
      color: color,
      child: maxExtent - shrinkOffset <= minExtent
          ? collapsed
          : ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: double.infinity,
                child: expanded,
              ),
            ),
    );
  }

  // The header widgets are rebuilt with the page, so always take the new ones.
  @override
  bool shouldRebuild(_StatsHeader oldDelegate) => true;
}

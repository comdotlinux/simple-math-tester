import 'dart:math';

import 'package:material_ui/material_ui.dart' hide Text;
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'digit_text.dart';
import 'digits.dart';
import 'hundredths.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'labels.dart';
import 'math_tester_model.dart';
import 'operations.dart';
import 'progress.dart' show SuspectQuestion;
import 'question_text.dart';
import 'report_dialog.dart';
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

  /// The flag that marks [attempt]'s question as wrong; none for a question
  /// without a code (arithmetic).
  Widget? _flag(int index, Attempt attempt) =>
      SuspectQuestion.of(attempt.problem) == null
      ? null
      : ReportFlag(key: historyFlagKey(index), problem: attempt.problem);

  AppLocalizations get _l => AppLocalizations.of(context);

  /// The right answer as shown: an equation's with the language's decimal
  /// separator and a minus sign below zero.
  String _expected(Attempt attempt) => switch (attempt.problem) {
    EquationProblem(:final resultHundredths) => formatHundredths(
      resultHundredths,
      _l.localeName,
    ),
    final problem => formatNumber(problem.result),
  };

  /// The first answer of an answered [attempt], shown like [_expected].
  String _entered(Attempt attempt) =>
      switch ((attempt.problem, attempt.answerHundredths)) {
        (EquationProblem(), final hundredths?) => formatHundredths(
          hundredths,
          _l.localeName,
        ),
        _ => formatNumber(attempt.firstAnswer!),
      };

  @override
  Widget build(BuildContext context) {
    final history = context.select((MathTesterModel model) => model.history);
    final theme = Theme.of(context);
    final compact = context.select((MathTesterModel model) => model.compact);
    // The compact layout uses its dense rows at every width.
    final useCards = compact || MediaQuery.sizeOf(context).width < 800;
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
        _Stats(dense: compact),
        SizedBox(height: compact ? 12 : 24),
        Text(
          _l.questionsCompleted(history.length),
          key: keyed ? historyCountKey : null,
          style: compact
              ? theme.textTheme.titleMedium
              : theme.textTheme.titleLarge,
        ),
        SizedBox(height: compact ? 8 : 16),
        if (!useCards) _tableHeader(context),
      ],
    );
    Widget collapsed({required bool keyed}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompactBar(key: keyed ? compactStatsKey : null, dense: compact),
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
                vertical: compact ? 12 : 24,
              ),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _l.myAnswers,
                          style: compact
                              ? theme.textTheme.headlineMedium
                              : theme.textTheme.displaySmall,
                        ),
                        SizedBox(height: compact ? 12 : 24),
                        if (history.isEmpty)
                          _emptyState(context)
                        else ...[
                          _HintStats(history: history, dense: compact),
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
                        child: compact
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _compactRow(
                                  context,
                                  number,
                                  history[number],
                                ),
                              )
                            : useCards
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
    return Padding(
      key: answersLoadingKey,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            semanticsLabel: _l.loadingMoreAnswers,
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
        _l.allAnswersShown,
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
                _l.noAnswersYet,
                key: noResultsOnResultsPageKey,
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                _l.noAnswersHint,
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
                    label: Text(_l.practice),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _l.questionNumber('${index + 1}'),
                      style: textTheme.labelMedium?.copyWith(color: muted),
                    ),
                  ),
                  ?_flag(index, attempt),
                ],
              ),
              const SizedBox(height: 4),
              _questionText(context, attempt, textTheme.headlineMedium),
              const SizedBox(height: 12),
              _status(context, attempt),
              const SizedBox(height: 12),
              _answerDetails(attempt),
              const SizedBox(height: 4),
              Text(
                _l.timeTaken(_elapsed(attempt)),
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One line per answer, the same height whatever the verdict: number,
  /// problem = expected answer, what a wrong or skipped answer entered
  /// (cut short first when the line is full; the tooltip has it whole), a
  /// mark and the time. Screen readers hear the same facts as on the card.
  Widget _compactRow(BuildContext context, int index, Attempt attempt) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final (status, color, onColor, icon) = _verdict(_l, tokens, attempt);
    final expected = _expected(attempt);
    final entered = attempt.skipped
        ? _l.noAnswerEntered
        : _l.yourAnswer(_entered(attempt));
    final said = attempt.skipped
        ? _l.saidNoAnswer
        : attempt.correct
        ? null
        : _l.saidAnswer(_entered(attempt));
    final muted = textTheme.bodyMedium?.copyWith(color: tokens.inkMuted);
    final row = Row(
      spacing: 10,
      children: [
        Text('${index + 1}', style: muted),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: equationIsland(
              attempt.problem,
              Text.rich(
                TextSpan(
                  style: textTheme.titleMedium,
                  children: [
                    mathSpan(context, attempt.problem.shown(_l), null),
                    // An equation already has its "=" and a figure is a
                    // sentence, so an arrow leads to the answer; drawn, as
                    // no bundled font has "→".
                    if (attempt.problem is! ArithmeticProblem) ...[
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward,
                            size: textTheme.titleMedium?.fontSize,
                            color: textTheme.titleMedium?.color,
                            applyTextScaling: true,
                          ),
                        ),
                      ),
                      TextSpan(text: expected),
                    ] else
                      TextSpan(text: ' = $expected'),
                    if (said != null) TextSpan(text: '   $said', style: muted),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                // The smaller "said" part must not change the line height.
                strutStyle: StrutStyle.fromTextStyle(
                  textTheme.titleMedium!,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: tokens.outline,
              width: AppTokens.outlineWidth,
            ),
          ),
          child: Icon(icon, size: 16, color: onColor),
        ),
        if (!attempt.skipped)
          Text(
            formatElapsed(_l, attempt.elapsedMs, abbreviated: true),
            style: muted,
          ),
      ],
    );
    // The flag stays outside the row's one semantics node, so a screen
    // reader reaches it as its own button.
    final read = Semantics(
      container: true,
      label: shownDigits(
        context,
        _l.answerRowSemantics(
          '${index + 1}',
          attempt.problem.spoken(_l),
          status,
          entered,
          expected,
          _elapsed(attempt),
        ),
      ),
      child: ExcludeSemantics(
        child: said == null
            ? row
            : Tooltip(
                message: shownDigits(
                  context,
                  attempt.skipped
                      ? _l.noAnswerEntered
                      : _l.youSaid(_entered(attempt)),
                ),
                child: row,
              ),
      ),
    );
    return Slab(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: read),
              ?_flag(index, attempt),
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
      Text(_l.columnQuestion, style: headerStyle),
      Text(_l.columnAnswer, style: headerStyle),
      Text(_l.columnTime, style: headerStyle),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${index + 1}', style: textTheme.titleMedium),
            ?_flag(index, attempt),
          ],
        ),
        _questionText(context, attempt, textTheme.titleLarge),
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

  /// The question with a drawn line for a blank, read with the blank as a
  /// word.
  Widget _questionText(
    BuildContext context,
    Attempt attempt,
    TextStyle? style,
  ) => equationIsland(
    attempt.problem,
    Text.rich(
      mathSpan(context, attempt.problem.shown(_l), style),
      semanticsLabel: attempt.problem.spoken(_l),
    ),
  );

  String _elapsed(Attempt attempt) => attempt.skipped
      ? _l.timeNotAvailable
      : formatElapsed(_l, attempt.elapsedMs);

  /// The verdict's word, role colours and icon, shared by card and row.
  static (String, Color, Color, IconData) _verdict(
    AppLocalizations l,
    AppTokens tokens,
    Attempt attempt,
  ) => attempt.skipped
      ? (
          l.verdictSkipped,
          tokens.surfaceSunken,
          tokens.ink,
          Icons.remove_circle_outline,
        )
      : attempt.correct
      ? (l.verdictCorrect, tokens.correct, tokens.onCorrect, Icons.check_circle)
      : (l.verdictIncorrect, tokens.wrong, tokens.onWrong, Icons.refresh);

  /// The verdict as a word and an icon on a block of its role colour.
  Widget _status(BuildContext context, Attempt attempt) {
    final tokens = context.tokens;
    final (label, background, foreground, icon) = _verdict(_l, tokens, attempt);
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
        attempt.skipped ? _l.noAnswerEntered : _l.yourAnswer(_entered(attempt)),
      ),
      const SizedBox(height: 4),
      Text(_l.expectedAnswer(_expected(attempt))),
    ],
  );
}

/// The stats table's column headings.
List<String> statsColumns(AppLocalizations l) => [
  l.statsOperation,
  l.statsAccuracy,
  l.statsLevel,
];

/// Lifetime accuracy and level per operation, streaks, XP and player level.
///
/// [compact] is the pinned bar: icons and numbers only (screen readers hear
/// the full labels), no table.
class _Stats extends StatelessWidget {
  const _Stats({this.compact = false, this.dense = false});

  final bool compact;

  /// The compact layout setting: small chips and less padding.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final difficulty = context.select(
      (MathTesterModel model) => model.difficulty,
    );
    final game = context.select((MathTesterModel model) => model.game);
    final streak = context.select((MathTesterModel model) => model.shownStreak);
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.labelMedium?.copyWith(color: tokens.inkMuted);
    final small = compact || dense;

    Widget cell(Widget child) => Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 3 : 6),
      child: child,
    );

    Widget chip(
      String text,
      String value,
      Key key,
      IconData icon,
      Color color,
      Color onColor,
    ) => Semantics(
      // One node per chip, so each label is read on its own.
      container: true,
      child: Container(
        padding: small
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
          spacing: small ? 4 : 8,
          children: [
            Icon(icon, size: small ? 16 : 20, color: onColor),
            Flexible(
              child: Text(
                compact ? value : text,
                key: compact ? null : key,
                semanticsLabel: text,
                style: (small ? textTheme.labelMedium : const TextStyle())
                    ?.copyWith(color: onColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    final chips = Wrap(
      spacing: small ? 6 : 10,
      runSpacing: small ? 4 : 8,
      // Centred, so a wide screen does not leave the bar empty on one side.
      alignment: compact ? WrapAlignment.center : WrapAlignment.start,
      children: [
        chip(
          l.dailyStreak('$streak'),
          '$streak',
          dailyStreakStatKey,
          Icons.local_fire_department,
          tokens.streak,
          tokens.onStreak,
        ),
        chip(
          l.bestStreak('${game.bestStreak}'),
          '${game.bestStreak}',
          bestStreakStatKey,
          // The compact bar has no words, so the two streaks differ by icon.
          compact ? Icons.emoji_events : Icons.local_fire_department,
          tokens.streak,
          tokens.onStreak,
        ),
        chip(
          l.bestSprint('${game.bestSprint}'),
          '${game.bestSprint}',
          bestSprintStatKey,
          Icons.timer_outlined,
          tokens.sprint,
          tokens.onSprint,
        ),
        chip(
          l.totalXp('${game.xp}'),
          '${game.xp}',
          totalXpStatKey,
          Icons.star,
          tokens.xp,
          tokens.onXp,
        ),
        chip(
          l.playerLevel('${playerLevel(game.xp)}'),
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
          child: Padding(padding: EdgeInsets.all(dense ? 4 : 8), child: chips),
        ),
      );
    }
    return Slab(
      child: Card(
        key: statsCardKey,
        child: Padding(
          padding: EdgeInsets.all(dense ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.yourStats,
                style: dense ? textTheme.titleMedium : textTheme.titleLarge,
              ),
              SizedBox(height: dense ? 8 : 12),
              chips,
              SizedBox(height: dense ? 8 : 12),
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
                      for (final title in statsColumns(l))
                        cell(Text(title, style: headerStyle)),
                    ],
                  ),
                  for (final MapEntry(key: type, value: d)
                      in difficulty.entries)
                    // A kind that is off by default shows from its first
                    // answer.
                    if (arithmeticKinds.contains(type) || d.answered > 0)
                      TableRow(
                        children: [
                          cell(Text(type.label(l))),
                          cell(
                            d.answered == 0
                                ? Text('–', semanticsLabel: l.noneYet)
                                : Text(
                                    '${(100 * d.correct / d.answered).round()}%',
                                    style: textTheme.titleMedium,
                                  ),
                          ),
                          cell(
                            Text('${d.level}', style: textTheme.titleMedium),
                          ),
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

/// Hint use over all answers, then per kind with answers ([hintTotals]),
/// on its own card above the stats, once a hint was used on an answer. Not
/// in the pinned header, which cuts its bottom off as the page scrolls.
class _HintStats extends StatelessWidget {
  const _HintStats({required this.history, required this.dense});

  final List<Attempt> history;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final all = hintTotals(history);
    if (all.hinted == 0) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final lineStyle = dense ? textTheme.bodySmall : textTheme.bodyMedium;
    List<Widget> lines(
      ({int answered, int hinted, int correct, int correctWithoutHint}) t,
    ) => [
      Text(
        l.hintStatsUsed(
          t.answered,
          t.hinted,
          (100 * t.hinted / t.answered).round(),
        ),
        style: lineStyle,
      ),
      if (t.correct > 0)
        Text(
          l.hintStatsWithout(
            t.correct,
            t.correctWithoutHint,
            (100 * t.correctWithoutHint / t.correct).round(),
          ),
          style: lineStyle,
        ),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 12 : 24),
      child: Slab(
        child: Card(
          key: hintStatsKey,
          child: Padding(
            padding: EdgeInsets.all(dense ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: dense ? 2 : 4,
              children: [
                Text(
                  l.hintStatsTitle,
                  style: dense ? textTheme.titleMedium : textTheme.titleLarge,
                ),
                SizedBox(height: dense ? 4 : 8),
                ...lines(all),
                for (final type in OperationType.values)
                  if (hintTotals(history.where((a) => a.problem.kind == type))
                      case final kind when kind.answered > 0)
                    Padding(
                      key: hintStatsKindKey(type),
                      padding: EdgeInsets.only(top: dense ? 4 : 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: dense ? 2 : 4,
                        children: [
                          Text(
                            type.label(l),
                            style: textTheme.labelLarge?.copyWith(
                              color: context.tokens.inkMuted,
                            ),
                          ),
                          ...lines(kind),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pinned stats bar, with room above and below it.
class _CompactBar extends StatelessWidget {
  const _CompactBar({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: dense ? 4 : 8),
    child: _Stats(compact: true, dense: dense),
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
    // Rows scroll under the bar, so it paints the page colour. Both states
    // are clipped: for the one frame after a resize or text-scale change the
    // measured extents are stale, and a clip cannot overflow.
    return ColoredBox(
      color: color,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: maxExtent - shrinkOffset <= minExtent ? collapsed : expanded,
        ),
      ),
    );
  }

  // The header widgets are rebuilt with the page, so always take the new ones.
  @override
  bool shouldRebuild(_StatsHeader oldDelegate) => true;
}

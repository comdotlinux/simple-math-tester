import 'package:material_ui/material_ui.dart' hide Text;
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'digit_text.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'labels.dart';
import 'math_tester_model.dart';
import 'slab.dart';

/// What the round just ended did, as a card at the top of the page before
/// Start, announced through a live region. Done closes it; See my answers
/// closes it and opens My answers. Start or a sprint closes it too.
class RoundSummaryCard extends StatelessWidget {
  const RoundSummaryCard({super.key, required this.summary});

  final RoundSummary summary;

  @override
  Widget build(BuildContext context) {
    final model = context.read<MathTesterModel>();
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final edge = BorderSide(
      color: tokens.outline,
      width: AppTokens.outlineWidth,
    );
    // One node per row, read as its label and then its value; the value
    // goes under a label that leaves it no room (large text, a long word).
    Widget row(String label, String value, Key key) => MergeSemantics(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 12,
        children: [
          Text(label, style: textTheme.bodyLarge),
          Text(value, key: key, style: textTheme.titleMedium),
        ],
      ),
    );
    final level = summary.level;
    return Slab(
      child: Card(
        key: roundSummaryKey,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: tokens.primary,
                  border: Border(bottom: edge),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Icon(Icons.emoji_events, color: tokens.onPrimary),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l.summaryTitle,
                          style: textTheme.titleLarge?.copyWith(
                            color: tokens.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    if (summary.attempts.isEmpty)
                      Text(l.summaryNone, style: textTheme.bodyLarge)
                    else ...[
                      if (level != null)
                        Text(
                          l.summaryLevelUp('$level'),
                          key: summaryLevelKey,
                          style: textTheme.titleMedium,
                        ),
                      row(
                        l.summaryAnswered,
                        '${summary.answered}',
                        summaryAnsweredKey,
                      ),
                      row(
                        l.summaryCorrect,
                        '${summary.correct}',
                        summaryCorrectKey,
                      ),
                      row(l.summaryXp, '${summary.xp}', summaryXpKey),
                      row(
                        l.summaryBestCombo,
                        '${summary.bestCombo}',
                        summaryComboKey,
                      ),
                      row(
                        l.summaryHints,
                        '${summary.hintsOpened}',
                        summaryHintsKey,
                      ),
                      row(
                        l.summarySkipped,
                        '${summary.skipped}',
                        summarySkippedKey,
                      ),
                      row(
                        l.summaryTime,
                        formatElapsed(l, summary.time.inMilliseconds),
                        summaryTimeKey,
                      ),
                      if (summary.kinds.isNotEmpty)
                        Divider(height: 8, color: tokens.outline),
                      for (final kind in summary.kinds)
                        row(
                          kind.kind.label(l),
                          l.summaryKind('${kind.correct}', '${kind.answered}'),
                          summaryKindKey(kind.kind),
                        ),
                    ],
                    const SizedBox(height: 2),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 12,
                      overflowSpacing: 12,
                      overflowAlignment: OverflowBarAlignment.end,
                      // Stacked, the main button goes on top.
                      overflowDirection: VerticalDirection.up,
                      children: [
                        Slab(
                          pressable: true,
                          radius: AppTokens.radiusControl,
                          child: OutlinedButton(
                            key: roundSummaryAnswersKey,
                            onPressed: () {
                              model.dismissRoundSummary();
                              model.setCurrentPage(1);
                            },
                            child: Text(l.summarySeeAnswers),
                          ),
                        ),
                        Slab(
                          pressable: true,
                          radius: AppTokens.radiusControl,
                          child: FilledButton(
                            key: roundSummaryDoneKey,
                            onPressed: model.dismissRoundSummary,
                            child: Text(l.summaryDone),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

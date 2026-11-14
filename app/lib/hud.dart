import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'rules.dart';

/// The persistent header: daily streak, daily goal, XP and level, combo,
/// and the notice when progress can't be saved.
class Hud extends StatelessWidget {
  const Hud({super.key});

  @override
  Widget build(BuildContext context) {
    final streak = context.select((MathTesterModel m) => m.shownStreak);
    final daily = context.select((MathTesterModel m) => m.shownDailyCount);
    final xp = context.select((MathTesterModel m) => m.game.xp);
    final combo = context.select((MathTesterModel m) => m.game.combo);
    final canSave = context.select((MathTesterModel m) => m.canSave);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final strong = textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    final level = playerLevel(xp);
    final levelStart = xpForLevel(level);
    final levelEnd = xpForLevel(level + 1);

    return DecoratedBox(
      key: hudKey,
      decoration: BoxDecoration(
        color: tokens.paper,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Stat(
                  label: 'Daily streak: $streak',
                  children: [
                    Icon(Icons.local_fire_department, color: tokens.error),
                    Text('$streak', style: strong),
                  ],
                ),
                _Stat(
                  label: 'Daily goal: $daily of $dailyGoal',
                  children: [
                    SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        // The ring fills at the goal; the text keeps the real count.
                        value: min(daily, dailyGoal) / dailyGoal,
                        strokeWidth: 4,
                        color: tokens.teal,
                        backgroundColor: tokens.border,
                      ),
                    ),
                    Text('$daily/$dailyGoal', style: strong),
                  ],
                ),
                _Stat(
                  label: 'Combo: $combo',
                  children: [
                    Icon(Icons.bolt, color: tokens.teal),
                    Text('×$combo', style: strong),
                  ],
                ),
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  label:
                      'Level $level, $xp XP, '
                      '${levelEnd - xp} XP to level ${level + 1}',
                  child: SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Level $level · $xp XP', style: strong),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (xp - levelStart) / (levelEnd - levelStart),
                          minHeight: 8,
                          color: tokens.teal,
                          backgroundColor: tokens.mint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!canSave) ...[
              const SizedBox(height: 8),
              Text(
                'Progress can’t be saved on this device right now',
                style: textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One header value: a single semantics node whose label states it.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    label: label,
    child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: children),
  );
}

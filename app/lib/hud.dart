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
    final strong = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final level = playerLevel(xp);
    final levelEnd = xpForLevel(level + 1);

    return DecoratedBox(
      key: hudKey,
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        border: Border(
          bottom: BorderSide(
            color: tokens.outline,
            width: AppTokens.outlineWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Stat(
                    label: 'Daily streak: $streak',
                    children: [
                      _Badge(
                        icon: Icons.local_fire_department,
                        color: tokens.streak,
                        onColor: tokens.onStreak,
                      ),
                      Text('$streak', style: strong),
                    ],
                  ),
                  _Stat(
                    label: 'Daily goal: $daily of $dailyGoal',
                    children: [
                      SizedBox.square(
                        dimension: 32,
                        child: CircularProgressIndicator(
                          // The ring fills at the goal; the text keeps the
                          // real count.
                          value: min(daily, dailyGoal) / dailyGoal,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color: tokens.goalRing,
                        ),
                      ),
                      Text('$daily/$dailyGoal', style: strong),
                    ],
                  ),
                  _Stat(
                    label: 'Combo: $combo',
                    children: [
                      _Badge(
                        icon: Icons.bolt,
                        color: tokens.combo,
                        onColor: tokens.onCombo,
                      ),
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
                      // Full width on a phone, so the level fits on one line.
                      width: min(constraints.maxWidth, 260),
                      // Counts up from the shown value to a new total; the
                      // label above always states the total.
                      child: TweenAnimationBuilder<int>(
                        tween: IntTween(begin: xp, end: xp),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, shown, _) {
                          final level = playerLevel(shown);
                          final start = xpForLevel(level);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Level $level · $shown XP', style: strong),
                              const SizedBox(height: 2),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: tokens.outline,
                                    width: AppTokens.outlineWidth,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: LinearProgressIndicator(
                                  value:
                                      (shown - start) /
                                      (xpForLevel(level + 1) - start),
                                  minHeight: 10,
                                  color: tokens.xpBar,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
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

/// An icon on a round block of its role colour.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(
        color: context.tokens.outline,
        width: AppTokens.outlineWidth,
      ),
    ),
    child: Icon(icon, size: 20, color: onColor),
  );
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
    // The value wraps rather than overflow at large numbers and text sizes.
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        ...children.take(children.length - 1),
        Flexible(child: children.last),
      ],
    ),
  );
}

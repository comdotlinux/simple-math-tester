import 'package:material_ui/material_ui.dart' hide Text;

import 'app_theme.dart';
import 'digit_text.dart';
import 'figure.dart';
import 'figure_view.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'solution_steps.dart';

/// The first [shown] of [steps], numbered, the newest one announced to
/// screen readers. With a [figure], the figure stands right above the
/// newest step and highlights the parts that step uses ([figureHint]), so
/// the picture, the step and whatever follows the view (such as a Next
/// step button) are seen together. It needs no model and no card around
/// it, so it can stand on the page or in a dialog.
class HintSteps extends StatelessWidget {
  const HintSteps({
    super.key,
    required this.steps,
    required this.shown,
    this.figure,
  });

  final List<SolutionStep> steps;
  final int shown;
  final Figure? figure;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final figure = this.figure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < shown; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          if (figure != null && index == shown - 1) ...[
            // The step's sentence names each part, so the picture is extra.
            ExcludeSemantics(
              child: FigureView(
                key: hintFigureKey,
                figure: figure,
                height: figureHeight(compact: true),
                semanticsLabel: '',
                highlight: figureHint(figure)[index].parts,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Semantics(
            container: true,
            liveRegion: index == shown - 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.outline,
                      width: AppTokens.outlineWidth,
                    ),
                  ),
                  child: Text(
                    '${index + 1}.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: tokens.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(steps[index](l), style: textTheme.bodyLarge),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

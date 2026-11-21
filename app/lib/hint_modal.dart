import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'hint_steps.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'labels.dart';
import 'math_tester_model.dart';
import 'operations.dart';
import 'question_text.dart';
import 'slab.dart';

/// The hint of the question on screen, in the app's own card over the
/// dimmed page: on a phone a panel anchored to the bottom that takes most
/// of the height, on a wide screen a centred card. The question stays at
/// the top while the steps scroll; Next step shows one more, and the last
/// step, which states the answer, has its own button. Close, the dimmed
/// area, Back and Escape close it; focus stays inside while it is open.
Future<void> showHintModal(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _HintModal());

class _HintModal extends StatefulWidget {
  const _HintModal();

  @override
  State<_HintModal> createState() => _HintModalState();
}

class _HintModalState extends State<_HintModal> {
  final _scroll = ScrollController();
  final _closeFocus = FocusNode();

  @override
  void dispose() {
    _scroll.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Reopened, the hint shows its newest step.
    _toNewest();
  }

  void _reveal(MathTesterModel model) {
    model.revealStep();
    // The reveal button goes once nothing is left to show; Close keeps the
    // focus inside.
    if (!model.canRevealStep) _closeFocus.requestFocus();
    _toNewest();
  }

  /// The newest step is the last one.
  void _toNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MathTesterModel>();
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final phone = MediaQuery.sizeOf(context).width < 600;
    final problem = model.current;
    final steps = model.steps;
    final revealed = model.revealedSteps;
    final edge = BorderSide(
      color: tokens.outline,
      width: AppTokens.outlineWidth,
    );
    void close() => Navigator.pop(context);

    Widget card({required bool pin}) => Slab(
      child: Card(
        key: solutionStepsKey,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              fit: phone ? FlexFit.tight : FlexFit.loose,
              child: CustomScrollView(
                controller: _scroll,
                shrinkWrap: !phone,
                slivers: [
                  // The title and the question stay in view while the steps
                  // scroll under them, and scroll too where large text
                  // leaves no room; a figure shows above the newest step,
                  // so here it is its prompt.
                  (pin ? PinnedHeaderSliver.new : SliverToBoxAdapter.new)(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceRaised,
                        border: Border(bottom: edge),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 4,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              l.workItOut,
                              style: textTheme.labelLarge?.copyWith(
                                color: tokens.inkMuted,
                              ),
                            ),
                          ),
                          Text.rich(
                            mathSpan(context, switch (problem) {
                              FigureProblem(:final figure) => figurePromptText(
                                l,
                                figure,
                              ),
                              _ => problem.shown(l),
                            }, textTheme.titleLarge),
                            textAlign: TextAlign.center,
                            semanticsLabel: l.mathQuestion(problem.spoken(l)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 14,
                        children: [
                          HintSteps(
                            steps: steps,
                            shown: revealed,
                            figure: switch (problem) {
                              FigureProblem(:final figure) => figure,
                              _ => null,
                            },
                          ),
                          // Before a check the answer stays hidden, as it
                          // always has.
                          if (!model.canRevealStep && revealed < steps.length)
                            Text(
                              l.hintAnswerAfterCheck,
                              style: textTheme.bodyMedium?.copyWith(
                                color: tokens.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(top: edge),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12 + 5),
                child: OverflowBar(
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
                        key: hintCloseKey,
                        focusNode: _closeFocus,
                        autofocus: !model.canRevealStep,
                        onPressed: close,
                        child: Text(
                          MaterialLocalizations.of(context).closeButtonLabel,
                        ),
                      ),
                    ),
                    if (model.canRevealStep)
                      Slab(
                        pressable: true,
                        radius: AppTokens.radiusControl,
                        child: FilledButton.icon(
                          key: revealStepButtonKey,
                          autofocus: true,
                          onPressed: () => _reveal(model),
                          icon: Icon(
                            revealed == steps.length - 1
                                ? Icons.lightbulb_outline
                                : Icons.navigate_next,
                          ),
                          label: Text(
                            revealed == steps.length - 1
                                ? l.showAnswer
                                : l.nextStep,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Align(
      alignment: phone ? Alignment.bottomCenter : Alignment.center,
      child: Padding(
        // Room for the card's slab below it.
        padding: phone
            ? const EdgeInsets.fromLTRB(8, 0, 8, 8 + 5)
            : const EdgeInsets.fromLTRB(24, 24, 24, 24 + 5),
        child: LayoutBuilder(
          builder: (context, area) {
            final height = area.maxHeight * (phone ? .92 : .85);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: phone ? double.infinity : 560,
                maxHeight: height,
              ),
              // Pinned in a short modal with large text, the question
              // would leave the steps no room.
              child: card(
                pin: height >= MediaQuery.textScalerOf(context).scale(400),
              ),
            );
          },
        ),
      ),
    );
  }
}

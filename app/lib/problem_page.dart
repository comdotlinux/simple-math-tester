import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'operations.dart';
import 'rules.dart';
import 'slab.dart';

class ProblemPage extends StatefulWidget {
  const ProblemPage({super.key});

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage> {
  late final MathTesterModel _model;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _model = context.read<MathTesterModel>();
    _controller = TextEditingController(text: _model.draftInput);
    _model.addListener(_syncDraft);
  }

  void _syncDraft() {
    if (_controller.text == _model.draftInput) return;
    _controller.value = TextEditingValue(
      text: _model.draftInput,
      selection: TextSelection.collapsed(offset: _model.draftInput.length),
    );
  }

  @override
  void dispose() {
    _model.removeListener(_syncDraft);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MathTesterModel>();
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final sprinting = model.inSprint;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 600 ? 16 : 24,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          sprinting ? 'Sprint' : 'Let’s practice',
                          style: theme.textTheme.displaySmall,
                        ),
                      ),
                      // A tier change would move levels during a round.
                      if (!sprinting)
                        Slab(
                          pressable: true,
                          radius: AppTokens.radiusControl,
                          child: IconButton(
                            key: settingsButtonKey,
                            tooltip: 'Settings',
                            onPressed: () => _showSettings(context),
                            icon: const Icon(
                              Icons.settings_outlined,
                              semanticLabel: 'Settings',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sprinting
                        ? 'Answer as many as you can in '
                              '${sprintLength.inSeconds} seconds.'
                        : 'Take your time and give it a try.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (model.tier == null)
                    const _TierPicker()
                  else ...[
                    if (model.lastSprint case final result?) ...[
                      _SprintResult(result: result),
                      const SizedBox(height: 24),
                    ],
                    if (sprinting) ...[
                      _SprintStatus(score: model.sprintScore),
                      const SizedBox(height: 24),
                    ],
                    Row(
                      children: [
                        for (final type in OperationType.values) ...[
                          if (type.index > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _OperationToggle(
                              type: type,
                              selected: model.selectedOperations.contains(type),
                              onPressed: () => model.toggleOperation(type),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    _QuestionCard(problem: model.current),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      style: theme.textTheme.headlineMedium,
                      decoration: const InputDecoration(
                        labelText: 'Your answer',
                        hintText: 'Type a number',
                      ),
                      onChanged: model.setDraftInput,
                      onSubmitted: (_) => model.submitAnswer(),
                    ),
                    const SizedBox(height: 12),
                    _AnswerFeedback(model: model),
                    const SizedBox(height: 16),
                    Slab(
                      pressable: true,
                      radius: AppTokens.radiusControl,
                      child: FilledButton.icon(
                        key: checkAnswerButtonKey,
                        onPressed: model.submitAnswer,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Check answer'),
                      ),
                    ),
                    if (!sprinting) ...[
                      const SizedBox(height: 16),
                      // Side by side when both fit, else full-width rows.
                      Flex(
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: wide
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.stretch,
                        spacing: 16,
                        children: [
                          _flexed(
                            wide,
                            Slab(
                              pressable: true,
                              radius: AppTokens.radiusControl,
                              child: OutlinedButton.icon(
                                key: nextQuestionButtonKey,
                                onPressed: model.generateNextProblem,
                                icon: const Icon(Icons.navigate_next),
                                label: const Text('Next question'),
                              ),
                            ),
                          ),
                          _flexed(
                            wide,
                            Slab(
                              pressable: true,
                              radius: AppTokens.radiusControl,
                              child: FilledButton.icon(
                                key: sprintButtonKey,
                                onPressed: model.startSprint,
                                style: FilledButton.styleFrom(
                                  backgroundColor: tokens.sprint,
                                  foregroundColor: tokens.onSprint,
                                ),
                                icon: const Icon(Icons.timer_outlined),
                                label: Text(
                                  '${sprintLength.inSeconds}-second sprint',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Hints(model: model),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _flexed(bool row, Widget child) => row ? Expanded(child: child) : child;

/// The hero: the operation's name on a colour band over the question.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.problem});

  final Problem problem;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Slab(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The question's own label already names the operation.
            ExcludeSemantics(
              child: _Band(
                color: tokens.operation,
                child: Text(
                  problem.kind.label,
                  style: textTheme.labelMedium?.copyWith(
                    color: tokens.onOperation,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 44),
              child: Text(
                problem.question,
                key: questionOnProblemsPageKey,
                textAlign: TextAlign.center,
                semanticsLabel: 'Math question: ${problem.question}',
                style: textTheme.displayLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A colour block across the top of a card, ruled off from its body.
class _Band extends StatelessWidget {
  const _Band({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: color,
      border: Border(
        bottom: BorderSide(
          color: context.tokens.outline,
          width: AppTokens.outlineWidth,
        ),
      ),
    ),
    child: child,
  );
}

/// The score so far and the countdown of a running round.
class _SprintStatus extends StatelessWidget {
  const _SprintStatus({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = Theme.of(context).textTheme.headlineMedium
        ?.copyWith(color: tokens.onSprint);
    return Slab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: tokens.sprint,
          border: Border.all(
            color: tokens.outline,
            width: AppTokens.outlineWidth,
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(Icons.timer_outlined, size: 32, color: tokens.onSprint),
                // Only this rebuilds on a tick: a plain number, no animation.
                Flexible(
                  child: ValueListenableBuilder<int>(
                    valueListenable: context
                        .read<MathTesterModel>()
                        .sprintSecondsLeft,
                    builder: (context, seconds, _) => Text(
                      '$seconds s left',
                      key: sprintCountdownKey,
                      semanticsLabel: '$seconds seconds left',
                      style: style,
                    ),
                  ),
                ),
              ],
            ),
            Text('Score: $score', style: style),
          ],
        ),
      ),
    );
  }
}

/// The end of a round, announced through a live region.
class _SprintResult extends StatelessWidget {
  const _SprintResult({required this.result});

  final ({int score, int best, List<int> levels}) result;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final mix = [
      for (var level = 1; level <= result.levels.length; level++)
        if (result.levels[level - 1] > 0)
          'level $level: ${result.levels[level - 1]}',
    ];
    Widget tile(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceSunken,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      ),
      child: Text(text, style: textTheme.titleLarge),
    );
    return Slab(
      child: Card(
        key: sprintResultKey,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Band(
                color: tokens.sprint,
                child: Row(
                  spacing: 10,
                  children: [
                    Icon(Icons.emoji_events, color: tokens.onSprint),
                    Expanded(
                      child: Text(
                        'Sprint over',
                        style: textTheme.titleLarge?.copyWith(
                          color: tokens.onSprint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        tile('Score: ${result.score}'),
                        tile('Personal best: ${result.best}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Scores at different levels are weighted, so the mix is
                    // shown.
                    Text(
                      mix.isEmpty
                          ? 'No answers this round.'
                          : 'Answers by difficulty: ${mix.join(', ')}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.inkMuted,
                      ),
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

/// Covers the practice controls until a starting tier is chosen; it has no
/// way out other than a choice.
class _TierPicker extends StatelessWidget {
  const _TierPicker();

  @override
  Widget build(BuildContext context) {
    final model = context.read<MathTesterModel>();
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Slab(
      child: Card(
        key: tierPickerKey,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'How hard should it start?',
                  style: textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Questions get easier or harder as you answer. '
                'You can change this later in settings.',
                style: textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
              ),
              for (final tier in Tier.values) ...[
                const SizedBox(height: 16),
                Slab(
                  pressable: true,
                  radius: AppTokens.radiusControl,
                  child: OutlinedButton(
                    onPressed: () => model.chooseTier(tier),
                    child: Row(
                      spacing: 12,
                      children: [
                        Expanded(child: Text(tier.label)),
                        const Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple list of settings; for now only the starting tier.
void _showSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final model = context.watch<MathTesterModel>();
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          key: settingsSheetKey,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              ListTile(
                title: Semantics(
                  header: true,
                  child: Text(
                    'Starting difficulty',
                    style: textTheme.titleLarge,
                  ),
                ),
                subtitle: Text(
                  'Now: ${model.tier?.label ?? 'not chosen'}. Choosing one '
                  'starts every operation again at that difficulty.',
                ),
              ),
              for (final tier in Tier.values)
                ListTile(
                  title: Text(tier.label),
                  selected: tier == model.tier,
                  trailing: tier == model.tier
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () {
                    if (tier != model.tier) model.chooseTier(tier);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Selected stands up on its slab with a check; unselected sits flat on a
/// sunken fill, so the state reads without colour.
class _OperationToggle extends StatelessWidget {
  const _OperationToggle({
    required this.type,
    required this.selected,
    required this.onPressed,
  });

  final OperationType type;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final foreground = selected ? tokens.onOperation : tokens.inkMuted;
    return Tooltip(
      message: type.label,
      excludeFromSemantics: true,
      // One node: the button's tap action, the name and the selected state.
      child: MergeSemantics(
        child: Semantics(
          selected: selected,
          child: Slab(
            pressable: true,
            down: !selected,
            radius: AppTokens.radiusControl,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    backgroundColor: selected
                        ? tokens.operation
                        : tokens.surfaceSunken,
                    foregroundColor: foreground,
                  ),
                  child: Text(
                    type.displayString,
                    semanticsLabel: type.label,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  PositionedDirectional(
                    top: 5,
                    end: 5,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: foreground,
                      ),
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

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.model});

  final MathTesterModel model;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final message =
        model.validationMessage ??
        switch (model.answerCorrect) {
          null => null,
          true => 'You got it!',
          false => 'Not quite. Try another answer.',
        };
    final (background, foreground, icon) = switch (model.answerCorrect) {
      null => (tokens.primary, tokens.onPrimary, Icons.info_outline),
      true => (tokens.correct, tokens.onCorrect, Icons.check_circle),
      false => (tokens.wrong, tokens.onWrong, Icons.lightbulb_outline),
    };
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('no-feedback'))
          : Semantics(
              key: ValueKey(message),
              container: true,
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(
                    color: tokens.outline,
                    width: AppTokens.outlineWidth,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 28, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Hints extends StatelessWidget {
  const _Hints({required this.model});

  final MathTesterModel model;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final revealed = model.revealedSteps;

    // The reveal control stays last and keeps one key, so it keeps its
    // element and keyboard focus while its label changes and steps appear.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (revealed > 0)
          Slab(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Let’s work it out', style: textTheme.titleLarge),
                    for (var index = 0; index < revealed; index++) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        container: true,
                        liveRegion: index == revealed - 1,
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
                                child: Text(
                                  model.steps[index],
                                  style: textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          // Directional mode keeps a disabled button focusable, so reaching
          // the last allowed step does not drop keyboard focus.
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(navigationMode: NavigationMode.directional),
            child: TextButton.icon(
              key: revealStepButtonKey,
              onPressed: model.canRevealStep ? model.revealStep : null,
              icon: Icon(
                revealed == 0 ? Icons.lightbulb_outline : Icons.navigate_next,
              ),
              label: Text(revealed == 0 ? 'Hint' : 'Next step'),
            ),
          ),
        ),
      ],
    );
  }
}

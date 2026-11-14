import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'operations.dart';
import 'rules.dart';

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
    final sprinting = model.inSprint;
    return LayoutBuilder(
      builder: (context, constraints) {
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
                        IconButton(
                          key: settingsButtonKey,
                          tooltip: 'Settings',
                          onPressed: () => _showSettings(context),
                          icon: const Icon(
                            Icons.settings_outlined,
                            semanticLabel: 'Settings',
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
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (model.tier == null)
                    const _TierPicker()
                  else ...[
                    if (model.lastSprint case final result?) ...[
                      _SprintResult(result: result),
                      const SizedBox(height: 16),
                    ],
                    if (sprinting) ...[
                      _SprintStatus(score: model.sprintScore),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        for (final type in OperationType.values) ...[
                          if (type.index > 0) const SizedBox(width: 8),
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
                    const SizedBox(height: 16),
                    Card(
                      color: context.tokens.mint,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Text(
                          model.current.question,
                          key: questionOnProblemsPageKey,
                          textAlign: TextAlign.center,
                          semanticsLabel:
                              'Math question: ${model.current.question}',
                          style: theme.textTheme.displaySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      style: theme.textTheme.titleLarge,
                      decoration: const InputDecoration(
                        labelText: 'Your answer',
                        hintText: 'Type a number',
                      ),
                      onChanged: model.setDraftInput,
                      onSubmitted: (_) => model.submitAnswer(),
                    ),
                    const SizedBox(height: 12),
                    _AnswerFeedback(model: model),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          key: checkAnswerButtonKey,
                          onPressed: model.submitAnswer,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Check answer'),
                        ),
                        if (!sprinting) ...[
                          OutlinedButton.icon(
                            key: nextQuestionButtonKey,
                            onPressed: model.generateNextProblem,
                            icon: const Icon(Icons.navigate_next),
                            label: const Text('Next question'),
                          ),
                          OutlinedButton.icon(
                            key: sprintButtonKey,
                            onPressed: model.startSprint,
                            icon: const Icon(Icons.timer_outlined),
                            label: Text(
                              '${sprintLength.inSeconds}-second sprint',
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!sprinting) ...[
                      const SizedBox(height: 12),
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

/// The score so far and the countdown of a running round.
class _SprintStatus extends StatelessWidget {
  const _SprintStatus({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = Theme.of(context).textTheme.titleLarge;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.paper,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            // Only this rebuilds on a tick: a plain number, no animation.
            ValueListenableBuilder<int>(
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
    final textTheme = Theme.of(context).textTheme;
    final mix = [
      for (var level = 1; level <= result.levels.length; level++)
        if (result.levels[level - 1] > 0)
          'level $level: ${result.levels[level - 1]}',
    ];
    return Card(
      key: sprintResultKey,
      color: context.tokens.mint,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sprint over', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 24,
                runSpacing: 4,
                children: [
                  Text('Score: ${result.score}', style: textTheme.titleMedium),
                  Text(
                    'Personal best: ${result.best}',
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Scores at different levels are weighted, so the mix is shown.
              Text(
                mix.isEmpty
                    ? 'No answers this round.'
                    : 'Answers by difficulty: ${mix.join(', ')}',
                style: textTheme.bodyMedium,
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
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: tierPickerKey,
      color: context.tokens.paper,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'How hard should it start?',
                style: textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Questions get easier or harder as you answer. '
              'You can change this later in settings.',
              style: textTheme.bodyMedium,
            ),
            for (final tier in Tier.values) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => model.chooseTier(tier),
                child: Text(tier.label),
              ),
            ],
          ],
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
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  trailing: tier == model.tier ? const Icon(Icons.check) : null,
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
    return Tooltip(
      message: type.label,
      excludeFromSemantics: true,
      // One node: the button's tap action, the name and the selected state.
      child: MergeSemantics(
        child: Semantics(
          selected: selected,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              backgroundColor: selected ? tokens.teal : null,
              foregroundColor: selected ? tokens.paper : tokens.ink,
              side: BorderSide(color: selected ? tokens.teal : tokens.muted),
            ),
            child: Text(
              type.displayString,
              semanticsLabel: type.label,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
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
    final message =
        model.validationMessage ??
        switch (model.answerCorrect) {
          null => null,
          true => 'You got it!',
          false => 'Not quite. Try another answer.',
        };
    final correct = model.answerCorrect ?? false;
    final foreground = model.answerCorrect == null
        ? context.tokens.error
        : correct
        ? context.tokens.teal
        : context.tokens.error;
    final background = model.answerCorrect == null
        ? context.tokens.peach
        : correct
        ? context.tokens.mint
        : context.tokens.peach;
    final icon = model.answerCorrect == null
        ? Icons.info_outline
        : correct
        ? Icons.check_circle
        : Icons.lightbulb_outline;
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
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
    final revealed = model.revealedSteps;
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    // The reveal control stays last and keeps one key, so it keeps its
    // element and keyboard focus while its label changes and steps appear.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (revealed > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Let’s work it out',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (var index = 0; index < revealed; index++) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      container: true,
                      liveRegion: index == revealed - 1,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text('${index + 1}.', style: textStyle),
                          ),
                          Expanded(
                            child: Text(model.steps[index], style: textStyle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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

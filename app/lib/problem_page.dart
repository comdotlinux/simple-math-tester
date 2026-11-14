import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'operations.dart';

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
                  Text('Let’s practice', style: theme.textTheme.displaySmall),
                  const SizedBox(height: 8),
                  Text(
                    'Take your time and give it a try.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
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
                      OutlinedButton.icon(
                        key: nextQuestionButtonKey,
                        onPressed: model.generateNextProblem,
                        icon: const Icon(Icons.navigate_next),
                        label: const Text('Next question'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Hints(model: model),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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
    final reveal = model.canRevealStep
        ? Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: revealed == 0 ? hintButtonKey : nextStepButtonKey,
              onPressed: model.revealStep,
              icon: Icon(
                revealed == 0 ? Icons.lightbulb_outline : Icons.navigate_next,
              ),
              label: Text(revealed == 0 ? 'Hint' : 'Next step'),
            ),
          )
        : null;
    if (revealed == 0) return reveal ?? const SizedBox.shrink();

    return Card(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${index + 1}.', style: textStyle),
                  ),
                  Expanded(child: Text(model.steps[index], style: textStyle)),
                ],
              ),
            ],
            if (reveal != null) ...[const SizedBox(height: 8), reveal],
          ],
        ),
      ),
    );
  }
}

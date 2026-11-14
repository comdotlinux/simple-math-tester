import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'solution_steps.dart';

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
                  _AnswerFeedback(key: ValueKey(model.current), model: model),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnswerFeedback extends StatefulWidget {
  const _AnswerFeedback({super.key, required this.model});

  final MathTesterModel model;

  @override
  State<_AnswerFeedback> createState() => _AnswerFeedbackState();
}

class _AnswerFeedbackState extends State<_AnswerFeedback> {
  bool _showSteps = false;

  @override
  void didUpdateWidget(covariant _AnswerFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model.answerCorrect != true) _showSteps = false;
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
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
    final showSteps = model.answerCorrect == false || (correct && _showSteps);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: foreground),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (correct)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _showSteps = !_showSteps),
                          icon: Icon(
                            _showSteps
                                ? Icons.expand_less
                                : Icons.menu_book_outlined,
                          ),
                          label: Text(_showSteps ? 'Hide steps' : 'Show steps'),
                        ),
                      ),
                    if (showSteps) ...[
                      const SizedBox(height: 16),
                      _SolutionSteps(model: model),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _SolutionSteps extends StatelessWidget {
  const _SolutionSteps({required this.model});

  final MathTesterModel model;

  @override
  Widget build(BuildContext context) {
    final steps = solutionSteps(model.current);
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Let’s work it out',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < steps.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text('${index + 1}.', style: textStyle),
              ),
              Expanded(child: Text(steps[index], style: textStyle)),
            ],
          ),
          if (index < steps.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'keys.dart';
import 'math_tester_model.dart';
import 'number_pad.dart';
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
  final _focus = FocusNode();
  final _answerKey = GlobalKey();
  final _scroll = ScrollController();

  /// Whether a phone page with the docked field repeats the question over
  /// its top, because the question card is scrolled out of view (for
  /// example while reading hints).
  bool _questionPinned = false;

  /// Keeps the field's state and input connection when it moves between
  /// the page and the phone dock.
  final _fieldKey = GlobalKey();
  final _padAvailable = padReplacesKeyboard(defaultTargetPlatform);
  late bool _padShown = _padAvailable;

  /// What the answer block last showed, to bring it back into view only
  /// when that changes.
  Object? _revealed;

  /// The problem and check the field last took focus for.
  Object? _focusedFor;

  @override
  void initState() {
    super.initState();
    _model = context.read<MathTesterModel>();
    _controller = TextEditingController(text: _model.draftInput);
    _model.addListener(_syncDraft);
    _focusedFor = _answerState;
    _model.addListener(_keepFocus);
    _scroll.addListener(_pinQuestion);
  }

  /// With the phone dock the answer key marks the question card; once its
  /// top is scrolled above the page, the page repeats the question.
  void _pinQuestion() {
    final card = _answerKey.currentContext?.findRenderObject();
    var pinned = false;
    if (card is RenderBox && card.attached && _scroll.hasClients) {
      final top = RenderAbstractViewport.of(card).getOffsetToReveal(card, 0);
      pinned = _scroll.offset > top.offset + 1;
    }
    if (pinned != _questionPinned) setState(() => _questionPinned = pinned);
  }

  void _syncDraft() {
    if (_controller.text == _model.draftInput) return;
    _controller.value = TextEditingValue(
      text: _model.draftInput,
      selection: TextSelection.collapsed(offset: _model.draftInput.length),
    );
  }

  Object? get _answerState =>
      (_model.current, _model.lastCheck, _model.validationMessage);

  /// The answer comes first: a new problem or a check, also one made from
  /// a button reached with Tab, puts the focus back on the field.
  void _keepFocus() {
    if (_answerState == _focusedFor) return;
    _focusedFor = _answerState;
    if (ModalRoute.isCurrentOf(context) ?? true) _focus.requestFocus();
  }

  @override
  void dispose() {
    _model.removeListener(_syncDraft);
    _model.removeListener(_keepFocus);
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The keyboard button on the field: hides the pad and opens the system
  /// keyboard, or brings the pad back.
  void _toggleKeyboard() {
    setState(() => _padShown = !_padShown);
    if (kIsWeb) {
      // The web engine sets the editing element's inputmode only when it
      // creates the element and never clears "none" on a config update, so
      // a new connection carries the new keyboard type. It opens after the
      // rebuild, also when the field had no focus: a config update sent
      // before the semantics tree hands the engine its element crashes the
      // engine's semantics text editing.
      _focus.unfocus();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus(),
      );
      return;
    }
    if (!_focus.hasFocus) {
      _focus.requestFocus();
      return;
    }
    // The rebuild sends the new keyboard type; the open field then needs an
    // explicit show or hide.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SystemChannels.textInput.invokeMethod<void>(
        _padShown ? 'TextInput.hide' : 'TextInput.show',
      ),
    );
  }

  /// Keeps the field and its feedback in view above a docked pad, as the
  /// system keyboard does, whenever the problem or the feedback changes.
  void _revealAnswer(MathTesterModel model, bool docked) {
    final shown = (
      model.current,
      model.answerCorrect,
      model.validationMessage,
      docked,
    );
    if (!docked || shown == _revealed) return;
    // The page opens in place; later changes scroll there.
    final jump = _revealed == null || MediaQuery.disableAnimationsOf(context);
    _revealed = shown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final answer = _answerKey.currentContext;
      if (answer == null || !answer.mounted) return;
      Scrollable.ensureVisible(
        answer,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: jump ? Duration.zero : const Duration(milliseconds: 200),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MathTesterModel>();
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final sprinting = model.inSprint;
    final pad = NumberPad(
      controller: _controller,
      onEdited: (text) {
        model.setDraftInput(text);
        model.keyPressed();
      },
      onCheck: model.checkOrNext,
      next: model.answerCorrect != null,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPad = _padShown && model.tier != null;
        // Wide pages dock the pad beside the practice column; others dock
        // it below like a keyboard while the page keeps room for the
        // question and field above it, and otherwise put it under the
        // field.
        final side = showPad && constraints.maxWidth >= 700;
        // A phone-height page docks the field and the feedback with a dense
        // pad, so after a check the question, the answer, the feedback and
        // Next all stay on screen. The estimate holds room for the feedback,
        // so a check never moves the pad out of the dock.
        final phone = !side && constraints.maxHeight < 700;
        final scaler = MediaQuery.textScalerOf(context);
        final dockHeight = phone
            ? NumberPad.height(scaler, dense: true) +
                  scaler.scale(28) * 1.2 +
                  128
            : NumberPad.height(scaler) + 2 * 12 + 7;
        final docked =
            side ||
            showPad && constraints.maxHeight - dockHeight >= (phone ? 80 : 260);
        final compact = docked && phone;
        _revealAnswer(model, docked);
        const sideWidth = 300.0;
        final width = side
            ? constraints.maxWidth - sideWidth - 2 * 16
            : constraints.maxWidth;
        final wide = width >= 520;
        // Next sits in the feedback strip while a result shows there.
        final nextInStrip =
            compact && !sprinting && model.answerCorrect != null;
        final field = _CheckMotion(
          key: _fieldKey,
          check: model.lastCheck,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            // Hardware keys reach the field only while it
            // has focus.
            autofocus: true,
            keyboardType: _padShown ? TextInputType.none : TextInputType.number,
            // Every answer is a whole number of 0 or more:
            // pasted or typed text keeps only its digits.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            style: theme.textTheme.headlineMedium,
            decoration: InputDecoration(
              labelText: 'Your answer',
              contentPadding: compact
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                  : null,
              hintText: 'Type a number',
              suffixIcon: _padAvailable
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: IconButton(
                        key: keyboardSwitchKey,
                        tooltip: _padShown
                            ? 'Use the keyboard'
                            : 'Use the number pad',
                        onPressed: _toggleKeyboard,
                        icon: Icon(
                          _padShown ? Icons.keyboard_outlined : Icons.dialpad,
                        ),
                      ),
                    )
                  : null,
            ),
            onChanged: model.setDraftInput,
            // Enter keeps the focus, so a second Enter moves
            // on and the next answer can be typed straight away.
            onEditingComplete: () {},
            onSubmitted: (_) => model.checkOrNext(),
          ),
        );
        final page = SingleChildScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(
            horizontal: width < 600 ? 16 : 24,
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
                            onPressed: () =>
                                _showSettings(context).whenComplete(() {
                                  if (mounted) _focus.requestFocus();
                                }),
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
                    KeyedSubtree(
                      key: compact ? _answerKey : null,
                      child: _QuestionCard(
                        problem: model.current,
                        compact: compact,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 28),
                      Column(
                        key: _answerKey,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field,
                          // Above the feedback, so a message never moves it.
                          if (showPad && !docked) ...[
                            const SizedBox(height: 16),
                            pad,
                          ],
                          const SizedBox(height: 12),
                          _AnswerFeedback(model: model),
                        ],
                      ),
                    ],
                    if (!showPad) ...[
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
                    ],
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
                          if (!nextInStrip)
                            _flexed(
                              wide,
                              Slab(
                                pressable: true,
                                radius: AppTokens.radiusControl,
                                child: OutlinedButton.icon(
                                  key: nextQuestionButtonKey,
                                  onPressed: model.generateNextProblem,
                                  // Before a check, moving on skips it.
                                  icon: Icon(
                                    model.answerChecked
                                        ? Icons.navigate_next
                                        : Icons.skip_next,
                                  ),
                                  label: Text(
                                    model.answerChecked
                                        ? 'Next question'
                                        : 'Skip',
                                  ),
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
        // Taps anywhere on the page count as taps on the field, so a
        // button or pad key press never takes its focus.
        if (!docked) return TextFieldTapRegion(child: page);
        final edge = BorderSide(
          color: tokens.outline,
          width: AppTokens.outlineWidth,
        );
        final dock = DecoratedBox(
          decoration: BoxDecoration(
            // Beside the page the column continues the page; below it the
            // dock is a raised panel that the page scrolls under.
            color: side ? tokens.surface : tokens.surfaceRaised,
            border: side ? Border(left: edge) : Border(top: edge),
          ),
          child: Padding(
            // The extra bottom space holds the last row's slab; beside the
            // page the pad starts level with the page's top padding.
            padding: side
                ? const EdgeInsets.fromLTRB(16, 24, 16, 24 + 5)
                : compact
                ? const EdgeInsets.fromLTRB(16, 8, 16, 8 + 5)
                : const EdgeInsets.fromLTRB(16, 12, 16, 12 + 5),
            child: Align(
              alignment: side ? Alignment.topCenter : Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: side ? sideWidth - AppTokens.outlineWidth : 440,
                ),
                child: compact
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 6,
                        children: [
                          field,
                          _AnswerFeedback(
                            model: model,
                            dense: true,
                            onNext: nextInStrip
                                ? model.generateNextProblem
                                : null,
                          ),
                          NumberPad(
                            controller: _controller,
                            onEdited: pad.onEdited,
                            onCheck: pad.onCheck,
                            dense: true,
                            next: pad.next,
                          ),
                        ],
                      )
                    : pad,
              ),
            ),
          ),
        );
        return TextFieldTapRegion(
          child: Flex(
            direction: side ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                // A sticky header over the page, so the page neither moves nor
                // loses its scroll position when it shows.
                child: LayoutBuilder(
                  builder: (context, area) => Stack(
                    children: [
                      Positioned.fill(child: page),
                      // Only while the page keeps room to read below it.
                      if (compact &&
                          _questionPinned &&
                          area.maxHeight >=
                              scaler.scale(22) * 1.25 + 2 * 6 + 2 + 48)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          // Display only: a control scrolled under the strip
                          // (e.g. the hint button after ensureVisible) must
                          // still get its taps.
                          child: IgnorePointer(
                            child: _PinnedQuestion(problem: model.current),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              dock,
            ],
          ),
        );
      },
    );
  }
}

/// Pops the answer on a correct first check and shakes it on a wrong one;
/// nothing moves with reduced motion. Input is never blocked meanwhile.
class _CheckMotion extends StatefulWidget {
  const _CheckMotion({super.key, required this.check, required this.child});

  final ({int count, bool correct, bool first})? check;
  final Widget child;

  @override
  State<_CheckMotion> createState() => _CheckMotionState();
}

class _CheckMotionState extends State<_CheckMotion>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void didUpdateWidget(_CheckMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final check = widget.check;
    if (check == null ||
        check.count == oldWidget.check?.count ||
        (check.correct && !check.first) ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.check?.correct ?? false;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        // Both curves start and end at rest.
        return correct
            ? Transform.scale(scale: 1 + .06 * sin(pi * t), child: child)
            : Transform.translate(
                offset: Offset(10 * sin(6 * pi * t) * (1 - t), 0),
                child: child,
              );
      },
    );
  }
}

Widget _flexed(bool row, Widget child) => row ? Expanded(child: child) : child;

/// The hero: the operation's name on a colour band over the question.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.problem, required this.compact});

  final Problem problem;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    Widget question(TextStyle? style) => Text(
      problem.question,
      key: questionOnProblemsPageKey,
      textAlign: TextAlign.center,
      semanticsLabel: 'Math question: ${problem.question}',
      style: style,
    );
    return Slab(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The question's own label already names the operation; a phone
            // with the docked field drops the band for room.
            if (!compact)
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
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                  : const EdgeInsets.fromLTRB(20, 36, 20, 44),
              child: compact
                  // One line that shrinks to fit rather than wrapping.
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: question(
                        textTheme.displayLarge?.copyWith(fontSize: 52),
                      ),
                    )
                  : question(textTheme.displayLarge),
            ),
          ],
        ),
      ),
    );
  }
}

/// The question repeated over the top of a phone page whose question card
/// has scrolled away, so it stays in view with the docked field.
class _PinnedQuestion extends StatelessWidget {
  const _PinnedQuestion({required this.problem});

  final Problem problem;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.tokens.surfaceRaised,
      border: Border(
        bottom: BorderSide(
          color: context.tokens.outline,
          width: AppTokens.outlineWidth,
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // The card keeps the question's semantics.
      child: ExcludeSemantics(
        child: Text(
          problem.question,
          key: pinnedQuestionKey,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ),
  );
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
            Text('Score: $score', key: sprintScoreKey, style: style),
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
    Widget tile(String text, Key key) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceSunken,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
      ),
      child: Text(text, key: key, style: textTheme.titleLarge),
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
                        tile('Score: ${result.score}', sprintResultScoreKey),
                        tile(
                          'Personal best: ${result.best}',
                          sprintResultBestKey,
                        ),
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
                    key: tierOptionKey(tier),
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

/// A simple list of settings: the starting tier and the feedback switches.
Future<void> _showSettings(BuildContext context) => showModalBottomSheet<void>(
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
                child: Text('Starting difficulty', style: textTheme.titleLarge),
              ),
              subtitle: Text(
                key: currentTierNoteKey,
                'Now: ${model.tier?.label ?? 'not chosen'}. Choosing one '
                'starts every operation again at that difficulty.',
              ),
            ),
            for (final tier in Tier.values)
              ListTile(
                key: tierSettingKey(tier),
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
            const SizedBox(height: 8),
            SwitchListTile(
              key: soundSwitchKey,
              title: const Text('Sound'),
              subtitle: const Text('A short chime for answers and milestones'),
              value: model.sound,
              onChanged: model.setSound,
            ),
            SwitchListTile(
              key: hapticsSwitchKey,
              title: const Text('Vibration'),
              subtitle: const Text('A short buzz on key presses and answers'),
              value: model.haptics,
              onChanged: model.setHaptics,
            ),
          ],
        ),
      ),
    );
  },
);

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
                  key: operationToggleKey(type),
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
                      // Its own fill states what the mark is drawn on.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.operation,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: foreground,
                        ),
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

/// The feedback strip; [dense] for the phone dock, where it also carries
/// the Next button ([onNext]) after a result.
class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.model, this.dense = false, this.onNext});

  final MathTesterModel model;
  final bool dense;
  final VoidCallback? onNext;

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
                padding: dense
                    ? const EdgeInsets.fromLTRB(12, 6, 6, 6)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(
                    color: tokens.outline,
                    width: AppTokens.outlineWidth,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                ),
                child: Row(
                  spacing: dense ? 8 : 12,
                  children: [
                    Icon(icon, size: dense ? 24 : 28, color: foreground),
                    Expanded(
                      child: Text(
                        message,
                        style:
                            (dense
                                    ? Theme.of(context).textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          )
                                    : Theme.of(context).textTheme.titleMedium)
                                ?.copyWith(color: foreground),
                      ),
                    ),
                    if (onNext case final next?)
                      Slab(
                        pressable: true,
                        radius: AppTokens.radiusControl,
                        child: OutlinedButton.icon(
                          key: nextQuestionButtonKey,
                          onPressed: next,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(Icons.navigate_next),
                          label: const Text(
                            'Next',
                            semanticsLabel: 'Next question',
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
              key: solutionStepsKey,
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

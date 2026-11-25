import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'digits.dart';
import 'figure_view.dart';
import 'hint_modal.dart';
import 'home_page.dart' show ContentArea;
import 'hundredths.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'labels.dart';
import 'legal.dart';
import 'licences_page.dart';
import 'math_tester_model.dart';
import 'number_pad.dart';
import 'operations.dart';
import 'progress.dart' show LayoutMode, SuspectQuestion;
import 'question_text.dart';
import 'report_dialog.dart';
import 'round_summary.dart';
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

  /// Start, which takes the focus back after End.
  final _startFocus = FocusNode();

  /// The one-time new-kind card, which the page opens with in view: on a
  /// short phone with large text it starts below the screen.
  final _newKindKey = GlobalKey();
  bool _cardRevealed = false;

  /// The summary End shows, brought to the top of the page.
  final _summaryKey = GlobalKey();
  final _answerKey = GlobalKey();

  /// Skip under the question card, which a docked phone page keeps in view
  /// with it.
  final _skipKey = GlobalKey();

  /// Try again and Show a hint after a wrong answer, which a docked phone
  /// page keeps in view, Try again first.
  final _choicesKey = GlobalKey();
  final _cardKey = GlobalKey();
  final _tryAgainKey = GlobalKey();
  final _scroll = ScrollController();

  /// Whether a phone page with the docked field repeats the question over
  /// its top, because the question card is scrolled out of view (for
  /// example on a short screen with large text).
  bool _questionPinned = false;

  /// End and the menu are a header pinned to the top of the page while
  /// practising, so neither the docked pad's reveal nor a scroll hides them
  /// (#200); pinned slivers also keep revealed controls below them. Whether
  /// the page is scrolled under the header, and the header's height.
  final _endHeaderKey = GlobalKey();
  bool _endPinned = false;
  double _endHeaderHeight = 0;

  /// Keeps the field's state and input connection when it moves between
  /// the page and the phone dock.
  final _fieldKey = GlobalKey();
  final _padAvailable = padReplacesKeyboard(defaultTargetPlatform);

  /// Phones (shortest side under 600, also in a mobile browser) start with
  /// the system number keyboard, tablets and desktops with the pad. Until
  /// the player picks, the default follows the size: the shortest side does
  /// not change when a phone turns, so only a resized window can move it.
  /// Known limit: on iOS web the keyboard opens only after a tap on the
  /// field, because Safari opens it only for a user gesture.
  bool get _padShown =>
      _padAvailable &&
      (_model.padChosen ?? MediaQuery.sizeOf(context).shortestSide >= 600);

  /// What the answer block last showed, to bring it back into view only
  /// when that changes.
  (Problem, bool?, InputProblem?, bool, bool, bool)? _revealed;

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
    final header = _endHeaderKey.currentContext?.findRenderObject();
    final endPinned =
        _model.practising && _scroll.hasClients && _scroll.offset > .5;
    final headerHeight = header is RenderBox && header.hasSize
        ? header.size.height
        : 0.0;
    if (pinned != _questionPinned ||
        endPinned != _endPinned ||
        headerHeight != _endHeaderHeight) {
      setState(() {
        _questionPinned = pinned;
        _endPinned = endPinned;
        _endHeaderHeight = headerHeight;
      });
    }
  }

  void _syncDraft() {
    if (_controller.text == _model.draftInput) return;
    _controller.value = TextEditingValue(
      text: _model.draftInput,
      selection: TextSelection.collapsed(offset: _model.draftInput.length),
    );
  }

  Object? get _answerState => (
    _model.current,
    _model.lastCheck,
    _model.inputProblem,
    _model.practising,
  );

  /// The answer comes first: Start, a new problem or a check, also one made
  /// from a button reached with Tab, puts the focus back on the field.
  void _keepFocus() {
    if (_answerState == _focusedFor) return;
    _focusedFor = _answerState;
    if (!_model.practising && !_model.inSprint) return;
    if (ModalRoute.isCurrentOf(context) ?? true) _focus.requestFocus();
  }

  /// Start: the questions replace the kinds, from the top of the page.
  void _start() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _model.startPractice();
  }

  /// End: back to the kinds, with the round's summary at the top; Start
  /// takes the focus as it is built again.
  void _end() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _model.endPractice();
    // Large text on a short phone would leave it below the title.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final summary = _summaryKey.currentContext;
      if (summary == null || !summary.mounted) return;
      Scrollable.ensureVisible(summary);
    });
  }

  @override
  void dispose() {
    _model.removeListener(_syncDraft);
    _model.removeListener(_keepFocus);
    _controller.dispose();
    _focus.dispose();
    _startFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// "Try again": the wrong answer stays in the field, selected, so the
  /// next key replaces it.
  void _tryAgain() {
    _focus.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  /// "Hint" and "Show a hint": the hint modal; closing it puts the focus
  /// back on the answer. After many hints the nudge to try first comes
  /// before it; "I will try" opens nothing and puts the focus back.
  Future<void> _showHint() async {
    final hint = !_model.takeHintNudge() || await showHintNudge(context);
    if (!mounted) return;
    if (hint) {
      _model.openHint();
      await showHintModal(context);
    }
    if (mounted) _focus.requestFocus();
  }

  /// The keyboard button on the field: hides the pad and opens the system
  /// keyboard, or brings the pad back.
  void _toggleKeyboard() {
    setState(() => _model.padChosen = !_padShown);
    // A new connection carries the new keyboard type. Android has no config
    // update at all, so an open field kept its old type and a tap on it
    // brought the system keyboard back over the pad. The web engine sets the
    // editing element's inputmode only when it creates the element and never
    // clears "none" on a config update. It opens after the rebuild, also
    // when the field had no focus: a config update sent before the semantics
    // tree hands the engine its element crashes the engine's semantics text
    // editing.
    _focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Keeps the field and its feedback in view above a docked pad, as the
  /// system keyboard does, whenever the problem or the feedback changes.
  void _revealAnswer(
    MathTesterModel model,
    bool docked,
    bool compact,
    bool showPad,
  ) {
    final shown = (
      model.current,
      model.answerCorrect,
      model.inputProblem,
      docked,
      compact,
      showPad,
    );
    // Each Start opens the questions in place.
    if (!model.practising && !model.inSprint) _revealed = null;
    if (!docked || shown == _revealed) return;
    // The page opens in place; later changes scroll there.
    final jump = _revealed == null || MediaQuery.disableAnimationsOf(context);
    final newProblem = _revealed?.$1 != model.current;
    _revealed = shown;
    final duration = jump ? Duration.zero : const Duration(milliseconds: 200);
    Future<void> reveal(
      GlobalKey key, [
      ScrollPositionAlignmentPolicy policy =
          ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    ]) async {
      final target = key.currentContext;
      if (target == null || !target.mounted) return;
      await Scrollable.ensureVisible(
        target,
        alignmentPolicy: policy,
        duration: duration,
      );
    }

    // Skip, the last control, comes into view. On a phone the answer key
    // marks the question card above Skip, so revealing Skip shows both when
    // they fit and Skip when they do not;
    // within a problem the page never scrolls back from where the player
    // took it. A new problem brings the card's top back into view, also
    // scrolling back, so it wins over Skip.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await reveal(_skipKey);
      // After a wrong answer the child looks at the question again: the
      // card stays in view with as much below it as fits.
      if (model.answerCorrect == false && await _revealCard(compact, jump)) {
        return;
      }
      await reveal(_answerKey);
      if (compact && newProblem) {
        await reveal(
          _answerKey,
          ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  /// Scrolls so the question card's top and the lowest of Try again and
  /// Show a hint, Try again, or (beside the pad on a taller page) the field
  /// and its feedback show together; when none fits with the card, the
  /// docked phone page shows the card, the taller page the feedback.
  /// False when there is nothing to reveal, or when a card taller than the
  /// page shows its end instead.
  Future<bool> _revealCard(bool compact, bool jump) async {
    RenderBox? box(GlobalKey key) =>
        switch (key.currentContext?.findRenderObject()) {
          final RenderBox box when box.attached => box,
          _ => null,
        };
    final card = box(compact ? _answerKey : _cardKey);
    if (card == null || !_scroll.hasClients) return false;
    final viewport = RenderAbstractViewport.of(card);
    final position = _scroll.position;
    // The offset that puts the card's top at the page's top, under End.
    final top = viewport.getOffsetToReveal(card, 0).offset;
    double? target;
    // A card taller than the page: on the docked phone page, whose dock
    // holds the feedback, a figure shows from its top, so the child sees
    // the figure again; otherwise the card's end shows, with the question
    // repeated over the page.
    if (viewport.getOffsetToReveal(card, 1).offset > top) {
      if (!compact || _model.current is! FigureProblem) return false;
      target = top;
    } else {
      for (final key in [_choicesKey, _tryAgainKey, if (!compact) _answerKey]) {
        final below = box(key);
        if (below == null) continue;
        // The offset that puts its bottom at the page's bottom.
        final bottom = viewport.getOffsetToReveal(below, 1).offset;
        if (bottom <= top) {
          target = position.pixels.clamp(bottom, top);
          break;
        }
      }
    }
    if (target == null) {
      final feedback = compact ? null : box(_answerKey);
      target = feedback == null
          ? position.pixels.clamp(
              viewport.getOffsetToReveal(card, 1).offset,
              top,
            )
          : viewport.getOffsetToReveal(feedback, 1).offset;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) {
      jump
          ? position.jumpTo(target)
          : await position.animateTo(
              target,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MathTesterModel>();
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final sprinting = model.inSprint;
    final signedDecimal = model.signedDecimalInput;
    // Before Start the page holds the kinds, Start and the sprint; while
    // practising (or in a sprint) the question and the answer.
    final setup = model.tier != null && !model.practising && !sprinting;
    final asking = model.tier != null && !setup;
    if (setup && model.newKind != null && !_cardRevealed) {
      _cardRevealed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final card = _newKindKey.currentContext;
        if (card == null || !card.mounted) return;
        Scrollable.ensureVisible(
          card,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPad = _padShown && asking;
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
            ? NumberPad.height(scaler, dense: true, actions: !sprinting) +
                  scaler.scale(28) * 1.2 +
                  128 +
                  // A wrong answer's longer message, so the page above
                  // keeps room for End and the question after it (#200).
                  _longFeedback(context, constraints.maxWidth)
            : NumberPad.height(scaler, actions: !sprinting) + 2 * 12 + 7;
        // With the system keyboard a phone docks the field, the feedback and
        // Check without the pad, so the keyboard below never hides them.
        final keyDock =
            !showPad &&
            asking &&
            phone &&
            MediaQuery.sizeOf(context).shortestSide < 600 &&
            // Room above the dock for at least the pinned question.
            constraints.maxHeight -
                    _keyDockHeight(context, constraints.maxWidth) >=
                scaler.scale(22) * 1.25 + 2 * 6 + 2 + 48;
        final docked =
            side ||
            keyDock ||
            showPad && constraints.maxHeight - dockHeight >= (phone ? 80 : 260);
        final compact = docked && phone;
        _revealAnswer(model, docked, compact, showPad);
        const sideWidth = 300.0;
        final width = side
            ? constraints.maxWidth - sideWidth - 2 * 16
            : constraints.maxWidth;
        final wide = width >= 520;
        // Next sits in the feedback strip while a result shows there.
        // With the pad its big key is the one Next after a check.
        final nextInStrip =
            compact && !sprinting && !showPad && model.answerCorrect != null;
        final wrong = !sprinting && model.answerCorrect == false;
        // The docked phone page packs its column tighter, so the question
        // and Skip fit above the dock on a short screen; the compact layout
        // setting packs it the same way everywhere.
        final tight = compact || model.compact;
        final gap = tight ? 12.0 : 24.0;
        // Above a pad docked below, the smaller card keeps the figure in
        // view with the answer after a wrong answer (#200).
        final smallCard = tight || docked && !side;
        final button = tight
            ? const WidgetStatePropertyAll(Size(48, 48))
            : null;
        // Arithmetic questions have no code the report function accepts, and
        // a dialog would stop a running round's clock.
        final reportable =
            !sprinting && SuspectQuestion.of(model.current) != null;
        // Skip (Next once checked), the quiet Hint and Report, with the same
        // keys wherever they sit: the pad's top row while the pad shows,
        // else a line under the answer that wraps where it does not fit.
        List<Widget> actions({required bool inPad}) {
          // In the pad a long label shrinks, so the row keeps a key's height.
          const padStyle = ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8),
            ),
          );
          Widget label(IconData icon, String text) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [Icon(icon), Text(text)],
            ),
          );
          Widget quiet(
            Key? key,
            IconData icon,
            String text,
            VoidCallback onPressed,
          ) => inPad
              ? TextButton(
                  key: key,
                  onPressed: onPressed,
                  style: padStyle,
                  child: label(icon, text),
                )
              : TextButton.icon(
                  key: key,
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(text),
                );
          // Before a check, moving on skips it.
          final skipIcon = model.answerChecked
              ? Icons.navigate_next
              : Icons.skip_next;
          final skipText = model.answerChecked ? l.nextQuestion : l.skip;
          return [
            // Skip; after a check, Next where the pad's key is not it.
            if (!nextInStrip && !(inPad && model.answerCorrect != null))
              Slab(
                key: _skipKey,
                pressable: true,
                radius: AppTokens.radiusControl,
                child: inPad
                    ? OutlinedButton(
                        key: nextQuestionButtonKey,
                        onPressed: model.generateNextProblem,
                        style: padStyle,
                        child: label(skipIcon, skipText),
                      )
                    : OutlinedButton.icon(
                        key: nextQuestionButtonKey,
                        onPressed: model.generateNextProblem,
                        style: ButtonStyle(minimumSize: button),
                        icon: Icon(skipIcon),
                        label: Text(skipText),
                      ),
              ),
            if (!wrong)
              quiet(hintButtonKey, Icons.lightbulb_outline, l.hint, _showHint),
            if (reportable)
              Builder(
                builder: (context) {
                  final flag = reportFlagState(context, model.current);
                  // The tooltip says whether it is marked, and whether its
                  // report was sent; the flag fills once marked. Merged, a
                  // screen reader hears the word, the button and the state
                  // together.
                  return MergeSemantics(
                    key: reportFlagKey,
                    child: Tooltip(
                      message: flag.tooltip,
                      child: quiet(
                        null,
                        flag.icon,
                        l.reportButton,
                        flag.onPressed,
                      ),
                    ),
                  );
                },
              ),
          ];
        }

        final pad = NumberPad(
          controller: _controller,
          onEdited: (text) {
            model.setDraftInput(text);
            model.keyPressed();
          },
          onCheck: model.checkOrNext,
          next: model.answerCorrect != null,
          signedDecimal: signedDecimal,
          actions: sprinting || !showPad ? null : actions(inPad: true),
        );
        final pageActions = showPad || sprinting
            ? const <Widget>[]
            : actions(inPad: false);
        final field = _CheckMotion(
          key: _fieldKey,
          check: model.lastCheck,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            // Hardware keys reach the field only while it
            // has focus.
            autofocus: true,
            keyboardType: _padShown
                ? TextInputType.none
                : signedDecimal
                ? const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  )
                : TextInputType.number,
            // Arithmetic answers are whole numbers of 0 or more: pasted or
            // typed text keeps only its digits. With the minus and decimal
            // keys, an edit that could no longer become a number is refused.
            inputFormatters: [
              nativeDigitsToAscii,
              signedDecimal
                  ? TextInputFormatter.withFunction(
                      (old, edited) =>
                          canCompleteHundredths(edited.text) ? edited : old,
                    )
                  : FilteringTextInputFormatter.digitsOnly,
            ],
            textInputAction: TextInputAction.done,
            style: theme.textTheme.headlineMedium,
            decoration: InputDecoration(
              labelText: l.answerLabel,
              contentPadding: compact
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                  : null,
              // Beside Check the field is too narrow for the hint; the
              // label and the number keyboard say enough.
              hintText: keyDock ? null : l.answerHint,
              suffixIcon: _padAvailable
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: IconButton(
                        key: keyboardSwitchKey,
                        tooltip: _padShown ? l.useKeyboard : l.useNumberPad,
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
        final check = Slab(
          pressable: true,
          radius: AppTokens.radiusControl,
          child: FilledButton.icon(
            key: checkAnswerButtonKey,
            onPressed: model.submitAnswer,
            style: ButtonStyle(minimumSize: button),
            icon: const Icon(Icons.check_circle_outline),
            // Beside the docked field a short label leaves the field room.
            label: Text(
              keyDock ? l.check : l.checkAnswer,
              semanticsLabel: l.checkAnswer,
            ),
          ),
        );
        final menu = Slab(
          pressable: true,
          radius: AppTokens.radiusControl,
          child: IconButton(
            key: settingsButtonKey,
            tooltip: l.settings,
            onPressed: () => _showSettings(context).whenComplete(() {
              if (mounted) (setup ? _startFocus : _focus).requestFocus();
            }),
            icon: Icon(Icons.menu, semanticLabel: l.settings),
          ),
        );
        // End sits at the top, away from Check. The menu stays, so the kinds
        // can change during practice; it sits at the other end from End, so
        // neither is hit for the other. [middle] goes between them;
        // [oneLine] keeps the row a button high.
        Widget endRow({
          Widget middle = const SizedBox.shrink(),
          bool oneLine = false,
        }) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            menu,
            middle,
            // A long End label wraps instead of pushing past the edge.
            Flexible(
              child: Tooltip(
                message: l.endPracticeLabel,
                excludeFromSemantics: true,
                child: Slab(
                  pressable: true,
                  radius: AppTokens.radiusControl,
                  child: OutlinedButton.icon(
                    key: endPracticeButtonKey,
                    onPressed: _end,
                    style: ButtonStyle(minimumSize: button),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: oneLine
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l.endPractice,
                              semanticsLabel: l.endPracticeLabel,
                            ),
                          )
                        : Text(
                            l.endPractice,
                            semanticsLabel: l.endPracticeLabel,
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
        // A condition line ("n is positive") makes the pinned question two.
        final pinnedLines = model.current.shown(l).split('\n').length;
        final questionStrip = scaler.scale(22) * 1.25 * pinnedLines + 2 * 6 + 2;
        // The header packs tight on a phone-height page.
        final headerTop = phone ? 4.0 : gap;
        const headerBottom = 4.0;
        // On a page [area] high, the docked page's pinned question goes
        // under the header where the page keeps room to read below it, else
        // between the menu and End, scaled to the row.
        bool roomy(double area) =>
            area >= headerTop + 48 + headerBottom + questionStrip + 48;
        Widget header(double area) {
          final fitQuestion = compact && _questionPinned && !roomy(area);
          return PinnedHeaderSliver(
            child: DecoratedBox(
              key: _endHeaderKey,
              // Like the page until the page scrolls under it.
              decoration: BoxDecoration(
                color: _endPinned ? tokens.surfaceRaised : tokens.surface,
                border: Border(
                  bottom: BorderSide(
                    color: _endPinned ? tokens.outline : tokens.surface,
                    width: AppTokens.outlineWidth,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  width < 600 ? 16 : 24,
                  headerTop,
                  width < 600 ? 16 : 24,
                  headerBottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: endRow(
                      oneLine: compact && !roomy(area),
                      middle: fitQuestion
                          ? Expanded(
                              // Display only, as the question strip; wrapped
                              // to the room beside the buttons, then scaled
                              // down to their height.
                              child: IgnorePointer(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, room) => SizedBox(
                                      height: 48,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: SizedBox(
                                          width: room.maxWidth,
                                          child: _PinnedQuestion(
                                            problem: model.current,
                                            strip: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final content = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!model.practising)
                  Row(
                    crossAxisAlignment: compact
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          sprinting ? l.sprintTitle : l.practiceTitle,
                          style: tight
                              ? theme.textTheme.headlineMedium
                              : theme.textTheme.displaySmall,
                        ),
                      ),
                      // A tier change would move levels during a round.
                      if (!sprinting) menu,
                    ],
                  ),
                // The encouragement gives way to the question on a short
                // phone; the sprint rules stay.
                if (sprinting || !tight && !model.practising) ...[
                  const SizedBox(height: 8),
                  Text(
                    sprinting
                        ? l.sprintRules('${sprintLength.inSeconds}')
                        : l.practiceEncouragement,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                ],
                SizedBox(height: model.practising ? gap - headerBottom : gap),
                if (model.tier == null)
                  const _TierPicker()
                else if (setup) ...[
                  if (model.lastRound case final summary?) ...[
                    RoundSummaryCard(key: _summaryKey, summary: summary),
                    SizedBox(height: gap),
                  ],
                  if (model.lastSprint case final result?) ...[
                    _SprintResult(result: result),
                    SizedBox(height: gap),
                  ],
                  if (model.newKind case final kind?) ...[
                    _NewKindCard(key: _newKindKey, kind: kind),
                    SizedBox(height: gap),
                  ],
                  _KindToggles(compact: tight),
                  SizedBox(height: gap),
                  // Side by side when both fit, else full-width rows.
                  Flex(
                    direction: wide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: wide
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.stretch,
                    spacing: tight ? 12 : 16,
                    children: [
                      _flexed(
                        wide,
                        Slab(
                          pressable: true,
                          radius: AppTokens.radiusControl,
                          child: FilledButton.icon(
                            key: startPracticeButtonKey,
                            focusNode: _startFocus,
                            autofocus: true,
                            onPressed: _start,
                            style: ButtonStyle(
                              minimumSize: const WidgetStatePropertyAll(
                                Size(48, 56),
                              ),
                              textStyle: WidgetStatePropertyAll(
                                theme.textTheme.titleLarge,
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              l.startPractice,
                              semanticsLabel: l.startPracticeLabel,
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
                            ).copyWith(minimumSize: button),
                            icon: const Icon(Icons.timer_outlined),
                            label: Text(
                              l.sprintButton('${sprintLength.inSeconds}'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  if (sprinting) ...[
                    _SprintStatus(score: model.sprintScore),
                    SizedBox(height: gap),
                  ],
                  KeyedSubtree(
                    key: compact ? _answerKey : _cardKey,
                    child: _QuestionCard(
                      problem: model.current,
                      compact: smallCard,
                    ),
                  ),
                  if (!compact) ...[
                    SizedBox(height: smallCard ? 16 : 28),
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
                  if (!showPad && !docked) ...[
                    const SizedBox(height: 16),
                    check,
                  ],
                  if (!sprinting) ...[
                    // After a wrong answer the player chooses: try again,
                    // or open the hint.
                    if (wrong) ...[
                      SizedBox(height: tight ? 12 : 16),
                      Flex(
                        key: _choicesKey,
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: wide
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.stretch,
                        spacing: tight ? 12 : 16,
                        children: [
                          _flexed(
                            wide,
                            Slab(
                              key: _tryAgainKey,
                              pressable: true,
                              radius: AppTokens.radiusControl,
                              child: FilledButton.icon(
                                key: tryAgainButtonKey,
                                onPressed: _tryAgain,
                                style: ButtonStyle(minimumSize: button),
                                icon: const Icon(Icons.replay),
                                label: Text(l.tryAgain),
                              ),
                            ),
                          ),
                          _flexed(
                            wide,
                            Slab(
                              pressable: true,
                              radius: AppTokens.radiusControl,
                              child: OutlinedButton.icon(
                                key: hintButtonKey,
                                onPressed: _showHint,
                                style: ButtonStyle(minimumSize: button),
                                icon: const Icon(Icons.lightbulb_outline),
                                label: Text(l.showHint),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // With the system keyboard a small Skip, the quiet Hint
                    // and Report share one line, and wrap where they do not
                    // fit; with the pad they are its top row.
                    if (pageActions.isNotEmpty) ...[
                      SizedBox(height: tight ? 12 : 16),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: pageActions,
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        );
        // While practising, End and the menu are a pinned header.
        Widget page(double area) => !model.practising
            ? SingleChildScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: width < 600 ? 16 : 24,
                  vertical: gap,
                ),
                child: content,
              )
            : CustomScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  header(area),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      width < 600 ? 16 : 24,
                      0,
                      width < 600 ? 16 : 24,
                      gap,
                    ),
                    sliver: SliverToBoxAdapter(child: content),
                  ),
                ],
              );
        // Taps anywhere on the page count as taps on the field, so a
        // button or pad key press never takes its focus.
        if (!docked) {
          return _backEnds(
            TextFieldTapRegion(
              child: LayoutBuilder(
                builder: (context, area) => page(area.maxHeight),
              ),
            ),
          );
        }
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
                          if (showPad)
                            field
                          else
                            Row(
                              spacing: 8,
                              children: [
                                Expanded(child: field),
                                check,
                              ],
                            ),
                          _AnswerFeedback(
                            model: model,
                            dense: true,
                            onNext: nextInStrip
                                ? model.generateNextProblem
                                : null,
                          ),
                          if (showPad)
                            NumberPad(
                              controller: _controller,
                              onEdited: pad.onEdited,
                              onCheck: pad.onCheck,
                              dense: true,
                              next: pad.next,
                              signedDecimal: signedDecimal,
                              actions: pad.actions,
                            ),
                        ],
                      )
                    : pad,
              ),
            ),
          ),
        );
        return _backEnds(
          TextFieldTapRegion(
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
                        Positioned.fill(child: page(area.maxHeight)),
                        // Only while the page keeps room to read below it;
                        // under End and the menu while practising.
                        if (compact &&
                            _questionPinned &&
                            (model.practising
                                ? roomy(area.maxHeight)
                                : area.maxHeight >= questionStrip + 48))
                          Positioned(
                            top: model.practising ? _endHeaderHeight : 0,
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
          ),
        );
      },
    );
  }

  /// The keyboard dock's height, measured as it lays out on a page [width]
  /// wide with its tallest content, a wrong answer: the dock's padding, the
  /// field (its text line and padding) beside Check, the gap, and the
  /// feedback strip with Next beside the message, or under it when the
  /// message would take more than two lines there.
  double _keyDockHeight(BuildContext context, double width) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    TextPainter measure(String text, TextStyle? style, [double? maxWidth]) =>
        TextPainter(
          text: TextSpan(text: text, style: style),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
        )..layout(maxWidth: maxWidth ?? double.infinity);
    final field = measure('0', textTheme.headlineMedium);
    final label = measure(l.next, textTheme.labelLarge);
    // The strip's text room as `_AnswerFeedback` works it out: the dock's
    // gutters, the strip's border and padding, the icon and the gaps.
    final strip = min(width - 32, 440) - 2 * AppTokens.outlineWidth - 18;
    final style = textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    final beside = measure(
      l.feedbackWrong,
      style,
      max(0, strip - 24 - 2 * 8 - label.width - 54),
    );
    final double feedback;
    if (beside.computeLineMetrics().length > 2) {
      final under = measure(l.feedbackWrong, style, max(0, strip - 24 - 8));
      feedback = max(24.0, under.height) + 6 + 48 + 2 * 6;
      under.dispose();
    } else {
      feedback = max(48.0, beside.height) + 2 * 6;
    }
    final height =
        AppTokens.outlineWidth +
        8 +
        field.height +
        2 * 10 +
        6 +
        max(48.0, feedback) +
        8 +
        5;
    field.dispose();
    label.dispose();
    beside.dispose();
    return height;
  }

  /// How much taller than its two lines beside Next, which the dock's
  /// estimate holds, the docked feedback strip grows for the longest
  /// message, a wrong answer, once Next moves under it (large text, a long
  /// translation), on a page [width] wide.
  double _longFeedback(BuildContext context, double width) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    TextPainter measure(String text, TextStyle? style) => TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    );
    final label = measure(l.next, textTheme.labelLarge)..layout();
    // The strip's text room as `_AnswerFeedback` works it out: the dock's
    // gutters, the strip's border and padding, the icon and the gaps.
    final strip = min(width - 32, 440) - 2 * AppTokens.outlineWidth - 18;
    final message = measure(
      l.feedbackWrong,
      textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    )..layout(maxWidth: max(0, strip - 24 - 2 * 8 - label.width - 54));
    final lines = message.computeLineMetrics();
    var extra = 0.0;
    if (lines.length > 2) {
      final twoLines = lines[0].height + lines[1].height;
      message.layout(maxWidth: max(0, strip - 24 - 8));
      extra = max(0, message.height - twoLines) + 6 + 48;
    }
    label.dispose();
    message.dispose();
    return extra;
  }

  /// The Android back gesture while practising is End.
  Widget _backEnds(Widget child) => PopScope(
    canPop: !_model.practising,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _end();
    },
    child: child,
  );
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
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    // A condition line under an equation ("n is positive") in body size.
    final [line, ...notes] = problem.shown(l).split('\n');
    Widget question(TextStyle? style) => equationIsland(
      problem,
      Text.rich(
        TextSpan(
          children: [
            mathSpan(context, line, style),
            for (final note in notes)
              mathSpan(context, '\n$note', textTheme.titleLarge),
          ],
        ),
        key: questionOnProblemsPageKey,
        textAlign: TextAlign.center,
        semanticsLabel: l.mathQuestion(problem.spoken(l)),
      ),
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
                    problem.kind.label(l),
                    style: textTheme.labelMedium?.copyWith(
                      color: tokens.onOperation,
                    ),
                  ),
                ),
              ),
            if (problem case FigureProblem(:final figure))
              // The figure where the question text would be, with the
              // short prompt under it; the figure reads the whole sentence.
              Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(20, 6, 20, 6)
                    : const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  key: questionOnProblemsPageKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FigureView(
                      figure: figure,
                      height: figureHeight(compact: compact),
                      semanticsLabel: l.mathQuestion(problem.spoken(l)),
                    ),
                    SizedBox(height: compact ? 2 : 8),
                    ExcludeSemantics(
                      child: _WholeWords(
                        figurePromptText(l, figure),
                        style: compact
                            ? textTheme.titleLarge
                            : textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 20, vertical: 6)
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

/// Centred [text] that wraps only between words: a word wider than the
/// line ("Perimeter?" at large text on a small phone) shrinks the text
/// until it fits instead of breaking inside the word.
class _WholeWords extends StatelessWidget {
  const _WholeWords(this.text, {required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      var widest = 0.0;
      for (final word in text.split(RegExp(r'\s+'))) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textScaler: scaler,
          textDirection: Directionality.of(context),
        )..layout();
        widest = max(widest, painter.width);
        painter.dispose();
      }
      final size = style?.fontSize ?? 14;
      return Text(
        text,
        textAlign: TextAlign.center,
        style: style,
        textScaler: widest <= box.maxWidth
            ? null
            : TextScaler.linear(
                scaler.scale(size) / size * box.maxWidth / widest * .99,
              ),
      );
    },
  );
}

/// The question repeated over the top of a phone page whose question card
/// has scrolled away, so it stays in view with the docked field.
class _PinnedQuestion extends StatelessWidget {
  const _PinnedQuestion({required this.problem, this.strip = true});

  final Problem problem;

  /// False for the question alone, between the menu and End.
  final bool strip;

  @override
  Widget build(BuildContext context) {
    // The card keeps the question's semantics.
    final question = ExcludeSemantics(
      child: equationIsland(
        problem,
        Text.rich(
          mathSpan(
            context,
            problem.shown(AppLocalizations.of(context)),
            Theme.of(context).textTheme.titleLarge,
          ),
          key: pinnedQuestionKey,
          textAlign: TextAlign.center,
        ),
      ),
    );
    return !strip
        ? question
        : DecoratedBox(
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
              child: question,
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
    final l = AppLocalizations.of(context);
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
                      l.sprintSecondsLeft(seconds),
                      key: sprintCountdownKey,
                      semanticsLabel: l.sprintSecondsLeftSemantics(seconds),
                      style: style,
                    ),
                  ),
                ),
              ],
            ),
            Text(l.score('$score'), key: sprintScoreKey, style: style),
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
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final mix = [
      for (var level = 1; level <= result.levels.length; level++)
        if (result.levels[level - 1] > 0)
          l.sprintLevelCount('$level', '${result.levels[level - 1]}'),
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
                        l.sprintOver,
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
                        tile(l.score('${result.score}'), sprintResultScoreKey),
                        tile(
                          l.personalBest('${result.best}'),
                          sprintResultBestKey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Scores at different levels are weighted, so the mix is
                    // shown.
                    Text(
                      mix.isEmpty
                          ? l.noAnswersThisRound
                          : l.answersByDifficulty(mix.join(', ')),
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

/// Names a kind the player has not tried, once, above the toggles. Closing
/// it or switching the kind on hides it for good; it never comes back.
class _NewKindCard extends StatelessWidget {
  const _NewKindCard({super.key, required this.kind});

  final OperationType kind;

  @override
  Widget build(BuildContext context) {
    final model = context.read<MathTesterModel>();
    final l = AppLocalizations.of(context);
    return Slab(
      child: Card(
        key: newKindCardKey,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.auto_awesome_outlined),
          title: Text(l.newKindTitle(kind.label(l))),
          subtitle: Text(l.newKindSubtitle),
          trailing: IconButton(
            key: newKindDismissKey,
            icon: const Icon(Icons.close),
            tooltip: l.newKindDismiss,
            onPressed: () => model.dismissNewKind(kind),
          ),
          onTap: () => model.toggleOperation(kind),
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
    final l = AppLocalizations.of(context);
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
                child: Text(l.tierPickerTitle, style: textTheme.headlineMedium),
              ),
              const SizedBox(height: 8),
              Text(
                l.tierPickerBody,
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
                        Expanded(child: Text(tier.label(l))),
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

/// A simple list of settings: the starting tier, the feedback switches, the
/// theme and the legal pages.
Future<void> _showSettings(BuildContext context) {
  unawaited(context.read<MathTesterModel>().checkDeviceSettings());
  return _settingsSheet(context);
}

Future<void> _settingsSheet(BuildContext context) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  // showModalBottomSheet, but kept over the page column ([ContentArea]).
  return navigator.push(
    _ContentSheetRoute<void>(
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      showDragHandle: true,
      isScrollControlled: true,
      // A full-height sheet would otherwise reach under the status bar.
      useSafeArea: true,
      builder: _settingsList,
    ),
  );
}

class _ContentSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _ContentSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
    super.showDragHandle,
    super.useSafeArea,
  });

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => ContentArea(
    child: super.buildPage(context, animation, secondaryAnimation),
  );
}

Widget _settingsList(BuildContext context) {
  final model = context.watch<MathTesterModel>();
  final l = AppLocalizations.of(context);
  final textTheme = Theme.of(context).textTheme;
  final listTileTheme = Theme.of(context).listTileTheme;
  final compact = model.compact;
  // Compact tiles keep their 48 px minimum height.
  final density = compact ? VisualDensity.compact : null;
  final rowPadding = EdgeInsetsDirectional.fromSTEB(
    16,
    compact ? 6 : 12,
    24,
    compact ? 6 : 12,
  );
  final rowSpacing = compact ? 8.0 : 12.0;
  // Shorter than the screen, so the page shows above it. A drag down on
  // the list at its top shrinks the sheet; at its smallest it closes.
  return DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.8,
    maxChildSize: 0.8,
    minChildSize: 0.4,
    snap: true,
    builder: (_, scroll) => SafeArea(
      child: SingleChildScrollView(
        key: settingsSheetKey,
        controller: scroll,
        padding: EdgeInsets.fromLTRB(12, 0, 12, compact ? 8 : 16),
        child: ListTileTheme.merge(
          visualDensity: density,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: compact ? 0 : 4,
            children: [
              // The same kinds as before Start; a change applies from the
              // next question. The menu is hidden during a sprint.
              if (model.tier != null) ...[
                ListTile(
                  title: Semantics(
                    header: true,
                    child: Text(l.menuKinds, style: textTheme.titleLarge),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _KindToggles(compact: compact),
                ),
                SizedBox(height: compact ? 4 : 8),
              ],
              ListTile(
                title: Semantics(
                  header: true,
                  child: Text(
                    l.startingDifficulty,
                    style: textTheme.titleLarge,
                  ),
                ),
                subtitle: Text(
                  key: currentTierNoteKey,
                  l.currentTier(model.tier?.label(l) ?? l.tierNotChosen),
                ),
              ),
              for (final tier in Tier.values)
                ListTile(
                  key: tierSettingKey(tier),
                  title: Text(tier.label(l)),
                  selected: tier == model.tier,
                  trailing: tier == model.tier
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () {
                    if (tier != model.tier) model.chooseTier(tier);
                    Navigator.pop(context);
                  },
                ),
              SizedBox(height: compact ? 4 : 8),
              SwitchListTile(
                key: soundSwitchKey,
                title: Text(l.sound),
                subtitle: Text(l.soundSubtitle),
                value: model.sound,
                onChanged: model.setSound,
              ),
              if (model.soundMuted)
                Padding(
                  key: soundVolumeHintKey,
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.volumeOff, style: listTileTheme.subtitleTextStyle),
                      TextButton(
                        key: openVolumeSettingsKey,
                        onPressed: model.openVolumeSettings,
                        child: Text(l.openPhoneSettings),
                      ),
                    ],
                  ),
                ),
              SwitchListTile(
                key: hapticsSwitchKey,
                title: Text(l.vibration),
                subtitle: Text(l.vibrationSubtitle),
                value: model.haptics,
                onChanged: model.setHaptics,
              ),
              if (model.vibrationBlocked)
                Padding(
                  key: touchFeedbackHintKey,
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.touchFeedbackOff,
                        style: listTileTheme.subtitleTextStyle,
                      ),
                      TextButton(
                        key: openVibrationSettingsKey,
                        onPressed: model.openVibrationSettings,
                        child: Text(l.openPhoneSettings),
                      ),
                    ],
                  ),
                ),
              // Laid out like the switch tiles above: same insets and text
              // styles, with the choice on its own full-width line.
              Padding(
                padding: rowPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: rowSpacing,
                  children: [
                    Text(l.theme, style: listTileTheme.titleTextStyle),
                    SegmentedButton<ThemeMode>(
                      expandedInsets: EdgeInsets.zero,
                      showSelectedIcon: false,
                      segments: [
                        // Text only: an icon beside "System" wraps it at 360 px.
                        for (final (mode, label) in [
                          (ThemeMode.system, l.themeSystem),
                          (ThemeMode.light, l.themeLight),
                          (ThemeMode.dark, l.themeDark),
                        ])
                          ButtonSegment(
                            value: mode,
                            label: Text(
                              label,
                              key: themeModeKey(mode),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                      ],
                      selected: {model.themeMode},
                      onSelectionChanged: (modes) =>
                          model.setThemeMode(modes.single),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: rowPadding,
                child: Column(
                  // Stretch: the Wrap below would otherwise shrink the
                  // column and the sheet would centre it.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: rowSpacing,
                  children: [
                    Text(l.colours, style: listTileTheme.titleTextStyle),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final palette in AppPalette.values)
                          _Swatch(
                            key: paletteKey(palette),
                            palette: palette,
                            selected: palette == model.palette,
                            onTap: () => model.setPalette(palette),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: rowPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: rowSpacing,
                  children: [
                    Text(l.layout, style: listTileTheme.titleTextStyle),
                    SegmentedButton<LayoutMode>(
                      expandedInsets: EdgeInsets.zero,
                      showSelectedIcon: false,
                      segments: [
                        for (final (mode, label) in [
                          (LayoutMode.comfortable, l.layoutComfortable),
                          (LayoutMode.compact, l.layoutCompact),
                        ])
                          ButtonSegment(
                            value: mode,
                            label: Text(
                              label,
                              key: layoutModeKey(mode),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                      ],
                      selected: {model.layoutMode},
                      onSelectionChanged: (modes) =>
                          model.setLayoutMode(modes.single),
                    ),
                  ],
                ),
              ),
              // Eleven choices: a dialog, not a segmented row.
              ListTile(
                key: languageTileKey,
                leading: const Icon(Icons.translate),
                title: Text(l.language),
                subtitle: Text(
                  _languageName(model.language) ?? l.languageSystem,
                ),
                onTap: () => _showLanguages(context),
              ),
              SizedBox(height: compact ? 4 : 8),
              ListTile(
                key: privacyTileKey,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l.privacy),
                subtitle: Text(l.privacySubtitle),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const _PrivacyPage()),
                ),
              ),
              ListTile(
                key: licencesTileKey,
                leading: const Icon(Icons.description_outlined),
                title: Text(l.licences),
                subtitle: Text(l.licencesSubtitle),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LicencesPage()),
                ),
              ),
              ListTile(
                key: impressumTileKey,
                leading: const Icon(Icons.open_in_new),
                title: Text(l.impressum),
                subtitle: Text(l.impressumSubtitle),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  // Closed first, so a failure notice is not hidden behind it.
                  Navigator.pop(context);
                  if (!await model.openImpressum()) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.browserDidNotOpen)),
                    );
                  }
                },
              ),
              ListTile(
                key: sendProblemReportTileKey,
                leading: const Icon(Icons.outlined_flag),
                title: Text(l.reportSendProblem),
                subtitle: Text(l.reportSendProblemSubtitle),
                onTap: () {
                  // The sheet closes first; the dialog opens on the page.
                  final page = Navigator.of(context);
                  page.pop();
                  unawaited(showReportDialog(page.context));
                },
              ),
              ListTile(
                key: reportProblemTileKey,
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l.reportProblem),
                subtitle: Text(l.reportProblemSubtitle),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  if (!await model.openProblemReport()) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.browserDidNotOpen)),
                    );
                  }
                },
              ),
              ListTile(
                key: appVersionTileKey,
                leading: const Icon(Icons.info_outline),
                title: Text(l.appVersionTitle(appVersion)),
                subtitle: Text(l.releaseNotesSubtitle),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  if (!await model.openReleaseNotes()) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.browserDidNotOpen)),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A language's name in that language, such as "Deutsch"; null for none.
String? _languageName(String? code) =>
    code == null ? null : lookupAppLocalizations(appLocale(code)).languageName;

/// "System" and every translated language, each named in its own language
/// with its English name in small type on the same line (none for English).
Future<void> _showLanguages(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final model = context.read<MathTesterModel>();
    final l = AppLocalizations.of(context);
    return ContentArea(
      child: SimpleDialog(
        title: Text(l.language),
        children: [
          for (final code in [
            null,
            for (final locale in AppLocalizations.supportedLocales)
              locale.toString(),
          ])
            ListTile(
              key: languageOptionKey(code),
              // A long press (or hover) shows the English name the row may cut
              // off; screen readers already read the whole row.
              title: Tooltip(
                message: code == null || code == 'en'
                    ? ''
                    : '${_languageName(code)} · ${englishLanguageNames[code]}',
                excludeFromSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_languageName(code) ?? l.languageSystem),
                    if (code != null && code != 'en') ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          englishLanguageNames[code]!,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              selected: code == model.language,
              trailing: code == model.language
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () {
                model.setLanguage(code);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  },
);

/// The bundled privacy policy, readable offline.
class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final [(title, intro), ...sections] = privacyPolicy(
      AppLocalizations.of(context),
    );
    return Scaffold(
      key: privacyPageKey,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final paragraph in intro) _paragraph(paragraph),
            for (final (heading, paragraphs) in sections) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Semantics(
                  header: true,
                  child: Text(heading, style: textTheme.titleMedium),
                ),
              ),
              for (final paragraph in paragraphs) _paragraph(paragraph),
            ],
          ],
        ),
      ),
    );
  }

  Widget _paragraph(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(text),
  );
}

/// The narrowest a selection toggle gets in one row, gaps included.
const _toggleMinWidth = 58.0;

/// How many of [count] equal toggles go in one row of [width]: all of them,
/// or else half (rounded up) in each of two rows.
@visibleForTesting
int togglesPerRow(double width, int count) =>
    width >= count * _toggleMinWidth - 10 ? count : (count + 1) ~/ 2;

/// The kind toggles in rows, on the start screen and in the menu sheet.
class _KindToggles extends StatelessWidget {
  const _KindToggles({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MathTesterModel>();
    return LayoutBuilder(
      builder: (context, constraints) {
        const types = OperationType.values;
        final perRow = togglesPerRow(constraints.maxWidth, types.length);
        return Column(
          spacing: 10,
          children: [
            for (var i = 0; i < types.length; i += perRow)
              Row(
                spacing: 10,
                children: [
                  for (final type in types.skip(i).take(perRow))
                    Expanded(
                      child: _OperationToggle(
                        type: type,
                        selected: model.selectedOperations.contains(type),
                        onPressed: () => model.toggleOperation(type),
                        compact: compact,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Selected stands up on its slab with a check; unselected sits flat on a
/// sunken fill, so the state reads without colour.
class _OperationToggle extends StatelessWidget {
  const _OperationToggle({
    required this.type,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final OperationType type;
  final bool selected;
  final VoidCallback onPressed;

  /// Shorter, still a full touch target, for the docked phone page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final foreground = selected ? tokens.onOperation : tokens.inkMuted;
    return Tooltip(
      message: type.label(l),
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
                    minimumSize: compact ? const Size(48, 48) : null,
                    backgroundColor: selected
                        ? tokens.operation
                        : tokens.surfaceSunken,
                    foregroundColor: foreground,
                  ),
                  child: Text(
                    type.displayString,
                    semanticsLabel: type.label(l),
                    style: TextStyle(
                      fontSize: compact ? 26 : 30,
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
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final message =
        switch (model.inputProblem) {
          InputProblem.empty => l.enterNumberFirst,
          InputProblem.notANumber => l.useNumber,
          null => null,
        } ??
        switch (model.answerCorrect) {
          null => null,
          true => l.feedbackCorrect,
          false => l.feedbackWrong,
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
                child: LayoutBuilder(
                  builder: (context, box) {
                    final next = switch (onNext) {
                      final next? => Slab(
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
                          label: Text(l.next, semanticsLabel: l.nextQuestion),
                        ),
                      ),
                      null => null,
                    };
                    final style =
                        (dense
                                ? Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)
                                : Theme.of(context).textTheme.titleMedium)
                            ?.copyWith(color: foreground);
                    // Beside Next, large text on a narrow phone left the
                    // message a few words a line, and the docked strip grew
                    // taller than the page; a message that would take more
                    // than two lines there gets Next under it instead.
                    TextPainter measure(String text, TextStyle? style) =>
                        TextPainter(
                          text: TextSpan(text: text, style: style),
                          textScaler: MediaQuery.textScalerOf(context),
                          textDirection: Directionality.of(context),
                          maxLines: 2,
                        );
                    var below = false;
                    if (next != null) {
                      // Its label, icon, gap, padding and border.
                      final label = measure(
                        l.next,
                        Theme.of(context).textTheme.labelLarge,
                      )..layout();
                      final text = measure(message, style)
                        ..layout(
                          maxWidth: max(
                            0,
                            box.maxWidth - 24 - 2 * 8 - label.width - 54,
                          ),
                        );
                      below = text.didExceedMaxLines;
                      label.dispose();
                      text.dispose();
                    }
                    final row = Row(
                      spacing: dense ? 8 : 12,
                      children: [
                        Icon(icon, size: dense ? 24 : 28, color: foreground),
                        Expanded(child: Text(message, style: style)),
                        if (next != null && !below) next,
                      ],
                    );
                    return below
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            spacing: 6,
                            children: [row, ?next],
                          )
                        : row;
                  },
                ),
              ),
            ),
    );
  }
}

/// The colour themes' names, as the settings sheet shows them.
/// One colour theme's accent as a round button at least 48 px across; a
/// check and a thicker edge mark the chosen one.
class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final own = AppTokens.of(palette, Theme.of(context).brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: palette.label(AppLocalizations.of(context)),
      child: InkResponse(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 52,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: own.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.tokens.outline,
                  width: selected ? 4 : AppTokens.outlineWidth,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, color: own.onPrimary, size: 26)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

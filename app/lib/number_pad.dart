import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'hundredths.dart';
import 'keys.dart';
import 'l10n/app_localizations.dart';
import 'slab.dart';

/// The one per-platform decision: whether the pad replaces the system
/// keyboard. Where `TextInputType.none` turns out not to keep the soft
/// keyboard closed (criterion 39, checked per platform), that platform
/// returns false here and gets the system keyboard with no pad.
bool padReplacesKeyboard(TargetPlatform platform) => switch (platform) {
  // On web this is the browser's platform, so mobile browsers land here.
  TargetPlatform.android || TargetPlatform.iOS => true,
  // No soft keyboard to keep closed; the pad serves touch screens.
  TargetPlatform.fuchsia ||
  TargetPlatform.linux ||
  TargetPlatform.macOS ||
  TargetPlatform.windows => true,
};

/// Digits, Delete and the Check key, editing [controller] at its selection;
/// with [signedDecimal] also a minus key and a decimal key.
class NumberPad extends StatelessWidget {
  const NumberPad({
    super.key,
    required this.controller,
    required this.onEdited,
    required this.onCheck,
    this.dense = false,
    this.next = false,
    this.signedDecimal = false,
    this.actions,
  });

  final TextEditingController controller;

  /// Gets the new text after a digit or Delete key edits it.
  final ValueChanged<String> onEdited;

  /// Its key is the same `checkAnswerButtonKey` as the Check button it
  /// replaces.
  final VoidCallback onCheck;

  /// Smaller keys and gaps, for a phone that also docks the field above.
  final bool dense;

  /// Whether the Check key moves to the next question, after a check.
  final bool next;

  /// Adds a minus key and a decimal key, in the same three rows, for kinds
  /// whose answers can be negative or decimal. Edits that could no longer
  /// become such a number are ignored.
  final bool signedDecimal;

  /// Buttons in a row above the digits, as tall as a key and sharing its
  /// width equally: Skip, Hint and Report while practising, which then are
  /// not on the page. Null leaves the row out (a sprint).
  final List<Widget>? actions;

  /// Grows with the text, so a 200% digit still fits its key.
  static double keyHeight(TextScaler scaler, {bool dense = false}) =>
      max(dense ? 48 : 52, scaler.scale(28) * 1.2 + (dense ? 12 : 16));

  static double _gap(bool dense) => dense ? 6 : 8;

  static double height(
    TextScaler scaler, {
    bool dense = false,
    bool actions = false,
  }) {
    final rows = actions ? 4 : 3;
    return rows * keyHeight(scaler, dense: dense) + (rows - 1) * _gap(dense);
  }

  void _edit(String? digit) {
    final text = controller.text;
    var selection = controller.selection;
    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    var start = selection.start;
    if (digit == null && selection.isCollapsed) {
      if (start == 0) return;
      start--;
    }
    final next = text.replaceRange(start, selection.end, digit ?? '');
    if (signedDecimal && !canCompleteHundredths(next)) return;
    _set(next, start + (digit?.length ?? 0));
  }

  void _set(String text, int offset) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
    onEdited(text);
  }

  /// Adds a leading minus sign, or removes the one there.
  void _toggleMinus() {
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.end : text.length;
    if (text.startsWith(RegExp('[-−]'))) {
      _set(text.substring(1), max(offset - 1, 0));
    } else {
      _set('$minusSign$text', offset + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.tokens;
    final keyHeight = NumberPad.keyHeight(
      MediaQuery.textScalerOf(context),
      dense: dense,
    );
    final gap = _gap(dense);
    final keySize = WidgetStatePropertyAll(Size(48, keyHeight));
    const noPadding = WidgetStatePropertyAll(EdgeInsets.zero);

    Widget key(Widget button, {int flex = 1}) => Expanded(
      flex: flex,
      child: Slab(
        pressable: true,
        radius: AppTokens.radiusControl,
        child: button,
      ),
    );

    Widget digit(int value) => key(
      OutlinedButton(
        key: padDigitKey('$value'),
        onPressed: () => _edit('$value'),
        style: ButtonStyle(minimumSize: keySize, padding: noPadding),
        child: Text(
          '$value',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );

    // The digits keep their order in a right-to-left page, as on a phone
    // keypad; only the Check label (words) follows the page.
    final pageDirection = Directionality.of(context);
    Widget row(List<Widget> keys) => Directionality(
      textDirection: TextDirection.ltr,
      child: Row(spacing: gap, children: keys),
    );
    final checkIcon = Icon(
      next ? Icons.navigate_next : Icons.check_circle_outline,
      size: 28,
    );

    Widget sign(Key id, String label, String semantics, VoidCallback onTap) =>
        key(
          OutlinedButton(
            key: id,
            onPressed: onTap,
            style: ButtonStyle(minimumSize: keySize, padding: noPadding),
            child: Text(
              label,
              semanticsLabel: semantics,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
        );

    return Column(
      key: numberPadKey,
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        if (actions case final actions?)
          SizedBox(
            height: keyHeight,
            child: Row(
              spacing: gap,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final action in actions) Expanded(child: action)],
            ),
          ),
        row([for (var value = 1; value <= 5; value++) digit(value)]),
        row([for (var value = 6; value <= 10; value++) digit(value % 10)]),
        row([
          key(
            OutlinedButton(
              key: padDeleteKey,
              onPressed: () => _edit(null),
              style: ButtonStyle(
                minimumSize: keySize,
                padding: noPadding,
                backgroundColor: WidgetStatePropertyAll(tokens.surfaceSunken),
              ),
              child: Icon(
                Icons.backspace_outlined,
                size: 28,
                semanticLabel: l.padDelete,
              ),
            ),
          ),
          if (signedDecimal) ...[
            sign(padMinusKey, minusSign, l.padMinus, _toggleMinus),
            sign(
              padDecimalKey,
              decimalSeparator(l.localeName),
              l.padDecimalPoint,
              () => _edit(decimalSeparator(l.localeName)),
            ),
          ],
          key(
            flex: signedDecimal ? 2 : 4,
            // After a check this key is the page's one Next, so it answers
            // to the Next key as well.
            KeyedSubtree(
              key: next ? nextQuestionButtonKey : null,
              child: Directionality(
                textDirection: pageDirection,
                child: signedDecimal
                    // Two keys wide: a short label, shrunk rather than wrapped,
                    // so the key keeps its height.
                    ? FilledButton(
                        key: checkAnswerButtonKey,
                        onPressed: onCheck,
                        style: ButtonStyle(
                          minimumSize: keySize,
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 8,
                            children: [
                              checkIcon,
                              next
                                  ? Text(l.next, semanticsLabel: l.nextQuestion)
                                  : Text(
                                      l.check,
                                      semanticsLabel: l.checkAnswer,
                                    ),
                            ],
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        key: checkAnswerButtonKey,
                        onPressed: onCheck,
                        style: ButtonStyle(minimumSize: keySize),
                        icon: checkIcon,
                        label: next
                            ? Text(l.next, semanticsLabel: l.nextQuestion)
                            : Text(l.checkAnswer),
                      ),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

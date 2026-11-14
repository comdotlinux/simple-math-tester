import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'keys.dart';
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

/// Digits, Delete and the Check key, editing [controller] at its selection.
/// Every answer is a whole number of 0 or more, so there is no minus or
/// decimal key.
class NumberPad extends StatelessWidget {
  const NumberPad({
    super.key,
    required this.controller,
    required this.onEdited,
    required this.onCheck,
    this.dense = false,
    this.next = false,
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

  /// Grows with the text, so a 200% digit still fits its key.
  static double keyHeight(TextScaler scaler, {bool dense = false}) =>
      max(dense ? 48 : 52, scaler.scale(28) * 1.2 + 16);

  static double _gap(bool dense) => dense ? 6 : 8;

  static double height(TextScaler scaler, {bool dense = false}) =>
      3 * keyHeight(scaler, dense: dense) + 2 * _gap(dense);

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
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + (digit?.length ?? 0)),
    );
    onEdited(next);
  }

  @override
  Widget build(BuildContext context) {
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

    Widget row(List<Widget> keys) => Row(spacing: gap, children: keys);

    return Column(
      key: numberPadKey,
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
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
              child: const Icon(
                Icons.backspace_outlined,
                size: 28,
                semanticLabel: 'Delete',
              ),
            ),
          ),
          key(
            flex: 4,
            FilledButton.icon(
              key: checkAnswerButtonKey,
              onPressed: onCheck,
              style: ButtonStyle(minimumSize: keySize),
              icon: Icon(
                next ? Icons.navigate_next : Icons.check_circle_outline,
                size: 28,
              ),
              label: next
                  ? const Text('Next', semanticsLabel: 'Next question')
                  : const Text('Check answer'),
            ),
          ),
        ]),
      ],
    );
  }
}

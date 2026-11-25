/// [Text] that shows its digits as the page's [DigitScope] says: 0-9 in, the
/// language's own digits out. Every file that shows a number imports this
/// instead of the framework's `Text`.
// The key is not passed to super: see [Text._textKey].
// ignore_for_file: use_key_in_widget_constructors
library;

import 'package:flutter/widgets.dart' as w;
import 'package:flutter/widgets.dart' hide Text;

import 'digits.dart';

class Text extends StatelessWidget {
  const Text(
    String this.data, {
    Key? key,
    this.style,
    this.textAlign,
    this.overflow,
    this.softWrap,
    this.maxLines,
    this.semanticsLabel,
    this.textScaler,
    this.textDirection,
    this.strutStyle,
    this.textWidthBasis,
  }) : textSpan = null,
       _textKey = key;

  const Text.rich(
    InlineSpan this.textSpan, {
    Key? key,
    this.style,
    this.textAlign,
    this.overflow,
    this.softWrap,
    this.maxLines,
    this.semanticsLabel,
    this.textScaler,
    this.textDirection,
    this.strutStyle,
    this.textWidthBasis,
  }) : data = null,
       _textKey = key;

  // The key goes to the framework's Text, so a finder by key reads that.
  final Key? _textKey;
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final bool? softWrap;
  final int? maxLines;
  final String? semanticsLabel;
  final TextScaler? textScaler;
  final TextDirection? textDirection;
  final StrutStyle? strutStyle;
  final TextWidthBasis? textWidthBasis;

  @override
  Widget build(BuildContext context) {
    final language = DigitScope.of(context);
    String shown(String text) =>
        language == null ? text : localDigits(text, language);
    final semantics = semanticsLabel == null ? null : shown(semanticsLabel!);
    // Plain data stays `data` of the framework's Text, which tests read.
    return textSpan == null
        ? w.Text(
            shown(data!),
            key: _textKey,
            style: style,
            textAlign: textAlign,
            overflow: overflow,
            softWrap: softWrap,
            maxLines: maxLines,
            semanticsLabel: semantics,
            textScaler: textScaler,
            textDirection: textDirection,
            strutStyle: strutStyle,
            textWidthBasis: textWidthBasis,
          )
        : w.Text.rich(
            convertDigits(textSpan!, shown),
            key: _textKey,
            style: style,
            textAlign: textAlign,
            overflow: overflow,
            softWrap: softWrap,
            maxLines: maxLines,
            semanticsLabel: semantics,
            textScaler: textScaler,
            textDirection: textDirection,
            strutStyle: strutStyle,
            textWidthBasis: textWidthBasis,
          );
  }
}

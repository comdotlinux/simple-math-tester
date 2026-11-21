import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'operations.dart';

/// [text] in [style], with a drawn blank (a line on the baseline, as in a
/// textbook) for each [EquationProblem.blank]: no bundled font has that
/// glyph, and the web engine would fetch a font for it. The letter n on its own (not in a word such as a figure's sentence),
/// the unknown from level 3 on, is italic, as in a textbook. Callers give
/// the [Text.rich] a semantics label, because the blank has no words.
TextSpan mathSpan(BuildContext context, String text, TextStyle? style) {
  final marks = RegExp(
    '${EquationProblem.blank}|(?<!\\p{L})n(?!\\p{L})',
    unicode: true,
  ).allMatches(text);
  if (marks.isEmpty) return TextSpan(text: text, style: style);
  final effective = DefaultTextStyle.of(context).style.merge(style);
  final children = <InlineSpan>[];
  var start = 0;
  for (final mark in marks) {
    if (mark.start > start) {
      children.add(TextSpan(text: text.substring(start, mark.start)));
    }
    children.add(
      mark[0] == 'n'
          ? const TextSpan(
              text: 'n',
              style: TextStyle(fontStyle: FontStyle.italic),
            )
          : WidgetSpan(
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
              child: _Blank(
                fontSize: effective.fontSize ?? 14,
                color: effective.color ?? context.tokens.ink,
              ),
            ),
    );
    start = mark.end;
  }
  if (start < text.length) children.add(TextSpan(text: text.substring(start)));
  return TextSpan(style: style, children: children);
}

/// A thick line on the baseline about two digits wide, in the text colour:
/// longer and lower than a minus sign, so `10 − __ = 4` reads clearly.
class _Blank extends StatelessWidget {
  const _Blank({required this.fontSize, required this.color});

  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // RichText scales a WidgetSpan with the text scaler; size it unscaled.
    return Container(
      width: fontSize * 1.1,
      height: max(2, fontSize / 10),
      margin: EdgeInsets.symmetric(horizontal: fontSize * 0.06),
      color: color,
    );
  }
}

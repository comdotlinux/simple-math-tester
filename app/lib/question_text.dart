import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'operations.dart';

/// [text] in [style], with a drawn box for each [EquationProblem.blank]: no
/// bundled font has that glyph, and the web engine would fetch a font for
/// it. The letter n on its own (not in a word such as a figure's sentence),
/// the unknown from level 3 on, is italic, as in a textbook. Callers give
/// the [Text.rich] a semantics label, because the box has no words.
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
              alignment: PlaceholderAlignment.middle,
              child: _BlankBox(
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

/// An empty box about the size of a digit, outlined in the text colour.
class _BlankBox extends StatelessWidget {
  const _BlankBox({required this.fontSize, required this.color});

  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // A widget in text is not scaled with it; scale it here.
    final size = MediaQuery.textScalerOf(context).scale(fontSize);
    return Container(
      width: size * 0.62,
      height: size * 0.78,
      margin: EdgeInsets.symmetric(horizontal: size * 0.04),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: max(2, size / 18)),
        borderRadius: BorderRadius.circular(size * 0.1),
      ),
    );
  }
}

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'operations.dart';

/// [text] in [style], with a drawn box for each [EquationProblem.blank]: no
/// bundled font has that glyph, and the web engine would fetch a font for
/// it. Callers give the [Text.rich] a semantics label, because the box has
/// no words.
TextSpan mathSpan(BuildContext context, String text, TextStyle? style) {
  final parts = text.split(EquationProblem.blank);
  if (parts.length == 1) return TextSpan(text: text, style: style);
  final effective = DefaultTextStyle.of(context).style.merge(style);
  return TextSpan(
    style: style,
    children: [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _BlankBox(
              fontSize: effective.fontSize ?? 14,
              color: effective.color ?? context.tokens.ink,
            ),
          ),
        if (parts[i].isNotEmpty) TextSpan(text: parts[i]),
      ],
    ],
  );
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

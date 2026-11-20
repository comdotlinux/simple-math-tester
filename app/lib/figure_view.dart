import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'figure.dart';
import 'l10n/app_localizations.dart';

/// The height of the figure in the question card; the width is the card's.
double figureHeight({required bool compact}) => compact ? 150 : 210;

/// The colours a figure is drawn with, all theme roles: labels in ink on
/// the card, the outline in the outline colour, the area shaded with muted
/// ink and its grid in the card colour over it.
({Color label, Color line, Color shade, Color grid, Color card}) figureColors(
  AppTokens tokens,
) => (
  label: tokens.ink,
  line: tokens.outline,
  shade: tokens.inkMuted,
  grid: tokens.surfaceRaised,
  card: tokens.surfaceRaised,
);

/// The drawn size of [text] in [style] under [scaler].
Size measureLabel(String text, TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

/// The text form of [figure]: the shape, every label and what is asked,
/// such as "Rectangle, sides 5 and 3. Perimeter?". Read from the labels
/// themselves, so it says what the figure shows. Also the figure's
/// semantics label and the line in the history.
String figureSentence(AppLocalizations l, Figure figure) {
  final sides = [for (final label in figure.labels) label.text];
  final shape = switch (figure.shape) {
    FigureShape.square => l.figureSquare(sides[0]),
    FigureShape.rectangle => l.figureRectangle(sides[0], sides[1]),
    FigureShape.triangle => l.figureTriangle(sides[0], sides[1], sides[2]),
  };
  return l.figureQuestion(shape, figurePromptText(l, figure.prompt));
}

/// The short line under the figure, such as "Perimeter?".
String figurePromptText(AppLocalizations l, FigurePrompt prompt) =>
    switch (prompt) {
      FigurePrompt.perimeter => l.figurePerimeter,
      FigurePrompt.area => l.figureArea,
    };

/// [figure] drawn to scale over the available width, [height] tall, with
/// its labels in the theme's label style under the system text scale.
class FigureView extends StatelessWidget {
  const FigureView({
    super.key,
    required this.figure,
    required this.height,
    required this.semanticsLabel,
  });

  final Figure figure;
  final double height;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    final colors = figureColors(context.tokens);
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = layoutFigure(
              figure,
              Size(constraints.maxWidth, height),
              (text) => measureLabel(text, style, scaler),
            );
            return CustomPaint(
              size: Size(constraints.maxWidth, height),
              painter: FigurePainter(layout, colors, style, scaler),
            );
          },
        ),
      ),
    );
  }
}

/// Draws exactly what a [FigureLayout] says.
class FigurePainter extends CustomPainter {
  FigurePainter(this.layout, this.colors, this.style, this.scaler);

  final FigureLayout layout;
  final ({Color label, Color line, Color shade, Color grid, Color card}) colors;
  final TextStyle style;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()..addPolygon(layout.vertices, true);
    if (layout.shaded) {
      canvas.drawPath(outline, Paint()..color = colors.shade);
    }
    final grid = Paint()
      ..color = colors.grid
      ..strokeWidth = 2;
    for (final (from, to) in layout.gridLines) {
      canvas.drawLine(from, to, grid);
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = colors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = layout.strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
    for (final label in layout.labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: style.copyWith(color: colors.label),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      painter.paint(
        canvas,
        label.box.center - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(FigurePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.colors != colors ||
      oldDelegate.style != style ||
      oldDelegate.scaler != scaler;
}

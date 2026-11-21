import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'figure.dart';
import 'l10n/app_localizations.dart';

/// The height of the figure in the question card; the width is the card's.
double figureHeight({required bool compact}) => compact ? 150 : 210;

typedef FigureColors = ({
  Color label,
  Color line,
  Color shade,
  Color grid,
  Color card,
});

/// The colours a figure is drawn with, all theme roles: labels in ink on
/// the card, the outline in the outline colour, the area shaded with muted
/// ink and its grid in the card colour over it.
FigureColors figureColors(AppTokens tokens) => (
  label: tokens.ink,
  line: tokens.outline,
  shade: tokens.inkMuted,
  grid: tokens.surfaceRaised,
  card: tokens.surfaceRaised,
);

/// Angle marks, a circle's radius or diameter and its centre: in the
/// outline colour on the card, in the grid colour on a shaded inside.
Color markColor(FigureColors colors, {required bool shaded}) =>
    shaded ? colors.grid : colors.line;

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
    final localeName = AppLocalizations.of(context).localeName;
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
              localeName: localeName,
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
  final FigureColors colors;
  final TextStyle style;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final circle = layout.circle;
    final outline = Path();
    if (circle != null) {
      outline.addOval(circle);
    } else if (layout.rays) {
      for (final end in layout.vertices.skip(1)) {
        outline
          ..moveTo(layout.vertices[0].dx, layout.vertices[0].dy)
          ..lineTo(end.dx, end.dy);
      }
    } else {
      outline.addPolygon(layout.vertices, true);
    }
    if (layout.diagonal case (final from, final to)) {
      outline
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
    }
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
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final marks = Paint()
      ..color = markColor(colors, shaded: layout.shaded)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thinStroke;
    if (circle != null) {
      canvas
        ..drawLine(layout.vertices[0], layout.vertices[1], marks)
        ..drawCircle(circle.center, thinStroke, Paint()..color = marks.color);
    }
    for (final mark in layout.marks) {
      if (mark.right) {
        final along = Offset.fromDirection(mark.from, mark.radius);
        final across = Offset.fromDirection(
          mark.from + mark.sweep,
          mark.radius,
        );
        final c = mark.centre;
        canvas.drawPath(
          Path()
            ..moveTo((c + along).dx, (c + along).dy)
            ..lineTo((c + along + across).dx, (c + along + across).dy)
            ..lineTo((c + across).dx, (c + across).dy),
          marks,
        );
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: mark.centre, radius: mark.radius),
          mark.from,
          mark.sweep,
          false,
          marks,
        );
      }
    }
    // Each label on a patch of the card, so it reads also on a shaded
    // inside; the boxes never touch an outline.
    final patch = Paint()..color = colors.card;
    for (final label in layout.labels) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(label.box, const Radius.circular(4)),
        patch,
      );
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

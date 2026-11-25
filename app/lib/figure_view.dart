import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'digits.dart';
import 'figure.dart';
import 'l10n/app_localizations.dart';

/// The height of the figure in the question card at text scale 1; the
/// width is the card's. [FigureView] grows it with the text scale
/// ([figureCanvasHeight]).
double figureHeight({required bool compact}) => compact ? 150 : 210;

/// [height] grown by what a label line in [style] gains under [scaler],
/// once above the figure and once below it, so larger text gets a taller
/// canvas instead of a smaller figure.
double figureCanvasHeight(double height, TextStyle style, TextScaler scaler) {
  final size = style.fontSize!;
  return height + 2 * (scaler.scale(size) - size) * (style.height ?? 1);
}

typedef FigureColors = ({
  Color label,
  Color line,
  Color shade,
  Color grid,
  Color card,
  Color highlight,
  Color highlightEdge,
});

/// The colours a figure is drawn with, all theme roles: labels in ink on
/// the card, the outline in the outline colour, the area shaded with muted
/// ink and its grid in the card colour over it. A part a hint step uses is
/// highlighted in the accent colour edged with the colour drawn on the
/// accent, like the app's buttons.
FigureColors figureColors(AppTokens tokens) => (
  label: tokens.ink,
  line: tokens.outline,
  shade: tokens.inkMuted,
  grid: tokens.surfaceRaised,
  card: tokens.surfaceRaised,
  highlight: tokens.primary,
  highlightEdge: tokens.onPrimary,
);

/// Angle marks, a circle's radius or diameter and its centre: in the
/// outline colour on the card, in the grid colour on a shaded inside.
Color markColor(FigureColors colors, {required bool shaded}) =>
    shaded ? colors.grid : colors.line;

/// A highlighted line: an accent core this wide inside an edge of
/// [highlightEdgeWidth] on each side, wider than the thick outline.
const highlightCore = 7.0;
const highlightEdgeWidth = 3.0;

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

/// What a [FigurePainter] highlights, as indices into a [FigureLayout]:
/// edges, labels, angle marks and grid rows, the outline and the inside.
typedef FigureHighlight = ({
  Set<int> edges,
  Set<int> labels,
  Set<int> marks,
  Set<int> rows,
  bool outline,
  bool inside,
  bool diagonal,
});

/// [parts] of [figure] as indices into its layout: labels are the side
/// labels, a diagonal's `?`, then the angle labels; marks are the angle
/// arcs, then a right-angle square.
FigureHighlight highlightOf(Figure figure, FigureParts parts) => (
  edges: parts.edges,
  labels: {
    for (final (i, label) in figure.labels.indexed)
      if (parts.edges.contains(label.edge)) i,
    if (parts.diagonal && figure.diagonal) figure.labels.length,
    for (final (i, angle) in figure.angles.indexed)
      if (parts.angles.contains(angle.corner))
        figure.labels.length + (figure.diagonal ? 1 : 0) + i,
  },
  marks: {
    for (final (i, angle) in figure.angles.indexed)
      if (parts.angles.contains(angle.corner)) i,
    if (parts.rightAngle) figure.angles.length,
  },
  rows: parts.rows,
  outline: parts.outline,
  inside: parts.inside,
  diagonal: parts.diagonal,
);

/// [figure] drawn to scale over the available width, [height] tall at text
/// scale 1 and taller at larger text ([figureCanvasHeight]), with its
/// labels in the theme's label style under the system text scale, and the
/// [highlight] parts a hint step uses in the accent colour.
class FigureView extends StatelessWidget {
  const FigureView({
    super.key,
    required this.figure,
    required this.height,
    required this.semanticsLabel,
    this.highlight,
  });

  final Figure figure;
  final double height;
  final String semanticsLabel;
  final FigureParts? highlight;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    final colors = figureColors(context.tokens);
    final localeName = AppLocalizations.of(context).localeName;
    final parts = highlight;
    final height = figureCanvasHeight(this.height, style, scaler);
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
              digits: digitsLanguage(localeName),
            );
            return CustomPaint(
              size: Size(constraints.maxWidth, height),
              painter: FigurePainter(
                layout,
                colors,
                style,
                scaler,
                parts == null ? null : highlightOf(figure, parts),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Draws exactly what a [FigureLayout] says, and the [highlight] over it.
class FigurePainter extends CustomPainter {
  FigurePainter(
    this.layout,
    this.colors,
    this.style,
    this.scaler, [
    this.highlight,
  ]);

  final FigureLayout layout;
  final FigureColors colors;
  final TextStyle style;
  final TextScaler scaler;
  final FigureHighlight? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final circle = layout.circle;
    final outline = Path();
    final corners = layout.vertices;
    if (circle != null) outline.addOval(circle);
    if (layout.rays) {
      for (final end in corners.skip(1)) {
        outline
          ..moveTo(corners[0].dx, corners[0].dy)
          ..lineTo(end.dx, end.dy);
      }
    } else if (circle == null || corners.length > 2) {
      // One closed outline, or separate lines or triangles.
      final piece = layout.piece ?? corners.length;
      for (var i = 0; i < corners.length; i += piece) {
        outline.addPolygon(corners.sublist(i, i + piece), piece > 2);
      }
    }
    for (final (from, to) in [?layout.diagonal, ?layout.extension]) {
      outline
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
    }
    final lit = highlight;
    if (lit != null && lit.inside) {
      canvas.drawPath(outline, Paint()..color = colors.highlight);
    } else if (layout.shaded) {
      canvas.drawPath(outline, Paint()..color = colors.shade);
    }
    // On a highlighted inside the grid takes the edge colour, which reads
    // on the accent.
    final grid = Paint()
      ..color = lit != null && lit.inside ? colors.highlightEdge : colors.grid
      ..strokeWidth = 2;
    for (final (from, to) in layout.gridLines) {
      canvas.drawLine(from, to, grid);
    }
    if (lit != null && lit.rows.isNotEmpty) _paintRows(canvas, lit.rows);
    canvas.drawPath(
      outline,
      Paint()
        ..color = colors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = layout.strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    if (lit != null) {
      final band = Path();
      if (lit.outline) band.addPath(outline, Offset.zero);
      for (final edge in lit.edges) {
        final (from, to) = layout.rays
            ? (corners[0], corners[edge + 1])
            : switch (edgeEnds(edge, corners.length, layout.piece)) {
                (final a, final b) => (corners[a], corners[b]),
              };
        band
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy);
      }
      if (layout.diagonal case (final from, final to) when lit.diagonal) {
        band
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy);
      }
      _paintBand(canvas, band);
    }
    final marks = Paint()
      ..color = markColor(colors, shaded: layout.shaded)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thinStroke;
    if (circle != null) {
      // A highlighted radius or diameter is already drawn as a band; a
      // triangle in a circle draws its sides with the outline.
      if (corners.length == 2 && !(lit?.edges.contains(0) ?? false)) {
        canvas.drawLine(layout.vertices[0], layout.vertices[1], marks);
      }
      canvas.drawCircle(
        circle.center,
        thinStroke,
        Paint()..color = marks.color,
      );
    }
    for (final (from, to) in layout.ticks) {
      canvas.drawLine(from, to, marks);
    }
    // An arrowhead at the tip, its wings reaching back to the tail.
    for (final (tail, tip) in layout.arrows) {
      final across = Offset(tail.dy - tip.dy, tip.dx - tail.dx) * .5;
      canvas.drawPath(
        Path()
          ..moveTo((tail + across).dx, (tail + across).dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo((tail - across).dx, (tail - across).dy),
        Paint()
          ..color = marks.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thinStroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final (i, mark) in layout.marks.indexed) {
      final Path path;
      if (mark.right) {
        final along = Offset.fromDirection(mark.from, mark.radius);
        final across = Offset.fromDirection(
          mark.from + mark.sweep,
          mark.radius,
        );
        final c = mark.centre;
        path = Path()
          ..moveTo((c + along).dx, (c + along).dy)
          ..lineTo((c + along + across).dx, (c + along + across).dy)
          ..lineTo((c + across).dx, (c + across).dy);
      } else {
        path = Path()
          ..addArc(
            Rect.fromCircle(center: mark.centre, radius: mark.radius),
            mark.from,
            mark.sweep,
          );
      }
      if (lit != null && lit.marks.contains(i)) {
        _paintBand(canvas, path, core: thinStroke);
      } else {
        canvas.drawPath(path, marks);
      }
    }
    // Each label on a patch of the card, so it reads also on a shaded
    // inside; the boxes never touch an outline. A highlighted label stands
    // on an accent patch with an edge, in the colour drawn on the accent.
    for (final (i, label) in layout.labels.indexed) {
      final on = lit != null && lit.labels.contains(i);
      final box = RRect.fromRectAndRadius(label.box, const Radius.circular(4));
      canvas.drawRRect(
        box,
        Paint()..color = on ? colors.highlight : colors.card,
      );
      if (on) {
        canvas.drawRRect(
          box,
          Paint()
            ..color = colors.highlightEdge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      final painter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: style.copyWith(
            color: on ? colors.highlightEdge : colors.label,
          ),
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

  /// [path] as an accent band edged on both sides.
  void _paintBand(Canvas canvas, Path path, {double core = highlightCore}) {
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        path,
        stroke(colors.highlightEdge, core + 2 * highlightEdgeWidth),
      )
      ..drawPath(path, stroke(colors.highlight, core));
  }

  /// Grid [rows] from the top filled with the accent, their squares edged.
  void _paintRows(Canvas canvas, Set<int> rows) {
    final xs = layout.vertices.map((v) => v.dx);
    final ys = layout.vertices.map((v) => v.dy);
    final left = xs.reduce((a, b) => a < b ? a : b);
    final right = xs.reduce((a, b) => a > b ? a : b);
    final top = ys.reduce((a, b) => a < b ? a : b);
    final bottom = ys.reduce((a, b) => a > b ? a : b);
    // The inner lines across are the horizontal ones; the rest go down.
    final across = layout.gridLines.where((l) => l.$1.dy == l.$2.dy).length;
    final down = layout.gridLines.where((l) => l.$1.dx == l.$2.dx);
    final height = (bottom - top) / (across + 1);
    final edge = Paint()
      ..color = colors.highlightEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final row in rows) {
      final band = Rect.fromLTRB(
        left,
        top + row * height,
        right,
        top + (row + 1) * height,
      );
      canvas
        ..drawRect(band, Paint()..color = colors.highlight)
        ..drawRect(band, edge);
      for (final (from, _) in down) {
        canvas.drawLine(
          Offset(from.dx, band.top),
          Offset(from.dx, band.bottom),
          edge,
        );
      }
    }
  }

  @override
  bool shouldRepaint(FigurePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.colors != colors ||
      oldDelegate.style != style ||
      oldDelegate.scaler != scaler ||
      oldDelegate.highlight != highlight;
}

import 'dart:math';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

/// The shapes a [Figure] can be. A later shape (right triangle, L-shape,
/// angle, circle) is a new value here plus its own branch in the oracle;
/// polygons need nothing else, because [Figure] stores any corner list.
enum FigureShape { square, rectangle, triangle }

/// What a figure asks for, and so which language-free cue it carries: a
/// thick outline for the perimeter, a shaded inside for the area.
enum FigurePrompt { perimeter, area }

/// A length written next to one edge: the edge from corner [edge] to the
/// next corner. [hundredths] is the length in hundredths of a unit; null
/// shows the asked side as `?`.
@immutable
class SideLabel {
  const SideLabel(this.edge, this.hundredths);

  final int edge;
  final int? hundredths;

  /// The text drawn, such as "5", "2.5" or "?".
  // shortcut: '.' is the only decimal separator; per-language separators
  // come with the levels that show decimals (#123).
  String get text {
    final value = hundredths;
    if (value == null) return '?';
    if (value % 100 == 0) return '${value ~/ 100}';
    final cents = (value.abs() % 100).toString().padLeft(2, '0');
    return '${value ~/ 100}.${cents.endsWith('0') ? cents[0] : cents}';
  }

  @override
  bool operator ==(Object other) =>
      other is SideLabel &&
      other.edge == edge &&
      other.hundredths == hundredths;

  @override
  int get hashCode => Object.hash(edge, hundredths);

  @override
  String toString() => 'SideLabel($edge, $text)';
}

/// A figure to scale, as data: the corners in model units (one unit is
/// one length unit of the labels), the labels, an optional unit grid and
/// what is asked. Squares and rectangles have whole-number corners; a
/// triangle's corners are computed from its three whole sides, so their
/// distances match the labels to rounding.
@immutable
class Figure {
  const Figure({
    required this.shape,
    required this.vertices,
    required this.labels,
    required this.prompt,
    this.grid = false,
  });

  final FigureShape shape;

  /// Corners in drawing order with y pointing down; edge i runs from corner
  /// i to corner i + 1, and the last edge closes the shape.
  final List<Offset> vertices;
  final List<SideLabel> labels;
  final FigurePrompt prompt;

  /// Unit squares drawn inside, so a child can count the area. Only for a
  /// shape whose edges are all horizontal or vertical.
  final bool grid;

  @override
  bool operator ==(Object other) =>
      other is Figure &&
      other.shape == shape &&
      listEquals(other.vertices, vertices) &&
      listEquals(other.labels, labels) &&
      other.prompt == prompt &&
      other.grid == grid;

  @override
  int get hashCode => Object.hash(
    shape,
    Object.hashAll(vertices),
    Object.hashAll(labels),
    prompt,
    grid,
  );
}

/// A label's text and the box it is drawn in, in canvas pixels.
@immutable
class PlacedLabel {
  const PlacedLabel(this.text, this.box);

  final String text;
  final Rect box;
}

/// Everything a painter draws, in canvas pixels: what the child sees.
@immutable
class FigureLayout {
  const FigureLayout({
    required this.vertices,
    required this.labels,
    required this.grid,
    required this.gridLines,
    required this.strokeWidth,
    required this.shaded,
  });

  /// The corners, scaled uniformly from the model, so the drawing is to
  /// scale.
  final List<Offset> vertices;
  final List<PlacedLabel> labels;

  /// Whether a unit grid is drawn; a single unit square has no inner lines.
  final bool grid;

  /// The inner lines of the unit grid, each from one edge to the opposite.
  final List<(Offset, Offset)> gridLines;
  final double strokeWidth;

  /// Whether the inside is filled.
  final bool shaded;
}

/// The outline widths: thick is the perimeter cue.
const thinStroke = 3.0;
const thickStroke = 7.0;

/// Room around a label's text inside its box, between the box and the
/// outline, and between the figure and the canvas edge.
const labelPadding = 3.0;
const labelGap = 4.0;
const canvasMargin = 4.0;

/// Fits [figure] into [canvas]: one uniform scale for the whole figure, as
/// large as fits with every label box outside its own edge and inside the
/// canvas. [measure] gives the drawn size of a label's text.
FigureLayout layoutFigure(
  Figure figure,
  Size canvas,
  Size Function(String text) measure,
) {
  final stroke = figure.prompt == FigurePrompt.perimeter
      ? thickStroke
      : thinStroke;
  final model = figure.vertices;
  final count = model.length;
  var twiceArea = 0.0;
  for (var i = 0; i < count; i++) {
    final (a, b) = (model[i], model[(i + 1) % count]);
    twiceArea += a.dx * b.dy - b.dx * a.dy;
  }
  // Each point is placed at s * at + shift, inside a half-size of half.
  final points = <({Offset at, Offset shift, Size half})>[
    for (final v in model)
      (at: v, shift: Offset.zero, half: Size(stroke / 2, stroke / 2)),
  ];
  for (final label in figure.labels) {
    final (a, b) = (model[label.edge], model[(label.edge + 1) % count]);
    final along = b - a;
    var normal = Offset(along.dy, -along.dx) / along.distance;
    // With y down a positive area means corners run clockwise on screen,
    // where this normal points out of the shape.
    if (twiceArea < 0) normal = -normal;
    final text = measure(label.text);
    final half = Size(
      text.width / 2 + labelPadding,
      text.height / 2 + labelPadding,
    );
    final reach = half.width * normal.dx.abs() + half.height * normal.dy.abs();
    points.add((
      at: (a + b) / 2,
      shift: normal * (stroke / 2 + labelGap + reach),
      half: half,
    ));
  }

  Rect bounds(double scale) {
    var rect = Rect.zero;
    var first = true;
    for (final p in points) {
      final box = Rect.fromCenter(
        center: p.at * scale + p.shift,
        width: p.half.width * 2,
        height: p.half.height * 2,
      );
      rect = first ? box : rect.expandToInclude(box);
      first = false;
    }
    return rect;
  }

  bool fits(double scale) {
    final rect = bounds(scale);
    return rect.width <= canvas.width - 2 * canvasMargin &&
        rect.height <= canvas.height - 2 * canvasMargin;
  }

  var low = 0.0;
  var high = max(canvas.width, canvas.height);
  for (var i = 0; i < 40; i++) {
    final mid = (low + high) / 2;
    if (fits(mid)) {
      low = mid;
    } else {
      high = mid;
    }
  }
  final scale = low;
  final rect = bounds(scale);
  final origin = Offset(
    (canvas.width - rect.width) / 2 - rect.left,
    (canvas.height - rect.height) / 2 - rect.top,
  );
  Offset place(Offset at) => origin + at * scale;

  final gridLines = <(Offset, Offset)>[];
  if (figure.grid) {
    assert(
      figure.shape == FigureShape.square ||
          figure.shape == FigureShape.rectangle,
    );
    // shortcut: the grid fills the bounding box, right only for squares and
    // rectangles; an L-shape (#123) needs the lines clipped to the shape.
    final xs = model.map((v) => v.dx);
    final ys = model.map((v) => v.dy);
    final (left, right) = (xs.reduce(min), xs.reduce(max));
    final (top, bottom) = (ys.reduce(min), ys.reduce(max));
    for (var x = left + 1; x < right; x++) {
      gridLines.add((place(Offset(x, top)), place(Offset(x, bottom))));
    }
    for (var y = top + 1; y < bottom; y++) {
      gridLines.add((place(Offset(left, y)), place(Offset(right, y))));
    }
  }

  return FigureLayout(
    vertices: [for (final v in model) place(v)],
    labels: [
      for (final (i, label) in figure.labels.indexed)
        PlacedLabel(
          label.text,
          Rect.fromCenter(
            center: place(points[count + i].at) + points[count + i].shift,
            width: points[count + i].half.width * 2,
            height: points[count + i].half.height * 2,
          ),
        ),
    ],
    grid: figure.grid,
    gridLines: gridLines,
    strokeWidth: stroke,
    shaded: figure.prompt == FigurePrompt.area,
  );
}

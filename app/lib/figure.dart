import 'dart:math';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import 'hundredths.dart';

/// The shapes a [Figure] can be; each has its own branch in the oracle.
/// Polygons store their corners; a [rightTriangle] has its right angle at
/// corner 0. [straightAngle] and [rightAngle] are rays from corner 0 to the
/// other corners, in turning order. A [circle] stores the drawn radius or
/// diameter as its two corners, and its [Figure.centre].
enum FigureShape {
  square,
  rectangle,
  triangle,
  rightTriangle,
  lShape,
  straightAngle,
  rightAngle,
  circle,
}

/// What a figure asks for, and so which language-free cue it carries: a
/// thick outline for a perimeter or circumference (also when the perimeter
/// is given and a side is asked), a shaded inside for an area. An asked
/// side or angle carries a `?`; [angle] figures are thin and unshaded, with
/// an arc at every labelled angle.
enum FigurePrompt {
  perimeter,
  area,
  sideFromPerimeter,
  sideFromArea,
  angle,
  circumference,
}

/// A length written next to one edge: the edge from corner [edge] to the
/// next corner. [hundredths] is the length in hundredths of a unit; null
/// shows the asked side as `?`.
@immutable
class SideLabel {
  const SideLabel(this.edge, this.hundredths);

  final int edge;
  final int? hundredths;

  /// The text drawn, such as "5", "2.5" (in German "2,5") or "?".
  String text([String localeName = 'en']) => switch (hundredths) {
    final value? => formatHundredths(value, localeName),
    null => '?',
  };

  @override
  bool operator ==(Object other) =>
      other is SideLabel &&
      other.edge == edge &&
      other.hundredths == hundredths;

  @override
  int get hashCode => Object.hash(edge, hundredths);

  @override
  String toString() => 'SideLabel($edge, ${text()})';
}

/// An angle in whole degrees, null for the asked one (`?`). On a polygon
/// [corner] is the corner whose inside angle it is; on rays it is the
/// angle from the ray to corner [corner] to the ray to the next corner.
@immutable
class AngleLabel {
  const AngleLabel(this.corner, this.degrees);

  final int corner;
  final int? degrees;

  /// The text drawn, such as "50°" or "?".
  String get text => switch (degrees) {
    final value? => '$value°',
    null => '?',
  };

  @override
  bool operator ==(Object other) =>
      other is AngleLabel && other.corner == corner && other.degrees == degrees;

  @override
  int get hashCode => Object.hash(corner, degrees);

  @override
  String toString() => 'AngleLabel($corner, $text)';
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
    this.angles = const [],
    this.centre,
    this.total,
    this.pi,
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

  /// The angle labels; each angle is drawn with an arc.
  final List<AngleLabel> angles;

  /// A circle's centre; the circle passes through the farther corner.
  final Offset? centre;

  /// The given perimeter or area in hundredths, when a side is asked.
  final int? total;

  /// The value of π to use in hundredths, for a circle.
  final int? pi;

  @override
  bool operator ==(Object other) =>
      other is Figure &&
      other.shape == shape &&
      listEquals(other.vertices, vertices) &&
      listEquals(other.labels, labels) &&
      other.prompt == prompt &&
      other.grid == grid &&
      listEquals(other.angles, angles) &&
      other.centre == centre &&
      other.total == total &&
      other.pi == pi;

  @override
  int get hashCode => Object.hash(
    shape,
    Object.hashAll(vertices),
    Object.hashAll(labels),
    prompt,
    grid,
    Object.hashAll(angles),
    centre,
    total,
    pi,
  );
}

/// A label's text and the box it is drawn in, in canvas pixels.
@immutable
class PlacedLabel {
  const PlacedLabel(this.text, this.box);

  final String text;
  final Rect box;
}

/// An angle mark at [centre]: an arc of [radius] from the direction [from]
/// (radians, clockwise on screen from the x axis) over [sweep], or for a
/// [right] angle a small square of side [radius] in that corner.
@immutable
class AngleMark {
  const AngleMark(
    this.centre,
    this.radius,
    this.from,
    this.sweep, {
    this.right = false,
  });

  final Offset centre;
  final double radius;
  final double from;
  final double sweep;
  final bool right;
}

/// Everything a painter draws, in canvas pixels: what the child sees. The
/// given [total] and [pi] are shown in the prompt line under the figure.
@immutable
class FigureLayout {
  const FigureLayout({
    required this.vertices,
    required this.labels,
    required this.grid,
    required this.gridLines,
    required this.strokeWidth,
    required this.shaded,
    this.marks = const [],
    this.rays = false,
    this.circle,
    this.total,
    this.pi,
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

  /// Angle arcs and right-angle squares.
  final List<AngleMark> marks;

  /// Whether the edges are rays from the first corner to each other one
  /// instead of a closed outline.
  final bool rays;

  /// The circle's bounding square; its outline is the circle and the
  /// corners are the drawn radius or diameter.
  final Rect? circle;

  /// The given perimeter or area, and π, as the prompt line shows them.
  final String? total;
  final String? pi;
}

/// The outline widths: thick is the perimeter cue.
const thinStroke = 3.0;
const thickStroke = 7.0;

/// Room around a label's text inside its box, between the box and the
/// outline, and between the figure and the canvas edge.
const labelPadding = 3.0;
const labelGap = 4.0;
const canvasMargin = 4.0;

/// The largest angle arc, and the share of the shorter neighbouring edge
/// it may take.
const arcRadius = 24.0;
const arcShare = .3;

/// Fits [figure] into [canvas]: one uniform scale for the whole figure, as
/// large as fits with every label box outside its own edge and inside the
/// canvas. [measure] gives the drawn size of a label's text; numbers are
/// written in the language [localeName].
FigureLayout layoutFigure(
  Figure figure,
  Size canvas,
  Size Function(String text) measure, {
  String localeName = 'en',
}) {
  final stroke = switch (figure.prompt) {
    FigurePrompt.perimeter ||
    FigurePrompt.sideFromPerimeter ||
    FigurePrompt.circumference => thickStroke,
    _ => thinStroke,
  };
  final shaded = switch (figure.prompt) {
    FigurePrompt.area || FigurePrompt.sideFromArea => true,
    _ => false,
  };
  final model = figure.vertices;
  final count = model.length;
  final rays =
      figure.shape == FigureShape.straightAngle ||
      figure.shape == FigureShape.rightAngle;
  final centre = figure.centre;
  final radius = centre == null
      ? 0.0
      : model.map((v) => (v - centre).distance).reduce(max);
  var twiceArea = 0.0;
  for (var i = 0; i < count; i++) {
    final (a, b) = (model[i], model[(i + 1) % count]);
    twiceArea += a.dx * b.dy - b.dx * a.dy;
  }
  Offset unit(Offset o) => o / o.distance;
  Size boxOf(String text) {
    final size = measure(text);
    return Size(size.width / 2 + labelPadding, size.height / 2 + labelPadding);
  }

  // How far a box of half-size [half] reaches in the unit direction [n].
  double reach(Size half, Offset n) =>
      half.width * n.dx.abs() + half.height * n.dy.abs();

  // Each point is placed at s * at + shift, inside a half-size of half.
  final points = <({Offset at, Offset shift, Size half})>[
    if (centre == null)
      for (final v in model)
        (at: v, shift: Offset.zero, half: Size(stroke / 2, stroke / 2))
    else
      for (final d in const [
        Offset(1, 0),
        Offset(0, 1),
        Offset(-1, 0),
        Offset(0, -1),
      ])
        (
          at: centre + d * radius,
          shift: Offset.zero,
          half: Size(stroke / 2, stroke / 2),
        ),
  ];
  final first = points.length;
  final texts = <String>[];
  final xs = model.map((v) => v.dx);
  final ys = model.map((v) => v.dy);
  for (final label in figure.labels) {
    final (a, b) = (model[label.edge], model[(label.edge + 1) % count]);
    final along = b - a;
    var normal = Offset(along.dy, -along.dx) / along.distance;
    // With y down a positive area means corners run clockwise on screen,
    // where this normal points out of the shape.
    if (twiceArea < 0) normal = -normal;
    final text = label.text(localeName);
    final half = boxOf(text);
    texts.add(text);
    var at = (a + b) / 2;
    if (centre != null) {
      // Inside a circle the label stands over the radius near the centre,
      // or over the middle of the diameter, where it has the most room.
      at = a + along * (a == centre ? .15 : .5);
    } else if (normal.dx == 0 || normal.dy == 0) {
      // The label of an edge inside a notch stands outside the shape's
      // bounding box, straight out from its edge; elsewhere this changes
      // nothing.
      at = Offset(
        switch (normal.dx) {
          > 0 => xs.reduce(max),
          < 0 => xs.reduce(min),
          _ => at.dx,
        },
        switch (normal.dy) {
          > 0 => ys.reduce(max),
          < 0 => ys.reduce(min),
          _ => at.dy,
        },
      );
    }
    points.add((
      at: at,
      shift: normal * (stroke / 2 + labelGap + reach(half, normal)),
      half: half,
    ));
  }
  for (final angle in figure.angles) {
    final text = angle.text;
    final half = boxOf(text);
    texts.add(text);
    if (rays) {
      // Beyond the ray tips on the bisector, so it touches no ray.
      final o = model[0];
      final (a, b) = (model[angle.corner], model[angle.corner + 1]);
      final bisector = unit(unit(a - o) + unit(b - o));
      points.add((
        at: o + bisector * (a - o).distance,
        shift: bisector * (stroke / 2 + labelGap + reach(half, bisector)),
        half: half,
      ));
    } else {
      // Outside the corner, opposite the inside bisector, so it touches no
      // edge of the convex shape.
      final v = model[angle.corner];
      final prev = model[(angle.corner + count - 1) % count];
      final next = model[(angle.corner + 1) % count];
      final out = -unit(unit(prev - v) + unit(next - v));
      points.add((
        at: v,
        shift: out * (stroke / 2 + labelGap + reach(half, out)),
        half: half,
      ));
    }
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
    // rectangles; an L-shape needs the lines clipped to the shape.
    final (left, right) = (xs.reduce(min), xs.reduce(max));
    final (top, bottom) = (ys.reduce(min), ys.reduce(max));
    for (var x = left + 1; x < right; x++) {
      gridLines.add((place(Offset(x, top)), place(Offset(x, bottom))));
    }
    for (var y = top + 1; y < bottom; y++) {
      gridLines.add((place(Offset(left, y)), place(Offset(right, y))));
    }
  }

  // An arc between the directions to [a] and [b] seen from [v], on the
  // inside (the smaller turn), sized to the shorter of the two edges.
  AngleMark mark(Offset v, Offset a, Offset b, {bool right = false}) {
    final (pv, pa, pb) = (place(v), place(a), place(b));
    final from = atan2(pa.dy - pv.dy, pa.dx - pv.dx);
    var sweep = atan2(pb.dy - pv.dy, pb.dx - pv.dx) - from;
    if (sweep > pi) sweep -= 2 * pi;
    if (sweep < -pi) sweep += 2 * pi;
    final size = min(
      arcRadius,
      arcShare * min((pa - pv).distance, (pb - pv).distance),
    );
    // A right-angle square fits inside the arcs around the same corner.
    return AngleMark(pv, right ? size * .55 : size, from, sweep, right: right);
  }

  final marks = <AngleMark>[
    for (final angle in figure.angles)
      if (rays)
        mark(model[0], model[angle.corner], model[angle.corner + 1])
      else
        mark(
          model[angle.corner],
          model[(angle.corner + count - 1) % count],
          model[(angle.corner + 1) % count],
        ),
    if (figure.shape == FigureShape.rightAngle)
      mark(model[0], model[1], model[count - 1], right: true),
    if (figure.shape == FigureShape.rightTriangle)
      mark(model[0], model[count - 1], model[1], right: true),
  ];

  return FigureLayout(
    vertices: [for (final v in model) place(v)],
    labels: [
      for (final (i, text) in texts.indexed)
        PlacedLabel(
          text,
          Rect.fromCenter(
            center: place(points[first + i].at) + points[first + i].shift,
            width: points[first + i].half.width * 2,
            height: points[first + i].half.height * 2,
          ),
        ),
    ],
    grid: figure.grid,
    gridLines: gridLines,
    strokeWidth: stroke,
    shaded: shaded,
    marks: marks,
    rays: rays,
    circle: centre == null
        ? null
        : Rect.fromCircle(center: place(centre), radius: radius * scale),
    total: switch (figure.total) {
      final total? => formatHundredths(total, localeName),
      null => null,
    },
    pi: switch (figure.pi) {
      final value? => formatHundredths(value, localeName),
      null => null,
    },
  );
}

import 'dart:math';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import 'hundredths.dart';

/// The shapes a [Figure] can be; each has its own branch in the oracle.
/// Polygons store their corners; a [rightTriangle] has its right angle at
/// corner 0. [straightAngle], [rightAngle], [crossingLines] (two straight
/// lines crossing at corner 0) and [aroundPoint] (rays all the way round)
/// are rays from corner 0 to the other corners, in turning order. A
/// [circle] stores the drawn radius or diameter as its two corners, and its
/// [Figure.centre]. A [quadrilateral] is any convex four-sided shape.
enum FigureShape {
  square,
  rectangle,
  triangle,
  rightTriangle,
  lShape,
  straightAngle,
  rightAngle,
  circle,
  crossingLines,
  aroundPoint,
  quadrilateral,
}

/// What a figure asks for, and so which language-free cue it carries: a
/// thick outline for a perimeter or circumference (also when the perimeter
/// is given and a side is asked), a shaded inside for an area. An asked
/// side or angle carries a `?`; [angle] figures are thin and unshaded, with
/// an arc at every labelled angle. [length] asks a side or diagonal marked
/// `?` from the other labels (Pythagoras' theorem); thin and unshaded.
enum FigurePrompt {
  perimeter,
  area,
  sideFromPerimeter,
  sideFromArea,
  angle,
  circumference,
  length,
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
/// [corner] is the corner whose inside angle it is, and one past the last
/// corner the outside angle at a [Figure.extension]; on rays it is the
/// angle from the ray to corner [corner] to the ray to the next corner
/// (after the last ray comes the first again, see [nextRay]).
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

/// The corner of the ray after the ray to [corner], turning the same way,
/// among rays from corner 0 to the other [count] - 1 corners.
int nextRay(int corner, int count) => corner % (count - 1) + 1;

/// The corner where two ticked [edges] of a shape with [count] corners
/// meet: the top of an isosceles triangle.
int tickedTop(List<int> edges, int count) {
  final [e, f] = edges;
  return (e + 1) % count == f ? f : e;
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
    this.diagonal = false,
    this.extension,
    this.ticks = const [],
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

  /// A rectangle's diagonal from corner 0 to corner 2, drawn and marked
  /// `?` (it is always the asked length).
  final bool diagonal;

  /// The end of the side from corner 0 to the last corner, drawn on past
  /// the last corner. The outside angle there lies between this line and
  /// the side to the corner before the last.
  final Offset? extension;

  /// The edges that carry a tick mark across their middle: equal sides.
  final List<int> ticks;

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
      other.pi == pi &&
      other.diagonal == diagonal &&
      other.extension == extension &&
      listEquals(other.ticks, ticks);

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
    diagonal,
    extension,
    Object.hashAll(ticks),
  );
}

/// The parts of a [Figure] one hint step uses, which the figure beside the
/// step highlights: [edges] by index (edge i runs from corner i to the next;
/// on rays edge i is the ray to corner i + 1; a circle's edge 0 is its
/// radius or diameter), [angles] by their [AngleLabel.corner], grid [rows]
/// from the top, the [rightAngle] mark, the [outline], the shaded [inside]
/// and a rectangle's [diagonal].
@immutable
class FigureParts {
  const FigureParts({
    this.edges = const {},
    this.angles = const {},
    this.rows = const {},
    this.rightAngle = false,
    this.outline = false,
    this.inside = false,
    this.diagonal = false,
  });

  final Set<int> edges;
  final Set<int> angles;
  final Set<int> rows;
  final bool rightAngle;
  final bool outline;
  final bool inside;
  final bool diagonal;

  @override
  bool operator ==(Object other) =>
      other is FigureParts &&
      setEquals(other.edges, edges) &&
      setEquals(other.angles, angles) &&
      setEquals(other.rows, rows) &&
      other.rightAngle == rightAngle &&
      other.outline == outline &&
      other.inside == inside &&
      other.diagonal == diagonal;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(edges),
    Object.hashAllUnordered(angles),
    Object.hashAllUnordered(rows),
    rightAngle,
    outline,
    inside,
    diagonal,
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
    this.diagonal,
    this.extension,
    this.ticks = const [],
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

  /// A drawn diagonal, from corner to corner; its `?` stands on its middle
  /// like a textbook label, on a patch of the card that breaks the line.
  final (Offset, Offset)? diagonal;

  /// A side drawn on past a corner, from that corner to its end.
  final (Offset, Offset)? extension;

  /// Tick marks, each a short line across the middle of an edge.
  final List<(Offset, Offset)> ticks;
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

/// The length of a tick mark across an edge.
const tickLength = 12.0;

/// Fits [figure] into [canvas]: one uniform scale for the whole figure, as
/// large as fits with every label box outside its own edge and inside the
/// canvas. [measure] gives the drawn size of a label's text; numbers are
/// written in the language [localeName]. Rays all the way round a point
/// have no up or down, so they are turned (in steps of 15°) to the angle
/// that keeps their labels apart and draws them longest; so are a
/// quadrilateral and a triangle with a side drawn on, whose labels crowd a
/// short card.
FigureLayout layoutFigure(
  Figure figure,
  Size canvas,
  Size Function(String text) measure, {
  String localeName = 'en',
}) {
  if (figure.shape != FigureShape.crossingLines &&
      figure.shape != FigureShape.aroundPoint &&
      figure.shape != FigureShape.quadrilateral &&
      figure.extension == null) {
    return _layoutFigure(figure, canvas, measure, localeName);
  }
  FigureLayout? best;
  var longest = 0.0;
  var apart = false;
  for (var step = 0; step < 24; step++) {
    final (c, s) = (cos(step * pi / 12), sin(step * pi / 12));
    Offset turn(Offset v) => Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
    final turned = Figure(
      shape: figure.shape,
      vertices: [for (final v in figure.vertices) turn(v)],
      labels: figure.labels,
      prompt: figure.prompt,
      angles: figure.angles,
      extension: switch (figure.extension) {
        final end? => turn(end),
        null => null,
      },
    );
    final drawn = _layoutFigure(turned, canvas, measure, localeName);
    final length = (drawn.vertices[1] - drawn.vertices[0]).distance;
    final separate = !_anyOverlap([
      for (final label in drawn.labels) label.box,
    ]);
    // Labels apart first; then clearly longer, so rounding never picks
    // between equal turns.
    if (separate && !apart || separate == apart && length > longest * 1.0001) {
      (best, longest, apart) = (drawn, length, separate);
    }
  }
  return best!;
}

bool _anyOverlap(List<Rect> boxes) {
  for (final (i, box) in boxes.indexed) {
    for (final other in boxes.skip(i + 1)) {
      if (box.overlaps(other)) return true;
    }
  }
  return false;
}

FigureLayout _layoutFigure(
  Figure figure,
  Size canvas,
  Size Function(String text) measure,
  String localeName,
) {
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
  final rays = switch (figure.shape) {
    FigureShape.straightAngle ||
    FigureShape.rightAngle ||
    FigureShape.crossingLines ||
    FigureShape.aroundPoint => true,
    _ => false,
  };
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

  // A tick mark stands across the middle of its edge.
  ({Offset middle, Offset across}) tick(int edge) {
    final (a, b) = (model[edge], model[(edge + 1) % count]);
    final along = unit(b - a);
    return (middle: (a + b) / 2, across: Offset(-along.dy, along.dx));
  }

  // Each point is placed at s * at + shift, inside a half-size of half.
  final dot = Size(stroke / 2, stroke / 2);
  final points = <({Offset at, Offset shift, Size half})>[
    if (centre == null) ...[
      for (final v in model) (at: v, shift: Offset.zero, half: dot),
      if (figure.extension case final end?)
        (at: end, shift: Offset.zero, half: dot),
      for (final edge in figure.ticks)
        for (final side in const [-1, 1])
          (
            at: tick(edge).middle,
            shift: tick(edge).across * (side * tickLength / 2),
            half: dot,
          ),
    ] else
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
  if (figure.diagonal) {
    texts.add('?');
    points.add((
      at: (model[0] + model[2]) / 2,
      shift: Offset.zero,
      half: boxOf('?'),
    ));
  }
  for (final angle in figure.angles) {
    final text = angle.text;
    final half = boxOf(text);
    texts.add(text);
    if (rays) {
      // Beyond the ray tips on the bisector, so it touches no ray.
      final o = model[0];
      final (a, b) = (model[angle.corner], model[nextRay(angle.corner, count)]);
      // Half the smaller turn from one ray to the other; also defined for
      // a straight angle, which the oracle then rejects by its arc.
      final from = atan2(a.dy - o.dy, a.dx - o.dx);
      final turn = atan2(b.dy - o.dy, b.dx - o.dx) - from;
      final bisector = Offset.fromDirection(
        from + (turn + 3 * pi) % (2 * pi) / 2 - pi / 2,
      );
      points.add((
        at: o + bisector * (a - o).distance,
        shift: bisector * (stroke / 2 + labelGap + reach(half, bisector)),
        half: half,
      ));
    } else if (angle.corner == count) {
      // The outside angle at a side drawn on: on the line that halves it,
      // far enough out that the box clears both of its lines.
      final v = model[count - 1];
      final (a, b) = (unit(figure.extension! - v), unit(model[count - 2] - v));
      final halfAngle = acos((a.dx * b.dx + a.dy * b.dy).clamp(-1.0, 1.0)) / 2;
      final clear = [
        for (final d in [a, b])
          reach(half, Offset(-d.dy, d.dx)) + stroke / 2 + labelGap,
      ].reduce(max);
      points.add((
        at: v,
        shift: unit(a + b) * (clear / sin(halfAngle)),
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
        mark(model[0], model[angle.corner], model[nextRay(angle.corner, count)])
      else if (angle.corner == count)
        mark(model[count - 1], figure.extension!, model[count - 2])
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
    diagonal: figure.diagonal ? (place(model[0]), place(model[2])) : null,
    extension: switch (figure.extension) {
      final end? => (place(model[count - 1]), place(end)),
      null => null,
    },
    ticks: [
      for (final edge in figure.ticks)
        (
          place(tick(edge).middle) - tick(edge).across * (tickLength / 2),
          place(tick(edge).middle) + tick(edge).across * (tickLength / 2),
        ),
    ],
  );
}

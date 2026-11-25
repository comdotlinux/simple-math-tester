import 'dart:math';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';

import 'digits.dart';
import 'hundredths.dart';

/// The shapes a [Figure] can be; each has its own branch in the oracle.
/// Polygons store their corners; a [rightTriangle] has its right angle at
/// corner 0. [straightAngle], [rightAngle], [crossingLines] (two straight
/// lines crossing at corner 0) and [aroundPoint] (rays all the way round)
/// are rays from corner 0 to the other corners, in turning order. A
/// [circle] stores the drawn radius or diameter as its two corners, and its
/// [Figure.centre]. A [quadrilateral] is any convex four-sided shape.
/// [parallelLines] are three separate lines, each from one corner to the
/// next (corners 0 and 1, 2 and 3, 4 and 5): two parallel lines drawn left
/// to right and a line across them from top to bottom (see
/// [parallelAngle]). A [semicircle] is a triangle in a circle whose side
/// from corner 0 to corner 2 is a diameter through [Figure.centre]; the
/// angle at corner 1, on the circle, has no label. [similarTriangles] are
/// two separate triangles, corners 0 to 2 and 3 to 5, corner i matching
/// corner i + 3; their equal angles carry one, two and three arcs.
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
  parallelLines,
  semicircle,
  similarTriangles,
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
/// (after the last ray comes the first again, see [nextRay]); on
/// [FigureShape.parallelLines] see [parallelAngle].
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

/// The corners pieces are drawn from: two for separate lines, three for
/// separate triangles, or null for one outline (or rays) of all corners.
int? pieceOf(FigureShape shape) => switch (shape) {
  FigureShape.parallelLines => 2,
  FigureShape.similarTriangles => 3,
  _ => null,
};

/// The two corners edge [edge] joins among [count] corners drawn in pieces
/// of [piece] corners (see [pieceOf]): a line of two corners is one edge,
/// a closed piece has an edge from each corner to the next.
(int, int) edgeEnds(int edge, int count, int? piece) {
  final size = piece ?? count;
  final perPiece = piece == 2 ? 1 : size;
  final start = edge ~/ perPiece * size;
  final i = edge % perPiece;
  return (start + i, start + (i + 1) % size);
}

/// The number of edges of [count] corners drawn in pieces of [piece].
int edgeCount(int count, int? piece) => piece == 2 ? count ~/ 2 : count;

/// The angle [corner] of two parallel lines and a line across them (the
/// corners of [FigureShape.parallelLines]): its point, where line
/// [corner] ~/ 4 (0 the upper, 1 the lower) crosses the line across, and a
/// point on each of its arms. Around that point, turning the other way to
/// a clock on screen, the arms run right along the parallel line, up the
/// line across, left, and down; angle [corner] % 4 lies between arm
/// [corner] % 4 and the next one.
(Offset, Offset, Offset) parallelAngle(List<Offset> corners, int corner) {
  final line = corner ~/ 4;
  final (left, right) = (corners[2 * line], corners[2 * line + 1]);
  final (top, bottom) = (corners[4], corners[5]);
  final d = right - left;
  final e = bottom - top;
  final t =
      ((top - left).dx * e.dy - (top - left).dy * e.dx) /
      (d.dx * e.dy - d.dy * e.dx);
  final arms = [right, top, left, bottom];
  final j = corner % 4;
  return (left + d * t, arms[j], arms[(j + 1) % 4]);
}

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
    this.arrows = const [],
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

  /// The edges that carry an arrow mark: parallel lines.
  final List<int> arrows;

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
      listEquals(other.ticks, ticks) &&
      listEquals(other.arrows, arrows);

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
    Object.hashAll(arrows),
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
    this.piece,
    this.arrows = const [],
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

  /// How many corners each separately drawn piece has (see [pieceOf]), or
  /// null for one outline of all corners.
  final int? piece;

  /// Arrow marks on parallel lines, each from its tail to its tip along
  /// its line; the painter draws the arrowhead at the tip.
  final List<(Offset, Offset)> arrows;
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
/// (or of the way to the nearest other corner) it may take.
const arcRadius = 24.0;
const arcShare = .3;

/// The shortest side a turned figure is drawn with when a turn allows it:
/// clearly longer than the thick outline is wide.
const shortestSide = 16.0;

/// How far past its arc a label inside its angle may stand; one that would
/// stand farther out stands outside the corner instead.
const nextToArc = 12.0;

/// The length of a tick mark across an edge.
const tickLength = 12.0;

/// The length of an arrow mark along its line, and the radius of the
/// smallest of the arcs that mark equal angles and the room between them.
const arrowLength = 10.0;
const equalArc = 12.0;
const equalArcStep = 4.0;

/// The arcs of rays at one point: each wider angle than an arc's own
/// makes it larger by this share, so arcs that meet on a ray never join
/// up, and the narrowest angle, whose label stands farthest out, has the
/// largest arc.
const arcStep = .5;

/// Fits [figure] into [canvas]: one uniform scale for the whole figure, as
/// large as fits with every label box inside the canvas. [measure] gives
/// the drawn size of a label's text; numbers are written in the language
/// [localeName], in the digits of [digits] (a language code; `en` is 0-9,
/// see [localDigits]). A side label stands outside the middle of its side. An
/// angle label stands inside its angle on the line that halves it, just
/// past the arc, where its box clears every line, tick, arc and label;
/// otherwise just outside the corner on that line, across from the angle,
/// further out only as far as clears another label. Of the choices of
/// which labels stand inside, the one that draws the figure largest wins.
/// An angle between rays or outside a side drawn on is open, so its label
/// always stands in it. Rays all the way round a point have no up or down,
/// so they are turned (in steps of 15°); so are a quadrilateral and a
/// triangle with a side drawn on, whose labels crowd a short card. The
/// turns are laid out from the one whose corners could fill the canvas
/// most until one keeps every side at least [shortestSide], its labels
/// apart and each angle label nearer the middle of its own arc than of any
/// other; if none does, the one that draws the figure largest.
FigureLayout layoutFigure(
  Figure figure,
  Size canvas,
  Size Function(String text) measure, {
  String localeName = 'en',
  String digits = 'en',
}) {
  if (figure.shape != FigureShape.crossingLines &&
      figure.shape != FigureShape.aroundPoint &&
      figure.shape != FigureShape.quadrilateral &&
      figure.extension == null) {
    return _layoutFigure(figure, canvas, measure, localeName, digits).drawn;
  }
  Offset Function(Offset) turnBy(int step) {
    final (c, s) = _turns[step];
    return (v) => Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  final corners = [...figure.vertices, ?figure.extension];
  final fills = [
    for (final (c, s) in _turns)
      () {
        var (left, top, right, bottom) = (
          double.infinity,
          double.infinity,
          double.negativeInfinity,
          double.negativeInfinity,
        );
        for (final v in corners) {
          final (x, y) = (v.dx * c - v.dy * s, v.dx * s + v.dy * c);
          (left, right) = (min(left, x), max(right, x));
          (top, bottom) = (min(top, y), max(bottom, y));
        }
        final fill = min(
          canvas.width / max(right - left, 1e-9),
          canvas.height / max(bottom - top, 1e-9),
        );
        // Rounded, so rounding noise never picks between equal turns.
        return (fill * 1e4).round();
      }(),
  ];
  final steps = [for (var step = 0; step < 24; step++) step]
    ..sort((a, b) => fills[a] != fills[b] ? fills[b] - fills[a] : a - b);
  final unit = (figure.vertices[1] - figure.vertices[0]).distance;
  final labelled = figure.labels.length + (figure.diagonal ? 1 : 0);
  Offset middle(AngleMark mark) =>
      mark.centre +
      Offset.fromDirection(mark.from + mark.sweep / 2, mark.radius);
  FigureLayout? best;
  var largest = 0.0;
  var readable = false;
  for (final step in steps) {
    final turn = turnBy(step);
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
    final (:drawn, :crowded) = _layoutFigure(
      turned,
      canvas,
      measure,
      localeName,
      digits,
    );
    final scale = (drawn.vertices[1] - drawn.vertices[0]).distance / unit;
    // Every side long enough to see, labels apart, each angle label nearer
    // the middle of its own arc than of any other.
    final arcs = [
      for (final mark in drawn.marks)
        if (!mark.right) middle(mark),
    ];
    final corners = drawn.vertices;
    final sides = [
      for (var i = drawn.rays ? 1 : 0; i < corners.length; i++)
        drawn.rays
            ? (corners[0], corners[i])
            : (corners[i], corners[(i + 1) % corners.length]),
      ?drawn.extension,
    ];
    if (sides.every((side) => (side.$2 - side.$1).distance >= shortestSide) &&
        !_anyOverlap([for (final label in drawn.labels) label.box]) &&
        figure.angles.indexed.every((entry) {
          final at = drawn.labels[labelled + entry.$1].box.center;
          final own = (at - arcs[entry.$1]).distance;
          return arcs.indexed.every(
            (arc) => arc.$1 == entry.$1 || (at - arc.$2).distance > own,
          );
        })) {
      // A turn whose labels had to move out of each other's way may draw
      // the figure small, so every turn is tried for a larger one.
      if (!crowded) return drawn;
      if (!readable || scale > largest * 1.0001) {
        (best, largest, readable) = (drawn, scale, true);
      }
    } else if (!readable && scale > largest * 1.0001) {
      // Clearly larger, so rounding never picks between equal turns.
      (best, largest) = (drawn, scale);
    }
  }
  return best!;
}

/// The turns a figure is drawn at, in steps of 15°, as their cosine and
/// sine.
final _turns = [
  for (var step = 0; step < 24; step++)
    (cos(step * pi / 12), sin(step * pi / 12)),
];

bool _anyOverlap(List<Rect> boxes) {
  for (final (i, box) in boxes.indexed) {
    for (final other in boxes.skip(i + 1)) {
      if (box.overlaps(other)) return true;
    }
  }
  return false;
}

/// Whether the line from [a] to [b] meets [rect]: the part of the line
/// between each pair of the rectangle's sides is cut off in turn.
bool _meets(Offset a, Offset b, Rect rect) {
  final d = b - a;
  var (from, to) = (0.0, 1.0);
  for (final (p, q) in [
    (-d.dx, a.dx - rect.left),
    (d.dx, rect.right - a.dx),
    (-d.dy, a.dy - rect.top),
    (d.dy, rect.bottom - a.dy),
  ]) {
    if (p == 0) {
      if (q < 0) return false;
    } else if (p < 0) {
      from = max(from, q / p);
    } else {
      to = min(to, q / p);
    }
    if (from > to) return false;
  }
  return true;
}

/// [figure] laid out unturned, and whether labels outside their corners
/// had to move out of each other's way.
({FigureLayout drawn, bool crowded}) _layoutFigure(
  Figure figure,
  Size canvas,
  Size Function(String text) measure,
  String localeName,
  String digits,
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
  final piece = pieceOf(figure.shape);
  final parallel = figure.shape == FigureShape.parallelLines;
  final centre = figure.centre;
  final radius = centre == null
      ? 0.0
      : model.map((v) => (v - centre).distance).reduce(max);
  // The turning sense of the first piece; separate triangles are drawn
  // turning the same way.
  var twiceArea = 0.0;
  final sides = piece ?? count;
  for (var i = 0; i < sides; i++) {
    final (a, b) = (model[i], model[(i + 1) % sides]);
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
    final (from, to) = edgeEnds(label.edge, count, piece);
    final (a, b) = (model[from], model[to]);
    final along = b - a;
    var normal = Offset(along.dy, -along.dx) / along.distance;
    // With y down a positive area means corners run clockwise on screen,
    // where this normal points out of the shape.
    if (twiceArea < 0) normal = -normal;
    final text = localDigits(label.text(localeName), digits);
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

  // Each angle as its corner and a point on each of its arms. An angle
  // between rays or outside a side drawn on is open beyond its arms.
  final angles = [
    for (final angle in figure.angles)
      if (parallel)
        switch (parallelAngle(model, angle.corner)) {
          (final v, final a, final b) => (v: v, a: a, b: b, open: true),
        }
      else if (rays)
        (
          v: model[0],
          a: model[angle.corner],
          b: model[nextRay(angle.corner, count)],
          open: true,
        )
      else if (angle.corner == count)
        (
          v: model[count - 1],
          a: figure.extension!,
          b: model[count - 2],
          open: true,
        )
      else
        (
          v: model[angle.corner],
          a: model[(angle.corner + count - 1) % count],
          b: model[(angle.corner + 1) % count],
          open: false,
        ),
  ];
  double direction(Offset d) => atan2(d.dy, d.dx);
  // The smaller turn at [v] from the direction to [a] to the one to [b],
  // signed; also defined for a straight angle, which the oracle then
  // rejects by its arc.
  double turnAt(Offset v, Offset a, Offset b) =>
      (direction(b - v) - direction(a - v) + 3 * pi) % (2 * pi) - pi;
  final sweeps = [for (final g in angles) turnAt(g.v, g.a, g.b)];
  final bisectors = [
    for (final (i, g) in angles.indexed)
      Offset.fromDirection(direction(g.a - g.v) + sweeps[i] / 2),
  ];
  final halves = [
    for (final angle in figure.angles) boxOf(localDigits(angle.text, digits)),
  ];
  final growth = [
    for (final (i, sweep) in sweeps.indexed)
      rays
          ? 1 +
                arcStep *
                    [
                      for (final (j, other) in sweeps.indexed)
                        if (other.abs() > sweep.abs() ||
                            other.abs() == sweep.abs() && j < i)
                          j,
                    ].length
          : 1.0,
  ];
  // An arc sized to the shorter of its two arms, at scale [s].
  double arcSize(Offset v, Offset a, Offset b, double s) =>
      min(arcRadius, arcShare * min((a - v).distance, (b - v).distance) * s);
  // An angle's arc is also sized to the nearest other corner, so in a flat
  // shape it does not reach across to the corner opposite.
  final shortArm = [
    for (final g in angles)
      [
        (g.a - g.v).distance,
        (g.b - g.v).distance,
        for (final corner in model)
          if (corner != g.v) (corner - g.v).distance,
        for (final h in angles)
          if (h.v != g.v) (h.v - g.v).distance,
      ].reduce(min),
  ];
  final longArm = [
    for (final g in angles) max((g.a - g.v).distance, (g.b - g.v).distance),
  ];
  // How far along the bisector the box clears both arms.
  final between = [
    for (final (i, g) in angles.indexed)
      ([
                for (final arm in [g.a, g.b])
                  reach(
                    halves[i],
                    Offset(-unit(arm - g.v).dy, unit(arm - g.v).dx),
                  ),
              ].reduce(max) +
              stroke / 2 +
              labelGap) /
          max(sin(sweeps[i].abs() / 2), 1e-6),
  ];
  // Inside its angle: far enough along the bisector to clear both arms and
  // the arc.
  final past = [
    for (final (i, b) in bisectors.indexed) reach(halves[i], b) + labelGap,
  ];
  // Between rays: the nearest point along the bisector where the box
  // clears both rays, between them or just past their ends.
  double clearOfRays(int i, double s) {
    final g = angles[i];
    final ends = [(g.a - g.v) * s, (g.b - g.v) * s];
    bool clear(double d) {
      final room = Rect.fromCenter(
        center: bisectors[i] * d,
        width: halves[i].width * 2,
        height: halves[i].height * 2,
      ).inflate(stroke / 2 + labelGap);
      return !ends.any((end) => _meets(Offset.zero, end, room));
    }

    var (near, far) = (
      0.0,
      min(between[i], longArm[i] * s + stroke / 2 + past[i]),
    );
    for (var k = 0; k < 12; k++) {
      final mid = (near + far) / 2;
      if (clear(mid)) {
        far = mid;
      } else {
        near = mid;
      }
    }
    return far;
  }

  // An arc sized to the shorter arm; an outside angle's label stands far
  // out in its wedge, so its arc reaches out to just before the label,
  // within its lines.
  double arcAt(int i, double s) {
    final size = min(arcRadius, arcShare * shortArm[i] * s) * growth[i];
    if (!angles[i].open || rays) return size;
    // Between parallel lines the arc also reaches out to its label, so the
    // label is nearer it than the arc at the other crossing.
    final reach = parallel ? clearOfRays(i, s) : between[i];
    return max(size, min(reach - past[i], .8 * shortArm[i] * s));
  }

  double insideAt(int i, double s) => max(
    rays || parallel ? clearOfRays(i, s) : between[i],
    arcAt(i, s) + past[i],
  );

  // Outside the corner, across from the inside bisector, so it touches no
  // edge of the convex shape; further out by what clears another label
  // (see below).
  final outside = [
    for (final (i, b) in bisectors.indexed)
      stroke / 2 + labelGap + reach(halves[i], b),
  ];
  Offset angleCentre(int i, double s, {required bool inside}) =>
      angles[i].v * s +
      (angles[i].open || inside
          ? bisectors[i] * insideAt(i, s)
          : -bisectors[i] * outside[i]);
  Rect angleBox(int i, double s, Set<int> inside) => Rect.fromCenter(
    center: angleCentre(i, s, inside: inside.contains(i)),
    width: halves[i].width * 2,
    height: halves[i].height * 2,
  );
  Rect pointBox(int i, double s) => Rect.fromCenter(
    center: points[i].at * s + points[i].shift,
    width: points[i].half.width * 2,
    height: points[i].half.height * 2,
  );
  // The lines drawn, in model units.
  final lines = [
    for (var i = 0; i < (rays ? count - 1 : edgeCount(count, piece)); i++)
      rays
          ? (model[0], model[i + 1])
          : switch (edgeEnds(i, count, piece)) {
              (final from, final to) => (model[from], model[to]),
            },
    if (figure.extension case final end?) (model[count - 1], end),
    if (figure.diagonal) (model[0], model[2]),
  ];

  // Nine points along each arc of radius 1.
  final arcPoints = [
    for (final (j, g) in angles.indexed)
      [
        for (var t = 0; t <= 8; t++)
          Offset.fromDirection(direction(g.a - g.v) + sweeps[j] * t / 8),
      ],
  ];

  // Whether the label of the corner angle [i] fits inside it at scale [s],
  // with the labels in [inside] inside theirs: next to its arc, within the
  // shape, clear of every line, tick, arc and label, and nearer its own
  // corner and arc than any other.
  bool fitsInside(int i, double s, Set<int> inside) {
    final g = angles[i];
    // Next to its arc: a narrow angle pushes the label far along its
    // bisector, where it would read as standing in the middle of the shape.
    if (between[i] - past[i] - arcAt(i, s) > nextToArc) return false;
    final at = angleCentre(i, s, inside: true);
    for (var k = 0; k < count; k++) {
      final (p, q) = (model[k] * s, model[(k + 1) % count] * s);
      final turn = (q - p).dx * (at - p).dy - (q - p).dy * (at - p).dx;
      if (turn * twiceArea <= 0) return false;
      if (model[k] != g.v &&
          (at - model[k] * s).distance <= (at - g.v * s).distance) {
        return false;
      }
    }
    final box = Rect.fromCenter(
      center: at,
      width: halves[i].width * 2,
      height: halves[i].height * 2,
    );
    final room = box.inflate(stroke / 2 + 1);
    for (final (p, q) in lines) {
      if (_meets(p * s, q * s, room)) return false;
    }
    for (final edge in figure.ticks) {
      final (:middle, :across) = tick(edge);
      if (_meets(
        middle * s - across * (tickLength / 2),
        middle * s + across * (tickLength / 2),
        room,
      )) {
        return false;
      }
    }
    for (var k = first; k < points.length; k++) {
      if (pointBox(k, s).inflate(labelGap / 2).overlaps(box)) return false;
    }
    final ownArc = (at - g.v * s).distance - arcAt(i, s);
    for (var j = 0; j < angles.length; j++) {
      if (j == i) continue;
      if (angleBox(j, s, inside).inflate(labelGap / 2).overlaps(box)) {
        return false;
      }
      final other = angles[j];
      final r = arcAt(j, s);
      if ((at - other.v * s).distance - r <= ownArc) return false;
      for (final along in arcPoints[j]) {
        if (room.contains(other.v * s + along * r)) return false;
      }
    }
    return true;
  }

  Rect bounds(double s, Set<int> inside) {
    var (left, top, right, bottom) = (
      double.infinity,
      double.infinity,
      double.negativeInfinity,
      double.negativeInfinity,
    );
    void include(Offset centre, Size half) {
      left = min(left, centre.dx - half.width);
      top = min(top, centre.dy - half.height);
      right = max(right, centre.dx + half.width);
      bottom = max(bottom, centre.dy + half.height);
    }

    for (final p in points) {
      include(p.at * s + p.shift, p.half);
    }
    for (var i = 0; i < angles.length; i++) {
      include(angleCentre(i, s, inside: inside.contains(i)), halves[i]);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  // No scale is larger than the corners alone could fill the canvas.
  final extent = centre == null
      ? [...model, ?figure.extension]
      : [centre - Offset(radius, radius), centre + Offset(radius, radius)];
  final ceiling = min(
    canvas.width /
        (extent.map((p) => p.dx).reduce(max) -
            extent.map((p) => p.dx).reduce(min)),
    canvas.height /
        (extent.map((p) => p.dy).reduce(max) -
            extent.map((p) => p.dy).reduce(min)),
  );
  // How far the drawing at scale [s] overflows the canvas (at most 0 when
  // it fits).
  double overflow(double s, Set<int> inside) {
    final rect = bounds(s, inside);
    return max(
      rect.width - (canvas.width - 2 * canvasMargin),
      rect.height - (canvas.height - 2 * canvasMargin),
    );
  }

  // The largest scale that fits. The overflow grows with the scale, mostly
  // in straight pieces, so the line through a fitting and an overflowing
  // scale finds the next fitting one, nearer the largest; halving the gap
  // takes over where a step would overflow.
  double largest(Set<int> inside) {
    var (low, high) = (
      0.0,
      ceiling.isFinite ? ceiling : max(canvas.width, canvas.height),
    );
    var (under, over) = (overflow(low, inside), overflow(high, inside));
    if (under > 0) return 0;
    if (over <= 0) return high;
    for (var i = 0; i < 24 && high - low > 1e-6 * high; i++) {
      var mid = low + (high - low) * -under / (over - under);
      if (mid - low < 1e-9 * high) mid = (low + high) / 2;
      final at = overflow(mid, inside);
      if (at > 0) {
        (high, over) = (mid, at);
        mid = (low + high) / 2;
        final half = overflow(mid, inside);
        if (half > 0) {
          (high, over) = (mid, half);
        } else {
          (low, under) = (mid, half);
        }
      } else {
        (low, under) = (mid, at);
        if (at > -.5) break;
      }
    }
    return low;
  }

  // Which corner labels stand inside: all of them if they fit; otherwise,
  // of the choices left when labels that do not fit move out one by one,
  // the one that lets the figure grow largest.
  final corners = [
    for (final (i, g) in angles.indexed)
      if (!g.open) i,
  ];
  Set<int> chosen(int mask) => {
    for (final (j, i) in corners.indexed)
      if (mask >> j & 1 == 1) i,
  };
  final sizes = <int, double>{};
  double size(int mask) => sizes[mask] ??= largest(chosen(mask));
  final searched = <int>{};
  var (pick, scale) = (0, size(0));
  void search(int mask) {
    if (!searched.add(mask) || size(mask) <= scale) return;
    final choice = chosen(mask);
    final misfits = [
      for (final (j, i) in corners.indexed)
        if (mask >> j & 1 == 1 && !fitsInside(i, size(mask), choice)) j,
    ];
    if (misfits.isEmpty) {
      (pick, scale) = (mask, size(mask));
    }
    for (final j in misfits) {
      search(mask & ~(1 << j));
    }
  }

  search((1 << corners.length) - 1);
  final inside = chosen(pick);

  // A label outside its corner that overlaps another label moves further
  // out along the bisector, as little as clears it, and the figure shrinks
  // to make room; a label inside that then no longer fits moves out too.
  var crowded = false;
  for (var round = 0; round < 4; round++) {
    var moved = false;
    for (final i in [
      for (final (i, g) in angles.indexed)
        if (!g.open && !inside.contains(i)) i,
    ]) {
      final others = [
        for (var k = first; k < points.length; k++) pointBox(k, scale),
        for (var j = 0; j < angles.length; j++)
          if (j != i) angleBox(j, scale, inside),
      ];
      for (final other in others) {
        final box = angleBox(i, scale, inside);
        if (!box.overlaps(other)) continue;
        final d = -bisectors[i];
        outside[i] +=
            [
              if (d.dx > 1e-9) (other.right - box.left) / d.dx,
              if (d.dx < -1e-9) (other.left - box.right) / d.dx,
              if (d.dy > 1e-9) (other.bottom - box.top) / d.dy,
              if (d.dy < -1e-9) (other.top - box.bottom) / d.dy,
            ].reduce(min) +
            labelGap / 2;
        moved = crowded = true;
      }
    }
    if (!moved) break;
    scale = largest(inside);
    inside.removeAll({
      for (final i in inside)
        if (!fitsInside(i, scale, inside)) i,
    });
    scale = largest(inside);
  }

  final rect = bounds(scale, inside);
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

  // A right-angle square at [v] between the directions to [a] and [b]; it
  // fits inside the arcs around the same corner.
  AngleMark square(Offset v, Offset a, Offset b) => AngleMark(
    place(v),
    arcSize(v, a, b, scale) * .55,
    direction(a - v),
    turnAt(v, a, b),
    right: true,
  );

  final marks = <AngleMark>[
    for (final (i, g) in angles.indexed)
      AngleMark(place(g.v), arcAt(i, scale), direction(g.a - g.v), sweeps[i]),
    if (figure.shape == FigureShape.rightAngle)
      square(model[0], model[1], model[count - 1]),
    if (figure.shape == FigureShape.rightTriangle)
      square(model[0], model[count - 1], model[1]),
    // Equal angles of similar triangles: corner i and i + 3 carry i + 1
    // arcs, one line width and more apart, inside the smaller triangle.
    if (figure.shape == FigureShape.similarTriangles)
      for (var c = 0; c < count; c++)
        for (var m = 0; m <= c % 3; m++)
          () {
            final start = c ~/ 3 * 3;
            final (prev, next) = (
              model[start + (c + 2) % 3],
              model[start + (c + 1) % 3],
            );
            final v = model[c];
            final r =
                min(
                  equalArc,
                  .25 * min((prev - v).distance, (next - v).distance) * scale,
                ) +
                equalArcStep * m;
            return AngleMark(
              place(v),
              r,
              direction(prev - v),
              turnAt(v, prev, next),
            );
          }(),
  ];

  final labelBoxes = [
    for (final (i, _) in texts.indexed)
      pointBox(first + i, scale).shift(origin),
    for (var i = 0; i < angles.length; i++)
      angleBox(i, scale, inside).shift(origin),
  ];
  // An arrow mark on each parallel line, at the first place along it from
  // the left that keeps clear of every label and of the angle arcs.
  (Offset, Offset) arrowOn(int edge) {
    final (from, to) = edgeEnds(edge, count, piece);
    final (a, b) = (place(model[from]), place(model[to]));
    final along = (b - a) / (b - a).distance;
    (Offset, Offset) at(double t) {
      final middle = Offset.lerp(a, b, t)!;
      return (
        middle - along * (arrowLength / 2),
        middle + along * (arrowLength / 2),
      );
    }

    bool free((Offset, Offset) arrow) {
      final room = Rect.fromCenter(
        center: (arrow.$1 + arrow.$2) / 2,
        width: arrowLength + 2 * labelGap,
        height: arrowLength + 2 * labelGap,
      );
      return labelBoxes.every((box) => !box.overlaps(room)) &&
          angles.every(
            (g) => (place(g.v) - room.center).distance > 2 * arcRadius,
          );
    }

    for (var step = 2; step <= 18; step++) {
      if (free(at(step / 20))) return at(step / 20);
    }
    return at(.5);
  }

  final drawn = FigureLayout(
    vertices: [for (final v in model) place(v)],
    labels: [
      for (final (i, text) in texts.indexed) PlacedLabel(text, labelBoxes[i]),
      for (final (i, angle) in figure.angles.indexed)
        PlacedLabel(
          localDigits(angle.text, digits),
          labelBoxes[texts.length + i],
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
      final total? => localDigits(formatHundredths(total, localeName), digits),
      null => null,
    },
    pi: switch (figure.pi) {
      final value? => localDigits(formatHundredths(value, localeName), digits),
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
    piece: piece,
    arrows: [for (final edge in figure.arrows) arrowOn(edge)],
  );
  return (drawn: drawn, crowded: crowded);
}

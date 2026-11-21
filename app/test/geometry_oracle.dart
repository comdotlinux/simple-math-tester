import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:simple_math_tester/figure.dart';

/// The geometry oracle (guard V2b of the plan). Its input is only what the
/// child sees: the shape type, the prompt key and the drawn [FigureLayout]
/// (corners, label texts and where they stand, the grid, the angle marks,
/// the circle, the cues and the given numbers of the prompt line). It never
/// reads a [Figure], a family, parameters or the generator's answer.
///
/// The label solver here is hand-written by the same author as the
/// generators, so the textbook fixtures and the mutation tests back it.
///
/// Labelling convention it solves from: a square shows one side, a
/// rectangle two adjacent sides (the sides without a number equal the
/// opposite ones), a triangle all three, a right triangle its two legs
/// next to the right-angle mark, an L-shape two of the three edges along
/// each direction, a circle its radius or diameter; an angle figure all
/// its angles but the asked one. Two crossing lines show one angle and a
/// `?` on another one. For a length (Pythagoras' theorem) a right triangle
/// shows two sides and a `?` on the third, a rectangle two adjacent sides
/// and a `?` on its drawn diagonal. A triangle with a side drawn on past a
/// corner shows the two inside angles opposite that corner and the outside
/// angle there, one of them `?`; an isosceles triangle a tick on each of
/// its two equal sides, one angle and a `?`; a quadrilateral three angles
/// and a `?`. Two parallel lines carry an arrow each and show one angle at
/// one crossing with the line across and a `?` at the other. A triangle in
/// a circle with one side a diameter shows the angles at the ends of the
/// diameter, one of them `?`. Two triangles with equal angles marked by
/// one, two and three arcs show two sides of one and the matching two of
/// the other, one of them `?`. Anything else is not solvable.
class OracleFailure implements Exception {
  OracleFailure(this.message);

  final String message;

  @override
  String toString() => 'OracleFailure: $message';
}

/// Drawn lengths may differ from the labels by this share of the common
/// scale.
const tolerance = .005;

/// Drawn angles may differ from their labels by this many degrees.
const angleTolerance = .5;

/// Checks that the figure is honest and that [answer] (in hundredths) is
/// the answer to it; throws an [OracleFailure] otherwise. Returns the
/// answer it solved, in hundredths.
int checkFigure(
  FigureShape shape,
  FigurePrompt prompt,
  FigureLayout layout,
  int answer,
) {
  final solved = solveFigure(shape, prompt, layout);
  if (solved != answer) {
    throw OracleFailure('the labels give $solved hundredths, not $answer');
  }
  return solved;
}

/// The answer, in hundredths, that the visible figure asks for.
int solveFigure(FigureShape shape, FigurePrompt prompt, FigureLayout layout) {
  // The cue must match the prompt: a thick outline and no shading for a
  // perimeter, a shaded inside and a thin outline for an area, thin and
  // unshaded for an angle.
  final thick = layout.strokeWidth > thinStroke;
  final cueOk = switch (prompt) {
    FigurePrompt.perimeter ||
    FigurePrompt.sideFromPerimeter ||
    FigurePrompt.circumference => thick && !layout.shaded,
    FigurePrompt.area || FigurePrompt.sideFromArea => !thick && layout.shaded,
    FigurePrompt.angle || FigurePrompt.length => !thick && !layout.shaded,
  };
  if (!cueOk) throw OracleFailure('the cue does not show the $prompt');

  // The prompt line gives a total exactly when a side is asked, and π
  // exactly for a circle; rays and a circle are drawn only for their
  // shapes, and a grid only in squares and rectangles.
  final sideAsked =
      prompt == FigurePrompt.sideFromPerimeter ||
      prompt == FigurePrompt.sideFromArea;
  if ((layout.total != null) != sideAsked) {
    throw OracleFailure('a given total with the prompt $prompt');
  }
  final isCircle = shape == FigureShape.circle;
  final inCircle = isCircle || shape == FigureShape.semicircle;
  if ((layout.pi != null) != isCircle || (layout.circle != null) != inCircle) {
    throw OracleFailure('π or a circle drawn with a $shape');
  }
  // Separate lines only for parallel lines, separate triangles only for
  // similar triangles, arrows only on parallel lines.
  final piece = switch (shape) {
    FigureShape.parallelLines => 2,
    FigureShape.similarTriangles => 3,
    _ => null,
  };
  if (layout.piece != piece) {
    throw OracleFailure('pieces of ${layout.piece} corners in a $shape');
  }
  if (layout.arrows.isNotEmpty && shape != FigureShape.parallelLines) {
    throw OracleFailure('arrows on a $shape');
  }
  final isRays = switch (shape) {
    FigureShape.straightAngle ||
    FigureShape.rightAngle ||
    FigureShape.crossingLines ||
    FigureShape.aroundPoint => true,
    _ => false,
  };
  if (layout.rays != isRays) throw OracleFailure('rays drawn with a $shape');
  if (layout.diagonal != null && shape != FigureShape.rectangle) {
    throw OracleFailure('a diagonal in a $shape');
  }
  // A side drawn on and tick marks belong to angles in a triangle.
  final triangleAngle =
      shape == FigureShape.triangle && prompt == FigurePrompt.angle;
  if ((layout.extension != null || layout.ticks.isNotEmpty) && !triangleAngle) {
    throw OracleFailure('a side drawn on or tick marks on a $shape');
  }
  if (layout.grid &&
      shape != FigureShape.square &&
      shape != FigureShape.rectangle) {
    throw OracleFailure('a grid in a $shape');
  }

  return switch (shape) {
    FigureShape.circle => _solveCircle(prompt, layout),
    FigureShape.straightAngle ||
    FigureShape.rightAngle ||
    FigureShape.crossingLines ||
    FigureShape.aroundPoint => _solveRays(shape, prompt, layout),
    FigureShape.rectangle when layout.diagonal != null => _solveDiagonal(
      prompt,
      layout,
    ),
    FigureShape.lShape => _solveLShape(prompt, layout),
    FigureShape.rightTriangle => _solveRightTriangle(prompt, layout),
    FigureShape.triangle when triangleAngle && layout.extension != null =>
      _solveExteriorAngle(layout),
    FigureShape.triangle when triangleAngle && layout.ticks.isNotEmpty =>
      _solveIsosceles(layout),
    FigureShape.triangle when triangleAngle => _solvePolygonAngles(layout, 3),
    FigureShape.quadrilateral when prompt == FigurePrompt.angle =>
      _solvePolygonAngles(layout, 4),
    FigureShape.quadrilateral => throw OracleFailure(
      'a quadrilateral with the prompt $prompt',
    ),
    FigureShape.parallelLines when prompt == FigurePrompt.angle =>
      _solveParallel(layout),
    FigureShape.semicircle when prompt == FigurePrompt.angle =>
      _solveSemicircle(layout),
    FigureShape.similarTriangles when prompt == FigurePrompt.length =>
      _solveSimilar(layout),
    FigureShape.parallelLines ||
    FigureShape.semicircle ||
    FigureShape.similarTriangles => throw OracleFailure(
      'a $shape with the prompt $prompt',
    ),
    FigureShape.square ||
    FigureShape.rectangle ||
    FigureShape.triangle => _solvePolygon(shape, prompt, layout),
  };
}

/// Squares, rectangles and triangles, with a perimeter or an area asked,
/// or a side asked from a given perimeter or area.
int _solvePolygon(FigureShape shape, FigurePrompt prompt, FigureLayout layout) {
  final corners = layout.vertices;
  final count = corners.length;
  final expectedCorners = switch (shape) {
    FigureShape.triangle => 3,
    _ => 4,
  };
  if (count != expectedCorners) {
    throw OracleFailure('a $shape with $count corners');
  }
  if (prompt == FigurePrompt.angle ||
      prompt == FigurePrompt.circumference ||
      prompt == FigurePrompt.length) {
    throw OracleFailure('a $shape with the prompt $prompt');
  }
  if (layout.marks.isNotEmpty) throw OracleFailure('marks on a $shape');
  final sideAsked =
      prompt == FigurePrompt.sideFromPerimeter ||
      prompt == FigurePrompt.sideFromArea;

  final byEdge = _sideLabels(layout.labels, corners);
  final asked = [
    for (final MapEntry(:key, :value) in byEdge.entries)
      if (value == null) key,
  ];
  if (!sideAsked && asked.isNotEmpty) {
    throw OracleFailure('a ? where nothing is missing');
  }
  if (sideAsked && asked.length != 1) {
    throw OracleFailure('a side is asked but ${asked.length} ? are drawn');
  }
  final total = sideAsked ? _number(layout.total!) : null;

  // The length of every edge, from the labels, the given total and the
  // shape type alone.
  final lengths = List<int?>.filled(count, null);
  switch (shape) {
    case FigureShape.square:
      if (byEdge.length != 1) throw OracleFailure('a square needs 1 label');
      final side =
          byEdge.values.single ??
          switch (prompt) {
            FigurePrompt.sideFromPerimeter => _exact(total!, 4),
            _ => _squareRoot(total! * 100),
          };
      lengths.fillRange(0, count, side);
    case FigureShape.rectangle:
      final edges = byEdge.keys.toList()..sort();
      if (edges.length != 2 || (edges[0] - edges[1]).abs() % 2 != 1) {
        throw OracleFailure('a rectangle needs 2 labels on adjacent edges');
      }
      for (final edge in edges) {
        final known = byEdge[edges.firstWhere((e) => e != edge)];
        final value =
            byEdge[edge] ??
            switch (prompt) {
              FigurePrompt.sideFromPerimeter => _exact(total!, 2) - known!,
              _ => _exact(total! * 100, known!),
            };
        if (value <= 0) throw OracleFailure('a side of $value');
        lengths[edge] = value;
        lengths[(edge + 2) % 4] = value;
      }
    case _:
      if (sideAsked) throw OracleFailure('no side is asked on a triangle');
      if (byEdge.length != 3) throw OracleFailure('a triangle needs 3 labels');
      for (final MapEntry(key: edge, value: value) in byEdge.entries) {
        lengths[edge] = value;
      }
  }
  final sides = lengths.cast<int>();
  final scale = _toScale(corners, sides);
  // Squares and rectangles have right angles.
  if (shape != FigureShape.triangle) _rightAngles(corners);

  final int solved;
  switch (prompt) {
    case FigurePrompt.perimeter:
      solved = sides.reduce((a, b) => a + b);
    case FigurePrompt.area:
      if (shape == FigureShape.triangle) {
        throw OracleFailure('no triangle area from three sides');
      }
      // Hundredths times hundredths, back to hundredths.
      solved = _exact(sides[0] * sides[1], 100);
    case _:
      solved = sides[asked.single];
  }

  if (layout.grid) {
    final cells = _countGridCells(corners, layout.gridLines, scale);
    if (cells * 100 != solved) {
      throw OracleFailure('the grid has $cells squares, the area is $solved');
    }
  }
  return solved;
}

/// Half the product of the two legs next to the right-angle mark; or for
/// a length, the side marked `?` by Pythagoras' theorem.
int _solveRightTriangle(FigurePrompt prompt, FigureLayout layout) {
  final corners = layout.vertices;
  if (corners.length != 3) throw OracleFailure('a right triangle corners');
  if (prompt != FigurePrompt.area && prompt != FigurePrompt.length) {
    throw OracleFailure('a right triangle asks for its area or a length');
  }
  if (layout.marks.length != 1) {
    throw OracleFailure('a right triangle needs one right-angle mark');
  }
  final mark = layout.marks.single;
  final corner = _cornerAt(mark.centre, corners);
  final (prev, next) = ((corner + 2) % 3, (corner + 1) % 3);
  _checkMark(mark, corners[corner], corners[prev], corners[next], right: true);
  final a = corners[prev] - corners[corner];
  final b = corners[next] - corners[corner];
  if ((a.dx * b.dx + a.dy * b.dy).abs() > tolerance * a.distance * b.distance) {
    throw OracleFailure('the marked corner is not a right angle');
  }
  final byEdge = _sideLabels(layout.labels, corners);
  // The legs are the edge into the marked corner and the edge out of it,
  // the longest side the edge across from it.
  if (prompt == FigurePrompt.length) {
    return _pythagoras(
      byEdge,
      corners,
      legs: (prev, corner),
      longest: next,
      longestEnds: (corners[next], corners[prev]),
    );
  }
  if (byEdge.length != 2 ||
      !byEdge.containsKey(prev) ||
      !byEdge.containsKey(corner) ||
      byEdge.values.contains(null)) {
    throw OracleFailure('a right triangle needs its two legs labelled');
  }
  final (legIn, legOut) = (byEdge[prev]!, byEdge[corner]!);
  final hypotenuse = sqrt(legIn * legIn + legOut * legOut);
  final scales = [
    a.distance * 100 / legIn,
    b.distance * 100 / legOut,
    (corners[next] - corners[prev]).distance * 100 / hypotenuse,
  ];
  _sameScale(scales);
  return _exact(legIn * legOut, 200);
}

/// The side marked `?` from the two others by Pythagoras' theorem: the
/// longest side times itself is the two legs times themselves added. In
/// whole hundredths, so a length whose square is not a square number fails.
/// Every edge in [byEdge] (labels by edge, see [_sideLabels]) must be drawn
/// to one scale; the longest side runs between [longestEnds].
int _pythagoras(
  Map<int, int?> byEdge,
  List<Offset> corners, {
  required (int, int) legs,
  required int longest,
  required (Offset, Offset) longestEnds,
}) {
  final edges = [legs.$1, legs.$2, longest];
  if (byEdge.length != 3 || !edges.every(byEdge.containsKey)) {
    throw OracleFailure('Pythagoras needs the two legs and the longest side');
  }
  final asked = [
    for (final e in edges)
      if (byEdge[e] == null) e,
  ];
  if (asked.length != 1) throw OracleFailure('${asked.length} sides asked');
  final (a, b, c) = (byEdge[legs.$1], byEdge[legs.$2], byEdge[longest]);
  final int solved;
  if (c == null) {
    solved = _squareRoot(a! * a + b! * b);
  } else {
    final leg = a ?? b!;
    final rest = c * c - leg * leg;
    if (rest <= 0) throw OracleFailure('a leg as long as the longest side');
    solved = _squareRoot(rest);
  }
  final lengths = {for (final e in edges) e: byEdge[e] ?? solved};
  final count = corners.length;
  _sameScale([
    for (final e in [legs.$1, legs.$2])
      (corners[(e + 1) % count] - corners[e]).distance * 100 / lengths[e]!,
    (longestEnds.$2 - longestEnds.$1).distance * 100 / lengths[longest]!,
  ]);
  return solved;
}

/// A rectangle with a drawn diagonal marked `?` and two adjacent sides
/// labelled: the diagonal is the longest side of the right triangles it
/// cuts the rectangle into.
int _solveDiagonal(FigurePrompt prompt, FigureLayout layout) {
  final corners = layout.vertices;
  if (corners.length != 4) throw OracleFailure('a rectangle has 4 corners');
  if (prompt != FigurePrompt.length) {
    throw OracleFailure('a diagonal with the prompt $prompt');
  }
  if (layout.marks.isNotEmpty || layout.grid) {
    throw OracleFailure('marks or a grid with a diagonal');
  }
  _rightAngles(corners);
  final (p, q) = layout.diagonal!;
  final (from, to) = (_cornerAt(p, corners), _cornerAt(q, corners));
  if ((from - to).abs() != 2) {
    throw OracleFailure('the diagonal does not join opposite corners');
  }
  // The diagonal is edge 4 to the label reader.
  final byEdge = _sideLabels(layout.labels, corners, (p, q));
  if (!byEdge.containsKey(4) || byEdge[4] != null) {
    throw OracleFailure('the diagonal is not marked ?');
  }
  final sides = byEdge.keys.where((e) => e != 4).toList()..sort();
  if (sides.length != 2 || (sides[0] - sides[1]).abs() % 2 != 1) {
    throw OracleFailure('a diagonal needs 2 labels on adjacent sides');
  }
  // Four right angles, so the unlabelled sides equal the ones across.
  return _pythagoras(
    byEdge,
    corners,
    legs: (sides[0], sides[1]),
    longest: 4,
    longestEnds: (p, q),
  );
}

/// The edges of an L-shape run along two directions; along each, the
/// edges going one way are as long as those going back. Two labels per
/// direction give the third edge.
int _solveLShape(FigurePrompt prompt, FigureLayout layout) {
  final corners = layout.vertices;
  if (corners.length != 6) throw OracleFailure('an L-shape has 6 corners');
  if (prompt != FigurePrompt.perimeter && prompt != FigurePrompt.area) {
    throw OracleFailure('an L-shape with the prompt $prompt');
  }
  if (layout.marks.isNotEmpty) throw OracleFailure('marks on an L-shape');
  _rightAngles(corners);
  // Each edge as a step of -1, 0 or 1 along x and y.
  final steps = <(int, int)>[];
  for (var i = 0; i < 6; i++) {
    final d = corners[(i + 1) % 6] - corners[i];
    if (d.dy.abs() <= tolerance * d.distance) {
      steps.add((d.dx.sign.toInt(), 0));
    } else if (d.dx.abs() <= tolerance * d.distance) {
      steps.add((0, d.dy.sign.toInt()));
    } else {
      throw OracleFailure('edge $i of the L-shape is slanted');
    }
  }
  final byEdge = _sideLabels(layout.labels, corners);
  if (byEdge.values.contains(null)) {
    throw OracleFailure('a ? where nothing is missing');
  }
  final lengths = List<int?>.filled(6, null);
  for (final horizontal in [true, false]) {
    final edges = [
      for (var i = 0; i < 6; i++)
        if ((horizontal ? steps[i].$1 : steps[i].$2) != 0) i,
    ];
    int sign(int i) => horizontal ? steps[i].$1 : steps[i].$2;
    final known = edges.where(byEdge.containsKey).toList();
    if (edges.length != 3 || known.length < 2) {
      throw OracleFailure('the L-shape has too few labels to solve');
    }
    final sum = known.fold(0, (s, i) => s + sign(i) * byEdge[i]!);
    for (final i in known) {
      lengths[i] = byEdge[i];
    }
    if (known.length == 3) {
      if (sum != 0) throw OracleFailure('the L-shape labels do not add up');
    } else {
      final missing = edges.firstWhere((i) => !byEdge.containsKey(i));
      final value = -sign(missing) * sum;
      if (value <= 0) throw OracleFailure('an edge of $value');
      lengths[missing] = value;
    }
  }
  final sides = lengths.cast<int>();
  _toScale(corners, sides);
  if (prompt == FigurePrompt.perimeter) return sides.reduce((a, b) => a + b);
  // The shoelace formula over the corners rebuilt from the lengths.
  var (x, y, twiceArea) = (0, 0, 0);
  for (var i = 0; i < 6; i++) {
    final (nx, ny) = (x + steps[i].$1 * sides[i], y + steps[i].$2 * sides[i]);
    twiceArea += x * ny - nx * y;
    (x, y) = (nx, ny);
  }
  return _exact(twiceArea.abs(), 200);
}

/// The angles of a convex shape with [count] corners add up to
/// (count − 2) × 180°: 180° in a triangle, 360° in a quadrilateral.
int _solvePolygonAngles(FigureLayout layout, int count) {
  final corners = layout.vertices;
  if (corners.length != count) {
    throw OracleFailure('${corners.length} corners, not $count');
  }
  _convex(corners);
  return _solveAngles(
    _angleLabels(layout),
    _insideAngles(corners),
    (count - 2) * 180,
  );
}

/// The outside angle of a triangle, between a side drawn on past a corner
/// and the other side at that corner, equals the two inside angles
/// opposite it added together: it and the inside angle next to it make a
/// straight line, and so do the three inside angles.
int _solveExteriorAngle(FigureLayout layout) {
  final corners = layout.vertices;
  if (corners.length != 3) throw OracleFailure('a triangle has 3 corners');
  _convex(corners);
  if (layout.ticks.isNotEmpty) throw OracleFailure('ticks on this triangle');
  final (start, end) = layout.extension!;
  final k = _cornerAt(start, corners);
  if ((end - start).distance <= 1) throw OracleFailure('no side drawn on');
  // The line continues one side at the corner straight on.
  final ends = [(k + 2) % 3, (k + 1) % 3];
  final straight = [
    for (final j in ends)
      if (_degreesBetween(corners[k], end, corners[j]) >= 180 - angleTolerance)
        j,
  ];
  if (straight.length != 1) {
    throw OracleFailure('the line drawn on does not continue a side');
  }
  final other = ends.firstWhere((j) => j != straight.single);
  final outside = (corners[k], end, corners[other]);
  final byKey = _angleLabels(layout, outside: outside);
  final inside = _insideAngles(corners);
  final measured = {
    for (final j in ends) j: inside[j],
    3: _degreesBetween(outside.$1, outside.$2, outside.$3),
  };
  if (byKey.length != 3 || !measured.keys.every(byKey.containsKey)) {
    throw OracleFailure(
      'an outside angle needs the two inside angles opposite it',
    );
  }
  final asked = [
    for (final MapEntry(:key, :value) in byKey.entries)
      if (value == null) key,
  ];
  if (asked.length != 1) throw OracleFailure('${asked.length} angles asked');
  for (final MapEntry(:key, :value) in byKey.entries) {
    if (value != null && (measured[key]! - value).abs() > angleTolerance) {
      throw OracleFailure('angle $value° is drawn as ${measured[key]}°');
    }
  }
  final (p, q) = (byKey[ends[0]], byKey[ends[1]]);
  final solved = asked.single == 3 ? p! + q! : byKey[3]! - (p ?? q)!;
  if (solved <= 0) throw OracleFailure('the asked angle is $solved°');
  if ((measured[asked.single]! - solved).abs() > angleTolerance) {
    throw OracleFailure(
      'the asked angle $solved° is drawn as ${measured[asked.single]}°',
    );
  }
  return solved * 100;
}

/// A triangle with a tick on two sides has those two sides equal, so it is
/// isosceles: the angles where the equal sides meet the third side are
/// equal, and all three add up to 180°.
int _solveIsosceles(FigureLayout layout) {
  final corners = layout.vertices;
  if (corners.length != 3) throw OracleFailure('a triangle has 3 corners');
  _convex(corners);
  final ticked = _tickedEdges(layout.ticks, corners);
  if (ticked.length != 2) {
    throw OracleFailure('${ticked.length} ticked sides, not 2');
  }
  double length(int edge) => (corners[(edge + 1) % 3] - corners[edge]).distance;
  final [e, f] = ticked;
  if ((length(e) - length(f)).abs() > tolerance * max(length(e), length(f))) {
    throw OracleFailure('the ticked sides are not drawn equal');
  }
  // The two ticked sides meet at the top.
  final top = {e, (e + 1) % 3}.intersection({f, (f + 1) % 3}).single;
  final byCorner = _angleLabels(layout);
  final known = [
    for (final MapEntry(:key, :value) in byCorner.entries)
      if (value != null) key,
  ];
  final asked = [
    for (final MapEntry(:key, :value) in byCorner.entries)
      if (value == null) key,
  ];
  if (known.length != 1 || asked.length != 1) {
    throw OracleFailure('an isosceles triangle needs one angle and one ?');
  }
  final given = byCorner[known.single]! * 100;
  // Every angle in hundredths of a degree.
  final angles = [
    for (var i = 0; i < 3; i++)
      if (known.single == top)
        i == top ? given : _exact(18000 - given, 2)
      else
        i == top ? 18000 - 2 * given : given,
  ];
  final measured = _insideAngles(corners);
  for (var i = 0; i < 3; i++) {
    if (angles[i] <= 0) throw OracleFailure('an angle of ${angles[i]}');
    if ((measured[i] - angles[i] / 100).abs() > angleTolerance) {
      throw OracleFailure(
        'angle $i is ${angles[i] / 100}° but drawn as ${measured[i]}°',
      );
    }
  }
  return angles[asked.single];
}

/// Two lines marked as parallel by an arrow on each, and a line across
/// them. The line across meets both at the same slant, so an angle at one
/// crossing equals the angle in the same place at the other
/// (corresponding angles); at one crossing, opposite angles are equal and
/// neighbours make a straight line, 180°. So two angles at different
/// crossings are equal when they are an even number of places apart around
/// their crossings (counted from the arrow's way), and add up to 180°
/// otherwise.
int _solveParallel(FigureLayout layout) {
  final c = layout.vertices;
  if (c.length != 6) throw OracleFailure('parallel lines need 3 lines');
  final lines = [(c[0], c[1]), (c[2], c[3]), (c[4], c[5])];
  bool sameWay(Offset u, Offset w) =>
      (u.dx * w.dy - u.dy * w.dx).abs() <=
      sin(angleTolerance * pi / 180) * u.distance * w.distance;
  // Each arrow lies along one line, and no line has two.
  final marked = <int, Offset>{};
  for (final (tail, tip) in layout.arrows) {
    final along = tip - tail;
    if (along.distance < arrowLength / 2) throw OracleFailure('a tiny arrow');
    final on = [
      for (final (i, (a, b)) in lines.indexed)
        if ((_alongside(tail, a, b) ?? 2) <= 1 &&
            (_alongside(tip, a, b) ?? 2) <= 1 &&
            sameWay(along, b - a))
          i,
    ];
    if (on.length != 1) throw OracleFailure('an arrow off every line');
    if (marked.containsKey(on.single)) {
      throw OracleFailure('two arrows on line ${on.single}');
    }
    marked[on.single] = along;
  }
  if (marked.length != 2) {
    throw OracleFailure('${marked.length} lines marked parallel, not 2');
  }
  final [m, n] = marked.keys.toList()..sort();
  final across = {0, 1, 2}.difference({m, n}).single;
  final (p, q) = (lines[m], lines[n]);
  if (!sameWay(p.$2 - p.$1, q.$2 - q.$1)) {
    throw OracleFailure('the lines marked parallel are not parallel');
  }
  final (u, w) = (marked[m]!, marked[n]!);
  if (u.dx * w.dx + u.dy * w.dy <= 0) {
    throw OracleFailure('the arrows point different ways');
  }
  final (t0, t1) = lines[across];
  // Where the line across crosses each parallel line: inside both lines,
  // with at least 16 px of every arm showing.
  final wedges = <(Offset, Offset, Offset)>[];
  for (final (key, (a, b)) in [(m, p), (n, q)]) {
    final d = b - a;
    final e = t1 - t0;
    final det = d.dx * e.dy - d.dy * e.dx;
    if (det.abs() <= sin(1 * pi / 180) * d.distance * e.distance) {
      throw OracleFailure('the line across is parallel too');
    }
    final s = ((t0 - a).dx * e.dy - (t0 - a).dy * e.dx) / det;
    final x = a + d * s;
    final arms = [a, b, t0, t1];
    if (arms.any((end) => (end - x).distance < 16) ||
        _alongside(x, t0, t1) == null ||
        s <= 0 ||
        s >= 1) {
      throw OracleFailure('the line across does not cross line $key');
    }
    // The arms in turning order, from the one the arrow points along.
    double degrees(Offset v) {
      final at = atan2(-(v.dy - x.dy), v.dx - x.dx) * 180 / pi;
      return at < 0 ? at + 360 : at;
    }

    final start = degrees(
      (b - a).dx * marked[key]!.dx + (b - a).dy * marked[key]!.dy > 0 ? b : a,
    );
    arms.sort(
      (g, h) => ((degrees(g) - start + 360) % 360).compareTo(
        (degrees(h) - start + 360) % 360,
      ),
    );
    for (var j = 0; j < 4; j++) {
      wedges.add((x, arms[j], arms[(j + 1) % 4]));
    }
  }
  if (layout.marks.any((mark) => mark.right)) {
    throw OracleFailure('a right-angle mark on parallel lines');
  }
  final arcOf = <int, AngleMark>{
    for (final (k, (v, a, b)) in wedges.indexed)
      k: ?_spanning(layout.marks, v, a, b),
  };
  // A label stands in the wedge of its angle, clear of both arms by a
  // degree, and is nearer that angle's arc than any other.
  final byKey = <int, int?>{};
  final keyOf = <PlacedLabel, int>{};
  for (final label in layout.labels) {
    final centre = label.box.center;
    final at = [
      for (final MapEntry(:key, value: arc) in arcOf.entries)
        if (_degreesBetween(wedges[key].$1, centre, wedges[key].$2) > 1 &&
            _degreesBetween(wedges[key].$1, centre, wedges[key].$3) > 1 &&
            (_degreesBetween(wedges[key].$1, centre, wedges[key].$2) +
                        _degreesBetween(
                          wedges[key].$1,
                          centre,
                          wedges[key].$3,
                        ) -
                        _degreesBetween(
                          wedges[key].$1,
                          wedges[key].$2,
                          wedges[key].$3,
                        ))
                    .abs() <
                angleTolerance)
          (key, (centre - arcMiddle(arc)).distance),
    ]..sort((x, y) => x.$2.compareTo(y.$2));
    if (at.isEmpty) {
      throw OracleFailure('label ${label.text} is in no marked angle');
    }
    if (byKey.containsKey(at.first.$1)) {
      throw OracleFailure('two labels in one angle');
    }
    byKey[at.first.$1] = _degrees(label.text);
    keyOf[label] = at.first.$1;
  }
  if (layout.marks.length != byKey.length) {
    throw OracleFailure(
      '${layout.marks.length} arcs for ${byKey.length} angles',
    );
  }
  _nearestArc(keyOf, arcOf, layout.marks);
  final known = [
    for (final MapEntry(:key, :value) in byKey.entries)
      if (value != null) key,
  ];
  final asked = [
    for (final MapEntry(:key, :value) in byKey.entries)
      if (value == null) key,
  ];
  if (known.length != 1 || asked.length != 1) {
    throw OracleFailure('parallel lines need one angle and one ?');
  }
  final (k, j) = (known.single, asked.single);
  if (k ~/ 4 == j ~/ 4) {
    throw OracleFailure('the angle and the ? are at one crossing');
  }
  double measured(int key) =>
      _degreesBetween(wedges[key].$1, wedges[key].$2, wedges[key].$3);
  final value = byKey[k]!;
  if ((measured(k) - value).abs() > angleTolerance) {
    throw OracleFailure('angle $value° is drawn as ${measured(k)}°');
  }
  final solved = (k - j).isEven ? value : 180 - value;
  if ((measured(j) - solved).abs() > angleTolerance) {
    throw OracleFailure('the asked angle $solved° is drawn as ${measured(j)}°');
  }
  return solved * 100;
}

/// A triangle in a circle with one side a diameter (both ends on the
/// circle, its middle at the centre) and the third corner on the circle:
/// the angle at that corner is a right angle (Thales), so the other two
/// add up to 90°.
int _solveSemicircle(FigureLayout layout) {
  final corners = layout.vertices;
  if (corners.length != 3) throw OracleFailure('a triangle has 3 corners');
  _convex(corners);
  final circle = layout.circle!;
  if ((circle.width - circle.height).abs() > .5) {
    throw OracleFailure('the circle is not round');
  }
  final (centre, radius) = (circle.center, circle.width / 2);
  bool onRim(Offset p) =>
      ((p - centre).distance - radius).abs() <= tolerance * radius;
  if (layout.marks.any((mark) => mark.right)) {
    throw OracleFailure('a right-angle mark in the circle');
  }
  final diameters = [
    for (var i = 0; i < 3; i++)
      if (onRim(corners[i]) &&
          onRim(corners[(i + 1) % 3]) &&
          ((corners[i] + corners[(i + 1) % 3]) / 2 - centre).distance <=
              tolerance * radius)
        i,
  ];
  if (diameters.length != 1) {
    throw OracleFailure('no side is a diameter through the centre');
  }
  final top = (diameters.single + 2) % 3;
  if (!onRim(corners[top])) {
    throw OracleFailure('the third corner is not on the circle');
  }
  final byCorner = _angleLabels(layout);
  if (byCorner.containsKey(top)) {
    throw OracleFailure('a label at the corner on the circle');
  }
  final known = [
    for (final MapEntry(:key, :value) in byCorner.entries)
      if (value != null) key,
  ];
  final asked = [
    for (final MapEntry(:key, :value) in byCorner.entries)
      if (value == null) key,
  ];
  if (known.length != 1 || asked.length != 1) {
    throw OracleFailure('a triangle in a circle needs one angle and one ?');
  }
  final measured = _insideAngles(corners);
  final given = byCorner[known.single]!;
  final solved = 90 - given;
  for (final (corner, value) in [
    (known.single, given),
    (asked.single, solved),
    (top, 90),
  ]) {
    if (value <= 0 || (measured[corner] - value).abs() > angleTolerance) {
      throw OracleFailure(
        'angle $corner is $value° but drawn as ${measured[corner]}°',
      );
    }
  }
  return solved * 100;
}

/// Two triangles whose angles match, marked by one, two and three arcs,
/// and are drawn equal: they have the same shape, so each side of one is
/// the same number of times its matching side of the other. Two matching
/// labelled sides give that number; the side marked `?` is its labelled
/// partner times it. Both triangles are drawn to one scale.
int _solveSimilar(FigureLayout layout) {
  final c = layout.vertices;
  if (c.length != 6) throw OracleFailure('two triangles have 6 corners');
  final triangles = [c.sublist(0, 3), c.sublist(3)];
  for (final t in triangles) {
    _convex(t);
  }
  Rect around(List<Offset> t) => Rect.fromPoints(
    Offset(t.map((p) => p.dx).reduce(min), t.map((p) => p.dy).reduce(min)),
    Offset(t.map((p) => p.dx).reduce(max), t.map((p) => p.dy).reduce(max)),
  );
  if (around(triangles[0]).overlaps(around(triangles[1]))) {
    throw OracleFailure('the triangles overlap');
  }
  // How many arcs mark each corner's angle.
  final arcs = List.filled(6, 0);
  for (final mark in layout.marks) {
    if (mark.right) throw OracleFailure('a right-angle mark');
    final k = _cornerAt(mark.centre, c);
    final start = k ~/ 3 * 3;
    _checkMark(
      mark,
      c[k],
      c[start + (k + 2) % 3],
      c[start + (k + 1) % 3],
      right: false,
    );
    arcs[k]++;
  }
  for (final t in [0, 3]) {
    if ({for (var i = 0; i < 3; i++) arcs[t + i]}.length != 3 ||
        arcs.sublist(t, t + 3).any((n) => n < 1 || n > 3)) {
      throw OracleFailure('each triangle needs 1, 2 and 3 arcs');
    }
  }
  // The matching corner of the second triangle has as many arcs, and the
  // same angle.
  final match = [
    for (var i = 0; i < 3; i++) 3 + arcs.sublist(3).indexOf(arcs[i]),
  ];
  final measured = [
    ..._insideAngles(triangles[0]),
    ..._insideAngles(triangles[1]),
  ];
  for (var i = 0; i < 3; i++) {
    if ((measured[i] - measured[match[i]]).abs() > angleTolerance) {
      throw OracleFailure('angles marked alike are drawn unequal');
    }
  }
  final edges = [
    for (final t in [0, 3])
      for (var i = 0; i < 3; i++) (c[t + i], c[t + (i + 1) % 3]),
  ];
  final byEdge = _segmentLabels(layout.labels, edges);
  // The edge of the second triangle between the matches of edge i's ends.
  int partner(int edge) {
    if (edge >= 3) {
      return [for (var i = 0; i < 3; i++) i]
          .firstWhere((i) => partner(i) == edge);
    }
    final ends = {match[edge], match[(edge + 1) % 3]};
    return 3 +
        [0, 1, 2].firstWhere((i) => {3 + i, 3 + (i + 1) % 3}.containsAll(ends));
  }

  final asked = [
    for (final MapEntry(:key, :value) in byEdge.entries)
      if (value == null) key,
  ];
  if (asked.length != 1) throw OracleFailure('${asked.length} sides asked');
  final e = asked.single;
  final known =
      byEdge[partner(e)] ??
      (throw OracleFailure('the side matching the ? has no number'));
  final pair = [
    for (final f in byEdge.keys)
      if (f != e &&
          f ~/ 3 == e ~/ 3 &&
          byEdge[f] != null &&
          byEdge[partner(f)] != null)
        f,
  ];
  if (pair.isEmpty) throw OracleFailure('no two matching sides labelled');
  // Sides of the ?'s triangle over their partners, the same for all.
  final f = pair.first;
  final solved = _exact(known * byEdge[f]!, byEdge[partner(f)]!);
  final lengths = {
    for (final MapEntry(:key, :value) in byEdge.entries) key: value ?? solved,
  };
  _sameScale([
    for (final MapEntry(:key, :value) in lengths.entries)
      (edges[key].$2 - edges[key].$1).distance * 100 / value,
  ]);
  return solved;
}

/// The edges that carry a tick: a line across the middle of the edge,
/// square to it and at least half a tick long; at most one per edge.
List<int> _tickedEdges(List<(Offset, Offset)> ticks, List<Offset> corners) {
  final count = corners.length;
  final edges = <int>[];
  for (final (a, b) in ticks) {
    final middle = (a + b) / 2;
    final edge = [
      for (var i = 0; i < count; i++)
        if (((corners[i] + corners[(i + 1) % count]) / 2 - middle).distance <=
            1)
          i,
    ];
    if (edge.length != 1) throw OracleFailure('a tick off every middle');
    final along = corners[(edge.single + 1) % count] - corners[edge.single];
    final across = b - a;
    final cosine =
        (along.dx * across.dx + along.dy * across.dy) /
        (along.distance * across.distance);
    if (across.distance < tickLength / 2 ||
        cosine.abs() > sin(angleTolerance * pi / 180)) {
      throw OracleFailure('a tick that does not cross its edge');
    }
    if (edges.contains(edge.single)) {
      throw OracleFailure('two ticks on edge ${edge.single}');
    }
    edges.add(edge.single);
  }
  return edges..sort();
}

/// Each corner's inside angle in degrees.
List<double> _insideAngles(List<Offset> corners) {
  final count = corners.length;
  return [
    for (var i = 0; i < count; i++)
      _degreesBetween(
        corners[i],
        corners[(i + count - 1) % count],
        corners[(i + 1) % count],
      ),
  ];
}

/// The outline turns the same way at every corner.
void _convex(List<Offset> corners) {
  final count = corners.length;
  final turns = <double>{};
  for (var i = 0; i < count; i++) {
    final a = corners[(i + 1) % count] - corners[i];
    final b = corners[(i + 2) % count] - corners[(i + 1) % count];
    turns.add((a.dx * b.dy - a.dy * b.dx).sign);
  }
  if (turns.contains(0) || turns.length != 1) {
    throw OracleFailure('the shape is not convex');
  }
}

/// Each angle label at its corner, with an arc spanning that angle. A label
/// stands on the line that halves its angle, within 10°: inside the angle,
/// or straight out across the corner from it. An [outside] angle (its
/// corner, then a point on each of its two lines) takes the key one past
/// the last corner; its label stands inside it, on the line that halves
/// it, within 10°. Where a label stands on the lines of two angles (inside
/// a symmetric shape the line that halves one angle can run through the
/// opposite corner), it belongs to the one whose arc it is nearer. Every
/// label is nearer the arc of its own angle than any other arc.
Map<int, int?> _angleLabels(
  FigureLayout layout, {
  (Offset, Offset, Offset)? outside,
}) {
  final corners = layout.vertices;
  final count = corners.length;
  final angles = {
    for (var i = 0; i < count; i++)
      i: (
        corners[i],
        corners[(i + count - 1) % count],
        corners[(i + 1) % count],
      ),
    count: ?outside,
  };
  final arcs = {
    for (final MapEntry(key: k, value: (v, a, b)) in angles.entries)
      k: ?_spanning(layout.marks, v, a, b),
  };
  final byKey = <int, int?>{};
  final keyOf = <PlacedLabel, int>{};
  for (final label in layout.labels) {
    final centre = label.box.center;
    final at = [
      for (final MapEntry(key: k, value: (v, a, b)) in angles.entries)
        if ([
          _halfway(v, a, b),
          if (k != count) v * 2 - _halfway(v, a, b),
        ].any((p) => _degreesBetween(v, centre, p) <= 10))
          k,
    ];
    if (at.length > 1) {
      double toArc(int k) => switch (arcs[k]) {
        final arc? => (centre - arcMiddle(arc)).distance,
        null => double.infinity,
      };
      at.sort((x, y) => toArc(x).compareTo(toArc(y)));
      if (toArc(at[0]) >= toArc(at[1])) {
        throw OracleFailure('label ${label.text} is as near two arcs');
      }
      at.removeRange(1, at.length);
    }
    if (at.length != 1) {
      throw OracleFailure('label ${label.text} is not clearly at one corner');
    }
    if (byKey.containsKey(at.single)) {
      throw OracleFailure('two labels at corner ${at.single}');
    }
    byKey[at.single] = _degrees(label.text);
    keyOf[label] = at.single;
  }
  if (layout.marks.length != byKey.length) {
    throw OracleFailure(
      '${layout.marks.length} arcs for ${byKey.length} '
      'angles',
    );
  }
  for (final key in byKey.keys) {
    if (!arcs.containsKey(key)) throw OracleFailure('no arc at angle $key');
  }
  _nearestArc(keyOf, arcs, layout.marks);
  return byKey;
}

/// The first of [marks] that is an arc spanning the angle at [v] between
/// [a] and [b] (see [_checkMark]), or null.
AngleMark? _spanning(List<AngleMark> marks, Offset v, Offset a, Offset b) {
  for (final mark in marks) {
    if (_markProblem(mark, v, a, b, right: false) == null) return mark;
  }
  return null;
}

/// Each label (with its key in [keyOf]) is nearer the middle of the arc of
/// its own angle ([arcOf]) than the middle of any other arc among [marks].
/// (Arcs of neighbouring rays meet on the ray they share, so the middle,
/// not the nearest point, tells them apart.)
void _nearestArc(
  Map<PlacedLabel, int> keyOf,
  Map<int, AngleMark> arcOf,
  List<AngleMark> marks,
) {
  for (final MapEntry(key: label, value: key) in keyOf.entries) {
    final own = (label.box.center - arcMiddle(arcOf[key]!)).distance;
    for (final mark in marks) {
      if (mark.right || identical(mark, arcOf[key])) continue;
      if ((label.box.center - arcMiddle(mark)).distance <= own) {
        throw OracleFailure('label ${label.text} is nearer another arc');
      }
    }
  }
}

/// The middle of the arc [mark].
Offset arcMiddle(AngleMark mark) =>
    mark.centre + Offset.fromDirection(mark.from + mark.sweep / 2, mark.radius);

/// Rays from one point: on a straight line the angles add up to 180°, in
/// a corner marked as a right angle to 90°, around the point to 360°. Two
/// crossing lines make two pairs of equal angles opposite each other, and
/// neighbours add up to 180°.
int _solveRays(FigureShape shape, FigurePrompt prompt, FigureLayout layout) {
  if (prompt != FigurePrompt.angle) {
    throw OracleFailure('rays with the prompt $prompt');
  }
  final corners = layout.vertices;
  if (corners.length < 3) throw OracleFailure('rays need 2 or more rays');
  final o = corners[0];
  // Each ray's direction in degrees, counterclockwise on screen.
  double direction(Offset p) {
    final d = atan2(-(p.dy - o.dy), p.dx - o.dx) * 180 / pi;
    return d < 0 ? d + 360 : d;
  }

  final order = [for (var i = 1; i < corners.length; i++) i]
    ..sort((a, b) => direction(corners[a]).compareTo(direction(corners[b])));
  // The gaps between neighbouring rays; the largest is the outside, unless
  // the rays go all the way round.
  final round =
      shape == FigureShape.crossingLines || shape == FigureShape.aroundPoint;
  final gaps = [
    for (var i = 0; i < order.length; i++)
      (
        from: order[i],
        to: order[(i + 1) % order.length],
        size:
            (direction(corners[order[(i + 1) % order.length]]) -
                direction(corners[order[i]]) +
                360) %
            360,
      ),
  ];
  final sizes = [for (final gap in gaps) gap.size];
  final outside = round ? null : gaps[sizes.indexOf(sizes.reduce(max))];
  final wedges = [
    for (final gap in gaps)
      if (gap.from != outside?.from) gap,
  ];
  final whole = wedges.fold(0.0, (s, w) => s + w.size);
  final rightMarks = layout.marks.where((m) => m.right).toList();
  final int total;
  if (shape == FigureShape.straightAngle) {
    if ((whole - 180).abs() > angleTolerance || rightMarks.isNotEmpty) {
      throw OracleFailure('the outer rays are not a straight line');
    }
    total = 180;
  } else if (round) {
    if (rightMarks.isNotEmpty) throw OracleFailure('a right-angle mark');
    // Two lines: each ray continues straight through the point, so every
    // angle and the next one make 180°.
    if (shape == FigureShape.crossingLines &&
        (wedges.length != 4 ||
            [
              for (var i = 0; i < 4; i++)
                wedges[i].size + wedges[(i + 1) % 4].size,
            ].any((pair) => (pair - 180).abs() > angleTolerance))) {
      throw OracleFailure('the rays are not two straight lines');
    }
    total = 360;
  } else {
    if ((whole - 90).abs() > angleTolerance || rightMarks.length != 1) {
      throw OracleFailure('the outer rays are not a marked right angle');
    }
    _checkMark(
      rightMarks.single,
      o,
      corners[outside!.to],
      corners[outside.from],
      right: true,
    );
    total = 90;
  }

  // A label belongs to the wedge its direction from the point lies in,
  // clear of both rays by a degree, and is nearer that wedge's arc than
  // any other arc.
  final byWedge = <int, int?>{};
  final keyOf = <PlacedLabel, int>{};
  for (final label in layout.labels) {
    final d = direction(label.box.center);
    final inside = [
      for (final (i, w) in wedges.indexed)
        if ((d - direction(corners[w.from]) + 360) % 360 case final turn
            when turn > 1 && turn < w.size - 1)
          i,
    ];
    if (inside.length != 1) {
      throw OracleFailure('label ${label.text} is not inside one angle');
    }
    if (byWedge.containsKey(inside.single)) {
      throw OracleFailure('two labels in one angle');
    }
    byWedge[inside.single] = _degrees(label.text);
    keyOf[label] = inside.single;
  }
  final arcs = layout.marks.where((m) => !m.right).toList();
  if (arcs.length != byWedge.length) {
    throw OracleFailure('${arcs.length} arcs for ${byWedge.length} angles');
  }
  final arcOf = <int, AngleMark>{};
  for (final i in byWedge.keys) {
    final w = wedges[i];
    arcOf[i] =
        _spanning(arcs, o, corners[w.from], corners[w.to]) ??
        (throw OracleFailure('no arc spans angle $i'));
  }
  _nearestArc(keyOf, arcOf, layout.marks);
  final measured = [for (final w in wedges) w.size];
  if (shape == FigureShape.crossingLines) {
    return _solveCrossing(byWedge, measured);
  }
  return _solveAngles(byWedge, measured, total);
}

/// Two crossing lines with one angle given and one asked, decided by where
/// the `?` is drawn: two wedges on from the given angle it is the
/// vertically opposite angle (equal), one wedge on a neighbour (on one
/// straight line with it, so 180° minus it).
int _solveCrossing(Map<int, int?> labels, List<double> measured) {
  final known = [
    for (final MapEntry(:key, :value) in labels.entries)
      if (value != null) key,
  ];
  final asked = [
    for (final MapEntry(:key, :value) in labels.entries)
      if (value == null) key,
  ];
  if (known.length != 1 || asked.length != 1) {
    throw OracleFailure('crossing lines need one angle and one ?');
  }
  final (k, j) = (known.single, asked.single);
  final value = labels[k]!;
  if ((measured[k] - value).abs() > angleTolerance) {
    throw OracleFailure('angle $value° is drawn as ${measured[k]}°');
  }
  final opposite = (j - k) % 4 == 2;
  final solved = opposite ? value : 180 - value;
  if (solved <= 0) throw OracleFailure('the asked angle is $solved°');
  if ((measured[j] - solved).abs() > angleTolerance) {
    throw OracleFailure('the asked angle $solved° is drawn as ${measured[j]}°');
  }
  return solved * 100;
}

/// The asked angle from the others and the [total], in hundredths; every
/// angle must be drawn as labelled.
int _solveAngles(Map<int, int?> labels, List<double> measured, int total) {
  if (labels.length != measured.length) {
    throw OracleFailure(
      '${labels.length} labels for ${measured.length} '
      'angles',
    );
  }
  final asked = [
    for (final MapEntry(:key, :value) in labels.entries)
      if (value == null) key,
  ];
  if (asked.length != 1) throw OracleFailure('${asked.length} angles asked');
  var rest = total;
  for (final MapEntry(:key, :value) in labels.entries) {
    if (value == null) continue;
    if ((measured[key] - value).abs() > angleTolerance) {
      throw OracleFailure('angle $value° is drawn as ${measured[key]}°');
    }
    rest -= value;
  }
  if (rest <= 0) throw OracleFailure('the asked angle is $rest°');
  if ((measured[asked.single] - rest).abs() > angleTolerance) {
    throw OracleFailure(
      'the asked angle $rest° is drawn as '
      '${measured[asked.single]}°',
    );
  }
  return rest * 100;
}

/// π times the diameter, or π times the radius times the radius, with
/// the π the prompt line gives.
int _solveCircle(FigurePrompt prompt, FigureLayout layout) {
  if (prompt != FigurePrompt.circumference && prompt != FigurePrompt.area) {
    throw OracleFailure('a circle with the prompt $prompt');
  }
  final circle = layout.circle!;
  if ((circle.width - circle.height).abs() > .5) {
    throw OracleFailure('the circle is not round');
  }
  final (centre, radius) = (circle.center, circle.width / 2);
  final piValue = _number(layout.pi!);
  if (layout.marks.isNotEmpty) throw OracleFailure('marks on a circle');
  if (layout.vertices.length != 2) {
    throw OracleFailure('a circle shows one radius or diameter');
  }
  final [p, q] = layout.vertices;
  bool at(Offset a, Offset b) => (a - b).distance <= tolerance * radius;
  bool onRim(Offset a) =>
      ((a - centre).distance - radius).abs() <= tolerance * radius;
  final bool diameter;
  if ((at(p, centre) && onRim(q)) || (at(q, centre) && onRim(p))) {
    diameter = false;
  } else if (onRim(p) && onRim(q) && at((p + q) / 2, centre)) {
    diameter = true;
  } else {
    throw OracleFailure('the line is neither a radius nor a diameter');
  }
  if (layout.labels.length != 1) throw OracleFailure('a circle has 1 label');
  final label = layout.labels.single;
  if (_alongside(label.box.center, p, q) == null) {
    throw OracleFailure('label ${label.text} is not at the line');
  }
  final value = _number(label.text);
  final d = diameter ? value : 2 * value;
  return switch (prompt) {
    FigurePrompt.circumference => _exact(piValue * d, 100),
    _ => _exact(piValue * d * d, 40000),
  };
}

/// Each label at the edge it stands beside: its centre lies across from
/// that edge (not beyond either end), it is the nearest such edge, and
/// clearly nearer than any other; one label per edge. A `?` is null. A
/// drawn [diagonal] counts as one more edge, numbered after the others.
Map<int, int?> _sideLabels(
  List<PlacedLabel> labels,
  List<Offset> corners, [
  (Offset, Offset)? diagonal,
]) => _segmentLabels(labels, [
  for (var i = 0; i < corners.length; i++)
    (corners[i], corners[(i + 1) % corners.length]),
  ?diagonal,
]);

/// Each label at the one of [edges] it stands beside, as for [_sideLabels].
Map<int, int?> _segmentLabels(
  List<PlacedLabel> labels,
  List<(Offset, Offset)> edges,
) {
  final byEdge = <int, int?>{};
  for (final label in labels) {
    final value = parseHundredths(label.text);
    final center = label.box.center;
    final distances = <int, double>{
      for (final (i, (p, q)) in edges.indexed) i: ?_alongside(center, p, q),
    };
    final sorted = distances.values.toList()..sort();
    if (sorted.isEmpty || sorted.length > 1 && sorted[0] >= .9 * sorted[1]) {
      throw OracleFailure('label ${label.text} is not clearly at one edge');
    }
    final edge = distances.keys.firstWhere((i) => distances[i] == sorted[0]);
    if (byEdge.containsKey(edge)) {
      throw OracleFailure('two labels on edge $edge');
    }
    byEdge[edge] = value;
  }
  return byEdge;
}

/// To scale: every drawn edge over its length gives the same scale, which
/// is returned in pixels per unit.
double _toScale(List<Offset> corners, List<int> sides) {
  final count = corners.length;
  return _sameScale([
    for (var i = 0; i < count; i++)
      (corners[(i + 1) % count] - corners[i]).distance * 100 / sides[i],
  ]);
}

double _sameScale(List<double> scales) {
  final scale = scales.reduce((a, b) => a + b) / scales.length;
  for (final s in scales) {
    if ((s - scale).abs() > tolerance * scale) {
      throw OracleFailure('not to scale: $scales px per unit');
    }
  }
  return scale;
}

void _rightAngles(List<Offset> corners) {
  final count = corners.length;
  for (var i = 0; i < count; i++) {
    final a = corners[(i + 1) % count] - corners[i];
    final b = corners[(i + 2) % count] - corners[(i + 1) % count];
    final cosine = (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
    if (cosine.abs() > tolerance) {
      throw OracleFailure('corner ${(i + 1) % count} is not a right angle');
    }
  }
}

/// The corner [p] is drawn at, within a pixel.
int _cornerAt(Offset p, List<Offset> corners) {
  for (var i = 0; i < corners.length; i++) {
    if ((corners[i] - p).distance <= 1) return i;
  }
  throw OracleFailure('a mark away from every corner');
}

/// [mark] sits at [v] and spans the smaller angle between the directions
/// to [a] and [b]: an arc, or for [right] a right-angle square.
void _checkMark(
  AngleMark mark,
  Offset v,
  Offset a,
  Offset b, {
  required bool right,
}) {
  if (_markProblem(mark, v, a, b, right: right) case final problem?) {
    throw OracleFailure(problem);
  }
}

/// What is wrong with [mark] as the mark of the angle at [v] between the
/// directions to [a] and [b] (see [_checkMark]), or null.
String? _markProblem(
  AngleMark mark,
  Offset v,
  Offset a,
  Offset b, {
  required bool right,
}) {
  if (mark.right != right) return 'the wrong kind of mark';
  if ((mark.centre - v).distance > 1 || mark.radius <= 0) {
    return 'a mark away from its corner';
  }
  if (mark.sweep.abs() >= pi) return 'a mark around the outside';
  double angleOf(Offset d) => atan2(d.dy, d.dx);
  bool same(double x, double y) {
    final d = (x - y) % (2 * pi);
    return min(d, 2 * pi - d) <= angleTolerance * pi / 180;
  }

  final (start, end) = (mark.from, mark.from + mark.sweep);
  final (toA, toB) = (angleOf(a - v), angleOf(b - v));
  if (!(same(start, toA) && same(end, toB) ||
      same(start, toB) && same(end, toA))) {
    return 'a mark that does not span its angle';
  }
  return null;
}

/// The angle at [v] between the directions to [a] and [b], in degrees.
double _degreesBetween(Offset v, Offset a, Offset b) {
  final (u, w) = (a - v, b - v);
  final cosine = (u.dx * w.dx + u.dy * w.dy) / (u.distance * w.distance);
  return acos(cosine.clamp(-1.0, 1.0)) * 180 / pi;
}

/// A point on the line that halves the angle at [v] between [a] and [b].
Offset _halfway(Offset v, Offset a, Offset b) =>
    v + (a - v) / (a - v).distance + (b - v) / (b - v).distance;

/// An angle label's whole degrees, or null for `?`.
int? _degrees(String text) {
  if (text == '?') return null;
  final match = RegExp(r'^(\d+)°$').firstMatch(text);
  if (match == null) throw OracleFailure('label "$text" is not an angle');
  return int.parse(match[1]!);
}

/// A number that must be shown, in hundredths.
int _number(String text) =>
    parseHundredths(text) ?? (throw OracleFailure('a ? as a given number'));

/// [a] / [b] when it is a whole number of hundredths.
int _exact(int a, int b) {
  if (a % b != 0) throw OracleFailure('$a / $b is not exact');
  return a ~/ b;
}

/// The side of a square of area [a] (in hundredths squared), when whole.
int _squareRoot(int a) {
  final root = sqrt(a).round();
  if (root * root != a) throw OracleFailure('no square has the area $a');
  return root;
}

/// A label's number in hundredths, or null for `?`. Accepts whole numbers
/// and at most two decimals after a '.'.
int? parseHundredths(String text) {
  if (text == '?') return null;
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) throw OracleFailure('label "$text" is not a number');
  final whole = int.parse(match[1]!);
  final decimals = (match[2] ?? '').padRight(2, '0');
  return whole * 100 + int.parse(decimals);
}

/// The unit squares of a grid over an axis-parallel rectangle: inner lines
/// one scale apart, each from edge to edge.
int _countGridCells(
  List<Offset> corners,
  List<(Offset, Offset)> lines,
  double scale,
) {
  final xs = corners.map((c) => c.dx);
  final ys = corners.map((c) => c.dy);
  final (left, right) = (xs.reduce(min), xs.reduce(max));
  final (top, bottom) = (ys.reduce(min), ys.reduce(max));
  final slack = tolerance * scale;
  final verticals = <double>[];
  final horizontals = <double>[];
  for (final (a, b) in lines) {
    if ((a.dx - b.dx).abs() <= slack) {
      final spans =
          (min(a.dy, b.dy) - top).abs() <= slack &&
          (max(a.dy, b.dy) - bottom).abs() <= slack;
      if (!spans) throw OracleFailure('a grid line stops short');
      verticals.add(a.dx);
    } else if ((a.dy - b.dy).abs() <= slack) {
      final spans =
          (min(a.dx, b.dx) - left).abs() <= slack &&
          (max(a.dx, b.dx) - right).abs() <= slack;
      if (!spans) throw OracleFailure('a grid line stops short');
      horizontals.add(a.dy);
    } else {
      throw OracleFailure('a slanted grid line');
    }
  }
  void evenlySpaced(List<double> at, double from, double to) {
    final stops = [from, ...at..sort(), to];
    for (var i = 1; i < stops.length; i++) {
      if ((stops[i] - stops[i - 1] - scale).abs() > slack) {
        throw OracleFailure('grid squares are not one unit wide');
      }
    }
  }

  evenlySpaced(verticals, left, right);
  evenlySpaced(horizontals, top, bottom);
  return (verticals.length + 1) * (horizontals.length + 1);
}

/// The distance from [p] to the edge from [a] to [b], or null when [p] is
/// not across from the edge.
double? _alongside(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared;
  if (t < 0 || t > 1) return null;
  return (p - (a + ab * t)).distance;
}

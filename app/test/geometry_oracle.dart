import 'dart:math';
import 'dart:ui' show Offset;

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
/// and a `?` on its drawn diagonal. Anything else is not solvable.
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
  if ((layout.pi != null) != isCircle || (layout.circle != null) != isCircle) {
    throw OracleFailure('π or a circle drawn with a $shape');
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
    FigureShape.triangle when prompt == FigurePrompt.angle =>
      _solveTriangleAngles(layout),
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

/// The three angles of a triangle add up to 180°.
int _solveTriangleAngles(FigureLayout layout) {
  final corners = layout.vertices;
  if (corners.length != 3) throw OracleFailure('a triangle has 3 corners');
  final measured = [
    for (var i = 0; i < 3; i++)
      _degreesBetween(corners[i], corners[(i + 2) % 3], corners[(i + 1) % 3]),
  ];
  // A label stands straight out from its corner: on the line that halves
  // the angle, outside the triangle, within 10°.
  final byCorner = <int, int?>{};
  for (final label in layout.labels) {
    final at = [
      for (var i = 0; i < 3; i++)
        if (_degreesBetween(
              corners[i],
              label.box.center,
              corners[i] * 2 -
                  _halfway(
                    corners[i],
                    corners[(i + 1) % 3],
                    corners[(i + 2) % 3],
                  ),
            ) <=
            10)
          i,
    ];
    if (at.length != 1) {
      throw OracleFailure('label ${label.text} is not clearly at one corner');
    }
    final corner = at.single;
    if (byCorner.containsKey(corner)) {
      throw OracleFailure('two labels at corner $corner');
    }
    byCorner[corner] = _degrees(label.text);
  }
  if (layout.marks.length != byCorner.length) {
    throw OracleFailure(
      '${layout.marks.length} arcs for ${byCorner.length} '
      'angles',
    );
  }
  for (final corner in byCorner.keys) {
    final mark = layout.marks.singleWhere(
      (m) => _cornerAt(m.centre, corners) == corner,
      orElse: () => throw OracleFailure('no arc at corner $corner'),
    );
    _checkMark(
      mark,
      corners[corner],
      corners[(corner + 2) % 3],
      corners[(corner + 1) % 3],
      right: false,
    );
  }
  return _solveAngles(byCorner, measured, 180);
}

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
  // clear of both rays by a degree.
  final byWedge = <int, int?>{};
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
  }
  final arcs = layout.marks.where((m) => !m.right).toList();
  if (arcs.length != byWedge.length) {
    throw OracleFailure('${arcs.length} arcs for ${byWedge.length} angles');
  }
  for (final i in byWedge.keys) {
    final w = wedges[i];
    if (!arcs.any((m) {
      try {
        _checkMark(m, o, corners[w.from], corners[w.to], right: false);
        return true;
      } on OracleFailure {
        return false;
      }
    })) {
      throw OracleFailure('no arc spans angle $i');
    }
  }
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
]) {
  final count = corners.length;
  final byEdge = <int, int?>{};
  for (final label in labels) {
    final value = parseHundredths(label.text);
    final center = label.box.center;
    final distances = <int, double>{
      for (var i = 0; i < count; i++)
        i: ?_alongside(center, corners[i], corners[(i + 1) % count]),
      if (diagonal case (final p, final q)) count: ?_alongside(center, p, q),
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
  if (mark.right != right) throw OracleFailure('the wrong kind of mark');
  if ((mark.centre - v).distance > 1 || mark.radius <= 0) {
    throw OracleFailure('a mark away from its corner');
  }
  if (mark.sweep.abs() >= pi) throw OracleFailure('a mark around the outside');
  double angleOf(Offset d) => atan2(d.dy, d.dx);
  bool same(double x, double y) {
    final d = (x - y) % (2 * pi);
    return min(d, 2 * pi - d) <= angleTolerance * pi / 180;
  }

  final (start, end) = (mark.from, mark.from + mark.sweep);
  final (toA, toB) = (angleOf(a - v), angleOf(b - v));
  if (!(same(start, toA) && same(end, toB) ||
      same(start, toB) && same(end, toA))) {
    throw OracleFailure('a mark that does not span its angle');
  }
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

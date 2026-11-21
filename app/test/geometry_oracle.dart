import 'dart:math';
import 'dart:ui' show Offset;

import 'package:simple_math_tester/figure.dart';

/// The geometry oracle (guard V2b of the plan). Its input is only what the
/// child sees: the shape type, the prompt key and the drawn [FigureLayout]
/// (corners, label texts and where they stand, the grid and the cues). It
/// never reads a [Figure], a family, parameters or the generator's answer.
///
/// The label solver here is hand-written by the same author as the
/// generators, so the textbook fixtures and the mutation tests back it.
///
/// Labelling convention it solves from: a square shows one side, a
/// rectangle two adjacent sides (the sides without a number equal the
/// opposite ones), a triangle all three. Anything else is not solvable.
class OracleFailure implements Exception {
  OracleFailure(this.message);

  final String message;

  @override
  String toString() => 'OracleFailure: $message';
}

/// Drawn lengths may differ from the labels by this share of the common
/// scale.
const tolerance = .005;

/// Checks that the figure is honest and that [answer] is the answer to it;
/// throws an [OracleFailure] otherwise. Returns the answer it solved, in
/// hundredths.
int checkFigure(
  FigureShape shape,
  FigurePrompt prompt,
  FigureLayout layout,
  num answer,
) {
  final solved = solveFigure(shape, prompt, layout);
  if (solved != (answer * 100).round()) {
    throw OracleFailure('the labels give $solved hundredths, not $answer');
  }
  return solved;
}

/// The answer, in hundredths, that the visible figure asks for.
int solveFigure(FigureShape shape, FigurePrompt prompt, FigureLayout layout) {
  final corners = layout.vertices;
  final count = corners.length;
  final expectedCorners = switch (shape) {
    FigureShape.square || FigureShape.rectangle => 4,
    FigureShape.triangle => 3,
  };
  if (count != expectedCorners) {
    throw OracleFailure('a $shape with $count corners');
  }

  // The cue must match the prompt: a thick outline and no shading for the
  // perimeter, a shaded inside and a thin outline for the area.
  final thick = layout.strokeWidth > thinStroke;
  final cueOk = switch (prompt) {
    FigurePrompt.perimeter => thick && !layout.shaded,
    FigurePrompt.area => !thick && layout.shaded,
  };
  if (!cueOk) throw OracleFailure('the cue does not show the $prompt');

  // A label stands beside an edge when its centre lies across from that
  // edge (not beyond either end). It belongs to the nearest such edge,
  // which must be clearly nearer than any other; one label per edge.
  final byEdge = <int, int>{};
  for (final label in layout.labels) {
    final value = parseHundredths(label.text);
    final center = label.box.center;
    final distances = <int, double>{
      for (var i = 0; i < count; i++)
        i: ?_alongside(center, corners[i], corners[(i + 1) % count]),
    };
    final sorted = distances.values.toList()..sort();
    if (sorted.isEmpty || sorted.length > 1 && sorted[0] >= .9 * sorted[1]) {
      throw OracleFailure('label ${label.text} is not clearly at one edge');
    }
    final edge = distances.keys.firstWhere((i) => distances[i] == sorted[0]);
    if (byEdge.containsKey(edge)) {
      throw OracleFailure('two labels on edge $edge');
    }
    if (value == null) throw OracleFailure('a ? where nothing is missing');
    byEdge[edge] = value;
  }

  // The length of every edge, from the labels and the shape type alone.
  final lengths = List<int?>.filled(count, null);
  switch (shape) {
    case FigureShape.square:
      if (byEdge.length != 1) throw OracleFailure('a square needs 1 label');
      lengths.fillRange(0, count, byEdge.values.single);
    case FigureShape.rectangle:
      final edges = byEdge.keys.toList()..sort();
      if (edges.length != 2 || (edges[0] - edges[1]).abs() % 2 != 1) {
        throw OracleFailure('a rectangle needs 2 labels on adjacent edges');
      }
      for (final edge in edges) {
        lengths[edge] = byEdge[edge];
        lengths[(edge + 2) % 4] = byEdge[edge];
      }
    case FigureShape.triangle:
      if (byEdge.length != 3) throw OracleFailure('a triangle needs 3 labels');
      for (final MapEntry(key: edge, value: value) in byEdge.entries) {
        lengths[edge] = value;
      }
  }
  final sides = lengths.cast<int>();

  // To scale: every drawn edge over its length gives the same scale.
  final scales = [
    for (var i = 0; i < count; i++)
      (corners[(i + 1) % count] - corners[i]).distance * 100 / sides[i],
  ];
  final scale = scales.reduce((a, b) => a + b) / count;
  for (final s in scales) {
    if ((s - scale).abs() > tolerance * scale) {
      throw OracleFailure('not to scale: $scales px per unit');
    }
  }
  // Squares and rectangles have right angles.
  if (shape != FigureShape.triangle) {
    for (var i = 0; i < count; i++) {
      final a = corners[(i + 1) % count] - corners[i];
      final b = corners[(i + 2) % count] - corners[(i + 1) % count];
      final cosine = (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
      if (cosine.abs() > tolerance) {
        throw OracleFailure('corner ${i + 1} is not a right angle');
      }
    }
  }

  final int solved;
  switch (prompt) {
    case FigurePrompt.perimeter:
      solved = sides.reduce((a, b) => a + b);
    case FigurePrompt.area:
      if (shape == FigureShape.triangle) {
        throw OracleFailure('no triangle area at these levels');
      }
      // Hundredths times hundredths, back to hundredths.
      solved = sides[0] * sides[1] ~/ 100;
  }

  if (layout.grid) {
    final cells = _countGridCells(corners, layout.gridLines, scale);
    if (cells * 100 != solved) {
      throw OracleFailure('the grid has $cells squares, the area is $solved');
    }
  }
  return solved;
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

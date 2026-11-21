import 'dart:math';
import 'dart:ui' show Offset;

import 'figure.dart';

/// The highest geometry level so far; raised as families are added.
const maxGeometryLevel = 2;

/// A geometry question: the figure the child sees and the answer, which
/// [GeometryFamily.build] computes from the parameters, not from the
/// figure.
typedef FigureQuestion = ({Figure figure, int answer});

/// The geometry question families. Each has a level, its whole finite
/// parameter space (tests enumerate it) and a pure `build` that rejects
/// parameters outside that space. The name is the variant saved in the
/// history, so a family is never renamed.
///
/// Labels shown: a square one side, a rectangle two adjacent sides (the
/// unseen sides equal the opposite ones), a triangle all three sides.
enum GeometryFamily {
  squarePerimeter(1, _squareSpace, _squarePerimeter),
  rectanglePerimeter(1, _rectangleSpace, _rectanglePerimeter),
  trianglePerimeter(1, _triangleSpace, _trianglePerimeter),
  rectangleArea(2, _areaSpace, _rectangleArea);

  const GeometryFamily(this.level, this._space, this.build);

  final int level;
  final List<List<int>> Function() _space;

  /// The question for [params]; throws an [ArgumentError] for parameters
  /// that are not in [space].
  final FigureQuestion Function(List<int> params) build;

  /// Every parameter list of this family.
  List<List<int>> get space => _space();
}

/// One geometry problem of [level], drawn uniformly by family, then by
/// parameters. The model draws again when it repeats the one before.
(GeometryFamily, List<int>) drawGeometry(Random random, int level) {
  final families = [
    for (final family in GeometryFamily.values)
      if (family.level == level) family,
  ];
  final family = families[random.nextInt(families.length)];
  final space = family.space;
  return (family, space[random.nextInt(space.length)]);
}

/// Sides at most 12; the longer side at most 4 times the shorter, so the
/// drawing stays readable.
bool _readable(int shorter, int longer) =>
    shorter >= 1 && longer <= 12 && longer <= 4 * shorter;

void _require(bool valid, List<int> params) {
  if (!valid) throw ArgumentError.value(params, 'params');
}

final _squares = [
  for (var side = 1; side <= 12; side++) [side],
];
final _rectangles = [
  for (var width = 1; width <= 12; width++)
    for (var height = 1; height <= 12; height++)
      if (width != height && _readable(min(width, height), max(width, height)))
        [width, height],
];
final _triangles = [
  for (var base = 2; base <= 12; base++)
    for (var right = 2; right <= base; right++)
      for (var left = 2; left <= right; left++)
        if (_validTriangle(base, left, right)) [base, left, right],
];
final _areas = [
  for (var width = 1; width <= 10; width++)
    for (var height = 1; height <= 10; height++)
      if (_readable(min(width, height), max(width, height))) [width, height],
];

List<List<int>> _squareSpace() => _squares;
List<List<int>> _rectangleSpace() => _rectangles;
List<List<int>> _triangleSpace() => _triangles;
List<List<int>> _areaSpace() => _areas;

/// A rectangle with its top-left corner at the origin; edge 1 is the
/// right side, edge 2 the bottom.
List<Offset> _box(int width, int height) => [
  Offset.zero,
  Offset(width.toDouble(), 0),
  Offset(width.toDouble(), height.toDouble()),
  Offset(0, height.toDouble()),
];

FigureQuestion _squarePerimeter(List<int> params) {
  _require(params.length == 1 && _readable(params[0], params[0]), params);
  final side = params[0];
  return (
    figure: Figure(
      shape: FigureShape.square,
      vertices: _box(side, side),
      labels: [SideLabel(2, side * 100)],
      prompt: FigurePrompt.perimeter,
    ),
    answer: 4 * side,
  );
}

FigureQuestion _rectanglePerimeter(List<int> params) {
  _require(
    params.length == 2 &&
        params[0] != params[1] &&
        _readable(params.reduce(min), params.reduce(max)),
    params,
  );
  final [width, height] = params;
  return (
    figure: Figure(
      shape: FigureShape.rectangle,
      vertices: _box(width, height),
      labels: [SideLabel(2, width * 100), SideLabel(1, height * 100)],
      prompt: FigurePrompt.perimeter,
    ),
    answer: 2 * (width + height),
  );
}

/// The base is the longest side and the left side the shortest, so each
/// triangle appears once. Every angle is at least 20°, the longest side at
/// most 4 times the shortest, and the triangle inequality is strict.
bool _validTriangle(int base, int left, int right) {
  if (left < 2 || left > right || right > base || base > 12) return false;
  if (left + right <= base || base > 4 * left) return false;
  // The smallest angle is opposite the shortest side, the left one.
  final cosSmallest =
      (base * base + right * right - left * left) / (2 * base * right);
  return cosSmallest <= cos(20 * pi / 180);
}

FigureQuestion _trianglePerimeter(List<int> params) {
  _require(
    params.length == 3 && _validTriangle(params[0], params[1], params[2]),
    params,
  );
  final [base, left, right] = params;
  // The apex lies [left] from the bottom-left corner and [right] from the
  // bottom-right one.
  final x = (base * base + left * left - right * right) / (2 * base);
  final apex = Offset(x, -sqrt(left * left - x * x));
  return (
    figure: Figure(
      shape: FigureShape.triangle,
      vertices: [Offset.zero, apex, Offset(base.toDouble(), 0)],
      labels: [
        SideLabel(0, left * 100),
        SideLabel(1, right * 100),
        SideLabel(2, base * 100),
      ],
      prompt: FigurePrompt.perimeter,
    ),
    answer: base + left + right,
  );
}

FigureQuestion _rectangleArea(List<int> params) {
  _require(
    params.length == 2 &&
        params.every((side) => side <= 10) &&
        _readable(params.reduce(min), params.reduce(max)),
    params,
  );
  final [width, height] = params;
  return (
    figure: Figure(
      shape: FigureShape.rectangle,
      vertices: _box(width, height),
      labels: [SideLabel(2, width * 100), SideLabel(1, height * 100)],
      prompt: FigurePrompt.area,
      grid: true,
    ),
    answer: width * height,
  );
}

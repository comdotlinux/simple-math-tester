import 'dart:math';
import 'dart:ui' show Offset;

import 'figure.dart';

/// The highest geometry level so far; raised as families are added.
const maxGeometryLevel = 5;

/// π as the questions use it, in hundredths; the prompt says "Use π = 3.14".
const piHundredths = 314;

/// A geometry question: the figure the child sees and the answer in
/// hundredths, which [GeometryFamily.build] computes from the parameters,
/// not from the figure.
typedef FigureQuestion = ({Figure figure, int answer});

/// The geometry question families. Each has a level, its whole finite
/// parameter space (tests enumerate it) and a pure `build` that rejects
/// parameters outside that space. The name is the variant saved in the
/// history, so a family is never renamed.
///
/// Labels shown: a square one side, a rectangle two adjacent sides (the
/// unseen sides equal the opposite ones), a triangle all three sides, a
/// right triangle its two legs, an L-shape two of its three horizontal and
/// two of its three vertical edges, a circle its radius or diameter.
enum GeometryFamily {
  squarePerimeter(1, _squareSpace, _squarePerimeter),
  rectanglePerimeter(1, _rectangleSpace, _rectanglePerimeter),
  trianglePerimeter(1, _triangleSpace, _trianglePerimeter),
  rectangleArea(2, _areaSpace, _rectangleArea),
  squareSideFromPerimeter(3, _squareSpace, _squareSideFromPerimeter),
  squareSideFromArea(3, _squareSpace, _squareSideFromArea),
  rectangleSideFromPerimeter(3, _rectangleSpace, _rectangleSideFromPerimeter),
  rectangleSideFromArea(3, _rectangleSpace, _rectangleSideFromArea),
  triangleAngle(4, _triangleAngleSpace, _triangleAngle),
  straightAngle(4, _straightSpace, _straightAngle),
  rightAngle(4, _rightSpace, _rightAngle),
  rightTriangleArea(5, _legSpace, _rightTriangleArea),
  lShapePerimeter(5, _lShapeSpace, _lShapePerimeter),
  lShapeArea(5, _lShapeSpace, _lShapeArea),
  halvesRectanglePerimeter(5, _halvesSpace, _halvesRectanglePerimeter),
  halvesRectangleArea(5, _halvesSpace, _halvesRectangleArea),
  circleCircumference(5, _diameterSpace, _circleCircumference),
  circleArea(5, _radiusSpace, _circleArea);

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

final _keys = Expando<Set<String>>();

/// Whether [params] is one of [space]'s parameter lists.
bool _inSpace(List<List<int>> space, List<int> params) => (_keys[space] ??= {
  for (final p in space) p.join(','),
}).contains(params.join(','));

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

/// Two angles of a triangle, each at least 20°, and the third as well.
final _triangleAngles = [
  for (var a = 20; a <= 140; a++)
    for (var b = 20; a + b <= 160; b++) [a, b],
];
final _straight = [
  for (var a = 20; a <= 160; a++) [a],
];
final _right = [
  for (var a = 10; a <= 80; a++) [a],
];

/// Legs 1 to 12 whose smaller angle is at least 20°.
final _legs = [
  for (var a = 1; a <= 12; a++)
    for (var b = 1; b <= 12; b++)
      if (min(a, b) / max(a, b) >= tan(20 * pi / 180)) [a, b],
];

/// An L-shape: the outer width and height, and the corner cut away at the
/// top right. Outer sides 4 to 12, wider than tall (a taller one is the
/// same shape turned, and its labels would not fit a phone at large text),
/// and every edge at least a quarter of the width, the L-shape's version
/// of the 4 to 1 rule.
final _lShapes = [
  for (var width = 5; width <= 12; width++)
    for (var height = 4; height < width; height++)
      for (var cutWidth = 1; cutWidth < width; cutWidth++)
        for (var cutHeight = 1; cutHeight < height; cutHeight++)
          if ([
            width,
            height,
            cutWidth,
            cutHeight,
            width - cutWidth,
            height - cutHeight,
          ].every((edge) => 4 * edge >= max(width, height)))
            [width, height, cutWidth, cutHeight],
];

/// Rectangles with sides in halves (params in half units, 1 to 24), at
/// least one side not whole.
final _halves = [
  for (var width = 1; width <= 24; width++)
    for (var height = 1; height <= 24; height++)
      if (width != height &&
          (width.isOdd || height.isOdd) &&
          max(width, height) <= 4 * min(width, height))
        [width, height],
];
final _diameters = [
  for (var d = 1; d <= 20; d++) [d],
];
final _radii = [
  for (var r = 1; r <= 10; r++) [r],
];

List<List<int>> _squareSpace() => _squares;
List<List<int>> _rectangleSpace() => _rectangles;
List<List<int>> _triangleSpace() => _triangles;
List<List<int>> _areaSpace() => _areas;
List<List<int>> _triangleAngleSpace() => _triangleAngles;
List<List<int>> _straightSpace() => _straight;
List<List<int>> _rightSpace() => _right;
List<List<int>> _legSpace() => _legs;
List<List<int>> _lShapeSpace() => _lShapes;
List<List<int>> _halvesSpace() => _halves;
List<List<int>> _diameterSpace() => _diameters;
List<List<int>> _radiusSpace() => _radii;

/// A rectangle with its top-left corner at the origin; edge 1 is the
/// right side, edge 2 the bottom.
List<Offset> _box(num width, num height) => [
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
    answer: 4 * side * 100,
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
    answer: 2 * (width + height) * 100,
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
    answer: (base + left + right) * 100,
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
    answer: width * height * 100,
  );
}

/// A square with a `?` on its bottom side and its perimeter or area given.
FigureQuestion _squareSide(List<int> params, {required bool fromArea}) {
  _require(params.length == 1 && _readable(params[0], params[0]), params);
  final side = params[0];
  return (
    figure: Figure(
      shape: FigureShape.square,
      vertices: _box(side, side),
      labels: const [SideLabel(2, null)],
      prompt: fromArea
          ? FigurePrompt.sideFromArea
          : FigurePrompt.sideFromPerimeter,
      total: (fromArea ? side * side : 4 * side) * 100,
    ),
    answer: side * 100,
  );
}

FigureQuestion _squareSideFromPerimeter(List<int> params) =>
    _squareSide(params, fromArea: false);

FigureQuestion _squareSideFromArea(List<int> params) =>
    _squareSide(params, fromArea: true);

/// A rectangle with its bottom side labelled, a `?` on its right side and
/// its perimeter or area given.
FigureQuestion _rectangleSide(List<int> params, {required bool fromArea}) {
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
      labels: [SideLabel(2, width * 100), const SideLabel(1, null)],
      prompt: fromArea
          ? FigurePrompt.sideFromArea
          : FigurePrompt.sideFromPerimeter,
      total: (fromArea ? width * height : 2 * (width + height)) * 100,
    ),
    answer: height * 100,
  );
}

FigureQuestion _rectangleSideFromPerimeter(List<int> params) =>
    _rectangleSide(params, fromArea: false);

FigureQuestion _rectangleSideFromArea(List<int> params) =>
    _rectangleSide(params, fromArea: true);

Offset _direction(int degrees) {
  final radians = degrees * pi / 180;
  // Counterclockwise on screen, where y points down.
  return Offset(cos(radians), -sin(radians));
}

/// A triangle with the angles a at corner 0 and b at corner 2; the angle
/// at corner 1 is asked. It is turned so its longest side lies at the
/// bottom, where it fits a wide card best.
FigureQuestion _triangleAngle(List<int> params) {
  _require(_inSpace(_triangleAngles, params), params);
  final [a, b] = params;
  const base = 10.0;
  // Law of sines: the side from corner 0 to 1 is opposite the angle b.
  final left = base * sin(b * pi / 180) / sin((a + b) * pi / 180);
  final corners = [Offset.zero, _direction(a) * left, const Offset(base, 0)];
  var longest = 0;
  for (var i = 1; i < 3; i++) {
    if ((corners[(i + 1) % 3] - corners[i]).distance >
        (corners[(longest + 1) % 3] - corners[longest]).distance) {
      longest = i;
    }
  }
  final from = corners[longest];
  final along = corners[(longest + 1) % 3] - from;
  Offset turn(Offset v, double by) =>
      Offset(v.dx * cos(by) - v.dy * sin(by), v.dx * sin(by) + v.dy * cos(by));
  var by = -atan2(along.dy, along.dx);
  // The third corner above the longest side, with y down.
  if (turn(corners[(longest + 2) % 3] - from, by).dy > 0) by += pi;
  return (
    figure: Figure(
      shape: FigureShape.triangle,
      vertices: [for (final c in corners) turn(c - from, by)],
      labels: const [],
      angles: [AngleLabel(0, a), const AngleLabel(1, null), AngleLabel(2, b)],
      prompt: FigurePrompt.angle,
    ),
    answer: (180 - a - b) * 100,
  );
}

/// Rays from the origin at 0°, a° and [whole]°; the angle a is given, the
/// rest of the whole is asked.
FigureQuestion _splitAngle(List<int> params, int whole, FigureShape shape) {
  final a = params.single;
  return (
    figure: Figure(
      shape: shape,
      vertices: [Offset.zero, _direction(0), _direction(a), _direction(whole)],
      labels: const [],
      angles: [AngleLabel(1, a), const AngleLabel(2, null)],
      prompt: FigurePrompt.angle,
    ),
    answer: (whole - a) * 100,
  );
}

FigureQuestion _straightAngle(List<int> params) {
  _require(_inSpace(_straight, params), params);
  return _splitAngle(params, 180, FigureShape.straightAngle);
}

FigureQuestion _rightAngle(List<int> params) {
  _require(_inSpace(_right, params), params);
  return _splitAngle(params, 90, FigureShape.rightAngle);
}

/// Legs a (bottom) and b (left), the right angle at the bottom-left
/// corner, the hypotenuse without a number.
FigureQuestion _rightTriangleArea(List<int> params) {
  _require(_inSpace(_legs, params), params);
  final [a, b] = params;
  return (
    figure: Figure(
      shape: FigureShape.rightTriangle,
      vertices: [
        Offset.zero,
        Offset(0, -b.toDouble()),
        Offset(a.toDouble(), 0),
      ],
      labels: [SideLabel(0, b * 100), SideLabel(2, a * 100)],
      prompt: FigurePrompt.area,
    ),
    answer: a * b * 50,
  );
}

/// The L-shape's corners from the top-left one, clockwise on screen: the
/// top edge, the inner vertical one, the inner horizontal one, the right
/// edge, the bottom and the left edge. Labelled: the top, the inner
/// horizontal, the left and the right edge.
Figure _lShape(List<int> params, FigurePrompt prompt) {
  final [width, height, cutWidth, cutHeight] = params;
  final top = width - cutWidth;
  return Figure(
    shape: FigureShape.lShape,
    vertices: [
      Offset.zero,
      Offset(top.toDouble(), 0),
      Offset(top.toDouble(), cutHeight.toDouble()),
      Offset(width.toDouble(), cutHeight.toDouble()),
      Offset(width.toDouble(), height.toDouble()),
      Offset(0, height.toDouble()),
    ],
    labels: [
      SideLabel(0, top * 100),
      SideLabel(2, cutWidth * 100),
      SideLabel(3, (height - cutHeight) * 100),
      SideLabel(5, height * 100),
    ],
    prompt: prompt,
  );
}

FigureQuestion _lShapePerimeter(List<int> params) {
  _require(_inSpace(_lShapes, params), params);
  final [width, height, _, _] = params;
  return (
    figure: _lShape(params, FigurePrompt.perimeter),
    answer: 2 * (width + height) * 100,
  );
}

FigureQuestion _lShapeArea(List<int> params) {
  _require(_inSpace(_lShapes, params), params);
  final [width, height, cutWidth, cutHeight] = params;
  return (
    figure: _lShape(params, FigurePrompt.area),
    answer: (width * height - cutWidth * cutHeight) * 100,
  );
}

Figure _halvesRectangle(List<int> params, FigurePrompt prompt) {
  final [width, height] = params;
  return Figure(
    shape: FigureShape.rectangle,
    vertices: _box(width / 2, height / 2),
    labels: [SideLabel(2, width * 50), SideLabel(1, height * 50)],
    prompt: prompt,
  );
}

FigureQuestion _halvesRectanglePerimeter(List<int> params) {
  _require(_inSpace(_halves, params), params);
  final [width, height] = params;
  return (
    figure: _halvesRectangle(params, FigurePrompt.perimeter),
    answer: (width + height) * 100,
  );
}

FigureQuestion _halvesRectangleArea(List<int> params) {
  _require(_inSpace(_halves, params), params);
  final [width, height] = params;
  // Half units times half units are quarters: 25 hundredths each.
  return (
    figure: _halvesRectangle(params, FigurePrompt.area),
    answer: width * height * 25,
  );
}

/// A circle of diameter [d] with its diameter drawn upright, so its label
/// (taller than wide) fits beside it.
FigureQuestion _circleCircumference(List<int> params) {
  _require(_inSpace(_diameters, params), params);
  final [d] = params;
  final r = d / 2;
  return (
    figure: Figure(
      shape: FigureShape.circle,
      vertices: [Offset(0, -r), Offset(0, r)],
      labels: [SideLabel(0, d * 100)],
      prompt: FigurePrompt.circumference,
      centre: Offset.zero,
      pi: piHundredths,
    ),
    answer: piHundredths * d,
  );
}

/// A circle of radius [r] with a radius drawn from the centre.
FigureQuestion _circleArea(List<int> params) {
  _require(_inSpace(_radii, params), params);
  final [r] = params;
  return (
    figure: Figure(
      shape: FigureShape.circle,
      vertices: [Offset.zero, Offset(r.toDouble(), 0)],
      labels: [SideLabel(0, r * 100)],
      prompt: FigurePrompt.area,
      centre: Offset.zero,
      pi: piHundredths,
    ),
    answer: piHundredths * r * r,
  );
}

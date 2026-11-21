import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/figure.dart';
import 'package:simple_math_tester/figure_view.dart';
import 'package:simple_math_tester/hundredths.dart' show formatHundredths;
import 'package:simple_math_tester/labels.dart';
import 'package:simple_math_tester/geometry.dart';
import 'package:simple_math_tester/solution_steps.dart';

import 'app_theme_test.dart' show contrast;
import 'en.dart';
import 'geometry_oracle.dart';

const scales = [1.0, 2.0];

final every = [
  for (final family in GeometryFamily.values)
    for (final params in family.space) (family, params),
];

/// The figure's edges as drawn: rays from the first corner, a circle's
/// radius or diameter, or the closed outline and a side drawn on.
List<(Offset, Offset)> drawnEdges(FigureLayout drawn) {
  final corners = drawn.vertices;
  if (drawn.rays) {
    return [for (final end in corners.skip(1)) (corners[0], end)];
  }
  if (drawn.circle != null) return [(corners[0], corners[1])];
  return [
    for (var i = 0; i < corners.length; i++)
      (corners[i], corners[(i + 1) % corners.length]),
    ?drawn.extension,
  ];
}

/// The corner of [angle] in [drawn]: the point of rays, the corner past
/// the last for an outside angle, or its own corner.
Offset angleCorner(Figure figure, FigureLayout drawn, AngleLabel angle) {
  final corners = drawn.vertices;
  return drawn.rays
      ? corners[0]
      : corners[min(angle.corner, corners.length - 1)];
}

/// How far the label of the angle [i] of [figure] stands from that angle
/// in [drawn]: from its box to the nearest point of the angle's arc, of its
/// two lines or of its corner. Angle labels follow the side labels and a
/// diagonal's ?; the angle arcs come first among the marks, in the same
/// order.
double fromAngle(Figure figure, FigureLayout drawn, int i) {
  final angle = figure.angles[i];
  final label =
      drawn.labels[figure.labels.length + (figure.diagonal ? 1 : 0) + i];
  final mark = drawn.marks[i];
  final corners = drawn.vertices;
  final count = corners.length;
  final v = angleCorner(figure, drawn, angle);
  final arms = drawn.rays
      ? [corners[angle.corner], corners[nextRay(angle.corner, count)]]
      : angle.corner == count
      ? [drawn.extension!.$2, corners[count - 2]]
      : [
          corners[(angle.corner + count - 1) % count],
          corners[(angle.corner + 1) % count],
        ];
  return [
    for (var t = 0; t <= 16; t++)
      toBox(
        label.box,
        mark.centre +
            Offset.fromDirection(mark.from + mark.sweep * t / 16, mark.radius),
      ),
    for (final end in arms) toSegment(label.box, v, end),
  ].reduce(min);
}

/// Whether the line from [a] to [b] meets [rect]: the part of the line
/// between each pair of the rectangle's sides is cut off in turn.
bool meets(Offset a, Offset b, Rect rect) {
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

/// The distance from the line from [a] to [b] to [box]; 0 where they meet.
double toSegment(Rect box, Offset a, Offset b) {
  if (meets(a, b, box)) return 0;
  double toLine(Offset p) {
    final ab = b - a;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared)
        .clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  return [
    toBox(box, a),
    toBox(box, b),
    for (final corner in [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ])
      toLine(corner),
  ].reduce(min);
}

/// The distance from [p] to [box]; 0 inside it.
double toBox(Rect box, Offset p) => Offset(
  max(0, max(box.left - p.dx, p.dx - box.right)),
  max(0, max(box.top - p.dy, p.dy - box.bottom)),
).distance;

/// [drawn] with some parts replaced, as a lying painter would draw it.
FigureLayout redrawn(
  FigureLayout drawn, {
  List<PlacedLabel>? labels,
  List<(Offset, Offset)>? gridLines,
  List<AngleMark>? marks,
  String? pi,
  bool keepPi = true,
  String? total,
  (Offset, Offset)? diagonal,
  bool keepDiagonal = true,
  (Offset, Offset)? extension,
  bool keepExtension = true,
  List<(Offset, Offset)>? ticks,
}) => FigureLayout(
  vertices: drawn.vertices,
  labels: labels ?? drawn.labels,
  grid: drawn.grid,
  gridLines: gridLines ?? drawn.gridLines,
  strokeWidth: drawn.strokeWidth,
  shaded: drawn.shaded,
  marks: marks ?? drawn.marks,
  rays: drawn.rays,
  circle: drawn.circle,
  total: total ?? drawn.total,
  pi: keepPi ? pi ?? drawn.pi : null,
  diagonal: keepDiagonal ? diagonal ?? drawn.diagonal : null,
  extension: keepExtension ? extension ?? drawn.extension : null,
  ticks: ticks ?? drawn.ticks,
);

/// [figure] with some parts replaced, as a lying generator would build it.
Figure copy(
  Figure figure, {
  List<Offset>? vertices,
  List<SideLabel>? labels,
  List<AngleLabel>? angles,
  int? total,
  bool? diagonal,
  Offset? extension,
  List<int>? ticks,
}) => Figure(
  shape: figure.shape,
  vertices: vertices ?? figure.vertices,
  labels: labels ?? figure.labels,
  prompt: figure.prompt,
  grid: figure.grid,
  angles: angles ?? figure.angles,
  centre: figure.centre,
  total: total ?? figure.total,
  pi: figure.pi,
  diagonal: diagonal ?? figure.diagonal,
  extension: extension ?? figure.extension,
  ticks: ticks ?? figure.ticks,
);

/// The value of a calculation such as "8 × 6 − 3 × 4", in exact
/// hundredths: × and ÷ first, then + and − from left to right. Throws when
/// a division or product is not a whole number of hundredths.
int calculate(String calculation) {
  final tokens = calculation.split(' ');
  int number(String text) {
    final [whole, ...decimals] = text.split('.');
    return int.parse(whole) * 100 +
        int.parse((decimals.isEmpty ? '' : decimals.single).padRight(2, '0'));
  }

  int exact(int a, int b) {
    expect(a % b, 0, reason: '$calculation is not exact');
    return a ~/ b;
  }

  final terms = <int>[number(tokens[0])];
  final signs = <String>[];
  for (var i = 1; i < tokens.length; i += 2) {
    final value = number(tokens[i + 1]);
    switch (tokens[i]) {
      case '×':
        terms.last = exact(terms.last * value, 100);
      case '÷':
        terms.last = exact(terms.last * 100, value);
      case final sign:
        signs.add(sign);
        terms.add(value);
    }
  }
  var result = terms[0];
  for (final (i, sign) in signs.indexed) {
    result += sign == '+' ? terms[i + 1] : -terms[i + 1];
  }
  return result;
}

/// A number as a whole token of [text], not part of a longer number.
RegExp numberToken(String number) =>
    RegExp('(?<![\\d.])${RegExp.escape(number)}(?![\\d]|\\.\\d)');

const _asks = {
  FigureMove.askPerimeter,
  FigureMove.askArea,
  FigureMove.askSideFromPerimeter,
  FigureMove.askSideFromArea,
  FigureMove.askAngle,
  FigureMove.askCircumference,
  FigureMove.askLength,
};
const _ideas = {
  FigureMove.squareSides,
  FigureMove.rectangleSides,
  FigureMove.perimeterAdds,
  FigureMove.gridArea,
  FigureMove.rectangleArea,
  FigureMove.halfPerimeter,
  FigureMove.squareArea,
  FigureMove.triangleAngles,
  FigureMove.straightAngle,
  FigureMove.rightAngle,
  FigureMove.rightTriangle,
  FigureMove.lShapePerimeter,
  FigureMove.lShapeArea,
  FigureMove.circumference,
  FigureMove.circleArea,
  FigureMove.verticallyOpposite,
  FigureMove.aroundPoint,
  FigureMove.pythagoras,
  FigureMove.diagonalTriangles,
  FigureMove.exteriorAngle,
  FigureMove.isosceles,
  FigureMove.quadrilateral,
};
const _answers = {
  FigureMove.perimeterIs,
  FigureMove.areaIs,
  FigureMove.sideIs,
  FigureMove.rootSide,
  FigureMove.rootLength,
  FigureMove.angleIs,
  FigureMove.circumferenceIs,
};
const _roots = {FigureMove.rootSide, FigureMove.rootLength};

/// The numbers a rule may bring in: halves, four sides, 90°, 180°, 360°.
const ruleNumbers = {200, 400, 9000, 18000, 36000};

/// What is wrong with [hint] as the hint of [figure], whose answer the
/// oracle solved as [solved] (hundredths); empty when nothing is. Checks
/// the shape (what is asked, the idea, the working, the answer), that each
/// calculation adds up in exact hundredths, that every number comes from a
/// highlighted part, the given total or π, a rule or an earlier step, that
/// every labelled part a calculation step highlights is read by it (or by
/// the earlier steps whose values it uses), that only the last step has
/// the answer and a check, and that the check holds.
/// [calculate], or null when a division or product is not exact.
int? _exact(String calculation) {
  try {
    return calculate(calculation);
  } on TestFailure {
    return null;
  }
}

List<String> hintProblems(Figure figure, List<FigureStep> hint, int solved) {
  final problems = <String>[];
  final count = figure.vertices.length;
  final rays = const {
    FigureShape.straightAngle,
    FigureShape.rightAngle,
    FigureShape.crossingLines,
    FigureShape.aroundPoint,
  }.contains(figure.shape);
  final edgeCount = figure.shape == FigureShape.circle
      ? 1
      : rays
      ? count - 1
      : count;
  final ys = figure.vertices.map((v) => v.dy);
  final rowCount = figure.grid ? (ys.reduce(max) - ys.reduce(min)).round() : 0;
  final labelOf = {
    for (final label in figure.labels) label.edge: label.hundredths,
  };
  final angleOf = {
    for (final angle in figure.angles)
      angle.corner: switch (angle.degrees) {
        final degrees? => degrees * 100,
        null => null,
      },
  };
  final given = {?figure.total, ?figure.pi};
  final answerToken = numberToken(formatHundredths(solved, 'en'));
  final earlier = <int>{};
  // The labels each value worked out so far was worked out from.
  final from = <int, Set<int>>{};
  if (hint.length < 4 ||
      !_asks.contains(hint.first.move) ||
      !_ideas.contains(hint[1].move) ||
      !_answers.contains(hint.last.move)) {
    problems.add('not shaped: what is asked, the idea, working, the answer');
  }
  for (final (i, step) in hint.indexed) {
    final last = i == hint.length - 1;
    void fail(String why) =>
        problems.add('step ${i + 1} ${step.move.name}: $why');
    if (i > 0 &&
        !last &&
        (_asks.contains(step.move) || _answers.contains(step.move))) {
      fail('out of place');
    }
    final parts = step.parts;
    if (parts.edges.any((edge) => edge < 0 || edge >= edgeCount) ||
        !parts.angles.every(angleOf.containsKey) ||
        parts.rows.any((row) => row < 0 || row >= rowCount) ||
        parts.diagonal && !figure.diagonal ||
        parts.rightAngle &&
            figure.shape != FigureShape.rightAngle &&
            figure.shape != FigureShape.rightTriangle) {
      fail('highlights a part the figure does not have');
    }
    final lit = {
      for (final edge in parts.edges) ?labelOf[edge],
      for (final corner in parts.angles) ?angleOf[corner],
    };
    final allowed = {...lit, ...given, ...ruleNumbers, ...earlier};
    final root = _roots.contains(step.move);
    for (final number in [...step.numbers, if (!root) ...step.terms]) {
      if (!allowed.contains(number)) {
        fail('$number is not from a highlighted part, given or worked out');
      }
    }
    final value = step.valueHundredths;
    if (step.terms.isNotEmpty) {
      if (value == null ||
          step.signs.length != step.terms.length - 1 ||
          _exact(step.calculation!) != value) {
        fail('${step.calculation} is not $value');
      }
      final used = {
        ...step.terms,
        for (final term in step.terms) ...?from[term],
      };
      for (final label in lit) {
        if (!used.contains(label)) {
          fail('highlights $label but does not use it');
        }
      }
    } else if (value != null) {
      fail('a value without a calculation');
    }
    if (last) {
      if (root) {
        if (step.terms.length != 2 ||
            step.terms.any((term) => term != solved) ||
            i == 0 ||
            hint[i - 1].move != FigureMove.whichSquare ||
            hint[i - 1].numbers.single != value) {
          fail('does not multiply the answer by itself to the square named');
        }
      } else if (value != solved) {
        fail('$value is not the answer $solved');
      }
      switch (step.checkKind) {
        case FigureCheck.calculation:
          final [left, right] = step.check!.split(' = ');
          final result = _exact(right);
          // The answer put back makes a number the child knows, or a
          // second way to the answer itself.
          if (_exact(left) != result ||
              !(answerToken.hasMatch(left) && allowed.contains(result) ||
                  result == solved && left != step.calculation)) {
            fail('check ${step.check}');
          }
        case FigureCheck.aBitMore:
          final [left, right] = step.check!.split(' = ');
          final result = _exact(right) ?? 0;
          if (_exact(left) != result ||
              !left.startsWith('3 × ') ||
              !allowed.contains(_exact(left.substring(4))) ||
              solved <= result ||
              solved * 10 >= result * 11) {
            fail('check a bit more than ${step.check}');
          }
        case FigureCheck.sides:
          if (step.move != FigureMove.perimeterIs ||
              step.terms.length != edgeCount) {
            fail('check of ${step.terms.length} sides');
          }
        case FigureCheck.countSquares:
          if (!figure.grid) fail('no squares to count');
        case null:
          if (!root) fail('no check');
      }
    } else if (step.checkKind != null || step.check != null) {
      fail('a check before the last step');
    }
    earlier.addAll(step.numbers);
    if (value != null) {
      earlier.add(value);
      from[value] = {
        for (final term in step.terms)
          if (lit.contains(term)) term,
        for (final term in step.terms) ...?from[term],
      };
    }
  }
  return problems;
}

/// [step] with some fields replaced, as a wrong writer would make it.
FigureStep copyStep(
  FigureStep step, {
  List<int>? numbers,
  List<int>? terms,
  int? valueHundredths,
  String? check,
  FigureParts? parts,
}) => FigureStep(
  step.move,
  numbers: numbers ?? step.numbers,
  terms: terms ?? step.terms,
  signs: step.signs,
  valueHundredths: valueHundredths ?? step.valueHundredths,
  checkKind: step.checkKind,
  check: check ?? step.check,
  parts: parts ?? step.parts,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(family['family'] as String);
      for (final font in (family['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  final style = buildAppTheme(Brightness.light).textTheme.titleMedium!;
  final measures = <double, Size Function(String)>{
    for (final scale in scales)
      scale: (() {
        final cache = <String, Size>{};
        return (String text) => cache.putIfAbsent(
          text,
          () => measureLabel(text, style, TextScaler.linear(scale)),
        );
      })(),
  };
  // The last figure laid out: a test checks several mutants of one figure
  // in a row, each against the figure's own layout.
  (Figure, Size, FigureLayout)? last;
  FigureLayout layout(Figure figure, [Size canvas = const Size(340, 210)]) {
    if (last case (final f, final c, final drawn)
        when f == figure && c == canvas) {
      return drawn;
    }
    final drawn = layoutFigure(figure, canvas, measures[1.0]!);
    last = (figure, canvas, drawn);
    return drawn;
  }

  // The question area of the phone (320 to 412 wide) and the compact
  // layout, and the widest card (the page gutter is 16 and the card padding
  // 20 on each side, and the card is at most 640 wide), as tall as the
  // figure in the regular and the compact card at each text scale.
  final canvases = {
    for (final scale in scales)
      scale: [
        for (final compact in [false, true])
          for (final width in const [248.0, 340.0, 600.0])
            Size(
              width,
              figureCanvasHeight(
                figureHeight(compact: compact),
                style,
                TextScaler.linear(scale),
              ),
            ),
      ],
  };

  test('the parameter spaces have the sizes of the plan', () {
    int count(int level) => [
      for (final (family, _) in every)
        if (family.level == level) family,
    ].length;
    final sizes = {
      for (final family in GeometryFamily.values)
        family.name: family.space.length,
    };
    // ignore: avoid_print
    print('geometry families: $sizes');
    expect(sizes, {
      'squarePerimeter': 12,
      'rectanglePerimeter': 108,
      'trianglePerimeter': 156,
      'rectangleArea': 84,
      'squareSideFromPerimeter': 12,
      'squareSideFromArea': 12,
      'rectangleSideFromPerimeter': 108,
      'rectangleSideFromArea': 108,
      'triangleAngle': 7381,
      'straightAngle': 141,
      'rightAngle': 71,
      'rightTriangleArea': 98,
      'lShapePerimeter': 396,
      'lShapeArea': 396,
      'halvesRectanglePerimeter': 324,
      'halvesRectangleArea': 324,
      'circleCircumference': 20,
      'circleArea': 10,
      'verticallyOppositeAngles': 282,
      'anglesAroundPoint': 496,
      'pythagorasHypotenuse': 12,
      'pythagorasLeg': 12,
      'rectangleDiagonal': 12,
      'exteriorAngle': 14060,
      'isoscelesTriangle': 122,
      'quadrilateralAngles': 2135,
    });
    expect(count(1), 276);
    expect(count(2), 84);
    expect(count(3), 240);
    expect(count(4), 22553);
    expect(count(5), 3739);
    expect(
      GeometryFamily.values.map((family) => family.level).reduce(max),
      maxGeometryLevel,
    );
  });

  test('every triangle obeys the plan: whole sides 2 to 12, strict triangle '
      'inequality, every angle at least 20°, longest at most 4 times the '
      'shortest', () {
    for (final params in GeometryFamily.trianglePerimeter.space) {
      final sides = [...params]..sort();
      final [a, b, c] = sides;
      expect(a, greaterThanOrEqualTo(2));
      expect(c, lessThanOrEqualTo(12));
      expect(a + b, greaterThan(c));
      expect(c, lessThanOrEqualTo(4 * a));
      final corners = GeometryFamily.trianglePerimeter
          .build(params)
          .figure
          .vertices;
      for (var i = 0; i < 3; i++) {
        final u = corners[(i + 1) % 3] - corners[i];
        final v = corners[(i + 2) % 3] - corners[i];
        final angle = acos(
          (u.dx * v.dx + u.dy * v.dy) / (u.distance * v.distance),
        );
        expect(angle * 180 / pi, greaterThanOrEqualTo(20), reason: '$params');
      }
    }
  });

  test('rectangles have sides 1 to 12, unequal for the perimeter, 1 to 10 '
      'for the area, the longer at most 4 times the shorter', () {
    for (final family in [
      GeometryFamily.rectanglePerimeter,
      GeometryFamily.rectangleArea,
      GeometryFamily.rectangleSideFromPerimeter,
      GeometryFamily.rectangleSideFromArea,
    ]) {
      for (final [width, height] in family.space) {
        final (shorter, longer) = (min(width, height), max(width, height));
        expect(shorter, greaterThanOrEqualTo(1));
        expect(longer, lessThanOrEqualTo(family.level == 2 ? 10 : 12));
        expect(longer, lessThanOrEqualTo(4 * shorter));
        if (family.level != 2) expect(width, isNot(height));
      }
    }
  });

  test('every angle drawn is whole and at least 20°, in a right angle at '
      'least 10°', () {
    for (final family in [
      GeometryFamily.triangleAngle,
      GeometryFamily.straightAngle,
      GeometryFamily.rightAngle,
    ]) {
      final least = family == GeometryFamily.rightAngle ? 10 : 20;
      for (final params in family.space) {
        final (:figure, :answer) = family.build(params);
        final angles = [
          for (final angle in figure.angles) angle.degrees ?? answer ~/ 100,
        ];
        expect(answer % 100, 0);
        expect(angles.every((a) => a >= least), isTrue, reason: '$params');
        expect(
          angles.reduce((a, b) => a + b),
          family == GeometryFamily.rightAngle ? 90 : 180,
        );
      }
    }
  });

  test('right triangles: legs 1 to 12, every angle at least 20°, the '
      'hypotenuse without a number', () {
    for (final [a, b] in GeometryFamily.rightTriangleArea.space) {
      expect([a, b].every((leg) => leg >= 1 && leg <= 12), isTrue);
      expect(atan(min(a, b) / max(a, b)) * 180 / pi, greaterThanOrEqualTo(20));
      final (:figure, :answer) = GeometryFamily.rightTriangleArea.build([a, b]);
      expect(figure.labels.map((label) => label.edge), unorderedEquals([0, 2]));
      expect(answer, a * b * 50);
    }
  });

  test('L-shapes: outer sides 4 to 12, wider than tall, every edge at least '
      'a quarter of the width', () {
    for (final [width, height, cutWidth, cutHeight]
        in GeometryFamily.lShapeArea.space) {
      expect([width, height].every((s) => s >= 4 && s <= 12), isTrue);
      expect(width, greaterThan(height));
      final edges = [
        width - cutWidth,
        cutHeight,
        cutWidth,
        height - cutHeight,
        width,
        height,
      ];
      expect(
        edges.every((e) => e >= 1 && 4 * e >= max(width, height)),
        isTrue,
        reason: '$edges',
      );
    }
    expect(
      GeometryFamily.lShapePerimeter.space,
      GeometryFamily.lShapeArea.space,
    );
  });

  test('halves: sides 0.5 to 12 in halves, at least one not whole, unequal, '
      'the longer at most 4 times the shorter', () {
    for (final [width, height] in GeometryFamily.halvesRectangleArea.space) {
      expect([width, height].every((s) => s >= 1 && s <= 24), isTrue);
      expect(width.isOdd || height.isOdd, isTrue);
      expect(width, isNot(height));
      expect(max(width, height), lessThanOrEqualTo(4 * min(width, height)));
    }
  });

  test('circle answers are 314 × d and 314 × r × r hundredths, never '
      'floating point', () {
    for (final [d] in GeometryFamily.circleCircumference.space) {
      expect(GeometryFamily.circleCircumference.build([d]).answer, 314 * d);
    }
    for (final [r] in GeometryFamily.circleArea.space) {
      expect(GeometryFamily.circleArea.build([r]).answer, 314 * r * r);
    }
    // In doubles 3.14 * 3 * 3 is 28.259999999999998.
    expect(GeometryFamily.circleArea.build([3]).answer, 2826);
  });

  test('Pythagoras: the six whole-number triples with sides up to 20, '
      'both leg orders, also for the diagonal', () {
    const triples = [
      (3, 4, 5),
      (6, 8, 10),
      (5, 12, 13),
      (9, 12, 15),
      (8, 15, 17),
      (12, 16, 20),
    ];
    final legs = {
      for (final (a, b, _) in triples) (a, b),
      for (final (a, b, _) in triples) (b, a),
    };
    int longest(int a, int b) =>
        triples.firstWhere((t) => {t.$1, t.$2}.containsAll({a, b})).$3;
    for (final family in [
      GeometryFamily.pythagorasHypotenuse,
      GeometryFamily.pythagorasLeg,
      GeometryFamily.rectangleDiagonal,
    ]) {
      final space = {for (final [a, b] in family.space) (a, b)};
      expect(space, hasLength(family.space.length));
      expect(space, legs);
      for (final [a, b] in family.space) {
        final c = longest(a, b);
        // Integer arithmetic only: a whole-number right triangle.
        expect(a * a + b * b, c * c);
        expect(family.build([a, b]).answer, switch (family) {
          GeometryFamily.pythagorasLeg => b * 100,
          _ => c * 100,
        });
      }
    }
  });

  test('crossing lines: the given angle 20° to 160°, the asked one '
      'opposite (equal) or a neighbour (180° minus)', () {
    final space = GeometryFamily.verticallyOppositeAngles.space;
    expect(space.map((p) => p[0]).toSet(), {for (var a = 20; a <= 160; a++) a});
    for (final [a, neighbour] in space) {
      final (:figure, :answer) = GeometryFamily.verticallyOppositeAngles.build([
        a,
        neighbour,
      ]);
      expect(figure.angles.first.degrees, a);
      expect(answer, (neighbour == 1 ? 180 - a : a) * 100);
    }
  });

  test('angles around a point: three angles 20° to 170° in steps of 5°, '
      'adding up to 360°', () {
    for (final params in GeometryFamily.anglesAroundPoint.space) {
      final (:figure, :answer) = GeometryFamily.anglesAroundPoint.build(params);
      final angles = [...params, answer ~/ 100];
      expect(answer % 500, 0, reason: '$params');
      expect(angles, hasLength(3));
      expect(angles.reduce((a, b) => a + b), 360);
      expect(
        angles.every((a) => a >= 20 && a <= 170 && a % 5 == 0),
        isTrue,
        reason: '$params',
      );
      expect(figure.angles.last.degrees, isNull);
    }
  });

  test('outside angle: whole inside angles a and b, every drawn angle at '
      'least 20°, the outside angle a + b 66° to 160°', () {
    final space = GeometryFamily.exteriorAngle.space;
    expect({for (final [a, b, _] in space) (a, b)}, hasLength(7030));
    for (final [a, b, form] in space) {
      final (:figure, :answer) = GeometryFamily.exteriorAngle.build([
        a,
        b,
        form,
      ]);
      expect([a, b, 180 - a - b].every((angle) => angle >= 20), isTrue);
      expect(a + b, inInclusiveRange(66, 160));
      expect(answer, (form == 0 ? a + b : b) * 100);
      expect(figure.extension, isNotNull);
      expect(
        figure.angles.where((angle) => angle.degrees == null),
        hasLength(1),
      );
    }
  });

  test('isosceles: the top 20° to 140° (even, so the base angles are '
      'whole) or a base angle 20° to 80°', () {
    for (final [angle, form] in GeometryFamily.isoscelesTriangle.space) {
      final (:figure, :answer) = GeometryFamily.isoscelesTriangle.build([
        angle,
        form,
      ]);
      final base = form == 0 ? (180 - angle) ~/ 2 : angle;
      final top = 180 - 2 * base;
      expect(base + base + top, 180);
      expect(base, greaterThanOrEqualTo(20), reason: '$angle');
      expect(top, inInclusiveRange(20, 140), reason: '$angle');
      if (form == 0) expect(angle.isEven, isTrue);
      expect(answer, (form == 0 ? base : top) * 100);
      expect(figure.ticks, [0, 1]);
    }
  });

  test('quadrilaterals: four angles 20° to 160° in steps of 10°, adding up '
      'to 360°, the fourth asked', () {
    for (final params in GeometryFamily.quadrilateralAngles.space) {
      final (:figure, :answer) = GeometryFamily.quadrilateralAngles.build(
        params,
      );
      final angles = [...params, answer ~/ 100];
      expect(angles.reduce((a, b) => a + b), 360);
      expect(
        angles.every((a) => a >= 20 && a <= 160 && a % 10 == 0),
        isTrue,
        reason: '$params',
      );
      expect(figure.angles.last, const AngleLabel(3, null));
    }
    // With the left-out ones, every combination in steps of 10°.
    expect(
      GeometryFamily.quadrilateralAngles.space.length +
          quadrilateralsLeftOut.length,
      2255,
    );
  });

  test('each left-out quadrilateral breaks a layout rule, does not read or '
      'has a label pushed away from its angle on some card', () {
    for (final code in quadrilateralsLeftOut) {
      final [a, b, c] = [for (final unit in code.codeUnits) (unit - 95) * 10];
      expect(
        () => GeometryFamily.quadrilateralAngles.build([a, b, c]),
        throwsArgumentError,
      );
      // Drawn as the family would draw it.
      final figure = Figure(
        shape: FigureShape.quadrilateral,
        vertices: quadrilateralCorners(a, b, c),
        labels: const [],
        angles: [
          AngleLabel(0, a),
          AngleLabel(1, b),
          AngleLabel(2, c),
          const AngleLabel(3, null),
        ],
        prompt: FigurePrompt.angle,
      );
      bool broken(Size canvas, double scale) {
        final drawn = layoutFigure(figure, canvas, measures[scale]!);
        final boxes = [for (final label in drawn.labels) label.box];
        if (drawnEdges(drawn).any((e) => (e.$2 - e.$1).distance < 16) ||
            [for (var i = 0; i < 4; i++) fromAngle(figure, drawn, i)]
                .any((near) => near > 16.5) ||
            [
              for (final (i, box) in boxes.indexed)
                for (final other in boxes.skip(i + 1)) box.overlaps(other),
            ].contains(true)) {
          return true;
        }
        try {
          checkFigure(
            figure.shape,
            figure.prompt,
            drawn,
            (360 - a - b - c) * 100,
          );
          return false;
        } on OracleFailure {
          return true;
        }
      }

      expect(
        [
          for (final scale in scales)
            for (final canvas in canvases[scale]!) broken(canvas, scale),
        ].contains(true),
        isTrue,
        reason: '$code [$a, $b, $c] fits now',
      );
    }
  });

  test('build rejects parameters outside the space', () {
    for (final (family, params) in [
      (GeometryFamily.squarePerimeter, [0]),
      (GeometryFamily.squarePerimeter, [13]),
      (GeometryFamily.rectanglePerimeter, [5, 5]),
      (GeometryFamily.rectanglePerimeter, [1, 5]),
      (GeometryFamily.trianglePerimeter, [10, 2, 8]),
      (GeometryFamily.trianglePerimeter, [3, 4, 5]),
      (GeometryFamily.trianglePerimeter, [12, 3, 10]),
      (GeometryFamily.rectangleArea, [11, 10]),
      (GeometryFamily.rectangleArea, [1, 5]),
      (GeometryFamily.rectangleArea, [3]),
      (GeometryFamily.squareSideFromArea, [13]),
      (GeometryFamily.rectangleSideFromPerimeter, [4, 4]),
      (GeometryFamily.rectangleSideFromArea, [1, 5]),
      (GeometryFamily.triangleAngle, [19, 60]),
      (GeometryFamily.triangleAngle, [80, 81]),
      (GeometryFamily.triangleAngle, [50]),
      (GeometryFamily.straightAngle, [161]),
      (GeometryFamily.rightAngle, [9]),
      (GeometryFamily.rightAngle, [81]),
      (GeometryFamily.rightTriangleArea, [1, 3]),
      (GeometryFamily.rightTriangleArea, [13, 12]),
      (GeometryFamily.lShapeArea, [12, 12, 1, 6]),
      (GeometryFamily.lShapeArea, [3, 4, 1, 1]),
      (GeometryFamily.lShapePerimeter, [8, 8, 8, 4]),
      (GeometryFamily.halvesRectangleArea, [4, 6]),
      (GeometryFamily.halvesRectangleArea, [1, 5]),
      (GeometryFamily.halvesRectanglePerimeter, [25, 23]),
      (GeometryFamily.circleCircumference, [0]),
      (GeometryFamily.circleCircumference, [21]),
      (GeometryFamily.circleArea, [11]),
      (GeometryFamily.circleArea, [5, 5]),
      (GeometryFamily.pythagorasHypotenuse, [3, 5]),
      (GeometryFamily.pythagorasHypotenuse, [4, 4]),
      (GeometryFamily.pythagorasLeg, [15, 20]),
      (GeometryFamily.pythagorasLeg, [3]),
      (GeometryFamily.rectangleDiagonal, [7, 24]),
      (GeometryFamily.verticallyOppositeAngles, [19, 0]),
      (GeometryFamily.verticallyOppositeAngles, [50, 2]),
      (GeometryFamily.verticallyOppositeAngles, [161, 1]),
      (GeometryFamily.anglesAroundPoint, [180, 90]),
      (GeometryFamily.anglesAroundPoint, [100, 101]),
      (GeometryFamily.anglesAroundPoint, [15, 175]),
      (GeometryFamily.anglesAroundPoint, [90, 90, 90]),
      (GeometryFamily.exteriorAngle, [19, 60, 0]),
      (GeometryFamily.exteriorAngle, [100, 61, 0]),
      (GeometryFamily.exteriorAngle, [50, 60, 2]),
      (GeometryFamily.exteriorAngle, [50, 60]),
      (GeometryFamily.isoscelesTriangle, [41, 0]),
      (GeometryFamily.isoscelesTriangle, [142, 0]),
      (GeometryFamily.isoscelesTriangle, [18, 0]),
      (GeometryFamily.isoscelesTriangle, [81, 1]),
      (GeometryFamily.isoscelesTriangle, [19, 1]),
      (GeometryFamily.isoscelesTriangle, [60, 2]),
      (GeometryFamily.quadrilateralAngles, [85, 95, 90]),
      (GeometryFamily.quadrilateralAngles, [170, 100, 30]),
      (GeometryFamily.quadrilateralAngles, [20, 20, 20]),
      (GeometryFamily.quadrilateralAngles, [100, 100]),
      (GeometryFamily.quadrilateralAngles, [20, 70, 160]),
      (GeometryFamily.exteriorAngle, [20, 20, 0]),
      (GeometryFamily.exteriorAngle, [40, 25, 1]),
    ]) {
      expect(
        () => family.build(params),
        throwsArgumentError,
        reason: '$family $params',
      );
    }
  });

  test('the oracle solves textbook figures', () {
    // Worked by hand: a 5 by 3 rectangle has perimeter 16 and area 15; a
    // square of side 7 perimeter 28; a 3-4-5 triangle perimeter 12 (its
    // smallest angle is about 37°, but the generator keeps the base
    // longest, so it is drawn as base 5, left 3, right 4).
    void solves(GeometryFamily family, List<int> params, int hundredths) {
      final (:figure, :answer) = family.build(params);
      expect(answer, hundredths, reason: '$family $params');
      expect(
        checkFigure(figure.shape, figure.prompt, layout(figure), hundredths),
        hundredths,
      );
    }

    solves(GeometryFamily.rectanglePerimeter, [5, 3], 1600);
    solves(GeometryFamily.rectangleArea, [5, 3], 1500);
    solves(GeometryFamily.squarePerimeter, [7], 2800);
    solves(GeometryFamily.trianglePerimeter, [5, 3, 4], 1200);
    // A perimeter of 16 with one side 5: the other is 16 ÷ 2 − 5 = 3. An
    // area of 15 with one side 5: 15 ÷ 5 = 3. A square of area 49: 7.
    solves(GeometryFamily.rectangleSideFromPerimeter, [5, 3], 300);
    solves(GeometryFamily.rectangleSideFromArea, [5, 3], 300);
    solves(GeometryFamily.squareSideFromPerimeter, [7], 700);
    solves(GeometryFamily.squareSideFromArea, [7], 700);
    // 180 − 50 − 60 = 70; on a line 180 − 35 = 145; in a corner 90 − 30.
    solves(GeometryFamily.triangleAngle, [50, 60], 7000);
    solves(GeometryFamily.straightAngle, [35], 14500);
    solves(GeometryFamily.rightAngle, [30], 6000);
    // Legs 6 and 4: 6 × 4 ÷ 2 = 12; legs 3 and 5: 7.5.
    solves(GeometryFamily.rightTriangleArea, [6, 4], 1200);
    solves(GeometryFamily.rightTriangleArea, [3, 5], 750);
    // An 8 by 6 L-shape missing a 3 by 2 corner: perimeter 28, area 42.
    solves(GeometryFamily.lShapePerimeter, [8, 6, 3, 2], 2800);
    solves(GeometryFamily.lShapeArea, [8, 6, 3, 2], 4200);
    // 2.5 by 1.5: perimeter 8, area 3.75.
    solves(GeometryFamily.halvesRectanglePerimeter, [5, 3], 800);
    solves(GeometryFamily.halvesRectangleArea, [5, 3], 375);
    // With π = 3.14: diameter 6 gives 18.84, radius 5 gives 78.5.
    solves(GeometryFamily.circleCircumference, [6], 1884);
    solves(GeometryFamily.circleArea, [5], 7850);
    // Legs 3 and 4: 9 + 16 = 25 = 5 × 5. Leg 12 and longest side 13:
    // 169 − 144 = 25, so the other leg is 5. A 6 by 8 rectangle has a
    // diagonal of 10 (36 + 64 = 100).
    solves(GeometryFamily.pythagorasHypotenuse, [3, 4], 500);
    solves(GeometryFamily.pythagorasHypotenuse, [15, 8], 1700);
    solves(GeometryFamily.pythagorasLeg, [12, 5], 500);
    solves(GeometryFamily.pythagorasLeg, [16, 12], 1200);
    solves(GeometryFamily.rectangleDiagonal, [6, 8], 1000);
    // Crossing lines with 50°: the opposite angle is 50, a neighbour 130.
    solves(GeometryFamily.verticallyOppositeAngles, [50, 0], 5000);
    solves(GeometryFamily.verticallyOppositeAngles, [50, 1], 13000);
    // Around a point with 100° and 150°: 360 − 250 = 110.
    solves(GeometryFamily.anglesAroundPoint, [100, 150], 11000);
    // Inside angles 50° and 60°: the outside angle is 110; from the
    // outside angle 110 and 50, the other inside angle is 60.
    solves(GeometryFamily.exteriorAngle, [50, 60, 0], 11000);
    solves(GeometryFamily.exteriorAngle, [50, 60, 1], 6000);
    solves(GeometryFamily.exteriorAngle, [70, 30, 1], 3000);
    // Isosceles with a 40° top: (180 − 40) ÷ 2 = 70; with 70° at the
    // bottom: 180 − 140 = 40.
    solves(GeometryFamily.isoscelesTriangle, [40, 0], 7000);
    solves(GeometryFamily.isoscelesTriangle, [70, 1], 4000);
    // A quadrilateral with 80°, 100° and 70°: 360 − 250 = 110; a
    // rectangle: 90.
    solves(GeometryFamily.quadrilateralAngles, [80, 100, 70], 11000);
    solves(GeometryFamily.quadrilateralAngles, [90, 90, 90], 9000);
    expect(parseHundredths('2.5'), 250);
    expect(parseHundredths('12'), 1200);
    expect(parseHundredths('?'), isNull);
  });

  group('mutations the oracle must catch', () {
    void mustFail(void Function() check, String why) =>
        expect(check, throwsA(isA<OracleFailure>()), reason: why);

    test('answer + 1', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        mustFail(
          () => checkFigure(
            figure.shape,
            figure.prompt,
            layout(figure),
            answer + 100,
          ),
          '$family $params',
        );
        mustFail(
          () => checkFigure(
            figure.shape,
            figure.prompt,
            layout(figure),
            answer + 1,
          ),
          '$family $params',
        );
      }
    });

    test('a label value changed: a length by 1, an angle by 1°', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        for (var i = 0; i < figure.labels.length; i++) {
          final labels = [...figure.labels];
          final value = labels[i].hundredths;
          if (value == null) continue;
          labels[i] = SideLabel(labels[i].edge, value + 100);
          final changed = copy(figure, labels: labels);
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              layout(changed),
              answer,
            ),
            '$family $params label $i',
          );
        }
        for (var i = 0; i < figure.angles.length; i++) {
          final angles = [...figure.angles];
          final value = angles[i].degrees;
          if (value == null) continue;
          angles[i] = AngleLabel(angles[i].corner, value + 1);
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              layout(copy(figure, angles: angles)),
              answer,
            ),
            '$family $params angle $i',
          );
        }
      }
    });

    test('a label moved to the next edge or angle', () {
      // On a square every edge has the same length, and a circle has one
      // line, so a moved label still tells the truth there.
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        if (figure.shape == FigureShape.square ||
            figure.shape == FigureShape.circle) {
          continue;
        }
        // Lines crossing at 90° make four equal angles.
        if (family == GeometryFamily.verticallyOppositeAngles &&
            params[0] == 90) {
          continue;
        }
        // An isosceles triangle with a 60° angle has three equal angles.
        if (family == GeometryFamily.isoscelesTriangle && params[0] == 60) {
          continue;
        }
        final Figure moved;
        if (figure.labels.isEmpty) {
          final angles = [...figure.angles];
          final rays = figure.shape != FigureShape.triangle;
          angles[0] = AngleLabel(
            rays ? 3 - angles[0].corner : (angles[0].corner + 1) % 3,
            angles[0].degrees,
          );
          moved = copy(figure, angles: angles);
        } else {
          final count = figure.vertices.length;
          final labels = [...figure.labels];
          labels[0] = SideLabel(
            (labels[0].edge + 1) % count,
            labels[0].hundredths,
          );
          moved = copy(figure, labels: labels);
        }
        mustFail(
          () => checkFigure(figure.shape, figure.prompt, layout(moved), answer),
          '$family $params',
        );
      }
    });

    test('a label box drawn at another edge or angle', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        if (figure.shape == FigureShape.square) continue;
        final drawn = layout(figure);
        if (drawn.labels.length < 2) continue;
        // The first label's box swaps places with the second's.
        final labels = [...drawn.labels];
        labels[0] = PlacedLabel(labels[0].text, drawn.labels[1].box);
        labels[1] = PlacedLabel(labels[1].text, drawn.labels[0].box);
        // Swapping two equal numbers changes nothing a child can see, also
        // when the ? stands for the same number.
        String value(PlacedLabel label) => label.text != '?'
            ? label.text
            : figure.prompt == FigurePrompt.angle
            ? '${answer ~/ 100}°'
            : formatHundredths(answer, 'en');
        if (value(labels[0]) == value(labels[1])) continue;
        mustFail(
          () => checkFigure(
            figure.shape,
            figure.prompt,
            redrawn(drawn, labels: labels),
            answer,
          ),
          '$family $params',
        );
      }
    });

    test('the figure stretched by 20% in one direction', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        // A circle has one length: any size of it is to scale.
        if (figure.shape == FigureShape.circle) continue;
        for (final stretch in [const Offset(1.2, 1), const Offset(1, 1.2)]) {
          // A ray nearly square to the line turns by less than a degree:
          // no drawn angle changes by a whole degree.
          if (layout(figure).rays) {
            double turn(Offset v) {
              final d =
                  atan2(v.dy * stretch.dy, v.dx * stretch.dx) -
                  atan2(v.dy, v.dx);
              return (d + 3 * pi) % (2 * pi) - pi;
            }

            if (figure.vertices
                .skip(1)
                .every((v) => turn(v).abs() * 180 / pi < 1)) {
              continue;
            }
          }
          Offset stretchOf(Offset v) =>
              Offset(v.dx * stretch.dx, v.dy * stretch.dy);
          // A shape with angles only and every side along x or y (a
          // rectangle drawn as a quadrilateral) keeps its angles.
          final corners = figure.vertices;
          if (figure.labels.isEmpty &&
              !layout(figure).rays &&
              [
                for (var i = 0; i < corners.length; i++)
                  corners[(i + 1) % corners.length] - corners[i],
              ].every((d) => d.dx.abs() < 1e-9 || d.dy.abs() < 1e-9)) {
            continue;
          }
          final stretched = copy(
            figure,
            vertices: [for (final v in figure.vertices) stretchOf(v)],
            extension: switch (figure.extension) {
              final end? => stretchOf(end),
              null => null,
            },
          );
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              layout(stretched),
              answer,
            ),
            '$family $params $stretch',
          );
        }
      }
    });

    test('prompt keys swapped', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        for (final other in FigurePrompt.values) {
          if (other == figure.prompt) continue;
          mustFail(
            () => checkFigure(figure.shape, other, layout(figure), answer),
            '$family $params $other',
          );
        }
      }
    });

    test('a needed label hidden', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        for (var i = 0; i < figure.labels.length; i++) {
          final hidden = copy(figure, labels: [...figure.labels]..removeAt(i));
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              layout(hidden),
              answer,
            ),
            '$family $params label $i',
          );
        }
        for (var i = 0; i < figure.angles.length; i++) {
          final hidden = copy(figure, angles: [...figure.angles]..removeAt(i));
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              layout(hidden),
              answer,
            ),
            '$family $params angle $i',
          );
        }
      }
    });

    test('hiding one needed L-shape label fails the label solver', () {
      for (final family in [
        GeometryFamily.lShapePerimeter,
        GeometryFamily.lShapeArea,
      ]) {
        for (final params in family.space) {
          final figure = family.build(params).figure;
          expect(figure.labels, hasLength(4));
          for (var i = 0; i < 4; i++) {
            final hidden = copy(
              figure,
              labels: [...figure.labels]..removeAt(i),
            );
            mustFail(
              () => solveFigure(figure.shape, figure.prompt, layout(hidden)),
              '$family $params label $i',
            );
          }
        }
      }
    });

    test('a grid square removed', () {
      for (final params in GeometryFamily.rectangleArea.space) {
        final (:figure, :answer) = GeometryFamily.rectangleArea.build(params);
        final drawn = layout(figure);
        // A single unit square has no inner line to remove.
        if (drawn.gridLines.isEmpty) continue;
        mustFail(
          () => checkFigure(
            figure.shape,
            figure.prompt,
            redrawn(drawn, gridLines: drawn.gridLines.sublist(1)),
            answer,
          ),
          '$params',
        );
      }
    });

    test('an angle arc or the right-angle square removed', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        final drawn = layout(figure);
        for (var i = 0; i < drawn.marks.length; i++) {
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              redrawn(drawn, marks: [...drawn.marks]..removeAt(i)),
              answer,
            ),
            '$family $params mark $i',
          );
        }
      }
    });

    test('the radius and diameter cues swapped', () {
      for (final family in [
        GeometryFamily.circleCircumference,
        GeometryFamily.circleArea,
      ]) {
        for (final params in family.space) {
          final (:figure, :answer) = family.build(params);
          final radius = figure.vertices.contains(figure.centre);
          final r = (figure.vertices[1] - figure.centre!).distance;
          final swapped = copy(
            figure,
            vertices: radius
                ? [Offset(-r, 0), Offset(r, 0)]
                : [Offset.zero, Offset(r, 0)],
          );
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              layout(swapped),
              answer,
            ),
            '$family $params',
          );
        }
      }
    });

    test('the π line removed or changed', () {
      for (final family in [
        GeometryFamily.circleCircumference,
        GeometryFamily.circleArea,
      ]) {
        for (final params in family.space) {
          final (:figure, :answer) = family.build(params);
          final drawn = layout(figure);
          expect(drawn.pi, '3.14');
          for (final mutant in [
            redrawn(drawn, keepPi: false),
            redrawn(drawn, pi: '3'),
            redrawn(drawn, pi: '3.15'),
          ]) {
            mustFail(
              () => checkFigure(figure.shape, figure.prompt, mutant, answer),
              '$family $params ${mutant.pi}',
            );
          }
        }
      }
    });

    test('the missing side ? moved, or the given total changed', () {
      for (final family in [
        GeometryFamily.squareSideFromPerimeter,
        GeometryFamily.squareSideFromArea,
        GeometryFamily.rectangleSideFromPerimeter,
        GeometryFamily.rectangleSideFromArea,
      ]) {
        for (final params in family.space) {
          final (:figure, :answer) = family.build(params);
          final asked = figure.labels.indexWhere((l) => l.hundredths == null);
          final mutants = [
            copy(figure, total: figure.total! + 100),
            // A rectangle's ? onto the labelled side or the side across
            // from it; a square's sides are all equal.
            if (figure.shape == FigureShape.rectangle)
              for (final edge in [0, 2])
                copy(
                  figure,
                  labels: [...figure.labels]..[asked] = SideLabel(edge, null),
                ),
          ];
          for (final mutant in mutants) {
            mustFail(
              () => checkFigure(
                figure.shape,
                figure.prompt,
                layout(mutant),
                answer,
              ),
              '$family $params',
            );
          }
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              redrawn(layout(figure), total: '0'),
              answer,
            ),
            '$family $params total 0',
          );
        }
      }
    });

    test('the diagonal removed or drawn along a side', () {
      for (final params in GeometryFamily.rectangleDiagonal.space) {
        final (:figure, :answer) = GeometryFamily.rectangleDiagonal.build(
          params,
        );
        final drawn = layout(figure);
        final corners = drawn.vertices;
        for (final mutant in [
          redrawn(drawn, keepDiagonal: false),
          layout(copy(figure, diagonal: false)),
          for (var i = 0; i < 4; i++)
            redrawn(drawn, diagonal: (corners[i], corners[(i + 1) % 4])),
        ]) {
          mustFail(
            () => checkFigure(figure.shape, figure.prompt, mutant, answer),
            '$params ${mutant.diagonal}',
          );
        }
      }
    });

    test('the ? moved to another side or angle', () {
      for (final family in [
        GeometryFamily.pythagorasHypotenuse,
        GeometryFamily.pythagorasLeg,
        GeometryFamily.rectangleDiagonal,
        GeometryFamily.verticallyOppositeAngles,
        GeometryFamily.anglesAroundPoint,
      ]) {
        for (final params in family.space) {
          final (:figure, :answer) = family.build(params);
          final mutants = <FigureLayout>[];
          if (figure.diagonal) {
            // The ? on a side, that side's number on the diagonal.
            final drawn = layout(figure);
            final asked = drawn.labels.indexWhere((l) => l.text == '?');
            for (var i = 0; i < drawn.labels.length; i++) {
              if (i == asked) continue;
              final labels = [...drawn.labels];
              labels[i] = PlacedLabel(labels[i].text, drawn.labels[asked].box);
              labels[asked] = PlacedLabel('?', drawn.labels[i].box);
              mutants.add(redrawn(drawn, labels: labels));
            }
          } else if (figure.labels.isNotEmpty) {
            // The ? and another side's number swap sides.
            final asked = figure.labels.indexWhere((l) => l.hundredths == null);
            for (var i = 0; i < figure.labels.length; i++) {
              if (i == asked) continue;
              final labels = [...figure.labels];
              labels[i] = SideLabel(
                figure.labels[asked].edge,
                labels[i].hundredths,
              );
              labels[asked] = SideLabel(figure.labels[i].edge, null);
              mutants.add(layout(copy(figure, labels: labels)));
            }
          } else {
            final count = figure.vertices.length;
            final asked = figure.angles.indexWhere((a) => a.degrees == null);
            for (var corner = 1; corner < count; corner++) {
              if (corner == figure.angles[asked].corner) continue;
              // Onto a labelled angle, that angle's number takes the ?'s
              // place; equal numbers there change nothing a child sees.
              final other = figure.angles.indexWhere((a) => a.corner == corner);
              final angles = [...figure.angles];
              angles[asked] = AngleLabel(corner, null);
              if (other >= 0) {
                final value = figure.angles[other].degrees!;
                if (value * 100 == answer) continue;
                angles[other] = AngleLabel(figure.angles[asked].corner, value);
              } else {
                // Both neighbours of the given angle are equal, and at 90°
                // all four angles are.
                final given = figure.angles.firstWhere(
                  (a) => a != figure.angles[asked],
                );
                final a = given.degrees!;
                final same = (corner - given.corner) % 4 == 2 ? a : 180 - a;
                if (same * 100 == answer) continue;
              }
              mutants.add(layout(copy(figure, angles: angles)));
            }
          }
          for (final mutant in mutants) {
            mustFail(
              () => checkFigure(figure.shape, figure.prompt, mutant, answer),
              '$family $params',
            );
          }
        }
      }
    });

    test('a ray turned by 10° with its label kept', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        if (!layout(figure).rays) continue;
        for (var ray = 1; ray < figure.vertices.length; ray++) {
          final v = figure.vertices[ray];
          const by = 10 * pi / 180;
          final vertices = [...figure.vertices];
          // Counterclockwise on screen, where y points down.
          vertices[ray] = Offset(
            v.dx * cos(by) + v.dy * sin(by),
            -v.dx * sin(by) + v.dy * cos(by),
          );
          mustFail(
            () => checkFigure(
              figure.shape,
              figure.prompt,
              layout(copy(figure, vertices: vertices)),
              answer,
            ),
            '$family $params ray $ray',
          );
        }
      }
    });
  });

  group('mutations of the outside angle, isosceles and quadrilateral '
      'figures', () {
    void mustFail(void Function() check, String why) =>
        expect(check, throwsA(isA<OracleFailure>()), reason: why);

    test('a tick mark removed or moved, or a ticked side drawn 20% longer', () {
      for (final params in GeometryFamily.isoscelesTriangle.space) {
        final (:figure, :answer) = GeometryFamily.isoscelesTriangle.build(
          params,
        );
        final drawn = layout(figure);
        final [c0, c1, c2] = figure.vertices;
        final mutants = <FigureLayout>[
          for (var i = 0; i < drawn.ticks.length; i++)
            redrawn(drawn, ticks: [...drawn.ticks]..removeAt(i)),
          redrawn(drawn, ticks: const []),
          // The left side 20% longer, so the ticked sides differ.
          layout(copy(figure, vertices: [c1 + (c0 - c1) * 1.2, c1, c2])),
          // A tick moved onto the base: another corner becomes the top.
          // With a 60° top all three angles are equal.
          if (params[0] != 60)
            for (final ticks in const [
              [1, 2],
              [0, 2],
            ])
              layout(copy(figure, ticks: ticks)),
        ];
        for (final mutant in mutants) {
          mustFail(
            () => checkFigure(figure.shape, figure.prompt, mutant, answer),
            '$params ${mutant.ticks.length} ticks',
          );
        }
      }
    });

    test('the side drawn on removed, or bent by 10°', () {
      for (final params in GeometryFamily.exteriorAngle.space) {
        final (:figure, :answer) = GeometryFamily.exteriorAngle.build(params);
        final corner = figure.vertices[2];
        final end = figure.extension! - corner;
        final mutants = [
          redrawn(layout(figure), keepExtension: false),
          for (final by in const [10 * pi / 180, -10 * pi / 180])
            layout(
              copy(
                figure,
                extension:
                    corner +
                    Offset(
                      end.dx * cos(by) - end.dy * sin(by),
                      end.dx * sin(by) + end.dy * cos(by),
                    ),
              ),
            ),
        ];
        for (final mutant in mutants) {
          mustFail(
            () => checkFigure(figure.shape, figure.prompt, mutant, answer),
            '$params ${mutant.extension}',
          );
        }
      }
    });

    test('the ? moved to another angle', () {
      for (final family in [
        GeometryFamily.exteriorAngle,
        GeometryFamily.isoscelesTriangle,
        GeometryFamily.quadrilateralAngles,
      ]) {
        for (final params in family.space) {
          final (:figure, :answer) = family.build(params);
          final asked = figure.angles.indexWhere((a) => a.degrees == null);
          final from = figure.angles[asked].corner;
          // Every corner, and the outside angle past the last one.
          final count =
              figure.vertices.length + (figure.extension == null ? 0 : 1);
          for (var corner = 0; corner < count; corner++) {
            if (corner == from) continue;
            final angles = [...figure.angles];
            angles[asked] = AngleLabel(corner, null);
            final other = figure.angles.indexWhere((a) => a.corner == corner);
            if (other >= 0) {
              // That angle's number takes the ?'s place; equal numbers
              // change nothing a child sees.
              final value = figure.angles[other].degrees!;
              if (value * 100 == answer) continue;
              angles[other] = AngleLabel(from, value);
            } else if (family == GeometryFamily.isoscelesTriangle) {
              // The angle the ? lands on, from the drawing's own numbers.
              final base = params[1] == 0 ? (180 - params[0]) ~/ 2 : params[0];
              final there = corner == 1 ? 180 - 2 * base : base;
              if (there * 100 == answer) continue;
            }
            mustFail(
              () => checkFigure(
                figure.shape,
                figure.prompt,
                layout(copy(figure, angles: angles)),
                answer,
              ),
              '$family $params ? at $corner',
            );
          }
        }
      }
    });
  });

  test('every problem of every level passes the oracle in every size, and '
      'its labels are at least 12 px, inside the canvas, apart from each '
      'other and off every corner and edge; each angle label next to its own '
      'angle and nearer its arc than any other; arcs at one point apart; '
      'the figure fills the canvas; at text scale 1 and 2, in phone and '
      'compact sizes', () {
    final watch = Stopwatch()..start();
    final checks = <int, int>{};
    var shortestEdge = double.infinity;
    var smallestSquare = double.infinity;
    // The farthest an angle label stands from its own angle, and the least
    // share of the canvas a figure fills, at each text scale.
    var farthest = 0.0;
    final least = {for (final scale in scales) scale: 1.0};
    final smallest = <double, String>{};
    for (final scale in scales) {
      expect(
        TextScaler.linear(scale).scale(style.fontSize!),
        greaterThanOrEqualTo(12),
      );
      for (final canvas in canvases[scale]!) {
        final area = Offset.zero & canvas;
        for (final (family, params) in every) {
          final (:figure, :answer) = family.build(params);
          expect(figure.grid, family.level == 2, reason: '$family $params');
          final drawn = layoutFigure(figure, canvas, measures[scale]!);
          checkFigure(figure.shape, figure.prompt, drawn, answer);
          checks.update(family.level, (n) => n + 1, ifAbsent: () => 1);
          final where = '$family $params $canvas x$scale';
          final corners = drawn.vertices;
          final edges = drawnEdges(drawn);
          for (final (a, b) in edges) {
            shortestEdge = min(shortestEdge, (b - a).distance);
          }
          if (figure.grid) {
            // One uniform scale, so the first edge gives the unit square.
            smallestSquare = min(
              smallestSquare,
              (corners[1] - corners[0]).distance /
                  (figure.vertices[1] - figure.vertices[0]).distance,
            );
          }
          for (final (i, label) in drawn.labels.indexed) {
            final text = measures[scale]!(label.text);
            expect(
              label.box.width,
              greaterThanOrEqualTo(text.width),
              reason: where,
            );
            expect(
              label.box.height,
              greaterThanOrEqualTo(text.height),
              reason: where,
            );
            expect(
              area.intersect(label.box),
              label.box,
              reason: '$where: ${label.text} leaves the canvas',
            );
            for (final other in drawn.labels.skip(i + 1)) {
              expect(
                label.box.overlaps(other.box),
                isFalse,
                reason: '$where: ${label.text} overlaps ${other.text}',
              );
            }
            final inner = label.box.deflate(.5);
            for (final (a, b) in [...edges, ...drawn.ticks]) {
              if (meets(a, b, inner)) {
                fail('$where: ${label.text} covers the outline');
              }
            }
            // A diagonal's ? stands on its middle like a textbook label and
            // leaves at least 16 px of it showing at each end; every other
            // label stays off it.
            if (drawn.diagonal case (final a, final b)) {
              final middle = (a + b) / 2;
              if (label.text == '?' &&
                  (label.box.center - middle).distance < .5) {
                for (final end in [a, b]) {
                  var t = 0.0;
                  while (label.box.contains(Offset.lerp(middle, end, t)!)) {
                    t += 1 / 256;
                  }
                  expect(
                    (1 - t) * (end - middle).distance,
                    greaterThanOrEqualTo(16),
                    reason: '$where: the ? hides the diagonal',
                  );
                }
              } else if (meets(a, b, inner)) {
                fail('$where: ${label.text} covers the diagonal');
              }
            }
            // Inside a circle, clear of its outline.
            if (drawn.circle case final circle?) {
              final room = circle.width / 2 - drawn.strokeWidth / 2;
              for (final corner in [
                label.box.topLeft,
                label.box.topRight,
                label.box.bottomLeft,
                label.box.bottomRight,
              ]) {
                expect(
                  (corner - circle.center).distance,
                  lessThanOrEqualTo(room),
                  reason: '$where: ${label.text} crosses the circle',
                );
              }
            }
          }
          // Angle labels follow the side labels and a diagonal's ?; the
          // angle arcs come first among the marks, in the same order.
          final first = figure.labels.length + (figure.diagonal ? 1 : 0);
          for (final (i, angle) in figure.angles.indexed) {
            final label = drawn.labels[first + i];
            final mark = drawn.marks[i];
            // Next to its angle (within 16.5 px of its arc, one of its two
            // lines or its corner), or as near as it can stand clear of
            // another label: 3 px nearer its corner it would overlap one.
            final near = fromAngle(figure, drawn, i);
            final corner = angleCorner(figure, drawn, angle);
            final nearer = label.box.shift(
              Offset.fromDirection((corner - label.box.center).direction, 3),
            );
            if (near > 16.5) {
              expect(
                drawn.labels.any(
                  (other) =>
                      !identical(other, label) && other.box.overlaps(nearer),
                ),
                isTrue,
                reason: '$where: ${label.text} stands $near px from its angle',
              );
            } else {
              farthest = max(farthest, near);
            }
            // Nearer the middle of its own arc than of any other arc.
            final own = (label.box.center - arcMiddle(mark)).distance;
            for (final other in drawn.marks) {
              if (identical(other, mark) || other.right) continue;
              expect(
                (label.box.center - arcMiddle(other)).distance,
                greaterThan(own),
                reason: '$where: ${label.text} is nearer another arc',
              );
            }
          }
          // Arcs at one point never meet: those whose angles touch or
          // overlap differ in radius by at least the line width.
          final arcs = [
            for (final mark in drawn.marks)
              if (!mark.right) mark,
          ];
          for (final (i, arc) in arcs.indexed) {
            for (final other in arcs.skip(i + 1)) {
              if ((arc.centre - other.centre).distance > 1) continue;
              (double, double) span(AngleMark m) => m.sweep < 0
                  ? (m.from + m.sweep, -m.sweep)
                  : (m.from, m.sweep);
              final (start, sweep) = span(arc);
              final (otherStart, otherSweep) = span(other);
              // How far the second arc starts past the first one's start,
              // and the first past the second's.
              final ahead = (otherStart - start) % (2 * pi);
              final behind = (start - otherStart) % (2 * pi);
              final touch =
                  ahead <= sweep + .02 ||
                  behind <= otherSweep + .02 ||
                  2 * pi - ahead < .02 ||
                  2 * pi - behind < .02;
              if (touch) {
                expect(
                  (arc.radius - other.radius).abs(),
                  greaterThanOrEqualTo(thinStroke),
                  reason: '$where: two arcs at one point join',
                );
              }
            }
          }
          // The figure's corners (a circle's outline, a side drawn on) fill
          // a share of the canvas across its tighter direction.
          final extent = [
            ...corners,
            ?drawn.extension?.$2,
            if (drawn.circle case final circle?) ...[
              circle.topLeft,
              circle.bottomRight,
            ],
          ];
          final xs = extent.map((p) => p.dx);
          final ys = extent.map((p) => p.dy);
          final share = max(
            (xs.reduce(max) - xs.reduce(min)) / canvas.width,
            (ys.reduce(max) - ys.reduce(min)) / canvas.height,
          );
          if (share < least[scale]!) {
            least[scale] = share;
            smallest[scale] = where;
          }
        }
      }
    }
    // Every edge is clearly longer than the thick outline is wide, and a
    // grid square is still a square to count.
    expect(shortestEdge, greaterThanOrEqualTo(16));
    expect(smallestSquare, greaterThanOrEqualTo(8));
    // At large text the labels are twice as big, so they take more of the
    // canvas, which grows only by two lines of text.
    expect(least[1.0], greaterThanOrEqualTo(.4), reason: smallest[1.0]);
    expect(least[2.0], greaterThanOrEqualTo(.24), reason: smallest[2.0]);
    // ignore: avoid_print
    print(
      'geometry oracle and layout rules: $checks checks by level of '
      '${every.length} problems in ${watch.elapsedMilliseconds} ms; angle '
      'labels at most ${farthest.toStringAsFixed(1)} px from their angle; '
      'figures fill at least $least of the canvas',
    );
  });

  test('the label, outline, shading, grid and mark colours are readable in '
      'every colour theme', () {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        final colors = figureColors(AppTokens.of(palette, brightness));
        final where = '${palette.name} ${brightness.name}';
        // Numbers and the ? are text on the card; inside a shaded circle
        // they stand on a patch of the card.
        expect(
          contrast(colors.label, colors.card),
          greaterThanOrEqualTo(4.5),
          reason: where,
        );
        // The outline, the shaded inside and the grid on it are graphics.
        expect(
          contrast(colors.line, colors.card),
          greaterThanOrEqualTo(3),
          reason: where,
        );
        expect(
          contrast(colors.shade, colors.card),
          greaterThanOrEqualTo(3),
          reason: where,
        );
        expect(
          contrast(colors.grid, colors.shade),
          greaterThanOrEqualTo(3),
          reason: where,
        );
        // Angle arcs, the right-angle square, a circle's radius or
        // diameter and its centre, on the card and on a shaded inside.
        expect(
          contrast(markColor(colors, shaded: false), colors.card),
          greaterThanOrEqualTo(3),
          reason: where,
        );
        expect(
          contrast(markColor(colors, shaded: true), colors.shade),
          greaterThanOrEqualTo(3),
          reason: where,
        );
        // A part a hint step uses: an accent band with an edge. Core and
        // edge differ, and one of them stands out from the card, from a
        // shaded inside and from the plain outline; a highlighted label is
        // text in the edge colour on the accent.
        double best(Color background) => max(
          contrast(colors.highlight, background),
          contrast(colors.highlightEdge, background),
        );
        expect(
          contrast(colors.highlight, colors.highlightEdge),
          greaterThanOrEqualTo(4.5),
          reason: where,
        );
        for (final background in [colors.card, colors.shade, colors.line]) {
          expect(best(background), greaterThanOrEqualTo(3), reason: where);
        }
      }
    }
    // The cues differ in shape too, never by colour alone.
    expect(thickStroke, greaterThanOrEqualTo(2 * thinStroke));
    // A highlighted part is a band wider than the thick outline.
    expect(highlightCore + 2 * highlightEdgeWidth, greaterThan(thickStroke));
  });

  test('the sentence names the shape, every number shown and the question', () {
    for (final (family, params) in every) {
      final figure = family.build(params).figure;
      final sentence = figureSentence(en, figure);
      final numbers = RegExp(r'\d+(?:\.\d+)?')
          .allMatches(sentence)
          .map((m) => m[0]);
      expect(numbers, [
        for (final label in figure.labels)
          if (label.hundredths != null) label.text(),
        for (final angle in figure.angles) ?angle.degrees?.toString(),
        if (figure.total case final total?) formatHundredths(total, 'en'),
        if (figure.pi != null) '3.14',
      ], reason: sentence);
      expect(
        sentence,
        endsWith(switch (figure.prompt) {
          FigurePrompt.area when figure.pi != null => 'Area? Use π = 3.14.',
          FigurePrompt.area => 'Area?',
          FigurePrompt.perimeter => 'Perimeter?',
          FigurePrompt.sideFromPerimeter ||
          FigurePrompt.sideFromArea => 'Side?',
          FigurePrompt.angle => 'Angle?',
          FigurePrompt.circumference => 'Circumference? Use π = 3.14.',
          FigurePrompt.length => 'Length?',
        }),
        reason: sentence,
      );
    }
    String sentence(GeometryFamily family, List<int> params) =>
        figureSentence(en, family.build(params).figure);
    expect(
      sentence(GeometryFamily.rectanglePerimeter, [5, 3]),
      'Rectangle, sides 5 and 3. Perimeter?',
    );
    expect(
      sentence(GeometryFamily.squarePerimeter, [7]),
      'Square, side 7. Perimeter?',
    );
    expect(
      sentence(GeometryFamily.trianglePerimeter, [5, 3, 4]),
      'Triangle, sides 3, 4 and 5. Perimeter?',
    );
    expect(
      sentence(GeometryFamily.rectangleArea, [4, 2]),
      'Rectangle, sides 4 and 2. Area?',
    );
    expect(
      sentence(GeometryFamily.rectangleSideFromPerimeter, [5, 3]),
      'Rectangle, sides 5 and ?. The perimeter is 16. Side?',
    );
    expect(
      sentence(GeometryFamily.squareSideFromArea, [7]),
      'Square, side ?. The area is 49. Side?',
    );
    expect(
      sentence(GeometryFamily.triangleAngle, [50, 60]),
      'Triangle, angles 50° and 60°. Angle?',
    );
    expect(
      sentence(GeometryFamily.straightAngle, [35]),
      'Straight line, one angle 35°. Angle?',
    );
    expect(
      sentence(GeometryFamily.rightAngle, [30]),
      'Right angle, one part 30°. Angle?',
    );
    expect(
      sentence(GeometryFamily.rightTriangleArea, [6, 4]),
      'Right triangle, legs 4 and 6. Area?',
    );
    expect(
      sentence(GeometryFamily.lShapeArea, [8, 6, 3, 2]),
      'L-shape, sides 5, 3, 4 and 6. Area?',
    );
    expect(
      sentence(GeometryFamily.halvesRectangleArea, [5, 3]),
      'Rectangle, sides 2.5 and 1.5. Area?',
    );
    expect(
      sentence(GeometryFamily.circleCircumference, [6]),
      'Circle, diameter 6. Circumference? Use π = 3.14.',
    );
    expect(
      sentence(GeometryFamily.circleArea, [5]),
      'Circle, radius 5. Area? Use π = 3.14.',
    );
    expect(
      sentence(GeometryFamily.pythagorasHypotenuse, [3, 4]),
      'Right triangle, legs 3 and 4, longest side ?. Length?',
    );
    expect(
      sentence(GeometryFamily.pythagorasLeg, [12, 5]),
      'Right triangle, legs 12 and ?, longest side 13. Length?',
    );
    expect(
      sentence(GeometryFamily.rectangleDiagonal, [8, 6]),
      'Rectangle, sides 8 and 6, diagonal ?. Length?',
    );
    expect(
      sentence(GeometryFamily.verticallyOppositeAngles, [50, 0]),
      'Two crossing lines, one angle 50°; ? is the angle opposite it. Angle?',
    );
    expect(
      sentence(GeometryFamily.verticallyOppositeAngles, [50, 1]),
      'Two crossing lines, one angle 50°; ? is the angle next to it. Angle?',
    );
    expect(
      sentence(GeometryFamily.anglesAroundPoint, [100, 150]),
      'Around a point, angles 100° and 150°. Angle?',
    );
    expect(
      sentence(GeometryFamily.exteriorAngle, [50, 60, 0]),
      'Triangle with one side drawn longer, inside angles 50° and 60°; ? is '
      'the outside angle. Angle?',
    );
    expect(
      sentence(GeometryFamily.exteriorAngle, [50, 60, 1]),
      'Triangle with one side drawn longer, inside angle 50°, outside angle '
      '110°; ? is the other inside angle across from the outside angle. '
      'Angle?',
    );
    expect(
      sentence(GeometryFamily.isoscelesTriangle, [40, 0]),
      'Isosceles triangle (two equal sides), top angle 40°; ? is a base '
      'angle. Angle?',
    );
    expect(
      sentence(GeometryFamily.isoscelesTriangle, [70, 1]),
      'Isosceles triangle (two equal sides), base angle 70°; ? is the top '
      'angle. Angle?',
    );
    expect(
      sentence(GeometryFamily.quadrilateralAngles, [80, 100, 70]),
      'Quadrilateral, angles 80°, 100° and 70°. Angle?',
    );
  });

  test('hints: every step is data the test recomputes, its highlighted parts '
      'are the ones its calculation reads, and the answer is only in the last '
      'step unless the figure shows it', () {
    final failures = <String>[];
    var steps = 0;
    for (final (family, params) in every) {
      final (:figure, :answer) = family.build(params);
      // The answer the oracle reads off the drawing, not the generator's.
      final solved = solveFigure(figure.shape, figure.prompt, layout(figure));
      expect(solved, answer, reason: '$family $params');
      final hint = figureHint(figure);
      steps += hint.length;
      for (final problem in hintProblems(figure, hint, solved)) {
        failures.add('$family $params: $problem');
      }
      // In the sentences: the answer only in the last one, unless shown.
      final texts = [for (final step in figureSteps(figure)) step(en)];
      final answerText = formatHundredths(answer, 'en');
      final shown = {
        for (final label in figure.labels) label.text(),
        for (final angle in figure.angles) ?angle.degrees?.toString(),
        if (figure.total case final total?) formatHundredths(total, 'en'),
        if (figure.pi case final pi?) formatHundredths(pi, 'en'),
      };
      if (texts.length != hint.length) failures.add('$family $params');
      for (final text in texts.take(texts.length - 1)) {
        if (shown.contains(answerText)) continue;
        if (numberToken(answerText).hasMatch(text)) {
          failures.add('$family $params: answer early in "$text"');
        }
      }
      if (!numberToken(answerText).hasMatch(texts.last)) {
        failures.add('$family $params: no answer in "${texts.last}"');
      }
    }
    expect(failures, isEmpty);
    // ignore: avoid_print
    print('geometry hints: $steps steps of ${every.length} problems');
  });

  test('a hint with a wrong value, number, check or highlight fails the '
      'recomputation', () {
    var mutants = 0;
    void expectFails(
      GeometryFamily family,
      List<int> params,
      List<FigureStep> mutant,
      String what,
    ) {
      final (:figure, answer: _) = family.build(params);
      final solved = solveFigure(figure.shape, figure.prompt, layout(figure));
      expect(
        hintProblems(figure, mutant, solved),
        isNotEmpty,
        reason: '$family $params: $what',
      );
      mutants++;
    }

    for (final (family, params) in every) {
      final figure = family.build(params).figure;
      final hint = figureHint(figure);
      final labels = {
        for (final label in figure.labels) ?label.hundredths,
        for (final angle in figure.angles)
          if (angle.degrees case final degrees?) degrees * 100,
      };
      final earlier = <int>{};
      for (final (i, step) in hint.indexed) {
        List<FigureStep> swap(FigureStep changed) => [
          for (final (j, other) in hint.indexed) j == i ? changed : other,
        ];
        if (step.valueHundredths case final value?) {
          expectFails(
            family,
            params,
            swap(copyStep(step, valueHundredths: value + 1)),
            'step ${i + 1} value + 1',
          );
          expectFails(
            family,
            params,
            swap(
              copyStep(
                step,
                terms: [step.terms.first + 100, ...step.terms.skip(1)],
              ),
            ),
            'step ${i + 1} first term + 1',
          );
          // A label read here, and known no other way, needs its part
          // highlighted.
          final known = {...earlier, ...ruleNumbers, ?figure.total, ?figure.pi};
          if (step.terms.any((t) => labels.contains(t) && !known.contains(t))) {
            expectFails(
              family,
              params,
              swap(copyStep(step, parts: const FigureParts())),
              'step ${i + 1} without highlight',
            );
          }
        }
        if (step.numbers.isNotEmpty) {
          expectFails(
            family,
            params,
            swap(
              copyStep(step, numbers: [for (final n in step.numbers) n + 1]),
            ),
            'step ${i + 1} numbers + 0.01',
          );
        }
        if (step.check case final check?) {
          final [left, right] = check.split(' = ');
          expectFails(
            family,
            params,
            swap(
              copyStep(
                step,
                check:
                    '$left = ${formatHundredths(calculate(right) + 100, 'en')}',
              ),
            ),
            'step ${i + 1} check + 1',
          );
        }
        // A calculation step that highlights a labelled part it does not
        // read.
        if (step.terms.isNotEmpty) {
          final used = {...step.terms, ...earlier};
          for (final label in figure.labels) {
            if (label.hundredths case final value?
                when !used.contains(value) &&
                    !step.parts.edges.contains(label.edge)) {
              expectFails(
                family,
                params,
                swap(
                  copyStep(
                    step,
                    parts: FigureParts(
                      edges: {...step.parts.edges, label.edge},
                      angles: step.parts.angles,
                      rows: step.parts.rows,
                      rightAngle: step.parts.rightAngle,
                      outline: step.parts.outline,
                      inside: step.parts.inside,
                      diagonal: step.parts.diagonal,
                    ),
                  ),
                ),
                'step ${i + 1} highlights edge ${label.edge}',
              );
              break;
            }
          }
        }
        earlier.addAll([...step.numbers, ...step.terms, ?step.valueHundredths]);
      }
    }
    // ignore: avoid_print
    print('geometry hint mutants: $mutants, all caught');
  });

  test('hints in words, for one problem of some families', () {
    List<String> hint(GeometryFamily family, List<int> params) => [
      for (final step in figureSteps(family.build(params).figure)) step(en),
    ];
    const perimeter =
        'We need the distance all the way around the shape. This is called '
        'the perimeter.';
    expect(hint(GeometryFamily.rectanglePerimeter, [5, 3]), [
      perimeter,
      'A rectangle has two pairs of equal sides. A side with no number is as '
          'long as the side opposite.',
      'The top side is opposite 5, so it is 5 too.',
      'The left side is opposite 3, so it is 3 too.',
      'Add all the sides: 5 + 3 + 5 + 3 = 16. So the perimeter is 16. Check: '
          'you added 4 sides, one for every side of the shape.',
    ]);
    expect(hint(GeometryFamily.rectangleArea, [4, 2]), [
      'We need the space inside the shape. This is called the area.',
      'The area is the number of squares inside. Count them row by row.',
      'Count the squares in one row: there are 4.',
      'Now count the rows: there are 2.',
      '2 × 4 = 8. So the area is 8. Check: count all the squares one by one.',
    ]);
    expect(hint(GeometryFamily.rectangleSideFromPerimeter, [5, 3]).skip(2), [
      'Half the perimeter: 16 ÷ 2 = 8.',
      '8 − 5 = 3. So the side is 3. Check: 5 + 3 + 5 + 3 = 16.',
    ]);
    // An answer of 2 would show in "÷ 2": both calculations come last.
    expect(hint(GeometryFamily.rectangleSideFromPerimeter, [5, 2]).skip(2), [
      'So halve the perimeter, then take away the side you know.',
      '14 ÷ 2 − 5 = 2. So the side is 2. Check: 5 + 2 + 5 + 2 = 14.',
    ]);
    expect(hint(GeometryFamily.triangleAngle, [50, 60]), [
      'We need the size of the angle marked ?.',
      'The three angles inside a triangle always add up to 180°.',
      'Take away the first angle: 180 − 50 = 130.',
      '130 − 60 = 70. So the angle is 70°. Check: 50 + 60 + 70 = 180.',
    ]);
    expect(hint(GeometryFamily.lShapeArea, [8, 6, 3, 2]).skip(2), [
      'The bottom is as long as the two top parts together: 5 + 3 = 8.',
      'Left side take away right side gives the middle side: 6 − 4 = 2.',
      'The whole rectangle is 8 × 6 = 48.',
      'The cut-out corner is 3 × 2 = 6.',
      '48 − 6 = 42. So the area is 42. Check: 42 + 6 = 48.',
    ]);
    expect(hint(GeometryFamily.circleArea, [5]).skip(1), [
      'The area of a circle is π × radius × radius. Use π = 3.14.',
      'The radius goes from the middle to the edge. Here it is 5.',
      'Radius × radius: 5 × 5 = 25.',
      '3.14 × 25 = 78.5. So the area is 78.5. Check: it is a bit more than '
          '3 × 25 = 75.',
    ]);
    const pythagoras =
        "Pythagoras' theorem works in a right triangle. The square on the "
        'longest side is as big as the other two squares together.';
    expect(hint(GeometryFamily.pythagorasLeg, [15, 8]), [
      'We need the length marked ?.',
      pythagoras,
      'The square on the side 17 is 17 × 17 = 289.',
      'The square on the side 15 is 15 × 15 = 225.',
      'Take the smaller square away from the bigger one: 289 − 225 = 64.',
      'Which number times itself makes 64?',
      '8 × 8 = 64, so the length marked ? is 8.',
    ]);
    expect(hint(GeometryFamily.rectangleDiagonal, [8, 6]).take(3), [
      'We need the length marked ?.',
      'The diagonal cuts the rectangle into two right triangles. It is their '
          'longest side.',
      pythagoras,
    ]);
    expect(hint(GeometryFamily.verticallyOppositeAngles, [50, 0]), [
      'We need the size of the angle marked ?.',
      'Vertically opposite angles are equal. Each one and the angle between '
          'them make a straight line, 180°.',
      'The angle between them is the rest of the straight line: 180 − 50 = '
          '130.',
      '180 − 130 = 50. So the angle is 50°. Check: 130 + 50 = 180.',
    ]);
    expect(hint(GeometryFamily.verticallyOppositeAngles, [50, 1]).skip(1), [
      'Angles on a straight line always add up to 180°. That is half a turn.',
      'One angle is 50°. The angle marked ? is the rest of the straight line.',
      '180 − 50 = 130. So the angle is 130°. Check: 50 + 130 = 180.',
    ]);
    expect(hint(GeometryFamily.anglesAroundPoint, [100, 150]).skip(1), [
      'Angles around a point always add up to 360°. That is one full turn.',
      'Add the angles you know: 100 + 150 = 250.',
      '360 − 250 = 110. So the angle is 110°. Check: 100 + 150 + 110 = 360.',
    ]);
    const exterior =
        'The outside angle of a triangle equals the two opposite inside '
        'angles added together. It makes a straight line, 180°, with the '
        'inside angle next to it. The three inside angles also make 180°.';
    expect(hint(GeometryFamily.exteriorAngle, [50, 60, 0]), [
      'We need the size of the angle marked ?.',
      exterior,
      'The inside angles opposite the outside angle are 50° and 60°.',
      '50 + 60 = 110. So the angle is 110°. Check: 110 − 50 = 60.',
    ]);
    expect(hint(GeometryFamily.exteriorAngle, [50, 60, 1]).skip(2), [
      'The outside angle 110° is 50° and the angle marked ? together.',
      '110 − 50 = 60. So the angle is 60°. Check: 50 + 60 = 110.',
    ]);
    expect(hint(GeometryFamily.isoscelesTriangle, [40, 0]), [
      'We need the size of the angle marked ?.',
      'An isosceles triangle has two equal sides and two equal angles. The '
          'ticks mark the equal sides. Fold it in half between them, and the '
          'two bottom angles meet exactly.',
      'The two equal angles share what is left: 180 − 40 = 140.',
      '140 ÷ 2 = 70. So the angle is 70°. Check: 70 + 70 + 40 = 180.',
    ]);
    expect(hint(GeometryFamily.isoscelesTriangle, [70, 1]).skip(2), [
      'The other angle at the bottom is also 70°.',
      'Take away the first angle: 180 − 70 = 110.',
      '110 − 70 = 40. So the angle is 40°. Check: 70 + 70 + 40 = 180.',
    ]);
    expect(hint(GeometryFamily.quadrilateralAngles, [80, 100, 70]).skip(1), [
      'The four angles of a quadrilateral always add up to 360°. A line '
          'between opposite corners cuts it into two triangles. Its angles '
          'are the angles of both triangles together.',
      'Add the angles you know: 80 + 100 + 70 = 250.',
      '360 − 250 = 110. So the angle is 110°. Check: 80 + 100 + 70 + 110 = '
          '360.',
    ]);
  });

  test('each hint step highlights the parts it names', () {
    FigureParts parts(GeometryFamily family, List<int> params, int step) =>
        figureHint(family.build(params).figure)[step].parts;
    // The rectangle's top side with the bottom it is opposite.
    expect(
      parts(GeometryFamily.rectanglePerimeter, [5, 3], 2),
      const FigureParts(edges: {2, 0}),
    );
    // One row of the grid, then all of them.
    expect(
      parts(GeometryFamily.rectangleArea, [4, 2], 2),
      const FigureParts(edges: {2}, rows: {0}),
    );
    expect(
      parts(GeometryFamily.rectangleArea, [4, 2], 3),
      const FigureParts(edges: {1}, rows: {0, 1}),
    );
    // The angle taken away first, then the other and the asked one.
    expect(
      parts(GeometryFamily.triangleAngle, [50, 60], 2),
      const FigureParts(angles: {0}),
    );
    expect(
      parts(GeometryFamily.triangleAngle, [50, 60], 3),
      const FigureParts(angles: {2, 1}),
    );
    // Between two vertically opposite angles: the rays to corners 2 and 3.
    expect(
      parts(GeometryFamily.verticallyOppositeAngles, [50, 0], 2),
      const FigureParts(angles: {1}, edges: {1, 2}),
    );
    // A circle's radius, and the diagonal of a rectangle.
    expect(
      parts(GeometryFamily.circleArea, [5], 2),
      const FigureParts(edges: {0}),
    );
    expect(
      parts(GeometryFamily.rectangleDiagonal, [8, 6], 1),
      const FigureParts(diagonal: true),
    );
    // The two ticked sides; the outside angle with the given inside one.
    expect(
      parts(GeometryFamily.isoscelesTriangle, [40, 0], 1),
      const FigureParts(edges: {0, 1}),
    );
    expect(
      parts(GeometryFamily.exteriorAngle, [50, 60, 1], 2),
      const FigureParts(angles: {3, 1}),
    );
  });

  test('a hint calculation off by one hundredth fails the recomputation', () {
    expect(calculate('3.14 × 6'), 1884);
    expect(calculate('8 × 6 − 3 × 2'), 4200);
    expect(calculate('180 − 50 − 60'), 7000);
    expect(calculate('3 × 5 ÷ 2'), 750);
    expect(calculate('3.14 × 5 × 5'), isNot(calculate('78.51')));
  });

  test('numbers in labels, the prompt and hints use the language\'s decimal '
      'separator', () {
    final figure = GeometryFamily.halvesRectangleArea.build([5, 3]).figure;
    expect(figure.labels.first.text('de'), '2,5');
    final drawn = layoutFigure(
      GeometryFamily.circleArea.build([5]).figure,
      const Size(340, 210),
      measures[1.0]!,
      localeName: 'de',
    );
    expect(drawn.pi, '3,14');
    expect(
      layoutFigure(
        figure,
        const Size(340, 210),
        measures[1.0]!,
        localeName: 'de',
      ).labels.map((label) => label.text),
      ['2,5', '1,5'],
    );
  });

  test('draws stay in their level and reach every family of it', () {
    final random = Random(7);
    for (var level = 1; level <= maxGeometryLevel; level++) {
      final seen = <GeometryFamily>{};
      for (var i = 0; i < 300; i++) {
        final (family, params) = drawGeometry(random, level);
        expect(family.level, level);
        expect(family.space, contains(params));
        seen.add(family);
      }
      expect(seen, {
        for (final family in GeometryFamily.values)
          if (family.level == level) family,
      });
    }
  });

  test('figures have value equality', () {
    for (final (family, a, b) in [
      (GeometryFamily.rectangleArea, [4, 2], [2, 4]),
      (GeometryFamily.triangleAngle, [50, 60], [60, 50]),
      (GeometryFamily.circleArea, [5], [4]),
      (GeometryFamily.rectangleSideFromArea, [5, 3], [5, 4]),
      (GeometryFamily.verticallyOppositeAngles, [50, 0], [50, 1]),
      (GeometryFamily.rectangleDiagonal, [6, 8], [8, 6]),
      (GeometryFamily.exteriorAngle, [50, 60, 0], [50, 60, 1]),
      (GeometryFamily.isoscelesTriangle, [40, 0], [40, 1]),
      (GeometryFamily.quadrilateralAngles, [80, 100, 70], [80, 100, 80]),
    ]) {
      expect(family.build(a).figure, family.build(a).figure);
      expect(family.build(a).figure.hashCode, family.build(a).figure.hashCode);
      expect(family.build(a).figure, isNot(family.build(b).figure));
    }
    expect(
      GeometryFamily.circleArea.build([5]).figure,
      isNot(copy(GeometryFamily.circleArea.build([5]).figure, total: 1)),
    );
    final diagonal = GeometryFamily.rectangleDiagonal.build([6, 8]).figure;
    expect(diagonal, isNot(copy(diagonal, diagonal: false)));
    expect(diagonal.hashCode, isNot(copy(diagonal, diagonal: false).hashCode));
    final isosceles = GeometryFamily.isoscelesTriangle.build([40, 0]).figure;
    expect(isosceles, isNot(copy(isosceles, ticks: [0, 2])));
    final exterior = GeometryFamily.exteriorAngle.build([50, 60, 0]).figure;
    expect(exterior, isNot(copy(exterior, extension: Offset.zero)));
  });
}

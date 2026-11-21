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

/// The question area of the phone (320 to 412 wide) and the compact
/// layout, and the widest card: the page gutter is 16 and the card padding
/// 20 on each side, and the card is at most 640 wide.
const canvases = [
  Size(248, 210),
  Size(340, 210),
  Size(600, 210),
  Size(248, 150),
  Size(340, 150),
  Size(600, 150),
];
const scales = [1.0, 2.0];

final every = [
  for (final family in GeometryFamily.values)
    for (final params in family.space) (family, params),
];

/// The figure's edges as drawn: rays from the first corner, a circle's
/// radius or diameter, or the closed outline.
List<(Offset, Offset)> drawnEdges(FigureLayout drawn) {
  final corners = drawn.vertices;
  if (drawn.rays) {
    return [for (final end in corners.skip(1)) (corners[0], end)];
  }
  if (drawn.circle != null) return [(corners[0], corners[1])];
  return [
    for (var i = 0; i < corners.length; i++)
      (corners[i], corners[(i + 1) % corners.length]),
  ];
}

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
);

/// [figure] with some parts replaced, as a lying generator would build it.
Figure copy(
  Figure figure, {
  List<Offset>? vertices,
  List<SideLabel>? labels,
  List<AngleLabel>? angles,
  int? total,
  bool? diagonal,
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

final _calculation = RegExp(
  r'(\d+(?:\.\d+)?(?: [+−×÷] \d+(?:\.\d+)?)+) = (\d+(?:\.\d+)?)',
);

/// A number as a whole token of [text], not part of a longer number.
RegExp numberToken(String number) =>
    RegExp('(?<![\\d.])${RegExp.escape(number)}(?![\\d]|\\.\\d)');

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
  FigureLayout layout(Figure figure, [Size canvas = const Size(340, 210)]) =>
      layoutFigure(figure, canvas, measures[1.0]!);

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
      'rectangleDiagonal': 11,
    });
    expect(count(1), 276);
    expect(count(2), 84);
    expect(count(3), 240);
    expect(count(4), 8371);
    expect(count(5), 1603);
    expect(
      GeometryFamily.values.map((family) => family.level).reduce(max),
      maxGeometryLevel,
    );
  });

  test('every problem of every level passes the oracle in every size', () {
    final watch = Stopwatch()..start();
    final checks = <int, int>{};
    final times = <int, int>{};
    for (final (family, params) in every) {
      final started = watch.elapsedMicroseconds;
      final (:figure, :answer) = family.build(params);
      expect(figure.grid, family.level == 2, reason: '$family $params');
      for (final scale in scales) {
        for (final canvas in canvases) {
          final drawn = layoutFigure(figure, canvas, measures[scale]!);
          checkFigure(figure.shape, figure.prompt, drawn, answer);
          checks.update(family.level, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      times.update(
        family.level,
        (t) => t + watch.elapsedMicroseconds - started,
        ifAbsent: () => watch.elapsedMicroseconds - started,
      );
    }
    for (var level = 1; level <= maxGeometryLevel; level++) {
      // ignore: avoid_print
      print(
        'geometry oracle level $level: ${checks[level]} checks in '
        '${times[level]! ~/ 1000} ms',
      );
    }
    // ignore: avoid_print
    print(
      'geometry oracle: ${checks.values.reduce((a, b) => a + b)} checks of '
      '${every.length} problems in ${watch.elapsedMilliseconds} ms',
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
      'both leg orders; the diagonal with the same sides but 5 by 12', () {
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
      expect(
        space,
        family == GeometryFamily.rectangleDiagonal
            ? legs.difference({(5, 12)})
            : legs,
      );
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
      (GeometryFamily.rectangleDiagonal, [5, 12]),
      (GeometryFamily.rectangleDiagonal, [7, 24]),
      (GeometryFamily.verticallyOppositeAngles, [19, 0]),
      (GeometryFamily.verticallyOppositeAngles, [50, 2]),
      (GeometryFamily.verticallyOppositeAngles, [161, 1]),
      (GeometryFamily.anglesAroundPoint, [180, 90]),
      (GeometryFamily.anglesAroundPoint, [100, 101]),
      (GeometryFamily.anglesAroundPoint, [15, 175]),
      (GeometryFamily.anglesAroundPoint, [90, 90, 90]),
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
          final stretched = copy(
            figure,
            vertices: [
              for (final v in figure.vertices)
                Offset(v.dx * stretch.dx, v.dy * stretch.dy),
            ],
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

  test('labels are at least 12 px, inside the canvas, apart from each other '
      'and off every corner and edge, at text scale 1 and 2, in phone and '
      'compact sizes', () {
    final watch = Stopwatch()..start();
    var shortestEdge = double.infinity;
    var smallestSquare = double.infinity;
    for (final scale in scales) {
      expect(
        TextScaler.linear(scale).scale(style.fontSize!),
        greaterThanOrEqualTo(12),
      );
      for (final canvas in canvases) {
        final area = Offset.zero & canvas;
        for (final (family, params) in every) {
          final figure = family.build(params).figure;
          final drawn = layoutFigure(figure, canvas, measures[scale]!);
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
            for (final (a, b) in edges) {
              for (var t = 0.0; t <= 1; t += 1 / 64) {
                if (inner.contains(Offset.lerp(a, b, t)!)) {
                  fail('$where: ${label.text} covers the outline');
                }
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
              } else {
                for (var t = 0.0; t <= 1; t += 1 / 64) {
                  if (inner.contains(Offset.lerp(a, b, t)!)) {
                    fail('$where: ${label.text} covers the diagonal');
                  }
                }
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
        }
      }
    }
    // Every edge is clearly longer than the thick outline is wide, and a
    // grid square is still a square to count.
    expect(shortestEdge, greaterThanOrEqualTo(16));
    expect(smallestSquare, greaterThanOrEqualTo(8));
    // ignore: avoid_print
    print('geometry layout rules: ${watch.elapsedMilliseconds} ms');
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
      }
    }
    // The cues differ in shape too, never by colour alone.
    expect(thickStroke, greaterThanOrEqualTo(2 * thinStroke));
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
  });

  test('hints: at least two steps, every calculation right, the answer only '
      'in the last step unless the figure shows it', () {
    for (final (family, params) in every) {
      final (:figure, :answer) = family.build(params);
      final steps = [for (final step in figureSteps(figure)) step(en)];
      final where = '$family $params: $steps';
      expect(steps.length, greaterThanOrEqualTo(2), reason: where);
      final answerText = formatHundredths(answer, 'en');
      final shown = {
        for (final label in figure.labels) label.text(),
        for (final angle in figure.angles) ?angle.degrees?.toString(),
        if (figure.total case final total?) formatHundredths(total, 'en'),
        if (figure.pi case final pi?) formatHundredths(pi, 'en'),
      };
      for (final step in steps.take(steps.length - 1)) {
        if (shown.contains(answerText)) continue;
        expect(step, isNot(contains(numberToken(answerText))), reason: where);
      }
      // Every calculation in every step adds up, in exact hundredths.
      for (final step in steps) {
        for (final match in _calculation.allMatches(step)) {
          expect(
            calculate(match[1]!),
            calculate(match[2]!),
            reason: '$where: ${match[0]}',
          );
        }
      }
      // The last step's last calculation ends in the answer; for a square
      // from its area it is side × side = area, then the side.
      final last = _calculation.allMatches(steps.last).last;
      if (const {
        GeometryFamily.squareSideFromArea,
        GeometryFamily.pythagorasHypotenuse,
        GeometryFamily.pythagorasLeg,
        GeometryFamily.rectangleDiagonal,
      }.contains(family)) {
        expect(last[1], '$answerText × $answerText', reason: where);
        expect(steps.last, endsWith('is $answerText.'), reason: where);
      } else {
        expect(last[2], answerText, reason: where);
      }
    }
    List<String> hint(GeometryFamily family, List<int> params) => [
      for (final step in figureSteps(family.build(params).figure)) step(en),
    ];
    expect(hint(GeometryFamily.rectanglePerimeter, [5, 3]), [
      'The two sides without a number are as long as the sides opposite '
          'them: 5 and 3.',
      'Add all the sides: 5 + 3 + 5 + 3 = 16.',
    ]);
    expect(hint(GeometryFamily.rectangleArea, [4, 2]), [
      'Count the squares: 2 rows of 4 squares each.',
      'So 2 × 4 = 8.',
    ]);
    expect(hint(GeometryFamily.rectangleSideFromPerimeter, [5, 3]), [
      'Half the perimeter is two neighbouring sides.',
      'So 16 ÷ 2 − 5 = 3.',
    ]);
    expect(hint(GeometryFamily.rectangleSideFromArea, [5, 3]), [
      'The area is one side times the other: 5 × ? = 15.',
      'So 15 ÷ 5 = 3.',
    ]);
    expect(hint(GeometryFamily.squareSideFromPerimeter, [7]), [
      'A square has four equal sides, so divide the perimeter by four.',
      'So 28 ÷ 4 = 7.',
    ]);
    expect(hint(GeometryFamily.squareSideFromArea, [7]), [
      'The area of a square is side × side. Which number times itself '
          'makes 49?',
      '7 × 7 = 49, so the side is 7.',
    ]);
    expect(hint(GeometryFamily.triangleAngle, [50, 60]), [
      'The three angles of a triangle add up to 180°.',
      'So 180 − 50 − 60 = 70.',
    ]);
    expect(hint(GeometryFamily.straightAngle, [35]), [
      'The angles on a straight line add up to 180°.',
      'So 180 − 35 = 145.',
    ]);
    expect(hint(GeometryFamily.rightAngle, [30]), [
      'The square in the corner marks a right angle: 90°.',
      'So 90 − 30 = 60.',
    ]);
    expect(hint(GeometryFamily.rightTriangleArea, [3, 5]), [
      'A right triangle is half of a rectangle with sides 3 and 5.',
      'So 3 × 5 ÷ 2 = 7.5.',
    ]);
    expect(hint(GeometryFamily.lShapePerimeter, [8, 6, 3, 2]), [
      'The sides without a number: 5 + 3 = 8 and 6 − 4 = 2.',
      'Add all the sides: 5 + 2 + 3 + 4 + 8 + 6 = 28.',
    ]);
    expect(hint(GeometryFamily.lShapeArea, [8, 6, 3, 2]), [
      'Think of the whole rectangle, then take away the missing corner.',
      'The sides without a number: 5 + 3 = 8 and 6 − 4 = 2. So 8 × 6 − 3 × 2 '
          '= 42.',
    ]);
    expect(hint(GeometryFamily.halvesRectangleArea, [5, 3]), [
      'The area of a rectangle is one side times the other.',
      'So 2.5 × 1.5 = 3.75.',
    ]);
    expect(hint(GeometryFamily.circleCircumference, [6]), [
      'The circumference is π times the diameter. Use π = 3.14.',
      'So 3.14 × 6 = 18.84.',
    ]);
    expect(hint(GeometryFamily.circleArea, [5]), [
      'The area of a circle is π × radius × radius. Use π = 3.14.',
      'So 3.14 × 5 × 5 = 78.5.',
    ]);
    const pythagoras =
        "Pythagoras' theorem: in a right triangle, the longest side times "
        'itself equals the two other sides times themselves, added. The '
        'square on the longest side holds exactly as much as the squares on '
        'the two other sides together.';
    expect(hint(GeometryFamily.pythagorasHypotenuse, [3, 4]), [
      pythagoras,
      '3 × 3 = 9 and 4 × 4 = 16.',
      'Add them: 9 + 16 = 25.',
      'Which number times itself makes 25? 5 × 5 = 25, so the side marked ? '
          'is 5.',
    ]);
    expect(hint(GeometryFamily.pythagorasLeg, [15, 8]), [
      pythagoras,
      '17 × 17 = 289 and 15 × 15 = 225.',
      "Take away the other side's: 289 − 225 = 64.",
      'Which number times itself makes 64? 8 × 8 = 64, so the side marked ? '
          'is 8.',
    ]);
    expect(hint(GeometryFamily.rectangleDiagonal, [8, 6]), [
      'The diagonal cuts the rectangle into two right triangles, and it is '
          'their longest side.',
      pythagoras,
      '8 × 8 = 64 and 6 × 6 = 36.',
      'Add them: 64 + 36 = 100.',
      'Which number times itself makes 100? 10 × 10 = 100, so the side '
          'marked ? is 10.',
    ]);
    expect(hint(GeometryFamily.verticallyOppositeAngles, [50, 0]), [
      'Vertically opposite angles are equal: each of them and the angle '
          'between them make a straight line, 180°.',
      'The angle between them: 180 − 50 = 130.',
      'So 180 − 130 = 50.',
    ]);
    expect(hint(GeometryFamily.verticallyOppositeAngles, [50, 1]), [
      'Angles on a straight line add up to 180°: an angle and the one next '
          'to it lie along one of the lines.',
      'So 180 − 50 = 130.',
    ]);
    expect(hint(GeometryFamily.anglesAroundPoint, [100, 150]), [
      'Angles around a point add up to 360°: together they make one full '
          'turn.',
      'Add the angles you know: 100 + 150 = 250.',
      'So 360 − 250 = 110.',
    ]);
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
  });
}

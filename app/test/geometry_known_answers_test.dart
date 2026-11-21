import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/figure.dart';
import 'package:simple_math_tester/figure_view.dart';
import 'package:simple_math_tester/geometry.dart';
import 'package:simple_math_tester/operations.dart';

import 'geometry_oracle.dart';

/// Known-answer rows from Illustrative Mathematics (CC BY 4.0, see
/// docs/attributions.md), so the geometry generators and the geometry
/// oracle cannot share a wrong idea unnoticed. Each row is a figure
/// question printed on the cited page and the answer printed there;
/// nothing here is computed. Units are dropped.
///
/// - [printed]: the exercise as the page states it.
/// - [given]: the numbers the page gives, which the figure must show.
/// - [asked]: what the page asks for.
/// - [answer]: the answer the page prints.
const _rows =
    <
      ({
        String id,
        String source,
        String lesson,
        String url,
        String printed,
        List<num> given,
        FigurePrompt asked,
        num answer,
      })
    >[
      (
        id: 'G01',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 7, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/2/7/index.html',
        printed:
            'Angles SVT and TVR are supplementary; angle SVT is 117°. '
            'Angle TVR?',
        given: [117],
        asked: FigurePrompt.angle,
        answer: 63,
      ),
      (
        id: 'G03',
        source: 'IM K–5 Math',
        lesson: 'Grade 4, Unit 7, Lesson 15',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-4/unit-7/lesson-15/lesson.html',
        printed: 'A right angle split in two, one part 62°. The shaded angle?',
        given: [62],
        asked: FigurePrompt.angle,
        answer: 28,
      ),
      (
        id: 'G05',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 1, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/1/1/index.html',
        printed: 'Right triangle, base 3 ft, height 8 ft. Area?',
        given: [3, 8],
        asked: FigurePrompt.area,
        answer: 12,
      ),
      (
        id: 'G07',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 1, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/1/1/index.html',
        printed: 'Rectangle 8 units by 6 units. Area?',
        given: [8, 6],
        asked: FigurePrompt.area,
        answer: 48,
      ),
      (
        id: 'G08',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 1, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/1/1/index.html',
        printed: 'A rectangle 4 units by 3 units. Area?',
        given: [4, 3],
        asked: FigurePrompt.area,
        answer: 12,
      ),
      (
        id: 'G10',
        source: 'IM K–5 Math',
        lesson: 'Grade 3, Unit 2, Lesson 10',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-3/unit-2/lesson-10/lesson.html',
        printed: 'Rectangular wall, 6 meters by 3 meters. Area?',
        given: [6, 3],
        asked: FigurePrompt.area,
        answer: 18,
      ),
      (
        id: 'G11',
        source: 'IM K–5 Math',
        lesson: 'Grade 3, Unit 2, Lesson 5',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-3/unit-2/lesson-5/lesson.html',
        printed: '5-by-3 gridded rectangle. Area?',
        given: [5, 3],
        asked: FigurePrompt.area,
        answer: 15,
      ),
      (
        id: 'G20',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 3, Lesson 8',
        url: 'https://im.kendallhunt.com/MS/students/2/3/8/index.html',
        printed: 'Circle with radius 10 cm. Area, with π = 3.14?',
        given: [10],
        asked: FigurePrompt.area,
        answer: 314,
      ),
      (
        id: 'G22',
        source: 'IM 6–8 Math',
        lesson: 'Grade 7, Unit 3, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/2/3/index.html',
        printed: 'Circular hole with diameter 6 inches. Area?',
        given: [6],
        asked: FigurePrompt.area,
        answer: 28.26,
      ),
      (
        id: 'G24',
        source: 'IM K–5 Math',
        lesson: 'Grade 4, Unit 5, Lesson 16',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-4/unit-5/lesson-16/lesson.html',
        printed:
            'A square from two 12-inch pipe cleaners (perimeter 24). Side?',
        given: [24],
        asked: FigurePrompt.sideFromPerimeter,
        answer: 6,
      ),
      (
        id: 'G25',
        source: 'IM K–5 Math',
        lesson: 'Grade 4, Unit 5, Lesson 16',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-4/unit-5/lesson-16/lesson.html',
        printed: 'A square from one 12-inch pipe cleaner (perimeter 12). Side?',
        given: [12],
        asked: FigurePrompt.sideFromPerimeter,
        answer: 3,
      ),
      (
        id: 'G26',
        source: 'IM K–5 Math',
        lesson: 'Grade 4, Unit 5, Lesson 16',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-4/unit-5/lesson-16/lesson.html',
        printed: 'A square with a perimeter of 60 inches. Side?',
        given: [60],
        asked: FigurePrompt.sideFromPerimeter,
        answer: 15,
      ),
      (
        id: 'G27',
        source: 'IM K–5 Math',
        lesson: 'Grade 3, Unit 7, Lesson 11',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-3/unit-7/lesson-11/lesson.html',
        printed:
            'A rectangle with a perimeter of 30, two sides 10. The others?',
        given: [10, 30],
        asked: FigurePrompt.sideFromPerimeter,
        answer: 5,
      ),
      (
        id: 'G28',
        source: 'IM 6–8 Math',
        lesson: 'Grade 8, Unit 1, Lesson 14',
        url: 'https://im.kendallhunt.com/MS/students/3/1/14/index.html',
        printed: 'Angle 5 is 70°; angle 8 is supplementary to it. Angle 8?',
        given: [70],
        asked: FigurePrompt.angle,
        answer: 110,
      ),
      (
        id: 'G12',
        source: 'IM K–5 Math',
        lesson: 'Grade 3, Unit 2, Lesson 13',
        url: 'https://im.kendallhunt.com/k5/teachers/grade-3/unit-2/lesson-13/lesson.html',
        printed:
            'Patio, all right angles: bottom 3 ft, right side rises 2 ft, '
            'goes right 6 ft, up 4 ft, top 9 ft, left side 6 ft. Area?',
        given: [3, 2, 6, 4, 9, 6],
        asked: FigurePrompt.area,
        answer: 42,
      ),
      (
        id: 'G29',
        source: 'IM 6–8 Math',
        lesson: 'Grade 6, Unit 4, Family materials',
        url: 'https://im.kendallhunt.com/MS/families/1/4/index.html',
        printed: 'A rectangular room 2½ m wide with an area of 11¼ m². Length?',
        given: [2.5, 11.25],
        asked: FigurePrompt.sideFromArea,
        answer: 4.5,
      ),
    ];

/// The rows an app family builds exactly, within its parameter space: the
/// row, the family and the params read off the printed exercise.
const _built = <(String, GeometryFamily, List<int>)>[
  ('G07', GeometryFamily.rectangleArea, [8, 6]),
  ('G08', GeometryFamily.rectangleArea, [4, 3]),
  ('G10', GeometryFamily.rectangleArea, [6, 3]),
  ('G11', GeometryFamily.rectangleArea, [5, 3]),
  ('G24', GeometryFamily.squareSideFromPerimeter, [6]),
  ('G25', GeometryFamily.squareSideFromPerimeter, [3]),
  ('G27', GeometryFamily.rectangleSideFromPerimeter, [10, 5]),
  ('G01', GeometryFamily.straightAngle, [117]),
  ('G28', GeometryFamily.straightAngle, [70]),
  ('G03', GeometryFamily.rightAngle, [62]),
  ('G05', GeometryFamily.rightTriangleArea, [3, 8]),
  ('G20', GeometryFamily.circleArea, [10]),
];

/// Rows no family draws, read by the oracle alone. G22 gives a diameter
/// and asks the area (circle areas show a radius); it is the circle the
/// circumference family draws with a diameter of 6. G26's side 15 is
/// longer than 12. G12 is an L-shape cut at the bottom right with all six
/// sides labelled. G29 asks a missing side in halves.
final _oracleOnly = {
  'G22': Figure(
    shape: FigureShape.circle,
    vertices: const [Offset(0, -3), Offset(0, 3)],
    labels: const [SideLabel(0, 600)],
    prompt: FigurePrompt.area,
    centre: Offset.zero,
    pi: piHundredths,
  ),
  'G26': const Figure(
    shape: FigureShape.square,
    vertices: [Offset.zero, Offset(15, 0), Offset(15, 15), Offset(0, 15)],
    labels: [SideLabel(2, null)],
    prompt: FigurePrompt.sideFromPerimeter,
    total: 6000,
  ),
  'G12': const Figure(
    shape: FigureShape.lShape,
    vertices: [
      Offset.zero,
      Offset(9, 0),
      Offset(9, 4),
      Offset(3, 4),
      Offset(3, 6),
      Offset(0, 6),
    ],
    labels: [
      SideLabel(0, 900),
      SideLabel(1, 400),
      SideLabel(2, 600),
      SideLabel(3, 200),
      SideLabel(4, 300),
      SideLabel(5, 600),
    ],
    prompt: FigurePrompt.area,
  ),
  'G29': const Figure(
    shape: FigureShape.rectangle,
    vertices: [Offset.zero, Offset(2.5, 0), Offset(2.5, 4.5), Offset(0, 4.5)],
    labels: [SideLabel(2, 250), SideLabel(1, null)],
    prompt: FigurePrompt.sideFromArea,
    total: 1125,
  ),
};

/// Level 1 asks perimeters of squares, rectangles and triangles; the
/// pages' rows for those are a rhombus, a parallelogram, a triangle whose
/// sides are only tick marks, or print no answer.
const _levelsWithoutRow = {1};

/// Families with no built row: issue #148 found no printed answer for
/// them that the family draws exactly (L-shape and halves rows are read by
/// the oracle alone, see [_oracleOnly]). The theorem families of #165
/// (crossing lines, angles around a point, Pythagoras) have no row yet.
const _familiesWithoutRow = {
  GeometryFamily.squarePerimeter,
  GeometryFamily.rectanglePerimeter,
  GeometryFamily.trianglePerimeter,
  GeometryFamily.squareSideFromArea,
  GeometryFamily.rectangleSideFromArea,
  GeometryFamily.triangleAngle,
  GeometryFamily.lShapePerimeter,
  GeometryFamily.lShapeArea,
  GeometryFamily.halvesRectanglePerimeter,
  GeometryFamily.halvesRectangleArea,
  GeometryFamily.circleCircumference,
  GeometryFamily.verticallyOppositeAngles,
  GeometryFamily.anglesAroundPoint,
  GeometryFamily.pythagorasHypotenuse,
  GeometryFamily.pythagorasLeg,
  GeometryFamily.rectangleDiagonal,
};

void main() {
  const kind = OperationType.geometry;
  final source = kind.source as GeometrySource;
  final style = buildAppTheme(Brightness.light).textTheme.titleMedium!;
  FigureLayout layout(Figure figure) => layoutFigure(
    figure,
    const Size(340, 210),
    (text) => measureLabel(text, style, TextScaler.noScaling),
  );

  int hundredths(num printed) => (printed * 100).round();

  /// The numbers the figure shows, in hundredths: side labels, angles and
  /// the given perimeter or area.
  List<int> shown(Figure figure) => [
    for (final label in figure.labels) ?label.hundredths,
    for (final angle in figure.angles)
      if (angle.degrees case final value?) value * 100,
    ?figure.total,
  ]..sort();

  void oracleAgrees(Figure figure, num answer) {
    final drawn = layout(figure);
    expect(
      checkFigure(figure.shape, figure.prompt, drawn, hundredths(answer)),
      hundredths(answer),
    );
    expect(
      () => checkFigure(
        figure.shape,
        figure.prompt,
        drawn,
        hundredths(answer + 1),
      ),
      throwsA(isA<OracleFailure>()),
    );
  }

  test('every row has its own id and is built or read by the oracle', () {
    final ids = _rows.map((row) => row.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect({..._built.map((b) => b.$1), ..._oracleOnly.keys}, ids.toSet());
  });

  test('levels with a built row, and the levels without one', () {
    final levels = _built.map((b) => b.$2.level).toSet();
    expect(levels, {2, 3, 4, 5});
    expect(
      {for (var l = 1; l <= maxGeometryLevel; l++) l}.difference(levels),
      _levelsWithoutRow,
    );
  });

  test('families with a built row, and the families without one', () {
    expect(
      GeometryFamily.values.toSet().difference(_built.map((b) => b.$2).toSet()),
      _familiesWithoutRow,
    );
  });

  group('build and the oracle', () {
    for (final (id, family, params) in _built) {
      final row = _rows.firstWhere((row) => row.id == id);
      test('${row.id}: ${family.name} $params is "${row.printed}"', () {
        expect(
          family.space.map((p) => p.join(',')),
          contains(params.join(',')),
        );
        final problem = source.build(
          kind,
          family.name,
          params,
          level: family.level,
        )!;
        final figure = problem.figure;
        expect(
          shown(figure),
          [for (final g in row.given) hundredths(g)]..sort(),
        );
        expect(figure.prompt, row.asked);
        expect(problem.resultHundredths, hundredths(row.answer));
        oracleAgrees(figure, row.answer);
      });
    }
  });

  group('the oracle alone', () {
    _oracleOnly.forEach((id, figure) {
      final row = _rows.firstWhere((row) => row.id == id);
      test('${row.id}: "${row.printed}" is ${row.answer}', () {
        expect(
          shown(figure),
          [for (final g in row.given) hundredths(g)]..sort(),
        );
        expect(figure.prompt, row.asked);
        oracleAgrees(figure, row.answer);
      });
    });
  });
}

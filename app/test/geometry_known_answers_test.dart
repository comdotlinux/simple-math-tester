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
    ];

/// The rows an app family builds exactly, within its parameter space: the
/// row, the family and the params read off the printed exercise.
const _built = <(String, GeometryFamily, List<int>)>[
  ('G07', GeometryFamily.rectangleArea, [8, 6]),
  ('G08', GeometryFamily.rectangleArea, [4, 3]),
  ('G10', GeometryFamily.rectangleArea, [6, 3]),
  ('G11', GeometryFamily.rectangleArea, [5, 3]),
  ('G01', GeometryFamily.straightAngle, [117]),
  ('G03', GeometryFamily.rightAngle, [62]),
  ('G05', GeometryFamily.rightTriangleArea, [3, 8]),
  ('G20', GeometryFamily.circleArea, [10]),
];

/// G22 gives a diameter and asks the area; no family draws that (circle
/// areas show a radius), so only the oracle reads it, from the circle the
/// circumference family draws with a diameter of 6.
final _oracleOnly = {
  'G22': Figure(
    shape: FigureShape.circle,
    vertices: const [Offset(0, -3), Offset(0, 3)],
    labels: const [SideLabel(0, 600)],
    prompt: FigurePrompt.area,
    centre: Offset.zero,
    pi: piHundredths,
  ),
};

/// Levels 1 and 3 ask perimeters and missing sides of squares and
/// rectangles; the pages' rows for those are a rhombus, a parallelogram
/// or print no answer.
const _levelsWithoutRow = {1, 3};

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

  /// The numbers the figure shows, in hundredths: side labels and angles.
  List<int> shown(Figure figure) => [
    for (final label in figure.labels) ?label.hundredths,
    for (final angle in figure.angles)
      if (angle.degrees case final value?) value * 100,
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
    expect(levels, {2, 4, 5});
    expect(
      {for (var l = 1; l <= maxGeometryLevel; l++) l}.difference(levels),
      _levelsWithoutRow,
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
        expect(shown(figure), [for (final g in row.given) hundredths(g)]);
        expect(figure.prompt, row.asked);
        oracleAgrees(figure, row.answer);
      });
    });
  });
}

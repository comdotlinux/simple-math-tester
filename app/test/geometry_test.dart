import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/figure.dart';
import 'package:simple_math_tester/figure_view.dart';
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
    expect(GeometryFamily.squarePerimeter.space, hasLength(12));
    expect(GeometryFamily.rectanglePerimeter.space, hasLength(108));
    expect(GeometryFamily.trianglePerimeter.space, hasLength(156));
    expect(GeometryFamily.rectangleArea.space, hasLength(84));
    expect(count(1), 276);
    expect(count(2), 84);
    expect(
      GeometryFamily.values.map((family) => family.level).reduce(max),
      maxGeometryLevel,
    );
  });

  test('every problem of levels 1 and 2 passes the oracle in every size', () {
    final watch = Stopwatch()..start();
    var checks = 0;
    for (final (family, params) in every) {
      final (:figure, :answer) = family.build(params);
      expect(figure.grid, family.level == 2, reason: '$family $params');
      for (final scale in scales) {
        for (final canvas in canvases) {
          final drawn = layoutFigure(figure, canvas, measures[scale]!);
          checkFigure(figure.shape, figure.prompt, drawn, answer);
          checks++;
        }
      }
    }
    // ignore: avoid_print
    print(
      'geometry oracle: $checks checks of ${every.length} problems in '
      '${watch.elapsedMilliseconds} ms',
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
    ]) {
      for (final [width, height] in family.space) {
        final (shorter, longer) = (min(width, height), max(width, height));
        expect(shorter, greaterThanOrEqualTo(1));
        expect(longer, lessThanOrEqualTo(family.level == 1 ? 12 : 10));
        expect(longer, lessThanOrEqualTo(4 * shorter));
        if (family.level == 1) expect(width, isNot(height));
      }
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
    final rectangle = GeometryFamily.rectanglePerimeter.build([5, 3]);
    expect(rectangle.answer, 16);
    checkFigure(
      FigureShape.rectangle,
      FigurePrompt.perimeter,
      layout(rectangle.figure),
      16,
    );
    final area = GeometryFamily.rectangleArea.build([5, 3]);
    expect(area.answer, 15);
    checkFigure(
      FigureShape.rectangle,
      FigurePrompt.area,
      layout(area.figure),
      15,
    );
    final square = GeometryFamily.squarePerimeter.build([7]);
    checkFigure(
      FigureShape.square,
      FigurePrompt.perimeter,
      layout(square.figure),
      28,
    );
    final triangle = GeometryFamily.trianglePerimeter.build([5, 3, 4]);
    checkFigure(
      FigureShape.triangle,
      FigurePrompt.perimeter,
      layout(triangle.figure),
      12,
    );
    expect(parseHundredths('2.5'), 250);
    expect(parseHundredths('12'), 1200);
    expect(parseHundredths('?'), isNull);
  });

  group('mutations the oracle must catch', () {
    void mustFail(void Function() check, String why) =>
        expect(check, throwsA(isA<OracleFailure>()), reason: why);

    Figure copy(
      Figure figure, {
      List<Offset>? vertices,
      List<SideLabel>? labels,
    }) => Figure(
      shape: figure.shape,
      vertices: vertices ?? figure.vertices,
      labels: labels ?? figure.labels,
      prompt: figure.prompt,
      grid: figure.grid,
    );

    test('answer + 1', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
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

    test('a label value changed', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        for (var i = 0; i < figure.labels.length; i++) {
          final labels = [...figure.labels];
          labels[i] = SideLabel(labels[i].edge, labels[i].hundredths! + 100);
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
      }
    });

    test('a label moved to the next edge', () {
      // On a square every edge has the same length, so a moved label still
      // tells the truth; only rectangles and triangles can lie this way.
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        if (figure.shape == FigureShape.square) continue;
        final count = figure.vertices.length;
        final labels = [...figure.labels];
        labels[0] = SideLabel(
          (labels[0].edge + 1) % count,
          labels[0].hundredths,
        );
        final moved = copy(figure, labels: labels);
        mustFail(
          () => checkFigure(figure.shape, figure.prompt, layout(moved), answer),
          '$family $params',
        );
      }
    });

    test('a label box drawn at another edge', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        if (figure.shape == FigureShape.square) continue;
        final drawn = layout(figure);
        // The first label's box swaps places with the second's.
        final labels = [...drawn.labels];
        labels[0] = PlacedLabel(labels[0].text, drawn.labels[1].box);
        labels[1] = PlacedLabel(labels[1].text, drawn.labels[0].box);
        final swapped = FigureLayout(
          vertices: drawn.vertices,
          labels: labels,
          grid: drawn.grid,
          gridLines: drawn.gridLines,
          strokeWidth: drawn.strokeWidth,
          shaded: drawn.shaded,
        );
        // Swapping two equal numbers changes nothing a child can see.
        if (labels[0].text == labels[1].text) continue;
        mustFail(
          () => checkFigure(figure.shape, figure.prompt, swapped, answer),
          '$family $params',
        );
      }
    });

    test('the figure stretched by 20% in one direction', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        for (final stretch in [const Offset(1.2, 1), const Offset(1, 1.2)]) {
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

    test('perimeter and area prompt keys swapped', () {
      for (final (family, params) in every) {
        final (:figure, :answer) = family.build(params);
        final other = figure.prompt == FigurePrompt.area
            ? FigurePrompt.perimeter
            : FigurePrompt.area;
        mustFail(
          () => checkFigure(figure.shape, other, layout(figure), answer),
          '$family $params',
        );
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
      }
    });

    test('a grid square removed', () {
      for (final params in GeometryFamily.rectangleArea.space) {
        final (:figure, :answer) = GeometryFamily.rectangleArea.build(params);
        final drawn = layout(figure);
        // A single unit square has no inner line to remove.
        if (drawn.gridLines.isEmpty) continue;
        final fewer = FigureLayout(
          vertices: drawn.vertices,
          labels: drawn.labels,
          grid: drawn.grid,
          gridLines: drawn.gridLines.sublist(1),
          strokeWidth: drawn.strokeWidth,
          shaded: drawn.shaded,
        );
        mustFail(
          () => checkFigure(figure.shape, figure.prompt, fewer, answer),
          '$params',
        );
      }
    });
  });

  test('labels are at least 12 px, inside the canvas, apart from each other '
      'and off every corner and edge, at text scale 1 and 2, in phone and '
      'compact sizes', () {
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
          final edges = [
            for (var i = 0; i < corners.length; i++)
              (corners[i], corners[(i + 1) % corners.length]),
          ];
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
                expect(
                  inner.contains(Offset.lerp(a, b, t)!),
                  isFalse,
                  reason: '$where: ${label.text} covers the outline',
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
  });

  test('the label, outline, shading and grid colours are readable in '
      'every colour theme', () {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        final colors = figureColors(AppTokens.of(palette, brightness));
        final where = '${palette.name} ${brightness.name}';
        // Numbers and the ? are text on the card.
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
      }
    }
    // The cues differ in shape too, never by colour alone.
    expect(thickStroke, greaterThanOrEqualTo(2 * thinStroke));
  });

  test('the sentence names the shape, every label and the question', () {
    for (final (family, params) in every) {
      final figure = family.build(params).figure;
      final sentence = figureSentence(en, figure);
      final numbers = RegExp(r'\d+').allMatches(sentence).map((m) => m[0]);
      expect(numbers, [
        for (final label in figure.labels) label.text,
      ], reason: sentence);
      expect(
        sentence,
        endsWith(figure.prompt == FigurePrompt.area ? 'Area?' : 'Perimeter?'),
      );
    }
    expect(
      figureSentence(
        en,
        GeometryFamily.rectanglePerimeter.build([5, 3]).figure,
      ),
      'Rectangle, sides 5 and 3. Perimeter?',
    );
    expect(
      figureSentence(en, GeometryFamily.squarePerimeter.build([7]).figure),
      'Square, side 7. Perimeter?',
    );
    expect(
      figureSentence(
        en,
        GeometryFamily.trianglePerimeter.build([5, 3, 4]).figure,
      ),
      'Triangle, sides 3, 4 and 5. Perimeter?',
    );
    expect(
      figureSentence(en, GeometryFamily.rectangleArea.build([4, 2]).figure),
      'Rectangle, sides 4 and 2. Area?',
    );
  });

  test('hints: at least two steps, the sum written out, the answer only in '
      'the last step unless the figure shows it', () {
    for (final (family, params) in every) {
      final (:figure, :answer) = family.build(params);
      final steps = [for (final step in figureSteps(figure)) step(en)];
      final where = '$family $params: $steps';
      expect(steps.length, greaterThanOrEqualTo(2), reason: where);
      final shown = {for (final label in figure.labels) label.text};
      for (final step in steps.take(steps.length - 1)) {
        if (shown.contains('$answer')) continue;
        expect(
          step,
          isNot(matches(RegExp('(?<!\\d)$answer(?!\\d)'))),
          reason: where,
        );
      }
      // The last step is a calculation that adds up and ends in the answer.
      final last = RegExp(r'([\d +×]+) = (\d+)').firstMatch(steps.last)!;
      final terms = last[1]!.trim();
      final value = terms.contains('×')
          ? terms
                .split('×')
                .map((t) => int.parse(t.trim()))
                .reduce((a, b) => a * b)
          : terms
                .split('+')
                .map((t) => int.parse(t.trim()))
                .reduce((a, b) => a + b);
      expect(value, answer, reason: where);
      expect(int.parse(last[2]!), answer, reason: where);
    }
    expect(
      [
        for (final step in figureSteps(
          GeometryFamily.rectanglePerimeter.build([5, 3]).figure,
        ))
          step(en),
      ],
      [
        'The two sides without a number are as long as the sides opposite '
            'them: 5 and 3.',
        'Add all the sides: 5 + 3 + 5 + 3 = 16.',
      ],
    );
    expect(
      [
        for (final step in figureSteps(
          GeometryFamily.rectangleArea.build([4, 2]).figure,
        ))
          step(en),
      ],
      ['Count the squares: 2 rows of 4 squares each.', 'So 2 × 4 = 8.'],
    );
  });

  test('a drawn problem never repeats the one before', () {
    final random = Random(7);
    for (final level in [1, 2]) {
      (GeometryFamily, List<int>)? previous;
      for (var i = 0; i < 2000; i++) {
        final next = drawGeometry(random, level, previous: previous);
        expect(next.$1.level, level);
        expect(next.$1.space, contains(next.$2));
        if (previous != null) {
          expect(
            next.$1 == previous.$1 &&
                next.$2.join(',') == previous.$2.join(','),
            isFalse,
          );
        }
        previous = next;
      }
    }
  });

  test('figures have value equality', () {
    final a = GeometryFamily.rectangleArea.build([4, 2]).figure;
    final b = GeometryFamily.rectangleArea.build([4, 2]).figure;
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(GeometryFamily.rectangleArea.build([2, 4]).figure));
  });
}

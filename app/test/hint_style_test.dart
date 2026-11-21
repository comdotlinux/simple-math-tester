import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/figure_view.dart';
import 'package:simple_math_tester/geometry.dart';
import 'package:simple_math_tester/hint_steps.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/solution_steps.dart';

import 'en.dart';

/// The hints of algebra and geometry are written for a child of 7 to 12 who
/// just got the question wrong: short sentences, one calculation a step,
/// and always the same shape (what is asked, the idea, the working, the
/// answer with its check). The geometry shape and the highlighted parts are
/// checked with the oracle in geometry_test.dart.

/// Words a sentence may have in English; numbers and signs do not count.
const maxWords = 15;

/// Characters a step may have in any language, so a translation that
/// grows cannot fill the screen.
const maxStepCharacters = 300;

/// A calculation with its value, such as `5 + 3 + 5 + 3 = 16` or
/// `−18 ÷ 3 = −6`; an equation with a letter or `?` is not one.
final calculation = RegExp(
  r'−?\d+(?:[.,]\d+)?(?: [+−×÷] −?\d+(?:[.,]\d+)?)+ = −?\d+(?:[.,]\d+)?',
);

/// Every algebra problem of every level and every geometry problem, by
/// family name, so each family is covered as soon as it exists.
Map<String, List<Problem>> everyProblemByFamily() {
  final algebra = OperationType.algebra.source as AlgebraSource;
  final geometry = OperationType.geometry.source as GeometrySource;
  final families = <String, List<Problem>>{};
  for (var level = 1; level <= algebra.highestLevel; level++) {
    for (final problem in algebra.problems(OperationType.algebra, level)) {
      (families[problem.variant] ??= []).add(problem);
    }
  }
  for (final family in GeometryFamily.values) {
    families[family.name] = [
      for (final params in family.space)
        geometry.build(
          OperationType.geometry,
          family.name,
          params,
          level: family.level,
        )!,
    ];
  }
  return families;
}

List<String> texts(Problem problem, AppLocalizations l) => [
  for (final step in solutionSteps(problem)) step(l),
];

/// The problem of each family whose English hint is longest.
Map<String, Problem> longestByFamily(Map<String, List<Problem>> families) => {
  for (final MapEntry(:key, :value) in families.entries)
    key: value.reduce(
      (a, b) =>
          texts(a, en).join().length >= texts(b, en).join().length ? a : b,
    ),
};

void main() {
  final families = everyProblemByFamily();
  final longest = longestByFamily(families);

  test('every English sentence of every hint has at most $maxWords words, '
      'and a step holds at most one calculation', () {
    final failures = <String>{};
    for (final problems in families.values) {
      for (final problem in problems) {
        for (final step in texts(problem, en)) {
          for (final sentence in step.split(RegExp(r'(?<=[.?!])\s+'))) {
            final words = sentence
                .split(' ')
                .where((word) => RegExp(r'\p{L}', unicode: true).hasMatch(word))
                .length;
            if (words > maxWords) failures.add('$words words: $sentence');
          }
          // The check after the answer is not part of the working.
          final working = step.split('Check:').first;
          if (calculation.allMatches(working).length > 1) {
            failures.add('two calculations: $step');
          }
        }
      }
    }
    expect(failures, isEmpty);
  });

  test('in every language, no hint step is longer than $maxStepCharacters '
      'characters', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      for (final MapEntry(key: family, value: problem) in longest.entries) {
        for (final step in texts(problem, l)) {
          expect(
            step.length,
            lessThanOrEqualTo(maxStepCharacters),
            reason: '$locale $family: $step',
          );
        }
      }
    }
  });

  test('every equation hint says what is asked, then the idea, then works '
      'one step at a time, and ends with the answer and its check', () {
    const ideas = {
      EquationMove.addAndTakeAway,
      EquationMove.swapTakeAway,
      EquationMove.multiplyAndDivide,
      EquationMove.swapDivide,
      EquationMove.squared,
      EquationMove.squareRoot,
      EquationMove.balance,
    };
    const answers = {EquationMove.answer, EquationMove.rootAnswer};
    for (final problems in families.values) {
      for (final problem in problems.whereType<EquationProblem>()) {
        final hint = equationHint(problem);
        final where =
            '${problem.question}: ${[for (final s in hint) s.move.name]}';
        expect(hint.length, greaterThanOrEqualTo(4), reason: where);
        expect(hint.first.move, EquationMove.ask, reason: where);
        expect(ideas, contains(hint[1].move), reason: where);
        expect(answers, contains(hint.last.move), reason: where);
        expect(hint.last.check, isNotNull, reason: where);
        for (final step in hint.skip(2).take(hint.length - 3)) {
          expect(step.move, isNot(EquationMove.ask), reason: where);
          expect(ideas, isNot(contains(step.move)), reason: where);
          expect(answers, isNot(contains(step.move)), reason: where);
        }
      }
    }
  });

  group('the hint view', () {
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

    testWidgets('shows the longest hint of every family without overflow at '
        '320x568 and text scale 2', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final brightness in Brightness.values) {
        for (final MapEntry(key: family, value: problem) in longest.entries) {
          final steps = solutionSteps(problem);
          final figure = switch (problem) {
            FigureProblem(:final figure) => figure,
            _ => null,
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(brightness),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    // The page gutter and the card's padding.
                    padding: const EdgeInsets.all(36),
                    child: HintSteps(
                      steps: steps,
                      shown: steps.length,
                      figure: figure,
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: family);
          expect(
            find.byKey(hintFigureKey),
            figure == null ? findsNothing : findsOneWidget,
            reason: family,
          );
          expect(find.text(steps.last(en)), findsOneWidget, reason: family);
        }
      }
    });

    testWidgets('the figure highlights the parts of the newest step', (
      tester,
    ) async {
      final problem = (OperationType.geometry.source as GeometrySource).build(
        OperationType.geometry,
        'rectanglePerimeter',
        [5, 3],
      )!;
      final steps = solutionSteps(problem);
      for (var shown = 1; shown <= steps.length; shown++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.light),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: HintSteps(
                  steps: steps,
                  shown: shown,
                  figure: problem.figure,
                ),
              ),
            ),
          ),
        );
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byKey(hintFigureKey),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as FigurePainter;
        final parts = figureHint(problem.figure)[shown - 1].parts;
        expect(painter.highlight!.edges, parts.edges, reason: 'step $shown');
        expect(
          painter.highlight!.outline,
          parts.outline,
          reason: 'step $shown',
        );
      }
    });
  });
}

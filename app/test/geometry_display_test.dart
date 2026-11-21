import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/figure_view.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

/// Figure questions on screen: the figure stands where the question text
/// would be, with the short prompt under it, and the sentence is its
/// semantics label and its text form in the pinned band and the history.
/// Sentences stay literal: the wording is the behaviour.
void main() {
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

  final source = OperationType.geometry.source as GeometrySource;
  final rectangle = source.build(OperationType.geometry, 'rectanglePerimeter', [
    5,
    3,
  ])!;
  const sentence = 'Rectangle, sides 5 and 3. Perimeter?';

  Future<MathTesterModel> launch(
    WidgetTester tester, {
    Size size = const Size(412, 900),
    LayoutMode layout = LayoutMode.comfortable,
    double scale = 1,
    List<Attempt> history = const [],
    FigureProblem? problem,
    String? language,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: problem ?? rectangle,
      progress: Progress(
        tier: Tier.easy,
        selectedOperations: {OperationType.geometry},
        history: history,
        layoutMode: layout,
        language: language,
      ),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        key: ObjectKey(model),
        value: model,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: const MathTesterApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return model;
  }

  for (final (size, scale) in [
    (const Size(412, 900), 1.0),
    (const Size(360, 640), 2.0),
    (const Size(320, 568), 1.0),
  ]) {
    testWidgets('the problem page shows the figure and the prompt and takes '
        'the right answer, $size x$scale', (tester) async {
      final semantics = tester.ensureSemantics();
      final model = await launch(tester, size: size, scale: scale);
      final question = find.byKey(questionOnProblemsPageKey);
      final figure = find.descendant(
        of: question,
        matching: find.byType(FigureView),
      );
      expect(figure, findsOneWidget);
      expect(tester.getSize(figure).width, greaterThan(200));
      expect(
        find.descendant(of: question, matching: find.text('Perimeter?')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Math question: $sentence'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '16');
      await tester.pump();
      model.submitAnswer();
      await tester.pumpAndSettle();
      expect(model.answerCorrect, isTrue);
      expect(model.history.single.correct, isTrue);
      expect(model.history.single.problem, same(rectangle));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  final circle = source.build(OperationType.geometry, 'circleArea', [
    5,
  ], level: 5)!;
  for (final (size, scale, layout) in [
    (const Size(412, 900), 1.0, LayoutMode.comfortable),
    (const Size(360, 640), 2.0, LayoutMode.comfortable),
    (const Size(320, 568), 2.0, LayoutMode.compact),
  ]) {
    testWidgets('a circle shows "Use π = 3.14" and takes a decimal answer, '
        '$size x$scale ${layout.name}', (tester) async {
      final semantics = tester.ensureSemantics();
      final model = await launch(
        tester,
        size: size,
        scale: scale,
        layout: layout,
        problem: circle,
      );
      final question = find.byKey(questionOnProblemsPageKey);
      expect(
        find.descendant(
          of: question,
          matching: find.text('Area? Use π = 3.14.'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Math question: Circle, radius 5. Area? Use π = 3.14.',
        ),
        findsOneWidget,
      );
      model.setDraftInput('78.5');
      model.submitAnswer();
      await tester.pumpAndSettle();
      expect(model.answerCorrect, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('in German the prompt writes 3,14 and 78,5 is right', (
    tester,
  ) async {
    final model = await launch(tester, problem: circle, language: 'de');
    expect(find.textContaining('π = 3,14'), findsOneWidget);
    expect(find.textContaining('3.14'), findsNothing);
    model.setDraftInput('78,5');
    model.submitAnswer();
    await tester.pumpAndSettle();
    expect(model.answerCorrect, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wrong answer opens the first hint', (tester) async {
    final model = await launch(tester);
    model.setDraftInput('15');
    model.submitAnswer();
    await tester.pumpAndSettle();
    expect(model.answerCorrect, isFalse);
    expect(
      find.text(
        'The two sides without a number are as long as the sides opposite '
        'them: 5 and 3.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pinned band shows the sentence', (tester) async {
    final model = await launch(tester, size: const Size(320, 568));
    model.setDraftInput('9');
    model.submitAnswer();
    await tester.pumpAndSettle();
    final pinned = find.byKey(pinnedQuestionKey);
    for (var i = 0; i < 10 && pinned.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -100),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }
    expect(pinned, findsOneWidget);
    expect(tester.widget<Text>(pinned).textSpan!.toPlainText(), sentence);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, layout) in [
    ('card', const Size(412, 900), LayoutMode.comfortable),
    ('table row', const Size(1000, 900), LayoutMode.comfortable),
    ('compact row', const Size(412, 900), LayoutMode.compact),
  ]) {
    testWidgets('a history $name shows and reads the sentence', (tester) async {
      final semantics = tester.ensureSemantics();
      final model = await launch(
        tester,
        size: size,
        layout: layout,
        history: [
          Attempt(
            rectangle,
            firstAnswer: 15,
            elapsedMs: 4000,
            answeredAt: DateTime(2026, 11, 21, 9),
          ),
        ],
      );
      model.setCurrentPage(1);
      await tester.pumpAndSettle();
      final row = find.byKey(historyRowKey(0));
      expect(
        find.descendant(of: row, matching: find.textContaining(sentence)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(sentence))),
        findsWidgets,
      );
      if (layout == LayoutMode.compact) {
        // Sentence, arrow, answer: never "Perimeter? = 16".
        expect(
          find.descendant(of: row, matching: find.byIcon(Icons.arrow_forward)),
          findsOneWidget,
        );
        expect(find.textContaining('= 16'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}

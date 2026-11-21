import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/problem_page.dart' show togglesPerRow;
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/question_text.dart';
import 'package:simple_math_tester/rules.dart';

/// Equations on screen: the blank is a drawn line on the baseline, never the
/// glyph U+25A1, which no bundled font has (the web engine would fetch a font
/// for it), nor typed underscores, and screen readers hear "blank".
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

  final source = OperationType.algebra.source as AlgebraSource;
  final equation = source.build(OperationType.algebra, 'missingSecondAddend', [
    3,
    4,
  ])!;
  final history = [
    Attempt(
      equation,
      firstAnswer: 5,
      elapsedMs: 4000,
      answeredAt: DateTime(2026, 11, 21, 9),
    ),
  ];

  Future<MathTesterModel> launch(
    WidgetTester tester, {
    // Practice starts as after a tap on Start; false stays before it.
    bool start = true,
    Size size = const Size(412, 900),
    LayoutMode layout = LayoutMode.comfortable,
    double scale = 1,
    EquationProblem? problem,
    List<Attempt>? attempts,
    String? language,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: problem ?? equation,
      progress: Progress(
        tier: Tier.easy,
        selectedOperations: {OperationType.algebra},
        history: attempts ?? history,
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
    if (start) {
      model.startPractice();
      await tester.pumpAndSettle();
    }
    return model;
  }

  /// No text drawn with a font holds the glyph or an underscore, and no
  /// label says either.
  void expectNoGlyph(WidgetTester tester) {
    final texts = find.byType(RichText).evaluate().toList();
    expect(texts, isNotEmpty);
    for (final element in texts) {
      final text = (element.widget as RichText).text.toPlainText();
      expect(text, isNot(contains('□')));
      expect(text, isNot(contains('_')));
    }
    expect(find.bySemanticsLabel(RegExp('[□_]')), findsNothing);
  }

  /// The [RichText] under [finder] draws `3 + `, a blank, ` = 7`.
  void expectBlank(WidgetTester tester, Finder finder) {
    final texts = [
      for (final element
          in find
              .descendant(of: finder, matching: find.byType(RichText))
              .evaluate())
        (element.widget as RichText).text,
    ].where((text) => text.toPlainText().contains('\ufffc'));
    expect(texts, hasLength(1));
    expect(texts.single.toPlainText(), startsWith('3 + \ufffc = 7'));
    var blanks = 0;
    texts.single.visitChildren((span) {
      if (span is WidgetSpan) blanks++;
      return true;
    });
    expect(blanks, greaterThanOrEqualTo(1));
  }

  testWidgets('the problem page draws the blank and reads it as "blank"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    expectBlank(tester, find.byKey(questionOnProblemsPageKey));
    expect(
      find.bySemanticsLabel('Math question: 3 + blank = 7'),
      findsOneWidget,
    );
    expectNoGlyph(tester);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('the blank is a line on the baseline that scales with the '
      'text', (tester) async {
    final found = <double, (Rect, double)>{};
    for (final scale in [1.0, 2.0]) {
      const style = TextStyle(fontSize: 40, color: Color(0xFF000000));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Builder(
                builder: (context) =>
                    Text.rich(mathSpan(context, '10 − □ = 4', style)),
              ),
            ),
          ),
        ),
      );
      final text = find.byType(RichText);
      Widget? blank;
      tester.widget<RichText>(text).text.visitChildren((span) {
        if (span is WidgetSpan) blank = span.child;
        return blank == null;
      });
      // The baseline: the top of the text plus the ascent of its digits.
      final digits = TextPainter(
        text: const TextSpan(text: '10', style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(scale),
      )..layout();
      addTearDown(digits.dispose);
      found[scale] = (
        tester.getRect(find.byWidget(blank!)),
        tester.getTopLeft(text).dy +
            digits.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      );
    }
    for (final (rect, baseline) in found.values) {
      // On the baseline and long and thin: unlike a minus sign, which is
      // short and at mid height.
      expect(rect.bottom, moreOrLessEquals(baseline, epsilon: 0.5));
      expect(rect.width, greaterThan(rect.height * 8));
    }
    final (one, _) = found[1.0]!;
    final (two, _) = found[2.0]!;
    expect(two.width, moreOrLessEquals(one.width * 2, epsilon: 0.5));
    expect(two.height, moreOrLessEquals(one.height * 2, epsilon: 0.5));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('the question card draws the blank at 320 x 568, text scale '
        '$scale, without overflow', (tester) async {
      await launch(tester, size: const Size(320, 568), scale: scale);
      final card = find.byKey(questionOnProblemsPageKey);
      expectBlank(tester, card);
      final blank = find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_Blank',
        ),
      );
      // Inside the question's text, and the text inside the screen's width.
      final rect = tester.getRect(blank);
      final text = tester.getRect(card);
      expect(rect.width, greaterThan(0));
      expect(text.inflate(0.5).contains(rect.topLeft), isTrue);
      expect(text.inflate(0.5).contains(rect.bottomRight), isTrue);
      expect(text.left, greaterThanOrEqualTo(0));
      expect(text.right, lessThanOrEqualTo(320));
      expectNoGlyph(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the pinned question band draws the blank', (tester) async {
    // Large text, so the page is long enough to scroll the card away.
    final model = await launch(tester, size: const Size(320, 568), scale: 2);
    model.setDraftInput('9');
    model.submitAnswer();
    await tester.pumpAndSettle();
    // Read down the page until the card scrolls away under the band.
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
    expectBlank(tester, pinned);
    expectNoGlyph(tester);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, layout) in [
    ('card', const Size(412, 900), LayoutMode.comfortable),
    ('table row', const Size(1000, 900), LayoutMode.comfortable),
    ('compact row', const Size(412, 900), LayoutMode.compact),
  ]) {
    testWidgets('a history $name draws the blank and reads it as "blank"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final model = await launch(tester, size: size, layout: layout);
      model.setCurrentPage(1);
      await tester.pumpAndSettle();
      final row = find.byKey(historyRowKey(0));
      expectBlank(tester, row);
      // Merged into the row's node, which may sit above the keyed widget.
      expect(find.bySemanticsLabel(RegExp('3 \\+ blank = 7')), findsOneWidget);
      expectNoGlyph(tester);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('the compact review line reads equation, arrow, answer', (
    tester,
  ) async {
    final model = await launch(tester, layout: LayoutMode.compact);
    model.setCurrentPage(1);
    await tester.pumpAndSettle();
    final row = find.byKey(historyRowKey(0));
    final line = [
      for (final element
          in find
              .descendant(of: row, matching: find.byType(RichText))
              .evaluate())
        (element.widget as RichText).text.toPlainText(),
    ].singleWhere((text) => text.startsWith('3 + '));
    // The blank and the arrow are drawn: 3 + [blank] = 7 [arrow] 4.
    expect(line, startsWith('3 + ￼ = 7￼4'));
    expect(line, isNot(contains('= 4')));
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.arrow_forward)),
      findsOneWidget,
    );
  });

  testWidgets('from level 3 the letter n is italic and 2n is read as '
      '2 × n', (tester) async {
    final semantics = tester.ensureSemantics();
    final letter = source.build(OperationType.algebra, 'anPlusB', [
      2,
      3,
      4,
    ], level: 4)!;
    await launch(tester, problem: letter);
    final text = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byKey(questionOnProblemsPageKey),
            matching: find.byType(RichText),
          ),
        )
        .map((widget) => widget.text)
        .singleWhere((span) => span.toPlainText().contains('n'));
    expect(text.toPlainText(), startsWith('2n + 3 = 11'));
    final italic = <String>[];
    text.visitChildren((span) {
      if (span is TextSpan && span.style?.fontStyle == FontStyle.italic) {
        italic.add(span.text!);
      }
      return true;
    });
    expect(italic, ['n']);
    expect(
      find.bySemanticsLabel('Math question: 2 × n + 3 = 11'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('only the letter n on its own is italic, not an n in a word', (
    tester,
  ) async {
    final italic = <String, List<String>>{};
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          for (final text in [
            '3(n − 2) = 12',
            'n ÷ 4 + 3 = 7',
            'Rectangle, sides 5 and 3. Perimeter?',
          ]) {
            final found = italic[text] = [];
            mathSpan(context, text, null).visitChildren((span) {
              if (span is TextSpan &&
                  span.style?.fontStyle == FontStyle.italic) {
                found.add(span.text!);
              }
              return true;
            });
          }
          return const SizedBox();
        },
      ),
    );
    expect(italic, {
      '3(n − 2) = 12': ['n'],
      'n ÷ 4 + 3 = 7': ['n'],
      'Rectangle, sides 5 and 3. Perimeter?': <String>[],
    });
  });

  testWidgets('a history card shows tenths with the language separator and '
      'a minus sign below zero', (tester) async {
    final tenths = source.build(OperationType.algebra, 'anTenths', [
      4,
      -25,
    ], level: 5)!;
    final model = await launch(
      tester,
      problem: tenths,
      language: 'de',
      attempts: [
        Attempt(
          tenths,
          firstAnswer: -2.4,
          answerHundredths: -240,
          elapsedMs: 4000,
          answeredAt: DateTime(2026, 11, 21, 9),
        ),
      ],
    );
    model.setCurrentPage(1);
    await tester.pumpAndSettle();
    final row = find.byKey(historyRowKey(0));
    expect(
      find.descendant(of: row, matching: find.textContaining('−2,5')),
      findsWidgets,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('−2,4')),
      findsWidgets,
    );
    expect(find.textContaining('2.5'), findsNothing);
    expect(find.textContaining('-2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('squares and roots', () {
    for (final (variant, params, level, shown, spoken) in [
      ('missingSquare', [7], 2, '7² = ￼', '7 squared = blank'),
      ('missingSquareRoot', [10], 2, '√100 = ￼', 'square root of 100 = blank'),
      ('aSquared', [12], 3, '12² = n', '12 squared = n'),
      ('squareRootOfC', [20], 4, '√400 = n', 'square root of 400 = n'),
      (
        'nSquared',
        [12],
        5,
        'n² = 144\nn is positive',
        'n squared = 144, n is positive',
      ),
      (
        'anSquared',
        [9, 12],
        5,
        '9n² = 1296\nn is positive',
        '9 × n squared = 1296, n is positive',
      ),
    ]) {
      testWidgets('$variant shows ² and √ as text and reads them as words, '
          'at 320x568 and text scale 2', (tester) async {
        final semantics = tester.ensureSemantics();
        final problem = source.build(
          OperationType.algebra,
          variant,
          params,
          level: level,
        )!;
        await launch(
          tester,
          size: const Size(320, 568),
          scale: 2,
          problem: problem,
        );
        final text = tester
            .widgetList<RichText>(
              find.descendant(
                of: find.byKey(questionOnProblemsPageKey),
                matching: find.byType(RichText),
              ),
            )
            .map((widget) => widget.text.toPlainText())
            .single;
        expect(text, shown);
        expect(text, isNot(contains('^')));
        expect(find.bySemanticsLabel('Math question: $spoken'), findsOneWidget);
        expectNoGlyph(tester);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }

    final positive = source.build(OperationType.algebra, 'nSquared', [
      7,
    ], level: 5)!;

    testWidgets('the condition line is in the pinned band', (tester) async {
      // Text scale 1.5, so the page is long enough to scroll the card
      // away now that practice shows nothing above the question.
      final model = await launch(
        tester,
        size: const Size(320, 568),
        scale: 1.5,
        problem: positive,
      );
      model.setDraftInput('6');
      model.submitAnswer();
      await tester.pumpAndSettle();
      final pinned = find.byKey(pinnedQuestionKey);
      for (var i = 0; i < 20 && pinned.evaluate().isEmpty; i++) {
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -100),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<RichText>(
              find.descendant(of: pinned, matching: find.byType(RichText)),
            )
            .text
            .toPlainText(),
        'n² = 49\nn is positive',
      );
      expect(tester.takeException(), isNull);
    });

    for (final (name, size, layout) in [
      ('card', const Size(412, 900), LayoutMode.comfortable),
      ('table row', const Size(1000, 900), LayoutMode.comfortable),
      ('compact row', const Size(412, 900), LayoutMode.compact),
    ]) {
      testWidgets('a history $name shows and reads the condition line', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final model = await launch(
          tester,
          size: size,
          layout: layout,
          problem: positive,
          attempts: [
            Attempt(
              positive,
              firstAnswer: 7,
              elapsedMs: 4000,
              answeredAt: DateTime(2026, 11, 21, 9),
            ),
          ],
        );
        model.setCurrentPage(1);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(historyRowKey(0)),
            matching: find.textContaining('n² = 49\nn is positive'),
          ),
          findsWidgets,
        );
        expect(
          find.bySemanticsLabel(RegExp('n squared = 49, n is positive')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  });

  group('selection toggles', () {
    testWidgets('six wrap to two rows of three at 320 wide, text scale 2', (
      tester,
    ) async {
      await launch(tester, start: false, size: const Size(320, 900), scale: 2);
      // The tooltip holds the whole toggle, raised or sunk.
      Rect toggle(OperationType type) => tester.getRect(
        find.ancestor(
          of: find.byKey(operationToggleKey(type)),
          matching: find.byType(Tooltip),
        ),
      );
      final tops = [for (final type in OperationType.values) toggle(type).top];
      expect(tops.toSet(), hasLength(2));
      expect(tops.where((top) => top == tops.first), hasLength(3));
      for (final type in OperationType.values) {
        expect(toggle(type).width, greaterThanOrEqualTo(48));
        expect(toggle(type).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });

    test('six wrap to two rows of three at 320 wide and share one row when '
        'they fit', () {
      // 320 minus the page's 16 px gutters each side.
      expect(togglesPerRow(288, 5), 5);
      expect(togglesPerRow(288, 6), 3);
      expect(togglesPerRow(358, 6), 6);
      expect(togglesPerRow(288, 7), 4);
    });
  });
}

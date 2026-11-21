import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/labels.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import 'en.dart';

/// One recorded attempt: right or wrong at the first check, or skipped; a
/// hint opened ([opened]) and steps seen before the first check ([steps],
/// the only hint fact saved before `hintOpened` was).
Attempt entry({
  OperationType kind = OperationType.plus,
  bool correct = true,
  bool skipped = false,
  bool sprint = false,
  bool opened = false,
  int steps = 0,
}) {
  final problem = ArithmeticProblem(2, 3, kind, kind.apply(2, 3));
  return Attempt(
    problem,
    firstAnswer: skipped ? null : (correct ? problem.result : 999),
    elapsedMs: 1000,
    answeredAt: DateTime(2026, 11, 21, 10),
    hintsUsed: steps,
    sprint: sprint,
    hintOpened: opened || steps > 0,
  );
}

/// [hinted] answers with a hint, then [plain] without, oldest first.
List<Attempt> answers(int hinted, int plain) => [
  for (var i = 0; i < hinted; i++) entry(opened: true),
  for (var i = 0; i < plain; i++) entry(),
];

const sum = ArithmeticProblem(48, 27, OperationType.plus, 75);

extension on OperationType {
  num apply(int a, int b) => switch (this) {
    OperationType.plus => a + b,
    OperationType.minus => a - b,
    OperationType.multiply => a * b,
    _ => a / b,
  };
}

void main() {
  group('hintNudgeDue', () {
    test('shows at 6 of the last 10 answers, not at 5', () {
      expect(hintNudgeDue(answers(6, 4)), isTrue);
      expect(hintNudgeDue(answers(5, 5)), isFalse);
      expect(hintNudgeDue([...answers(4, 4), ...answers(2, 0)]), isTrue);
    });

    test('the window slides: an 11th answer without a hint drops it', () {
      final history = answers(6, 4);
      expect(hintNudgeDue(history), isTrue);
      expect(hintNudgeDue([...history, entry()]), isFalse);
      expect(hintNudgeDue([...history, entry(opened: true)]), isTrue);
    });

    test('needs 10 answers; skips and sprint answers do not count', () {
      expect(hintNudgeDue(answers(9, 0)), isFalse);
      expect(hintNudgeDue([]), isFalse);
      expect(
        hintNudgeDue([
          ...answers(9, 0),
          entry(skipped: true, opened: true),
          entry(sprint: true),
        ]),
        isFalse,
      );
      // A skip and a sprint answer inside the window do not push hints out.
      expect(
        hintNudgeDue([
          ...answers(6, 3),
          for (var i = 0; i < 5; i++) entry(skipped: true),
          for (var i = 0; i < 5; i++) entry(sprint: true),
          entry(),
        ]),
        isTrue,
      );
    });

    test('an entry saved before hintOpened counts by its steps seen', () {
      final old = [
        for (var i = 0; i < 6; i++)
          Attempt(
            sum,
            firstAnswer: 75,
            elapsedMs: 1,
            answeredAt: DateTime(2026),
            hintsUsed: 1,
          ),
        ...answers(0, 4),
      ];
      expect(old.first.hintOpened, isFalse);
      expect(old.first.usedHint, isTrue);
      expect(hintNudgeDue(old), isTrue);
    });
  });

  group('hintTotals', () {
    test(
      'an empty history and one of only skips and sprints count nothing',
      () {
        const none = (
          answered: 0,
          hinted: 0,
          correct: 0,
          correctWithoutHint: 0,
        );
        expect(hintTotals([]), none);
        expect(hintTotals([entry(skipped: true), entry(sprint: true)]), none);
      },
    );

    test('equal a hand-counted history, per kind too', () {
      final history = mixedHistory();
      expect(hintTotals(history), (
        answered: 7,
        hinted: 4,
        correct: 5,
        correctWithoutHint: 3,
      ));
      Iterable<Attempt> of(OperationType kind) =>
          history.where((a) => a.problem.kind == kind);
      expect(hintTotals(of(OperationType.plus)), (
        answered: 4,
        hinted: 2,
        correct: 3,
        correctWithoutHint: 2,
      ));
      expect(hintTotals(of(OperationType.multiply)), (
        answered: 2,
        hinted: 1,
        correct: 1,
        correctWithoutHint: 1,
      ));
      expect(hintTotals(of(OperationType.minus)), (
        answered: 1,
        hinted: 1,
        correct: 1,
        correctWithoutHint: 0,
      ));
      expect(hintTotals(of(OperationType.divide)).answered, 0);
    });
  });

  group('the model', () {
    MathTesterModel model(List<Attempt> history) {
      final model = MathTesterModel(
        initialProblem: sum,
        nextProblem: () => sum,
        progress: Progress(tier: Tier.easy, history: history),
      );
      addTearDown(model.dispose);
      return model;
    }

    test('nudges once per question, and again on the next question', () {
      final m = model(answers(6, 4));
      expect(m.takeHintNudge(), isTrue);
      expect(m.takeHintNudge(), isFalse);
      m.openHint();
      m.generateNextProblem();
      // The skip is no answer, so the window is the same.
      expect(m.takeHintNudge(), isTrue);
    });

    test('not for a hint already opened, nor at 5 of 10', () {
      final m = model(answers(6, 4));
      m.openHint();
      expect(m.takeHintNudge(), isFalse);
      expect(model(answers(5, 5)).takeHintNudge(), isFalse);
    });

    test('the current question’s own attempt is not in the window', () {
      final m = model(answers(9, 0));
      m.setDraftInput('1');
      m.submitAnswer();
      expect(m.history, hasLength(10));
      expect(m.takeHintNudge(), isFalse);
    });

    test('an 11th answer without a hint drops it', () {
      final m = model(answers(6, 4));
      m.setDraftInput('75');
      m.submitAnswer();
      m.generateNextProblem();
      expect(m.takeHintNudge(), isFalse);
    });

    test('never in a sprint', () {
      final m = model(answers(10, 0));
      m.startSprint();
      expect(m.inSprint, isTrue);
      expect(m.takeHintNudge(), isFalse);
      m.endSprint();
      expect(m.takeHintNudge(), isTrue);
    });

    test('taking the nudge records nothing', () {
      final m = model(answers(6, 4));
      final before = m.history;
      expect(m.takeHintNudge(), isTrue);
      expect(m.hintOpened, isFalse);
      expect(m.revealedSteps, 0);
      expect(m.history, same(before));
    });
  });

  group('on screen', () {
    setUpAll(loadFonts);

    Future<MathTesterModel> launch(
      WidgetTester tester, {
      List<Attempt> history = const [],
      Size size = const Size(360, 640),
      double scale = 1,
      Brightness brightness = Brightness.light,
      String? language,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = MathTesterModel(
        initialProblem: sum,
        nextProblem: () => sum,
        progress: Progress(
          tier: Tier.easy,
          history: history,
          language: language,
          seenKinds: [for (final kind in OperationType.values) kind.name],
        ),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
              platformBrightness: brightness,
            ),
            child: const MathTesterApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return model;
    }

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    Future<void> answerWrong(WidgetTester tester, MathTesterModel model) async {
      model.setDraftInput('65');
      model.submitAnswer();
      await tester.pumpAndSettle();
    }

    bool fieldFocused(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;
    final nudge = find.byKey(hintNudgeKey);
    final modal = find.byKey(solutionStepsKey);

    testWidgets('at 6 of 10 the Hint button nudges first; I will try records '
        'nothing and focuses the answer; asked again, the hint opens', (
      tester,
    ) async {
      final model = await launch(tester, history: answers(6, 4));
      await tapKey(tester, hintButtonKey);
      expect(nudge, findsOneWidget);
      expect(modal, findsNothing);
      expect(find.text(en.hintNudgeMessage), findsOneWidget);

      await tapKey(tester, hintNudgeTryKey);
      expect(nudge, findsNothing);
      expect(modal, findsNothing);
      expect(model.hintOpened, isFalse);
      expect(model.revealedSteps, 0);
      expect(model.history, hasLength(10));
      expect(fieldFocused(tester), isTrue);

      await tapKey(tester, hintButtonKey);
      expect(nudge, findsNothing);
      expect(modal, findsOneWidget);
      expect(model.hintOpened, isTrue);
    });

    testWidgets('at 5 of 10 the hint opens at once', (tester) async {
      await launch(tester, history: answers(5, 5));
      await tapKey(tester, hintButtonKey);
      expect(nudge, findsNothing);
      expect(modal, findsOneWidget);
    });

    testWidgets('before 10 answers the hint opens at once', (tester) async {
      await launch(tester, history: answers(9, 0));
      await tapKey(tester, hintButtonKey);
      expect(nudge, findsNothing);
      expect(modal, findsOneWidget);
    });

    testWidgets('after a wrong answer, Show the hint anyway opens the hint and '
        'records it', (tester) async {
      final model = await launch(tester, history: answers(6, 4));
      await answerWrong(tester, model);
      await tapKey(tester, hintButtonKey);
      expect(nudge, findsOneWidget);

      await tapKey(tester, hintNudgeAnywayKey);
      expect(nudge, findsNothing);
      expect(modal, findsOneWidget);
      expect(model.history.last.hintOpened, isTrue);
      await tapKey(tester, hintCloseKey);
      expect(fieldFocused(tester), isTrue);

      // Reopening the opened hint never nudges.
      await tapKey(tester, hintButtonKey);
      expect(nudge, findsNothing);
      expect(modal, findsOneWidget);
    });

    testWidgets('Escape and the dimmed area count as I will try', (
      tester,
    ) async {
      final model = await launch(
        tester,
        history: answers(6, 4),
        size: const Size(1280, 900),
      );
      await tapKey(tester, hintButtonKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(nudge, findsNothing);
      expect(modal, findsNothing);
      expect(model.hintOpened, isFalse);
      expect(fieldFocused(tester), isTrue);

      model.generateNextProblem();
      await tester.pumpAndSettle();
      await tapKey(tester, hintButtonKey);
      expect(nudge, findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(nudge, findsNothing);
      expect(model.hintOpened, isFalse);
    });

    testWidgets('focus starts on I will try and Tab stays inside', (
      tester,
    ) async {
      await launch(tester, history: answers(6, 4), size: const Size(1280, 900));
      await tapKey(tester, hintButtonKey);
      expect(
        find.descendant(
          of: find.byKey(hintNudgeTryKey),
          matching: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
        ),
        findsOneWidget,
      );
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          find.descendant(of: nudge, matching: find.byWidget(focused.widget)),
          findsWidgets,
          reason: 'tab $i',
        );
      }
    });

    testWidgets('names its window, reads its message out and keeps 48 px '
        'buttons', (tester) async {
      final semantics = tester.ensureSemantics();
      await launch(tester, history: answers(6, 4));
      await tapKey(tester, hintButtonKey);
      final route = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.namesRoute == true,
      );
      expect(
        tester.getSemantics(route),
        isSemantics(label: en.hintNudgeTitle, namesRoute: true),
      );
      expect(
        tester.getSemantics(find.text(en.hintNudgeMessage)),
        isSemantics(label: en.hintNudgeMessage, isLiveRegion: true),
      );
      for (final key in [hintNudgeTryKey, hintNudgeAnywayKey]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$key');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$key');
      }
      semantics.dispose();
    });

    for (final size in const [Size(320, 568), Size(360, 640)]) {
      for (final scale in const [1.0, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets('the nudge fits at ${size.width.toInt()}x'
              '${size.height.toInt()}, text $scale, ${brightness.name}', (
            tester,
          ) async {
            final model = await launch(
              tester,
              history: answers(6, 4),
              size: size,
              scale: scale,
              brightness: brightness,
            );
            await answerWrong(tester, model);
            await tapKey(tester, hintButtonKey);
            expect(tester.takeException(), isNull);
            // Both buttons on screen without scrolling.
            for (final key in [hintNudgeTryKey, hintNudgeAnywayKey]) {
              final rect = tester.getRect(find.byKey(key));
              expect(
                (Offset.zero & size).contains(rect.topLeft) &&
                    (Offset.zero & size).contains(rect.bottomRight),
                isTrue,
                reason: '$key at $rect',
              );
            }
            await tapKey(tester, hintNudgeAnywayKey);
            expect(modal, findsOneWidget);
          });
        }
      }
    }

    Future<void> openMyAnswers(WidgetTester tester) =>
        tapKey(tester, myAnswersNavKey);

    testWidgets('My answers shows the totals of a hand-counted history, per '
        'kind', (tester) async {
      await launch(
        tester,
        history: mixedHistory(),
        size: const Size(1280, 900),
      );
      await openMyAnswers(tester);
      final block = find.byKey(hintStatsKey);
      expect(block, findsOneWidget);
      Finder shows(Finder within, String text) =>
          find.descendant(of: within, matching: find.text(text));
      expect(shows(block, en.hintStatsTitle), findsOneWidget);
      // All answers: the first lines of the block.
      expect(
        shows(block, 'Hint used on 4 of 7 questions, 57%'),
        findsOneWidget,
      );
      expect(
        shows(block, '3 of 5 correct answers without a hint, 60%'),
        findsOneWidget,
      );
      final plus = find.byKey(hintStatsKindKey(OperationType.plus));
      expect(shows(plus, OperationType.plus.label(en)), findsOneWidget);
      expect(shows(plus, 'Hint used on 2 of 4 questions, 50%'), findsOneWidget);
      expect(
        shows(plus, '2 of 3 correct answers without a hint, 67%'),
        findsOneWidget,
      );
      final times = find.byKey(hintStatsKindKey(OperationType.multiply));
      expect(
        shows(times, 'Hint used on 1 of 2 questions, 50%'),
        findsOneWidget,
      );
      expect(
        shows(times, '1 of 1 correct answer without a hint, 100%'),
        findsOneWidget,
      );
      final minus = find.byKey(hintStatsKindKey(OperationType.minus));
      expect(
        shows(minus, 'Hint used on 1 of 1 question, 100%'),
        findsOneWidget,
      );
      expect(
        shows(minus, '0 of 1 correct answer without a hint, 0%'),
        findsOneWidget,
      );
      // Only sprint answers: no lines for division.
      expect(find.byKey(hintStatsKindKey(OperationType.divide)), findsNothing);
    });

    testWidgets('no card before a hint was used on an answer; no correct '
        'line without a right answer', (tester) async {
      await launch(
        tester,
        history: [
          entry(skipped: true, opened: true),
          entry(sprint: true),
          entry(),
        ],
      );
      await openMyAnswers(tester);
      expect(find.byKey(statsCardKey), findsOneWidget);
      expect(find.byKey(hintStatsKey), findsNothing);

      await launch(tester, history: [entry(correct: false, opened: true)]);
      await openMyAnswers(tester);
      expect(find.text('Hint used on 1 of 1 question, 100%'), findsNWidgets(2));
      expect(find.textContaining('without a hint'), findsNothing);
    });

    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toString();
      testWidgets('$code: the hint totals fit at 320x568 and 360x640, text 1 '
          'and 2', (tester) async {
        for (final size in const [Size(320, 568), Size(360, 640)]) {
          for (final scale in const [1.0, 2.0]) {
            await launch(
              tester,
              history: mixedHistory(),
              size: size,
              scale: scale,
              brightness: code == 'en' ? Brightness.dark : Brightness.light,
              language: code,
            );
            await openMyAnswers(tester);
            expect(tester.takeException(), isNull, reason: '$size $scale');
            // Every line can be scrolled fully into view.
            final view = tester.getRect(
              find.descendant(
                of: find.byKey(resultsPageKey),
                matching: find.byType(Scrollable),
              ),
            );
            for (final key in [
              hintStatsKey,
              hintStatsKindKey(OperationType.minus),
            ]) {
              final lines = find.descendant(
                of: find.byKey(key),
                matching: find.byType(Text),
              );
              await tester.ensureVisible(lines.last);
              await tester.pumpAndSettle();
              final rect = tester.getRect(lines.last);
              expect(
                view.contains(rect.topLeft) &&
                    view.contains(rect.bottomRight - const Offset(1, 1)),
                isTrue,
                reason: '$key at $size $scale: $rect in $view',
              );
            }
          }
        }
      });
    }
  });
}

/// Hand-counted: 7 answers, a hint on 4 (57%); 5 right, 3 of them without
/// a hint before the check (60%).
List<Attempt> mixedHistory() => [
  // Plus: 4 answers, a hint on 2; 3 right, 2 without a hint.
  entry(),
  entry(),
  entry(steps: 1),
  entry(correct: false, opened: true),
  // Times: 2 answers, a hint on 1; the right one had its hint after the
  // check, so it was solved without one.
  entry(kind: OperationType.multiply, opened: true),
  entry(kind: OperationType.multiply, correct: false),
  // Minus: saved before hintOpened was, steps seen before the check.
  Attempt(
    const ArithmeticProblem(5, 3, OperationType.minus, 2),
    firstAnswer: 2,
    elapsedMs: 1000,
    answeredAt: DateTime(2026, 11, 20),
    hintsUsed: 2,
  ),
  // Not answers: a skip with a hint and a sprint answer.
  entry(skipped: true, opened: true),
  entry(kind: OperationType.divide, sprint: true),
];

Future<void> loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

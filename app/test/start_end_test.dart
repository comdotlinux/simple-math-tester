import 'dart:convert';

import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/home_page.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/l10n/app_localizations_en.dart';
import 'package:simple_math_tester/labels.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import 'en.dart';

/// Start and End of practice (issue #175): the kinds wait before Start,
/// practice shows only the question and the header, and End shows what the
/// round did.
void main() {
  final equation = (OperationType.algebra.source as AlgebraSource).build(
    OperationType.algebra,
    'missingMinuend',
    [3, 4],
  )!;
  const kinds = {
    OperationType.plus,
    OperationType.minus,
    OperationType.algebra,
  };

  Future<MathTesterModel> launch(
    WidgetTester tester, {
    Size size = const Size(360, 640),
    double scale = 1,
    Progress? progress,
    Problem problem = const ArithmeticProblem(2, 3, OperationType.plus, 5),
    Problem Function()? next,
    DateTime Function()? clock,
    bool updateReminders = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: problem,
      nextProblem: next,
      clock: clock,
      updateReminders: updateReminders,
      progress: progress ?? Progress(tier: Tier.easy),
      ticker: () => const Stream.empty(),
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

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> check(WidgetTester tester, String answer) async {
    await tester.enterText(find.byType(TextField), answer);
    await tap(tester, checkAnswerButtonKey);
  }

  String textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  /// Every string key from `keys.dart` on screen, so a control that should
  /// wait before Start fails the practice list below.
  Set<String> keysShown(WidgetTester tester) => {
    for (final element
        in find
            .byWidgetPredicate((widget) => widget.key is ValueKey<String>)
            .evaluate())
      (element.widget.key! as ValueKey<String>).value,
  };

  group('before Start', () {
    testWidgets('the app opens with the kinds, Start and the sprint, and no '
        'question', (tester) async {
      await launch(tester);
      for (final key in [
        startPracticeButtonKey,
        sprintButtonKey,
        settingsButtonKey,
        for (final kind in OperationType.values) operationToggleKey(kind),
        myAnswersNavKey,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(find.text(en.practiceTitle), findsOneWidget);
      for (final key in [
        questionOnProblemsPageKey,
        endPracticeButtonKey,
        nextQuestionButtonKey,
        numberPadKey,
      ]) {
        expect(find.byKey(key), findsNothing, reason: '$key');
      }
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Start has a clear label and moves the focus to the answer', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await launch(tester);
      expect(
        tester.getSemantics(find.byKey(startPracticeButtonKey)),
        isSemantics(
          label: 'Start practice',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      await tap(tester, startPracticeButtonKey);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(
        tester.getSemantics(find.byKey(endPracticeButtonKey)),
        isSemantics(
          label: 'End practice and see what you did',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('while practising', () {
    // The exact list: a control added to the practice page, or one that
    // should wait before Start, fails it.
    for (final (size, shown) in [
      (
        const Size(360, 640),
        {
          'material-app',
          'home-page',
          'problems-page',
          'hud',
          'hud-streak',
          'hud-goal',
          'hud-combo',
          'hud-xp',
          'end-practice-button',
          // The menu stays during practice to change the kinds (#179).
          'settings-button',
          'question-on-problems-page',
          'next-question-button',
          'hint-button',
          'keyboard-switch',
          'check-answer-button',
          'no-feedback',
        },
      ),
      (
        const Size(1280, 900),
        {
          'material-app',
          'home-page',
          'problems-page',
          'hud',
          'hud-streak',
          'hud-goal',
          'hud-combo',
          'hud-xp',
          'end-practice-button',
          // The menu stays during practice to change the kinds (#179).
          'settings-button',
          'question-on-problems-page',
          'next-question-button',
          'hint-button',
          'keyboard-switch',
          'number-pad',
          'check-answer-button',
          'pad-delete',
          for (var digit = 0; digit <= 9; digit++) 'pad-digit-$digit',
          'no-feedback',
        },
      ),
    ]) {
      testWidgets('at ${size.width.toInt()}x${size.height.toInt()} the page '
          'shows only the header, the question, the answer, End and Skip', (
        tester,
      ) async {
        // Everything that waits before Start would show here: a new kind's
        // card, the update reminder, the sprint result.
        final model = await launch(
          tester,
          size: size,
          updateReminders: true,
          progress: Progress(tier: Tier.easy, updateReminderDate: '2000-01-01'),
        );
        expect(find.byKey(newKindCardKey), findsOneWidget);
        expect(find.byKey(updateReminderKey), findsOneWidget);
        model.startPractice();
        await tester.pumpAndSettle();
        expect(keysShown(tester), shown);
        expect(find.text(en.practiceTitle), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an algebra or geometry question has its Report button', (
      tester,
    ) async {
      final model = await launch(
        tester,
        problem: equation,
        progress: Progress(tier: Tier.easy, selectedOperations: kinds),
      );
      model.startPractice();
      await tester.pumpAndSettle();
      expect(find.byKey(reportFlagKey), findsOneWidget);
    });

    testWidgets('settings and My answers are two taps away: End, then the '
        'item', (tester) async {
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await tap(tester, endPracticeButtonKey);
      await tap(tester, settingsButtonKey);
      expect(find.byKey(settingsSheetKey), findsOneWidget);
      Navigator.of(tester.element(find.byKey(settingsSheetKey))).pop();
      await tester.pumpAndSettle();

      model.startPractice();
      await tester.pumpAndSettle();
      await tap(tester, endPracticeButtonKey);
      await tap(tester, myAnswersNavKey);
      expect(find.byKey(resultsPageKey), findsOneWidget);
    });

    testWidgets('the Android back gesture is End', (tester) async {
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(model.practising, isFalse);
      expect(find.byKey(homePageKey), findsOneWidget);
      expect(find.byKey(roundSummaryKey), findsOneWidget);
    });
  });

  group('End', () {
    /// History, XP, combo, goal and levels, which End must leave alone.
    Object counters(MathTesterModel model) => (
      model.history.length,
      [for (final attempt in model.history) attempt.hintOpened],
      model.game.xp,
      model.game.combo,
      model.game.dailyCount,
      model.game.streak,
      {
        for (final MapEntry(:key, :value) in model.difficulty.entries)
          key: (value.level, value.answered, value.correct),
      },
    ).toString();

    Future<void> expectEndRecordsNothing(
      WidgetTester tester,
      MathTesterModel model,
    ) async {
      final before = counters(model);
      final open = model.current;
      await tap(tester, endPracticeButtonKey);
      expect(counters(model), before);
      expect(model.practising, isFalse);
      expect(model.current, isNot(same(open)), reason: 'the question dropped');
      expect(find.byKey(questionOnProblemsPageKey), findsNothing);
      expect(find.byKey(startPracticeButtonKey), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(startPracticeButtonKey))
            .focusNode!
            .hasFocus,
        isTrue,
        reason: 'the focus goes to Start',
      );
    }

    testWidgets('on a fresh question records nothing', (tester) async {
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4');
      await expectEndRecordsNothing(tester, model);
      expect(model.lastRound!.attempts, isEmpty);
    });

    testWidgets('after a wrong answer with the two choices records nothing '
        'more', (tester) async {
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await check(tester, '4');
      expect(find.byKey(tryAgainButtonKey), findsOneWidget);
      await expectEndRecordsNothing(tester, model);
      expect(model.history, hasLength(1));
    });

    testWidgets('after the hint modal closed records nothing more', (
      tester,
    ) async {
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await check(tester, '4');
      await tap(tester, hintButtonKey);
      await tap(tester, hintCloseKey);
      await expectEndRecordsNothing(tester, model);
      expect(model.history.single.hintOpened, isTrue);
    });

    testWidgets('after End the kinds change, and the next Start asks only '
        'from them', (tester) async {
      final model = await launch(tester, size: const Size(1280, 900));
      model.startPractice();
      await tester.pumpAndSettle();
      await tap(tester, endPracticeButtonKey);
      for (final kind in [
        OperationType.plus,
        OperationType.minus,
        OperationType.multiply,
      ]) {
        await tap(tester, operationToggleKey(kind));
      }
      await tap(tester, startPracticeButtonKey);
      for (var i = 0; i < 10; i++) {
        expect(model.current.kind, OperationType.divide);
        await tap(tester, nextQuestionButtonKey);
      }
    });
  });

  group('the summary', () {
    testWidgets('equals a hand-counted round: mixed kinds, a hinted answer, '
        'a skip and a wrong answer', (tester) async {
      var now = DateTime(2026, 11, 21, 9);
      final queue = <Problem>[
        const ArithmeticProblem(9, 4, OperationType.minus, 5),
        equation,
        const ArithmeticProblem(4, 4, OperationType.plus, 8),
        const ArithmeticProblem(6, 1, OperationType.plus, 7),
        const ArithmeticProblem(8, 2, OperationType.minus, 6),
      ];
      final model = await launch(
        tester,
        clock: () => now,
        next: () => queue.length > 1 ? queue.removeAt(0) : queue.first,
        // 90 XP: the first right answer reaches level 2 at 100.
        progress: Progress(
          tier: Tier.easy,
          selectedOperations: kinds,
          game: const GameState(xp: 90),
        ),
      );
      await tap(tester, startPracticeButtonKey);
      // 1. 2 + 3, right: 10 XP, combo 1, level 2.
      await check(tester, '5');
      await tap(tester, nextQuestionButtonKey);
      // 2. 9 − 4 with the hint opened first, right: half of 11 XP, combo 2.
      await tap(tester, hintButtonKey);
      await tap(tester, hintCloseKey);
      await check(tester, '5');
      await tap(tester, nextQuestionButtonKey);
      // 3. The equation, wrong, then right: only the first check counts.
      await check(tester, '8');
      await check(tester, '${equation.result}');
      await tap(tester, nextQuestionButtonKey);
      // 4. 4 + 4, skipped.
      await tap(tester, nextQuestionButtonKey);
      // 5. 6 + 1, right: 10 XP, combo 1.
      await check(tester, '7');
      await tap(tester, nextQuestionButtonKey);
      // 6. 8 − 2 stays open: End drops it.
      await tester.enterText(find.byType(TextField), '6');
      now = now.add(const Duration(minutes: 2, seconds: 5));
      await tap(tester, endPracticeButtonKey);

      final summary = model.lastRound!;
      expect(summary.attempts, hasLength(5));
      expect(summary.answered, 4);
      expect(summary.correct, 3);
      expect(summary.xp, 10 + 6 + 10);
      expect(summary.bestCombo, 2);
      expect(summary.hintsOpened, 1);
      expect(summary.skipped, 1);
      expect(summary.time, const Duration(minutes: 2, seconds: 5));
      expect(summary.level, 2);
      expect(summary.kinds, [
        (kind: OperationType.plus, answered: 2, correct: 2),
        (kind: OperationType.minus, answered: 1, correct: 1),
        (kind: OperationType.algebra, answered: 1, correct: 0),
      ]);
      expect(model.game.xp, 90 + 26);

      expect(textOf(tester, summaryAnsweredKey), '4');
      expect(textOf(tester, summaryCorrectKey), '3');
      expect(textOf(tester, summaryXpKey), '26');
      expect(textOf(tester, summaryComboKey), '2');
      expect(textOf(tester, summaryHintsKey), '1');
      expect(textOf(tester, summarySkippedKey), '1');
      expect(textOf(tester, summaryTimeKey), '2 minutes 5 seconds');
      expect(textOf(tester, summaryLevelKey), 'You reached level 2!');
      expect(
        textOf(tester, summaryKindKey(OperationType.plus)),
        '2 of 2 right',
      );
      expect(
        textOf(tester, summaryKindKey(OperationType.algebra)),
        '0 of 1 right',
      );
      expect(find.byKey(summaryKindKey(OperationType.multiply)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no answers it says so calmly and Done closes it', (
      tester,
    ) async {
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await tap(tester, endPracticeButtonKey);
      expect(find.text(en.summaryNone), findsOneWidget);
      expect(find.byKey(summaryAnsweredKey), findsNothing);
      await tap(tester, roundSummaryDoneKey);
      expect(find.byKey(roundSummaryKey), findsNothing);
      expect(model.lastRound, isNull);
    });

    testWidgets('See my answers opens My answers', (tester) async {
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await check(tester, '5');
      await tap(tester, endPracticeButtonKey);
      await tap(tester, roundSummaryAnswersKey);
      expect(find.byKey(resultsPageKey), findsOneWidget);
      expect(model.lastRound, isNull);
    });

    testWidgets('a screen reader reads it in order: title, then each row as '
        'its label and value, then the buttons', (tester) async {
      final semantics = tester.ensureSemantics();
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await check(tester, '5');
      await tap(tester, endPracticeButtonKey);
      final labels = <String>[];
      void walk(SemanticsNode node) {
        final label = node.getSemanticsData().label;
        if (label.isNotEmpty) labels.add(label);
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(tester.getSemantics(find.byKey(roundSummaryKey)));
      final order = [
        en.summaryTitle,
        '${en.summaryAnswered}\n1',
        '${en.summaryCorrect}\n1',
        '${en.summaryXp}\n10',
        '${en.summaryBestCombo}\n1',
        '${en.summaryHints}\n0',
        '${en.summarySkipped}\n0',
        en.summaryTime,
        '${OperationType.plus.label(en)}\n${en.summaryKind('1', '1')}',
        en.summarySeeAnswers,
        en.summaryDone,
      ];
      var at = -1;
      for (final text in order) {
        final index = labels.indexWhere((label) => label.startsWith(text));
        expect(index, greaterThan(at), reason: '"$text" in $labels');
        at = index;
      }
      semantics.dispose();
    });

    testWidgets('a finished sprint keeps its own result, never two '
        'summaries', (tester) async {
      final model = await launch(tester);
      model.startPractice();
      await tester.pumpAndSettle();
      await check(tester, '5');
      await tap(tester, endPracticeButtonKey);
      expect(find.byKey(roundSummaryKey), findsOneWidget);
      model.startSprint();
      await tester.pumpAndSettle();
      expect(find.byKey(roundSummaryKey), findsNothing);
      model.endSprint();
      await tester.pumpAndSettle();
      expect(find.byKey(sprintResultKey), findsOneWidget);
      expect(find.byKey(roundSummaryKey), findsNothing);
      expect(find.byKey(startPracticeButtonKey), findsOneWidget);

      model.startPractice();
      model.endPractice();
      await tester.pumpAndSettle();
      expect(find.byKey(roundSummaryKey), findsOneWidget);
      expect(find.byKey(sprintResultKey), findsNothing);
    });
  });

  // Measured with the bundled fonts, as on a device.
  group('in every language', () {
    setUpAll(() async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final family in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(family['family'] as String);
        for (final font
            in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
    });

    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toString();
      for (final size in const [Size(320, 568), Size(360, 640)]) {
        for (final scale in const [1.0, 2.0]) {
          // Overflow is reported as an error, which fails the test.
          testWidgets('$code ${size.width.toInt()}x${size.height.toInt()} '
              'text x$scale: before Start, practice, a wrong answer and the '
              'summary fit', (tester) async {
            final model = await launch(
              tester,
              size: size,
              scale: scale,
              progress: Progress(
                tier: Tier.easy,
                language: code,
                selectedOperations: kinds,
                game: const GameState(xp: 95),
              ),
            );
            expect(tester.takeException(), isNull);
            await tap(tester, startPracticeButtonKey);
            expect(tester.takeException(), isNull);
            // Right, reaching level 2, then a skip and a wrong answer.
            await check(tester, '5');
            model.generateNextProblem();
            model.generateNextProblem();
            await tester.pumpAndSettle();
            await check(tester, '999');
            expect(find.byKey(tryAgainButtonKey), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tap(tester, endPracticeButtonKey);
            expect(find.byKey(summaryLevelKey), findsOneWidget);
            expect(find.byKey(roundSummaryKey), findsOneWidget);
            await tap(tester, roundSummaryDoneKey);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  // Issue #191: a translated End label pushed the top row past the edge.
  testWidgets('a very long End label fits the top row of a small phone at '
      'text x2.0', (tester) async {
    const size = Size(320, 568);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: const ArithmeticProblem(2, 3, OperationType.plus, 5),
      progress: Progress(tier: Tier.easy, selectedOperations: kinds),
      ticker: () => const Stream.empty(),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: MediaQuery(
          data: const MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(2),
          ),
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light, model.palette),
            localizationsDelegates: const [
              _LongEndDelegate(),
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MyHomePage(key: homePageKey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, startPracticeButtonKey);
    expect(tester.takeException(), isNull);
    expect(find.text(_LongEnd.label), findsOneWidget);
    final end = tester.getRect(find.byKey(endPracticeButtonKey));
    expect(end.right, lessThanOrEqualTo(size.width));
    expect(end.height, greaterThanOrEqualTo(48));
    final menu = tester.getSize(find.byKey(settingsButtonKey));
    expect(menu.shortestSide, greaterThanOrEqualTo(48));
  });
}

/// English, with an End label far longer than any translation.
class _LongEnd extends AppLocalizationsEn {
  static const label =
      'Endthepracticeroundnowandseeeverythingyoudidinthisround';

  @override
  String get endPractice => label;
}

class _LongEndDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _LongEndDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async => _LongEnd();

  @override
  bool shouldReload(_LongEndDelegate old) => false;
}

import 'dart:math';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/app_theme.dart';
import 'package:simple_math_tester/celebration.dart';
import 'package:simple_math_tester/hud.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/legal.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import 'fake_store.dart';

void main() {
  final pad = find.byKey(numberPadKey);
  Finder padKey(String label) =>
      find.byKey(label == 'Delete' ? padDeleteKey : padDigitKey(label));
  List<Finder> padKeys() => [
    for (var digit = 0; digit <= 9; digit++) padKey('$digit'),
    padKey('Delete'),
    find.byKey(checkAnswerButtonKey),
  ];
  final celebrationPainter = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is CelebrationPainter,
  );
  final xpCounter = find.byType(TweenAnimationBuilder<int>);
  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;
  // Values are checked by key and number; feedback, button, answer-row and
  // semantics wording stays literal because the wording is the behaviour.
  String textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;
  Matcher showsNumber(num number) => matches(
    RegExp('(^|[^0-9.])${RegExp.escape(formatNumber(number))}(\$|[^0-9.])'),
  );
  // Only these numbers, in this order.
  Matcher showsNumbers(List<num> numbers) => matches(
    RegExp(
      '^[^0-9]*'
      '${numbers.map((n) => RegExp.escape(formatNumber(n))).join('[^0-9]+')}'
      '[^0-9]*\$',
    ),
  );
  Matcher showsXp(int xp) => showsNumbers([playerLevel(xp), xp]);

  Future<MathTesterModel> launch(
    WidgetTester tester, {
    Size size = const Size(1000, 900),
    double scale = 1,
    double keyboardInset = 0,
    bool disableAnimations = false,
    Problem problem = const Problem(12, 3, OperationType.plus, 15),
    Tier? tier = Tier.easy,
    GameState game = const GameState(),
    DateTime Function()? clock,
    EdgeInsets padding = EdgeInsets.zero,
    Stream<void> Function()? ticker,
    Brightness brightness = Brightness.light,
    void Function(Haptic)? haptic,
    bool haptics = true,
    ProgressStore? store,
    bool canSave = true,
    List<Attempt> history = const [],
    Future<bool> Function(Uri)? openLink,
    // Phones start with the system keyboard; this opens the pad as a
    // player does, with the keyboard button.
    bool usePad = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final model = MathTesterModel(
      initialProblem: problem,
      progress: Progress(
        tier: tier,
        game: game,
        haptics: haptics,
        history: history,
      ),
      clock: clock,
      ticker: ticker,
      haptic: haptic,
      store: store,
      canSave: canSave,
      openLink: openLink,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
            disableAnimations: disableAnimations,
            platformBrightness: brightness,
          ),
          child: const MathTesterApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(model.dispose);
    if (usePad && pad.evaluate().isEmpty) {
      await tester.ensureVisible(find.byKey(keyboardSwitchKey));
      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
    }
    return model;
  }

  testWidgets('Practice and results remain navigable', (tester) async {
    await launch(tester);
    expect(find.byKey(questionOnProblemsPageKey), findsOneWidget);
    await tester.tap(find.byKey(myAnswersNavKey));
    await tester.pumpAndSettle();
    expect(find.byKey(noResultsOnResultsPageKey), findsOneWidget);
    await tester.tap(find.byKey(practiceNavKey));
    await tester.pumpAndSettle();
    expect(find.byKey(questionOnProblemsPageKey), findsOneWidget);
  });

  // Android ignores a config update on an open connection, so only a new
  // connection tells it the keyboard type; with the old one a tap on the
  // field brought the system keyboard back over the pad.
  testWidgets('The keyboard button reconnects the focused field with the '
      'new keyboard type', (tester) async {
    await launch(tester, size: const Size(360, 640), keyboardInset: 260);
    final log = tester.testTextInput.log;
    // The keyboard type of each new connection since the log was cleared.
    List<String> connected() => [
      for (final call in log)
        if (call.method == 'TextInput.setClient')
          ((call.arguments as List)[1] as Map)['inputType']['name'] as String,
    ];
    expect(connected(), ['TextInputType.number']);

    for (final type in ['TextInputType.none', 'TextInputType.number']) {
      log.clear();
      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
      expect(connected(), [type]);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
    }
  });

  for (final useKeyboard in [false, true]) {
    testWidgets(
      'Submit visible answer via ${useKeyboard ? 'keyboard' : 'button'}',
      (tester) async {
        final model = await launch(tester);
        await tester.enterText(find.byType(TextField), '15');
        if (useKeyboard) {
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          await tester.tap(find.byKey(checkAnswerButtonKey));
        }
        await tester.pumpAndSettle();
        expect(model.history.single.correct, isTrue);
        expect(find.text('You got it!'), findsOneWidget);
        await tester.tap(find.byKey(nextQuestionButtonKey));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
        await tester.tap(find.byKey(checkAnswerButtonKey));
        await tester.pumpAndSettle();
        expect(model.history, hasLength(1));
        expect(find.text('Enter a number first.'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Draft survives navigation and results distinguish skipped answers',
    (tester) async {
      final model = await launch(tester);
      await tester.enterText(find.byType(TextField), '42');
      await tester.tap(find.byKey(myAnswersNavKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(practiceNavKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '42',
      );
      await tester.tap(find.byKey(nextQuestionButtonKey));
      await tester.pumpAndSettle();
      expect(model.history.length, 1);
      await tester.tap(find.byKey(myAnswersNavKey));
      await tester.pumpAndSettle();
      // The verdict word is what the row tells the player.
      expect(
        find.descendant(
          of: find.byKey(historyRowKey(0)),
          matching: find.text('Skipped'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Results rows below the fold appear when scrolled to', (
    tester,
  ) async {
    final model = await launch(tester, size: const Size(360, 640));
    model.setDraftInput('14');
    model.submitAnswer();
    model.generateNextProblem();
    model.setDraftInput('${model.current.result}');
    model.submitAnswer();
    model.generateNextProblem();
    model.generateNextProblem();
    model.setCurrentPage(1);
    await tester.pumpAndSettle();
    expect(textOf(tester, historyCountKey), showsNumber(3));
    // Rows are built lazily: the last one is not on screen yet.
    final last = find.byKey(historyRowKey(2));
    expect(last, findsNothing);

    await tester.scrollUntilVisible(
      last,
      100,
      scrollable: find.descendant(
        of: find.byKey(resultsPageKey),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.descendant(of: last, matching: find.text('Skipped')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  List<Attempt> answers(int count) => [
    for (var i = 1; i <= count; i++)
      Attempt(
        Problem(i, 1, OperationType.plus, i + 1),
        firstAnswer: i + 1,
        elapsedMs: 1500,
        answeredAt: DateTime(2026, 11, 13, 18),
      ),
  ];

  for (final scale in [1.0, 1.3]) {
    testWidgets('At text scale $scale the stats shrink to a pinned bar', (
      tester,
    ) async {
      final model = await launch(
        tester,
        size: const Size(360, 640),
        scale: scale,
        history: answers(30),
      );
      final semantics = tester.ensureSemantics();
      model.setCurrentPage(1);
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(resultsPageKey),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      final bar = find.byKey(compactStatsKey);
      expect(find.byKey(statsCardKey), findsOneWidget);
      expect(bar, findsNothing);

      position.jumpTo(1500);
      await tester.pumpAndSettle();
      expect(bar, findsOneWidget);
      final pinned = tester.getRect(bar);
      expect(pinned.top, greaterThanOrEqualTo(0));
      expect(pinned.height, lessThan(640 / 5));
      expect(find.byKey(statsCardKey), findsNothing);
      // The bar shows numbers only; screen readers hear the full labels.
      // (The daily streak is left out: the header reads it too.)
      for (final label in [
        'Best streak: 0',
        'Best sprint: 0',
        'Total XP: 0',
        'Player level: 1',
      ]) {
        expect(find.semantics.byLabel(label), findsOne, reason: label);
      }

      // Rows move under the bar; the bar stays put.
      final rowLabel = find.text(
        tester
            .widget<Text>(find.textContaining(RegExp(r'^Question \d+$')).last)
            .data!,
      );
      final rowTop = tester.getRect(rowLabel).top;
      position.jumpTo(position.pixels + 200);
      await tester.pumpAndSettle();
      expect(tester.getRect(bar), pinned);
      expect(tester.getRect(rowLabel).top, rowTop - 200);

      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(bar, findsNothing);
      expect(find.byKey(statsCardKey), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('Resizing while scrolled down keeps the header whole', (
    tester,
  ) async {
    final model = await launch(
      tester,
      size: const Size(360, 640),
      history: answers(30),
    );
    model.setCurrentPage(1);
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(resultsPageKey),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    position.jumpTo(1500);
    await tester.pumpAndSettle();
    expect(find.byKey(compactStatsKey), findsOneWidget);

    // The header's measured heights are one frame old after each change.
    for (final size in [const Size(640, 360), const Size(240, 640)]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.byKey(compactStatsKey), findsOneWidget);
    }
  });

  testWidgets('My answers loads 20 rows at a time, then shows the end', (
    tester,
  ) async {
    final model = await launch(
      tester,
      size: const Size(360, 640),
      history: answers(45),
    );
    model.setCurrentPage(1);
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(resultsPageKey),
      matching: find.byType(Scrollable),
    );
    // Rows in the cache area below the screen count as built.
    final loading = find.byKey(answersLoadingKey, skipOffstage: false);
    final end = find.byKey(answersEndKey, skipOffstage: false);
    // Jumps down until the loading row or the end marker is built, then
    // pumps the one frame a page needs to load.
    Future<void> scrollToEnd() async {
      final position = tester.state<ScrollableState>(list).position;
      while (loading.evaluate().isEmpty && end.evaluate().isEmpty) {
        position.jumpTo(min(position.pixels + 300, position.maxScrollExtent));
        await tester.pump();
      }
      if (loading.evaluate().isNotEmpty) {
        final spinner = find.descendant(
          of: loading,
          matching: find.byType(CircularProgressIndicator, skipOffstage: false),
          skipOffstage: false,
        );
        expect(
          tester.widget<CircularProgressIndicator>(spinner).semanticsLabel,
          'Loading more answers',
        );
        await tester.pump();
      }
    }

    // Answer rows the list can build, plus the loading row or end marker.
    int rowCount() => tester
        .widget<SliverList>(
          find.descendant(
            of: find.byKey(resultsPageKey),
            matching: find.byType(SliverList, skipOffstage: false),
            skipOffstage: false,
          ),
        )
        .delegate
        .estimatedChildCount!;

    expect(find.text('45 questions completed.'), findsOneWidget);
    expect(rowCount(), 21);
    // Newest first: the top page holds Questions 45 to 26.
    expect(find.text('Question 25', skipOffstage: false), findsNothing);

    await scrollToEnd();
    expect(rowCount(), 41);
    await scrollToEnd();
    expect(rowCount(), 46);
    await scrollToEnd();
    expect(rowCount(), 46);
    expect(loading, findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(answersEndKey),
      300,
      scrollable: list,
    );
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text("That's all your answers"), findsOneWidget);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.semantics.byLabel("That's all your answers"), findsOne);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('At 360x640 the first row is reachable below the stats card', (
    tester,
  ) async {
    final model = await launch(tester, size: const Size(360, 640));
    model.setDraftInput('14');
    model.submitAnswer();
    model.generateNextProblem();
    model.setDraftInput('${model.current.result}');
    model.submitAnswer();
    model.generateNextProblem();
    model.generateNextProblem();
    model.setCurrentPage(1);
    await tester.pumpAndSettle();
    expect(find.byKey(statsCardKey), findsOneWidget);
    expect(textOf(tester, historyCountKey), showsNumber(3));
    final first = find.byKey(historyRowKey(0));
    // The header and the stats card fill the first screen.
    expect(first.hitTestable(), findsNothing);

    // Scroll until the row is built, then bring its whole card into view,
    // so a taller stats card cannot leave part of the row off screen.
    await tester.scrollUntilVisible(
      first,
      100,
      scrollable: find.descendant(
        of: find.byKey(resultsPageKey),
        matching: find.byType(Scrollable),
      ),
    );
    final row = find.descendant(of: first, matching: find.byType(Card));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    // The whole first row is on screen at once. Searched inside that row,
    // because the random second problem can also have 14 as its answer.
    Finder inRow(String text) =>
        find.descendant(of: row, matching: find.text(text)).hitTestable();
    expect(inRow('Question 1'), findsOneWidget);
    expect(inRow(model.history.first.problem.question), findsOneWidget);
    expect(inRow('Your answer: 14'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets('Results at width $width show the first answer', (
      tester,
    ) async {
      final model = await launch(tester, size: Size(width, 900));
      model.setDraftInput('14');
      model.submitAnswer();
      model.setDraftInput('15');
      model.submitAnswer();
      model.setCurrentPage(1);
      await tester.pumpAndSettle();
      expect(textOf(tester, historyCountKey), showsNumber(1));
      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('Your answer: 14'), findsOneWidget);
      expect(find.text('Expected answer: 15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Results at width $width drop ".0" but keep decimals', (
      tester,
    ) async {
      final model = await launch(
        tester,
        size: Size(width, 900),
        problem: const Problem(12, 3, OperationType.divide, 4.0),
      );
      model.setDraftInput('4.5');
      model.submitAnswer();
      model.setCurrentPage(1);
      await tester.pumpAndSettle();
      expect(find.text('Your answer: 4.5'), findsOneWidget);
      expect(find.text('Expected answer: 4'), findsOneWidget);
      expect(find.textContaining('4.0'), findsNothing);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('Short viewport and keyboard inset keep practice usable, '
        '${brightness.name} theme', (tester) async {
      final model = await launch(
        tester,
        size: const Size(390, 500),
        scale: 2,
        keyboardInset: 180,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      // A phone starts with the system keyboard.
      expect(find.byKey(numberPadKey), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '15');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('You got it!'), findsOneWidget);
      await tester.ensureVisible(find.byKey(nextQuestionButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(nextQuestionButtonKey));
      await tester.pumpAndSettle();
      expect(model.history.length, 1);
      expect(tester.takeException(), isNull);
    });
  }

  group('hints', () {
    const steps = [
      'Break 12 into 10 + 2 and 3 into 3.',
      'Add matching places: 10 + 0 = 10; 2 + 3 = 5.',
      'Combine the parts: 10 + 5 = 15.',
    ];

    int visibleSteps() =>
        steps.where((step) => find.text(step).evaluate().isNotEmpty).length;

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    Future<void> check(WidgetTester tester, String answer) async {
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), answer);
      await tapKey(tester, checkAnswerButtonKey);
    }

    Future<MathTesterModel> launchNarrow(WidgetTester tester) => launch(
      tester,
      size: const Size(320, 500),
      scale: 2,
      keyboardInset: 180,
    );

    final revealControl = find.byKey(revealStepButtonKey);

    bool canReveal(WidgetTester tester) =>
        tester.widget<ButtonStyleButton>(revealControl).enabled;

    Finder revealLabel(String label) =>
        find.descendant(of: revealControl, matching: find.text(label));

    testWidgets('criterion 7: steps reveal one at a time', (tester) async {
      final model = await launchNarrow(tester);
      expect(model.steps, steps);
      expect(visibleSteps(), 0);
      expect(find.byKey(solutionStepsKey), findsNothing);
      expect(revealLabel('Hint'), findsOneWidget);
      expect(canReveal(tester), isTrue);

      await tapKey(tester, revealStepButtonKey);
      expect(visibleSteps(), 1);
      expect(find.text(steps[0]), findsOneWidget);
      expect(find.byKey(solutionStepsKey), findsOneWidget);
      expect(revealLabel('Hint'), findsNothing);
      expect(revealLabel('Next step'), findsOneWidget);

      await tapKey(tester, revealStepButtonKey);
      expect(visibleSteps(), 2);
      // The final step states the answer and needs a valid check first.
      expect(canReveal(tester), isFalse);
      expect(revealLabel('Next step'), findsOneWidget);
      await tapKey(tester, revealStepButtonKey);
      expect(visibleSteps(), 2);
      expect(find.text(steps.last), findsNothing);

      await check(tester, '15');
      expect(find.text('You got it!'), findsOneWidget);
      expect(visibleSteps(), 2);
      expect(canReveal(tester), isTrue);
      await tapKey(tester, revealStepButtonKey);
      expect(visibleSteps(), 3);
      expect(find.text(steps.last), findsOneWidget);
      expect(canReveal(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('criterion 8: a wrong first check without hints shows 1 step', (
      tester,
    ) async {
      await launchNarrow(tester);
      await check(tester, '14');
      expect(find.text('Not quite. Try another answer.'), findsOneWidget);
      expect(visibleSteps(), 1);
      expect(find.text(steps[0]), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('criterion 8: a wrong first check keeps 2 opened steps', (
      tester,
    ) async {
      await launchNarrow(tester);
      await tapKey(tester, revealStepButtonKey);
      await tapKey(tester, revealStepButtonKey);
      await check(tester, '14');
      expect(find.text('Not quite. Try another answer.'), findsOneWidget);
      expect(visibleSteps(), 2);
      expect(find.text(steps.last), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard focus stays on the reveal control', (tester) async {
      await launch(tester);
      Focus.of(
        tester.element(
          find.descendant(of: revealControl, matching: find.text('Hint')),
        ),
      ).requestFocus();
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);

      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
      }
      expect(visibleSteps(), 2);
      expect(canReveal(tester), isFalse);
      expect(revealLabel('Next step'), findsOneWidget);
      expect(
        find.ancestor(of: revealControl, matching: find.byType(Card)),
        findsNothing,
      );
    });

    testWidgets('the newest step is announced through a live region', (
      tester,
    ) async {
      await launch(tester);
      await tapKey(tester, revealStepButtonKey);
      expect(
        tester.getSemantics(find.text(steps[0])),
        isSemantics(isLiveRegion: true),
      );
      await tapKey(tester, revealStepButtonKey);
      expect(
        tester.getSemantics(find.text(steps[1])),
        isSemantics(isLiveRegion: true),
      );
      expect(
        tester.getSemantics(find.text(steps[0])),
        isSemantics(isLiveRegion: false),
      );
    });
  });

  group('operation chips', () {
    // flutter_test's byTooltip matches Flutter's own Tooltip, not material_ui's.
    Finder tooltip(String message) => find.byWidgetPredicate(
      (widget) => widget is Tooltip && widget.message == message,
    );

    // Its semantics node is the whole chip.
    Finder chip(OperationType type) => find.byKey(operationToggleKey(type));

    testWidgets('criterion 5: the last selected chip stays selected', (
      tester,
    ) async {
      final model = await launch(
        tester,
        size: const Size(390, 844),
        usePad: true,
      );
      for (final type in OperationType.values) {
        expect(
          tester.getSemantics(chip(type)),
          isSemantics(isSelected: true, hasSelectedState: true),
        );
      }
      for (final type in [
        OperationType.plus,
        OperationType.minus,
        OperationType.divide,
      ]) {
        await tester.tap(chip(type));
        await tester.pumpAndSettle();
      }
      expect(
        tester.getSemantics(chip(OperationType.plus)),
        isSemantics(isSelected: false, hasSelectedState: true),
      );

      await tester.tap(chip(OperationType.multiply));
      await tester.pumpAndSettle();
      expect(model.selectedOperations, {OperationType.multiply});
      expect(
        tester.getSemantics(chip(OperationType.multiply)),
        isSemantics(
          label: 'Multiplication',
          isSelected: true,
          hasSelectedState: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      // Deselecting kinds kept the problem on screen and recorded nothing.
      expect(find.text('12 + 3'), findsOneWidget);
      expect(model.history, isEmpty);
    });

    testWidgets('chips show only the sign and name the operation', (
      tester,
    ) async {
      await launch(tester);
      for (final (type, sign, name) in [
        (OperationType.plus, '+', 'Addition'),
        (OperationType.minus, '\u2212', 'Subtraction'),
        (OperationType.multiply, '\u00d7', 'Multiplication'),
        (OperationType.divide, '\u00f7', 'Division'),
      ]) {
        expect(find.text(sign), findsOneWidget);
        expect(tooltip(name), findsOneWidget);
        expect(
          tester.getSemantics(chip(type)),
          isSemantics(label: name, isSelected: true, hasSelectedState: true),
        );
      }
    });

    for (final width in [320.0, 390.0, 800.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('chips stay on one line at $width, text scale $scale', (
          tester,
        ) async {
          await launch(tester, size: Size(width, 900), scale: scale);
          final rects = [
            for (final type in OperationType.values)
              tester.getRect(tooltip(type.label)),
          ];
          final card = tester.getRect(
            find.ancestor(
              of: find.byKey(questionOnProblemsPageKey),
              matching: find.byType(Card),
            ),
          );
          for (final rect in rects) {
            expect(rect.top, rects.first.top);
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.width, moreOrLessEquals(rects.first.width));
          }
          expect(rects.first.left, moreOrLessEquals(card.left));
          expect(rects.last.right, moreOrLessEquals(card.right));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('criterion 37: reduced motion gives feedback and '
        'celebration zero duration and builds no particles, '
        '${brightness.name} theme', (tester) async {
      final model = await launch(
        tester,
        disableAnimations: true,
        brightness: brightness,
        // 10 XP from level 2 and one answer from the daily goal.
        game: const GameState(
          xp: 90,
          dailyCount: 9,
          lastActiveDate: '2026-11-14',
        ),
        clock: () => DateTime(2026, 11, 14, 9),
      );
      // Checked with Enter: a tap's ink splash would be a running animation.
      // The label floats with its own short animation as text arrives.
      await tester.enterText(find.byType(TextField), '14');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse, reason: 'shake');

      model.generateNextProblem();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        formatNumber(model.current.result),
      );
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(model.celebrations, 1);
      expect(tester.hasRunningAnimations, isFalse, reason: 'pop and burst');
      expect(celebrationPainter, findsNothing);
      expect(model.game.xp, 100);
      expect(playerLevel(model.game.xp), 2);
      expect(textOf(tester, hudXpKey), showsXp(100));
      expect(
        tester.widget<TweenAnimationBuilder<int>>(xpCounter).duration,
        Duration.zero,
      );
      final feedback = find.ancestor(
        of: find.text('You got it!'),
        matching: find.byType(AnimatedSwitcher),
      );
      expect(feedback, findsOneWidget);
      expect(tester.widget<AnimatedSwitcher>(feedback).duration, Duration.zero);
    });

    testWidgets('Practice controls meet 48px touch targets, '
        '${brightness.name} theme', (tester) async {
      await launch(
        tester,
        size: const Size(390, 844),
        brightness: brightness,
        usePad: true,
      );
      for (final finder in [
        find.byKey(checkAnswerButtonKey),
        find.byKey(nextQuestionButtonKey),
        find.byKey(revealStepButtonKey),
        find.byType(TextField),
        find.byKey(settingsButtonKey),
        find.byKey(sprintButtonKey),
        find.byKey(keyboardSwitchKey),
        for (final type in OperationType.values)
          find.byWidgetPredicate(
            (widget) => widget is Tooltip && widget.message == type.label,
          ),
        ...padKeys(),
      ]) {
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    // The compact docked phone page, with the pad and with the system
    // keyboard.
    for (final size in const [Size(360, 640), Size(412, 720)]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('Docked phone controls meet 48px touch targets at '
            '${size.width.toInt()}x${size.height.toInt()}, text scale '
            '$scale, ${brightness.name} theme', (tester) async {
          void expectTargets(List<Finder> finders) {
            for (final finder in finders) {
              final size = tester.getSize(finder);
              expect(size.width, greaterThanOrEqualTo(48), reason: '$finder');
              expect(size.height, greaterThanOrEqualTo(48), reason: '$finder');
            }
          }

          final shared = [
            find.byKey(nextQuestionButtonKey),
            find.byKey(sprintButtonKey),
            find.byKey(keyboardSwitchKey),
            for (final type in OperationType.values)
              find.byWidgetPredicate(
                (widget) => widget is Tooltip && widget.message == type.label,
              ),
          ];
          await launch(
            tester,
            size: size,
            scale: scale,
            brightness: brightness,
          );
          expect(pad, findsNothing);
          expectTargets([...shared, find.byKey(checkAnswerButtonKey)]);
          await tester.tap(find.byKey(keyboardSwitchKey));
          await tester.pumpAndSettle();
          expect(pad, findsOneWidget);
          expectTargets([...shared, ...padKeys()]);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final width in [320.0, 390.0, 600.0, 768.0, 800.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Responsive $width at text scale $scale, '
            '${brightness.name} theme', (tester) async {
          final model = await launch(
            tester,
            size: Size(width, 900),
            scale: scale,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(TextField), findsOneWidget);
          expect(find.byKey(hudKey), findsOneWidget);
          model.generateNextProblem();
          model.setCurrentPage(1);
          await tester.pumpAndSettle();
          expect(find.byKey(hudKey), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  group('tier picker', () {
    for (final (width, scale) in [(320.0, 2.0), (390.0, 1.0), (1000.0, 1.0)]) {
      testWidgets('covers practice until a tier is chosen at $width, '
          'text scale $scale', (tester) async {
        final model = await launch(
          tester,
          size: Size(width, 640),
          scale: scale,
          tier: null,
        );
        expect(find.byKey(tierPickerKey), findsOneWidget);
        expect(find.byKey(questionOnProblemsPageKey), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(
          tester.getSemantics(find.text('How hard should it start?')),
          isSemantics(isHeader: true),
        );
        for (final tier in Tier.values) {
          final button = find.byKey(tierOptionKey(tier));
          await tester.ensureVisible(button);
          final size = tester.getSize(button);
          expect(size.height, greaterThanOrEqualTo(48));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(
            tester.getSemantics(button),
            isSemantics(label: tier.label, isButton: true, hasTapAction: true),
          );
        }
        expect(tester.takeException(), isNull);

        // "My answers" stays reachable while the picker is shown.
        await tester.tap(find.byKey(myAnswersNavKey));
        await tester.pumpAndSettle();
        expect(find.byKey(noResultsOnResultsPageKey), findsOneWidget);
        await tester.tap(find.byKey(practiceNavKey));
        await tester.pumpAndSettle();
        expect(find.byKey(tierPickerKey), findsOneWidget);

        final medium = find.byKey(tierOptionKey(Tier.medium));
        await tester.ensureVisible(medium);
        await tester.tap(medium);
        await tester.pumpAndSettle();
        expect(model.tier, Tier.medium);
        expect(model.current.level, 3);
        expect(model.history, isEmpty);
        expect(find.byKey(tierPickerKey), findsNothing);
        expect(find.byKey(questionOnProblemsPageKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a tier can be chosen with the keyboard', (tester) async {
      final model = await launch(tester, tier: null);
      Focus.of(
        tester.element(
          find.descendant(
            of: find.byKey(tierOptionKey(Tier.hard)),
            matching: find.text(Tier.hard.label),
          ),
        ),
      ).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(model.tier, Tier.hard);
      expect(model.current.level, 4);
    });
  });

  group('settings sheet', () {
    Finder tierTile(Tier tier) => find.byKey(tierSettingKey(tier));

    for (final (width, scale) in [(320.0, 2.0), (1000.0, 1.0)]) {
      testWidgets('changes the tier and draws at the new level at $width, '
          'text scale $scale', (tester) async {
        final model = await launch(
          tester,
          size: Size(width, 640),
          scale: scale,
          tier: Tier.easy,
        );
        expect(
          tester.getSemantics(find.byKey(settingsButtonKey)),
          isSemantics(label: 'Settings', isButton: true, hasTapAction: true),
        );
        await tester.ensureVisible(find.byKey(settingsButtonKey));
        await tester.tap(find.byKey(settingsButtonKey));
        await tester.pumpAndSettle();
        expect(find.byKey(settingsSheetKey), findsOneWidget);
        expect(textOf(tester, currentTierNoteKey), contains(model.tier!.label));
        for (final (key, label) in [
          (soundSwitchKey, 'Sound'),
          (hapticsSwitchKey, 'Vibration'),
        ]) {
          await tester.ensureVisible(find.byKey(key));
          await tester.pumpAndSettle();
          expect(tester.getSemantics(find.byKey(key)).label, startsWith(label));
          expect(
            tester.getSemantics(find.byKey(key)),
            isSemantics(
              hasToggledState: true,
              isToggled: true,
              hasTapAction: true,
            ),
          );
          expect(
            tester.getSize(find.byKey(key)).height,
            greaterThanOrEqualTo(48),
          );
        }
        for (final tier in Tier.values) {
          await tester.ensureVisible(tierTile(tier));
          await tester.pumpAndSettle();
          expect(
            tester.getSemantics(tierTile(tier)),
            isSemantics(
              label: tier.label,
              isSelected: tier == Tier.easy,
              hasTapAction: true,
            ),
          );
          expect(
            tester.getSize(tierTile(tier)).height,
            greaterThanOrEqualTo(48),
          );
        }
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(tierTile(Tier.hard));
        await tester.tap(tierTile(Tier.hard));
        await tester.pumpAndSettle();
        expect(find.byKey(settingsSheetKey), findsNothing);
        expect(model.tier, Tier.hard);
        expect(model.current.level, 4);
        // The replaced problem is not recorded.
        expect(model.history, isEmpty);
        expect(find.text('12 + 3'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('choosing the current tier keeps the problem', (tester) async {
      final model = await launch(tester);
      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(tierTile(Tier.easy));
      await tester.pumpAndSettle();
      expect(find.byKey(settingsSheetKey), findsNothing);
      expect(model.current.question, '12 + 3');
    });

    testWidgets('the theme choice switches to dark and is saved', (
      tester,
    ) async {
      final store = FakeStore();
      final model = await launch(tester, store: store);
      Brightness shown() =>
          Theme.of(tester.element(find.byKey(problemsPageKey))).brightness;
      SegmentedButton<ThemeMode> choice() =>
          tester.widget(find.byType(SegmentedButton<ThemeMode>));
      expect(shown(), Brightness.light);
      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();

      for (final mode in ThemeMode.values) {
        await tester.ensureVisible(find.byKey(themeModeKey(mode)));
        await tester.pumpAndSettle();
        expect(find.byKey(themeModeKey(mode)), findsOneWidget);
      }
      expect(choice().selected, {ThemeMode.system});

      await tester.tap(find.byKey(themeModeKey(ThemeMode.dark)));
      await tester.pumpAndSettle();
      expect(model.themeMode, ThemeMode.dark);
      expect(choice().selected, {ThemeMode.dark});
      expect(shown(), Brightness.dark);
      final saved = Progress.decode((await store.read(progressKey))!);
      expect(saved.themeMode, ThemeMode.dark);

      await tester.tap(find.byKey(themeModeKey(ThemeMode.light)));
      await tester.pumpAndSettle();
      expect(shown(), Brightness.light);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the theme choice fits on one line at 360, text scale 1.3', (
      tester,
    ) async {
      await launch(tester, size: const Size(360, 640), scale: 1.3);
      await tester.ensureVisible(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byKey(settingsSheetKey));
      final choice = find.byType(SegmentedButton<ThemeMode>);
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      final rect = tester.getRect(choice);
      expect(rect.left, moreOrLessEquals(sheet.left + 12 + 16));
      expect(rect.right, moreOrLessEquals(sheet.right - 12 - 24));
      expect(rect.height, greaterThanOrEqualTo(52));
      for (final mode in ThemeMode.values) {
        final label = tester.renderObject<RenderParagraph>(
          find.byKey(themeModeKey(mode)),
        );
        expect(label.didExceedMaxLines, isFalse, reason: mode.name);
        expect(
          tester.getSize(find.byKey(themeModeKey(mode))).width,
          lessThan(rect.width / 3),
        );
      }
      expect(tester.takeException(), isNull);
    });

    Future<void> tapInSheet(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets('criterion 61: Privacy shows the bundled policy offline', (
      tester,
    ) async {
      final opened = <Uri>[];
      await launch(
        tester,
        size: const Size(320, 640),
        scale: 2,
        openLink: (uri) async => (opened..add(uri)).isNotEmpty,
      );
      await tapInSheet(tester, privacyTileKey);

      expect(find.byKey(privacyPageKey), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      // The list is lazy; the Turnstile paragraph is below the fold.
      await tester.scrollUntilVisible(
        find.textContaining('loads Cloudflare Turnstile'),
        300,
      );
      expect(opened, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(privacyPageKey), findsNothing);
      expect(find.byKey(settingsSheetKey), findsOneWidget);
    });

    testWidgets('criterion 61: Impressum opens the production page', (
      tester,
    ) async {
      final opened = <Uri>[];
      await launch(
        tester,
        openLink: (uri) async => (opened..add(uri)).isNotEmpty,
      );
      await tapInSheet(tester, impressumTileKey);

      expect(opened, [Uri.parse('https://math.munich-tech.de/impressum')]);
      expect(opened.single, impressumUrl);
      expect(find.byKey(settingsSheetKey), findsNothing);
      expect(find.text('The browser did not open.'), findsNothing);
    });

    for (final (name, opener) in <(String, Future<bool> Function(Uri))>[
      ('reports false', (_) async => false),
      ('throws', (_) async => throw StateError('no browser')),
    ]) {
      testWidgets('when the opener $name, a notice says so', (tester) async {
        await launch(tester, openLink: opener);
        await tapInSheet(tester, impressumTileKey);

        expect(find.text('The browser did not open.'), findsOneWidget);
      });
    }
  });

  group('header', () {
    final morning = DateTime(2026, 11, 14, 9);
    const playing = GameState(
      xp: 250,
      combo: 4,
      dailyCount: 6,
      lastActiveDate: '2026-11-14',
      lastGoalDate: '2026-11-14',
      streak: 3,
      bestStreak: 3,
    );

    void expectLabel(WidgetTester tester, String label) => expect(
      tester.getSemantics(find.bySemanticsLabel(label)),
      matchesSemantics(label: label),
    );

    String goal(int count) => 'Daily goal: $count of 10';

    testWidgets('criterion 24: each value has a label with its value', (
      tester,
    ) async {
      await launch(tester, game: playing, clock: () => morning);
      expectLabel(tester, 'Daily streak: 3');
      expectLabel(tester, goal(6));
      expectLabel(tester, 'Level 2, 250 XP, 50 XP to level 3');
      expectLabel(tester, 'Combo: 4');

      // 12 + 3 at level 1 with combo 4 earns 14 XP.
      await tester.enterText(find.byType(TextField), '15');
      await tester.tap(find.byKey(checkAnswerButtonKey));
      await tester.pumpAndSettle();
      expectLabel(tester, 'Daily streak: 3');
      expectLabel(tester, goal(7));
      expectLabel(tester, 'Level 2, 264 XP, 36 XP to level 3');
      expectLabel(tester, 'Combo: 5');
    });

    testWidgets('criterion 24: bootstrap shows XP 250 and streak 3 at once', (
      tester,
    ) async {
      final today = localDate(DateTime.now());
      final store = FakeStore({
        progressKey: Progress(
          tier: Tier.easy,
          game: GameState(
            xp: 250,
            streak: 3,
            bestStreak: 3,
            lastActiveDate: today,
            lastGoalDate: today,
          ),
        ).encode(),
      });
      await bootstrap(store);
      await tester.pump();
      expectLabel(tester, 'Daily streak: 3');
      expectLabel(tester, 'Level 2, 250 XP, 50 XP to level 3');
      expect(textOf(tester, hudXpKey), showsXp(250));
    });

    testWidgets('criterion 23: a document from yesterday shows the ring at 0', (
      tester,
    ) async {
      final yesterday = dateBefore(localDate(DateTime.now()));
      final store = FakeStore({
        progressKey: Progress(
          tier: Tier.easy,
          game: GameState(dailyCount: 7, lastActiveDate: yesterday),
        ).encode(),
      });
      await bootstrap(store);
      await tester.pump();
      expectLabel(tester, goal(0));
      expect(textOf(tester, hudGoalKey), showsNumbers([0, dailyGoal]));
    });

    testWidgets('criterion 23: a resume after the date changed resets it', (
      tester,
    ) async {
      var now = DateTime(2026, 11, 14, 23, 50);
      final model = await launch(tester, game: playing, clock: () => now);
      expectLabel(tester, goal(6));

      now = DateTime(2026, 11, 15, 0, 5);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expectLabel(tester, goal(0));
      expect(model.game.dailyCount, 0);
      expect(model.game.lastActiveDate, '2026-11-15');
      expect(model.history, isEmpty);
    });

    testWidgets('criterion 23: left open past midnight, a rebuild shows 0', (
      tester,
    ) async {
      var now = DateTime(2026, 11, 14, 23, 59);
      final model = await launch(tester, game: playing, clock: () => now);
      expectLabel(tester, goal(6));

      now = DateTime(2026, 11, 15, 0, 1);
      tester.element(find.byType(Hud)).markNeedsBuild();
      await tester.pump();
      expectLabel(tester, goal(0));
      expect(model.game.dailyCount, 6, reason: 'no event has run');
    });

    for (final (width, scale) in [(320.0, 2.0), (390.0, 1.0), (1000.0, 1.0)]) {
      testWidgets('shows on both pages inside the safe area at $width, '
          'text scale $scale', (tester) async {
        final model = await launch(
          tester,
          size: Size(width, 700),
          scale: scale,
          padding: const EdgeInsets.only(top: 59, bottom: 34),
          // Every value at its decode clamp, to show the header still fits.
          game: const GameState(
            xp: maxStoredXp,
            combo: maxStoredRun,
            dailyCount: maxStoredDailyCount,
            lastActiveDate: '2026-11-14',
            lastGoalDate: '2026-11-14',
            streak: maxStoredRun,
            bestStreak: maxStoredRun,
          ),
          clock: () => morning,
        );
        for (final page in [0, 1]) {
          model.setCurrentPage(page);
          await tester.pumpAndSettle();
          final hud = tester.getRect(find.byKey(hudKey));
          expect(hud.top, greaterThanOrEqualTo(59));
          expect(hud.left, greaterThanOrEqualTo(0));
          expect(hud.right, lessThanOrEqualTo(width));
          expectLabel(tester, 'Daily streak: 100000');
          expectLabel(tester, goal(10000));
          expectLabel(tester, 'Combo: 100000');
          expectLabel(
            tester,
            'Level 4472, 1000000000 XP, 162800 XP to level 4473',
          );
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('the no-write notice is in the header', (tester) async {
      final previous = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = previous);
      await bootstrap(FakeStore()..readFailures = 1);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(hudKey),
          matching: find.byKey(cantSaveNoticeKey),
        ),
        findsOneWidget,
      );
    });
  });

  for (final (width, scale) in [(320.0, 2.0), (1000.0, 1.0)]) {
    testWidgets('My answers shows stats above the history at $width, '
        'text scale $scale', (tester) async {
      final model = await launch(
        tester,
        size: Size(width, 900),
        scale: scale,
        clock: () => DateTime(2026, 11, 14, 9),
        game: const GameState(
          xp: 250,
          lastActiveDate: '2026-11-14',
          lastGoalDate: '2026-11-13',
          streak: 3,
          bestStreak: 8,
        ),
      );
      model.setDraftInput('15');
      model.submitAnswer();
      model.generateNextProblem();
      model.setCurrentPage(1);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(statsCardKey)).bottom,
        lessThan(tester.getRect(find.byKey(historyCountKey)).top),
      );
      final addition = find.ancestor(
        of: find.text(OperationType.plus.label),
        matching: find.byType(Table),
      );
      expect(addition, findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('–'), findsNWidgets(3));
      expect(textOf(tester, dailyStreakStatKey), showsNumber(3));
      expect(textOf(tester, bestStreakStatKey), showsNumber(8));
      // 12 + 3 at level 1 with combo 0 earns 10 XP.
      expect(model.game.xp, 260);
      expect(textOf(tester, totalXpStatKey), showsNumber(260));
      expect(textOf(tester, playerLevelStatKey), showsNumber(playerLevel(260)));
      expect(tester.takeException(), isNull);
    });
  }

  group('sprint', () {
    late StreamController<void> ticks;
    late DateTime now;
    final start = DateTime(2026, 11, 14, 9);
    setUp(() {
      // Synchronous, so a tick is handled before the next pump's frame.
      ticks = StreamController<void>.broadcast(sync: true);
      now = start;
    });
    tearDown(() => ticks.close());

    Future<MathTesterModel> launchSprint(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      double scale = 1,
      bool disableAnimations = false,
      GameState game = const GameState(bestSprint: 5),
    }) async {
      final model = await launch(
        tester,
        size: size,
        scale: scale,
        disableAnimations: disableAnimations,
        game: game,
        clock: () => now,
        ticker: () => ticks.stream,
      );
      await tester.ensureVisible(find.byKey(sprintButtonKey));
      await tester.tap(find.byKey(sprintButtonKey));
      await tester.pumpAndSettle();
      return model;
    }

    Future<void> tickTo(WidgetTester tester, int seconds) async {
      now = start.add(Duration(seconds: seconds));
      ticks.add(null);
      await tester.pump();
    }

    Future<void> answer(WidgetTester tester, num value) async {
      await tester.enterText(find.byType(TextField), formatNumber(value));
      await tester.ensureVisible(find.byKey(checkAnswerButtonKey));
      await tester.tap(find.byKey(checkAnswerButtonKey));
      await tester.pumpAndSettle();
    }

    final countdown = find.byKey(sprintCountdownKey);

    testWidgets('criterion 25: Next and Hint are absent; time out shows the '
        'score and the best, announced, and a new problem', (tester) async {
      final model = await launchSprint(tester);
      expect(model.inSprint, isTrue);
      expect(find.byKey(nextQuestionButtonKey), findsNothing);
      expect(find.byKey(revealStepButtonKey), findsNothing);
      expect(find.byKey(sprintButtonKey), findsNothing);
      expect(textOf(tester, sprintCountdownKey), showsNumber(60));
      expect(
        tester.getSemantics(countdown),
        isSemantics(label: '60 seconds left'),
      );

      final first = model.current;
      await answer(tester, first.result + 1);
      expect(model.current, isNot(same(first)), reason: 'wrong moves on');
      await answer(tester, model.current.result);
      expect(textOf(tester, sprintScoreKey), showsNumber(10));
      expect(find.byKey(nextQuestionButtonKey), findsNothing);
      expect(find.byKey(revealStepButtonKey), findsNothing);

      await tickTo(tester, 30);
      expect(textOf(tester, sprintCountdownKey), showsNumber(30));
      final onScreen = model.current;
      await tester.enterText(find.byType(TextField), '${onScreen.result}');
      await tickTo(tester, 60);
      await tester.pumpAndSettle();

      expect(model.inSprint, isFalse);
      expect(countdown, findsNothing);
      expect(model.history, hasLength(2), reason: 'time-out problem unsaved');
      expect(model.current, isNot(same(onScreen)));
      expect(model.game.combo, 0);
      final result = find.byKey(sprintResultKey);
      expect(result, findsOneWidget);
      expect(
        find.descendant(of: result, matching: find.byKey(sprintResultScoreKey)),
        findsOneWidget,
      );
      expect(textOf(tester, sprintResultScoreKey), showsNumber(10));
      expect(textOf(tester, sprintResultBestKey), showsNumber(10));
      expect(find.text('Answers by difficulty: level 1: 2'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Sprint over')),
        isSemantics(isLiveRegion: true),
      );
      expect(find.byKey(nextQuestionButtonKey), findsOneWidget);
      expect(find.byKey(revealStepButtonKey), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('criterion 25: switching to My answers ends the round with '
        'the score so far', (tester) async {
      final model = await launchSprint(tester);
      await answer(tester, model.current.result);
      final onScreen = model.current;
      await tester.tap(find.byKey(myAnswersNavKey));
      await tester.pumpAndSettle();
      expect(model.inSprint, isFalse);
      expect(textOf(tester, bestSprintStatKey), showsNumber(10));

      await tester.tap(find.byKey(practiceNavKey));
      await tester.pumpAndSettle();
      expect(countdown, findsNothing);
      expect(textOf(tester, sprintResultScoreKey), showsNumber(10));
      expect(model.current, isNot(same(onScreen)));
      expect(model.history, hasLength(1));
    });

    testWidgets('a lower score keeps the personal best', (tester) async {
      final model = await launchSprint(
        tester,
        game: const GameState(bestSprint: 500),
      );
      await answer(tester, model.current.result);
      await tickTo(tester, 60);
      await tester.pumpAndSettle();
      expect(textOf(tester, sprintResultScoreKey), showsNumber(10));
      expect(textOf(tester, sprintResultBestKey), showsNumber(500));
      expect(model.game.bestSprint, 500);
    });

    testWidgets('the back gesture ends the round, not the app', (tester) async {
      final model = await launchSprint(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(model.inSprint, isFalse);
      expect(find.byKey(homePageKey), findsOneWidget);
      expect(find.byKey(sprintResultKey), findsOneWidget);
    });

    testWidgets('no sprint before a tier is chosen', (tester) async {
      await launch(tester, tier: null);
      expect(find.byKey(tierPickerKey), findsOneWidget);
      expect(find.byKey(sprintButtonKey), findsNothing);
    });

    // A build of the question Text always creates a new RichText child, so
    // the number of distinct RichText instances seen is its build count.
    testWidgets('criterion 26: five ticks leave the question build count', (
      tester,
    ) async {
      final model = await launchSprint(tester);
      final builds = Set<Widget>.identity();
      void record() => builds.add(
        tester.widget(
          find.descendant(
            of: find.byKey(questionOnProblemsPageKey),
            matching: find.byType(RichText),
          ),
        ),
      );
      record();
      for (var second = 1; second <= 5; second++) {
        await tickTo(tester, second);
        expect(textOf(tester, sprintCountdownKey), showsNumber(60 - second));
        record();
      }
      expect(builds, hasLength(1));

      // The count does move when the page rebuilds.
      model.setDraftInput('1');
      await tester.pump();
      record();
      expect(builds, hasLength(2));
    });

    for (final (width, scale) in [(320.0, 2.0), (1000.0, 1.0)]) {
      testWidgets('fits at $width, text scale $scale, with reduced motion', (
        tester,
      ) async {
        final model = await launchSprint(
          tester,
          size: Size(width, 700),
          scale: scale,
          disableAnimations: true,
          game: const GameState(bestSprint: 123456),
        );
        expect(tester.takeException(), isNull);
        await answer(tester, model.current.result);
        await tickTo(tester, 1);
        expect(textOf(tester, sprintCountdownKey), showsNumber(59));
        expect(tester.takeException(), isNull);
        await tickTo(tester, 60);
        await tester.pumpAndSettle();
        expect(find.byKey(sprintResultKey), findsOneWidget);
        final button = find.byKey(sprintButtonKey);
        await tester.ensureVisible(button);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('themes', () {
    for (final brightness in Brightness.values) {
      testWidgets('the app follows a ${brightness.name} platform setting', (
        tester,
      ) async {
        await launch(tester, brightness: brightness);
        final context = tester.element(find.byKey(questionOnProblemsPageKey));
        final expected = brightness == Brightness.light
            ? AppTokens.light
            : AppTokens.dark;
        expect(Theme.of(context).brightness, brightness);
        expect(context.tokens, expected);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor ??
              Theme.of(context).scaffoldBackgroundColor,
          expected.surface,
        );
      });
    }

    double contrast(Color a, Color b) {
      final (la, lb) = (a.computeLuminance(), b.computeLuminance());
      return (max(la, lb) + .05) / (min(la, lb) + .05);
    }

    Color? opaque(Color? color) => color != null && color.a == 1 ? color : null;

    Color? decorationFill(Decoration? decoration) => switch (decoration) {
      BoxDecoration(:final color) => opaque(color),
      ShapeDecoration(:final color) => opaque(color),
      _ => null,
    };

    /// The fill an element's text is drawn on: the nearest opaque colour
    /// painted by an ancestor.
    Color? backgroundOf(Element element) {
      Color? found;
      element.visitAncestorElements((ancestor) {
        // A navigation destination draws its indicator as a sibling below
        // the icon, not as an ancestor.
        if (ancestor.widget is Stack) {
          ancestor.visitChildElements((child) {
            if (child.widget
                case NavigationIndicator(:final animation, :final color)
                when animation.value > 0) {
              found = opaque(color);
            }
          });
          if (found != null) return false;
        }
        found = switch (ancestor.widget) {
          DecoratedBox(:final decoration) => decorationFill(decoration),
          Ink(:final decoration) => decorationFill(decoration),
          ColoredBox(:final color) => opaque(color),
          PhysicalShape(:final color) => opaque(color),
          PhysicalModel(:final color) => opaque(color),
          InputDecorator(:final decoration) when decoration.filled ?? false =>
            opaque(decoration.fillColor),
          Material(:final color?) => opaque(color),
          Material(type: MaterialType.canvas) => opaque(
            Theme.of(ancestor).canvasColor,
          ),
          _ => null,
        };
        return found == null;
      });
      return found;
    }

    /// Every (text or icon colour, fill behind it) pair on screen, with the
    /// text that shows it.
    Map<(Color, Color), String> drawnPairs(WidgetTester tester) {
      final pairs = <(Color, Color), String>{};
      void add(Element element, Color? color, String text) {
        final background = backgroundOf(element);
        expect(color, isNotNull, reason: 'no colour for "$text"');
        expect(background, isNotNull, reason: 'no fill behind "$text"');
        pairs[(color!, background!)] = text;
      }

      for (final element in find.byType(RichText).evaluate()) {
        final span = (element.widget as RichText).text;
        span.visitChildren((child) {
          if (child is TextSpan && (child.text ?? '').trim().isNotEmpty) {
            final icon = element.findAncestorWidgetOfExactType<Icon>();
            add(
              element,
              child.style?.color ?? span.style?.color,
              icon == null
                  ? child.text!
                  : 'icon ${icon.semanticLabel ?? icon.icon?.codePoint}',
            );
          }
          return true;
        });
      }
      for (final element in find.byType(EditableText).evaluate()) {
        final field = element.widget as EditableText;
        add(element, field.style.color, field.controller.text);
      }
      return pairs;
    }

    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(400, 2000),
        Size(1000, 2000),
        Size(360, 640),
      ]) {
        testWidgets('criterion 33: every text and icon on every screen reaches '
            '4.5 to 1 on the fill behind it, ${brightness.name} theme at '
            '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          final tokens = brightness == Brightness.light
              ? AppTokens.light
              : AppTokens.dark;
          final seen = <(Color, Color), String>{};
          final states = <String>[];
          String role(Color color) => [
            for (final MapEntry(:key, :value) in tokens.colors.entries)
              if (value == color) key.name,
          ].join('/').ifEmpty(() => '$color');
          Future<void> collect(String state) async {
            await tester.pumpAndSettle();
            states.add(state);
            for (final MapEntry(key: pair, value: text) in drawnPairs(
              tester,
            ).entries) {
              seen.putIfAbsent(pair, () => '$state: "$text"');
            }
          }

          final model = await launch(
            tester,
            size: size,
            brightness: brightness,
            tier: null,
            canSave: false,
            ticker: () => const Stream.empty(),
          );
          await collect('tier picker, cannot save');
          model.setCurrentPage(1);
          await collect('my answers, empty');
          model.setCurrentPage(0);
          model.chooseTier(Tier.easy);
          model.toggleOperation(OperationType.divide);
          await collect('practice with an unselected toggle');
          while (model.canRevealStep) {
            model.revealStep();
          }
          await collect('hints up to a disabled reveal button');
          model.submitAnswer();
          await collect('empty check message');
          model.setDraftInput('14');
          model.submitAnswer();
          await collect('wrong answer');
          model.setDraftInput('15');
          model.submitAnswer();
          await collect('correct answer');
          await tester.tap(find.byKey(keyboardSwitchKey));
          // A phone starts with the system keyboard, so there the switch
          // opens the pad; elsewhere it shows the Check button.
          await collect('keyboard button pressed once');
          await tester.tap(find.byKey(keyboardSwitchKey));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(settingsButtonKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(settingsButtonKey));
          await collect('settings sheet');
          Navigator.of(tester.element(find.byKey(settingsSheetKey))).pop();
          model.startSprint();
          await collect('sprint');
          model.endSprint();
          await collect('sprint result');
          model.setCurrentPage(1);
          await collect('my answers with stats');

          // The walk did reach the pad, the fills and both kinds of ink.
          final foregrounds = {for (final (fg, _) in seen.keys) fg};
          expect(
            foregrounds,
            containsAll({
              tokens.ink,
              tokens.inkMuted,
              tokens.onPrimary,
              tokens.onOperation,
              tokens.onWrong,
              tokens.onCorrect,
              tokens.onSprint,
            }),
          );
          expect([
            for (final MapEntry(key: (fg, bg), value: where) in seen.entries)
              // Translucent text has no fixed contrast; disabled states use
              // opaque theme colours instead.
              if (fg.a < 1 || contrast(fg, bg) < 4.5)
                '$where: ${contrast(fg, bg).toStringAsFixed(2)} for '
                    '${role(fg)} on ${role(bg)}',
          ], isEmpty);
        });
      }
    }
  });

  for (final width in [360.0, 800.0]) {
    testWidgets('criterion 38: every control lies inside the safe area at '
        '$width', (tester) async {
      const top = 59.0, bottom = 34.0, height = 800.0;
      final model = await launch(
        tester,
        size: Size(width, height),
        padding: const EdgeInsets.only(top: top, bottom: bottom),
        ticker: () => const Stream.empty(),
      );
      final safe = Rect.fromLTRB(0, top, width, height - bottom);

      Future<void> expectInside(String state) async {
        await tester.pumpAndSettle();
        final controls = find.byWidgetPredicate(
          (widget) => widget is InkResponse || widget is EditableText,
        );
        var checked = 0;
        for (final element in controls.evaluate()) {
          final box = element.renderObject! as RenderBox;
          var rect = box.localToGlobal(Offset.zero) & box.size;
          // Inside a scroll view only the part in its viewport is on screen.
          if (Scrollable.maybeOf(element) case final scrollable?) {
            final view = scrollable.context.findRenderObject()! as RenderBox;
            final viewRect = view.localToGlobal(Offset.zero) & view.size;
            if (!rect.overlaps(viewRect)) continue;
            rect = rect.intersect(viewRect);
          }
          checked++;
          expect(
            rect.left >= safe.left - .01 &&
                rect.top >= safe.top - .01 &&
                rect.right <= safe.right + .01 &&
                rect.bottom <= safe.bottom + .01,
            isTrue,
            reason: '$state: ${element.widget.runtimeType} at $rect',
          );
        }
        expect(checked, greaterThanOrEqualTo(2), reason: state);
      }

      await expectInside('practice');
      model.setDraftInput('14');
      model.submitAnswer();
      await expectInside('wrong answer with a hint');
      await tester.ensureVisible(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(settingsButtonKey));
      await expectInside('settings sheet');
      Navigator.of(tester.element(find.byKey(settingsSheetKey))).pop();
      model.startSprint();
      await expectInside('sprint');
      model.endSprint();
      await expectInside('sprint result');
      model.setCurrentPage(1);
      await expectInside('my answers');
    });
  }

  group('answer-first flow', () {
    bool fieldFocused(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;
    String question(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(questionOnProblemsPageKey)).data!;
    Finder nextLabel(String label) => find.descendant(
      of: find.byKey(nextQuestionButtonKey),
      matching: find.text(label),
    );
    Future<void> enter(WidgetTester tester) async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    testWidgets('Enter checks, a second Enter moves on; the button says Skip '
        'before a check and Next question after', (tester) async {
      final model = await launch(tester);
      final first = model.current;
      expect(fieldFocused(tester), isTrue);
      expect(nextLabel('Skip'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(nextQuestionButtonKey)),
        isSemantics(label: 'Skip', isButton: true),
      );

      tester.testTextInput.enterText(formatNumber(first.result));
      await enter(tester);
      expect(model.history.single.correct, isTrue);
      expect(fieldFocused(tester), isTrue);
      expect(nextLabel('Next question'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(nextQuestionButtonKey)),
        isSemantics(label: 'Next question', isButton: true),
      );

      await enter(tester);
      expect(model.history, hasLength(1), reason: 'not recorded as a skip');
      expect(model.answerCorrect, isNull);
      expect(model.draftInput, '');
      expect(model.current, isNot(same(first)));
      expect(fieldFocused(tester), isTrue);
      expect(nextLabel('Skip'), findsOneWidget);

      // Enter on an empty field asks for a number; it never skips.
      final shown = question(tester);
      await enter(tester);
      expect(find.text('Enter a number first.'), findsOneWidget);
      expect(question(tester), shown);
    });

    testWidgets('a new answer after a wrong check is checked, not skipped', (
      tester,
    ) async {
      final model = await launch(tester);
      final first = model.current;
      tester.testTextInput.enterText(formatNumber(first.result + 1));
      await enter(tester);
      expect(model.answerCorrect, isFalse);
      tester.testTextInput.enterText(formatNumber(first.result));
      await tester.pump();
      await enter(tester);
      expect(model.answerCorrect, isTrue);
      expect(model.current, same(first));
      expect(find.text('You got it!'), findsOneWidget);
    });

    testWidgets(
      'the pad Check key checks, then reads Next and moves on',
      (tester) async {
        final model = await launch(
          tester,
          size: const Size(390, 844),
          usePad: true,
        );
        final first = model.current;
        final check = find.byKey(checkAnswerButtonKey);
        for (final digit in formatNumber(first.result).split('')) {
          await tester.tap(padKey(digit));
          await tester.pump();
        }
        await tester.tap(check);
        await tester.pumpAndSettle();
        expect(model.history.single.correct, isTrue);
        expect(
          find.descendant(of: check, matching: find.text('Next')),
          findsOne,
        );
        expect(
          tester.getSemantics(check),
          isSemantics(label: 'Next question', isButton: true),
        );
        expect(fieldFocused(tester), isTrue);

        await tester.tap(check);
        await tester.pumpAndSettle();
        expect(model.history, hasLength(1));
        expect(model.current, isNot(same(first)));
        expect(
          find.descendant(of: check, matching: find.text('Check answer')),
          findsOne,
        );
        expect(fieldFocused(tester), isTrue);
      },
      // A mouse press outside a field takes its focus on desktop.
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('focus comes back after Skip from the keyboard and after '
        'closing settings', (tester) async {
      final model = await launch(tester);
      final first = model.current;
      Focus.of(tester.element(nextLabel('Skip'))).requestFocus();
      await tester.pump();
      expect(fieldFocused(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(model.current, isNot(same(first)));
      expect(fieldFocused(tester), isTrue);

      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      expect(fieldFocused(tester), isFalse);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(settingsSheetKey), findsNothing);
      expect(fieldFocused(tester), isTrue);
    });

    testWidgets(
      'pressing a hint or an operation keeps the field focused',
      (tester) async {
        await launch(tester);
        await tester.tap(find.byKey(revealStepButtonKey));
        await tester.pumpAndSettle();
        expect(fieldFocused(tester), isTrue);
        await tester.tap(find.byKey(operationToggleKey(OperationType.minus)));
        await tester.pumpAndSettle();
        expect(fieldFocused(tester), isTrue);
      },
      // A mouse press outside a field takes its focus on desktop.
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  });

  group('number pad', () {
    Future<void> tapPad(WidgetTester tester, String label) async {
      await tester.tap(padKey(label));
      await tester.pump();
    }

    Map<String, dynamic> inputType(WidgetTester tester) =>
        tester.testTextInput.setClientArgs!['inputType']
            as Map<String, dynamic>;

    testWidgets('criterion 35: hardware typing and Enter check, pad keys edit '
        'the same field, the switch hides the pad, one Check', (tester) async {
      final model = await launch(
        tester,
        size: const Size(390, 844),
        usePad: true,
      );
      expect(pad, findsOneWidget);
      expect(find.byKey(checkAnswerButtonKey), findsOneWidget);
      expect(find.text('Check answer'), findsOneWidget);
      expect(
        find.descendant(of: pad, matching: find.byKey(checkAnswerButtonKey)),
        findsOneWidget,
      );

      // The field has focus with the pad shown, and asks for no soft
      // keyboard; hardware keys reach it through the platform text input.
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(inputType(tester)['name'], 'TextInputType.none');
      tester.testTextInput.enterText('15');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(model.history.single.correct, isTrue);
      expect(find.text('You got it!'), findsOneWidget);
      // Enter keeps the focus, so typing goes on into the field.
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TextField>(),
        isNotNull,
      );

      await tester.ensureVisible(find.byKey(nextQuestionButtonKey));
      await tester.tap(find.byKey(nextQuestionButtonKey));
      await tester.pumpAndSettle();
      for (final label in ['1', '2', '0']) {
        await tapPad(tester, label);
      }
      expect(fieldText(tester), '120');
      expect(model.draftInput, '120');
      await tapPad(tester, 'Delete');
      expect(fieldText(tester), '12');
      expect(model.draftInput, '12');
      // A key replaces a selection, as typing does.
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 1,
      );
      await tapPad(tester, '7');
      expect(fieldText(tester), '72');

      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
      expect(pad, findsNothing);
      expect(inputType(tester)['name'], 'TextInputType.number');
      expect(fieldText(tester), '72');
      expect(find.byKey(checkAnswerButtonKey), findsOneWidget);
      // Beside the docked field of a phone page it reads "Check".
      expect(
        tester.getSemantics(find.byKey(checkAnswerButtonKey)),
        isSemantics(label: 'Check answer', isButton: true),
      );
      expect(
        tester.getSemantics(find.byKey(keyboardSwitchKey)),
        isSemantics(tooltip: 'Use the number pad', isButton: true),
      );

      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
      expect(pad, findsOneWidget);
      expect(inputType(tester)['name'], 'TextInputType.none');
      expect(find.byKey(checkAnswerButtonKey), findsOneWidget);
      expect(find.text('Check answer'), findsOneWidget);
      await tester.tap(find.byKey(checkAnswerButtonKey));
      await tester.pumpAndSettle();
      expect(model.history, hasLength(2));
    });

    String switchTooltip(WidgetTester tester) =>
        tester.widget<IconButton>(find.byKey(keyboardSwitchKey)).tooltip!;

    for (final (size, phone) in const [
      (Size(360, 640), true),
      (Size(412, 720), true),
      (Size(390, 844), true),
      (Size(844, 390), true),
      (Size(800, 1000), false),
      (Size(1024, 768), false),
      (Size(1440, 900), false),
    ]) {
      testWidgets('starts with the ${phone ? 'system keyboard' : 'pad'} at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await launch(tester, size: size);
        expect(pad, phone ? findsNothing : findsOneWidget);
        expect(
          inputType(tester)['name'],
          phone ? 'TextInputType.number' : 'TextInputType.none',
        );
        expect(
          switchTooltip(tester),
          phone ? 'Use the number pad' : 'Use the keyboard',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('on a phone the keyboard button opens the pad and brings '
        'the system keyboard back', (tester) async {
      final model = await launch(tester, size: const Size(360, 640));
      expect(pad, findsNothing);
      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
      expect(pad, findsOneWidget);
      expect(inputType(tester)['name'], 'TextInputType.none');
      expect(switchTooltip(tester), 'Use the keyboard');
      await tapPad(tester, '1');
      await tapPad(tester, '5');
      await tester.tap(find.byKey(checkAnswerButtonKey));
      await tester.pumpAndSettle();
      expect(model.history.single.correct, isTrue);

      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
      expect(pad, findsNothing);
      expect(inputType(tester)['name'], 'TextInputType.number');
      expect(switchTooltip(tester), 'Use the number pad');
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the default follows the size until the player picks, then '
        'the pick stays', (tester) async {
      final model = await launch(tester, size: const Size(390, 844));
      Future<void> resize(Size size) async {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: model,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: const MathTesterApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(pad, findsNothing);
      // Turning a phone keeps its shortest side.
      await resize(const Size(844, 390));
      expect(pad, findsNothing);
      // A window widened past a phone takes the pad while nothing is
      // picked.
      await resize(const Size(1000, 900));
      expect(pad, findsOneWidget);
      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
      expect(pad, findsNothing);
      await resize(const Size(390, 844));
      expect(pad, findsNothing);
      await resize(const Size(1000, 900));
      expect(pad, findsNothing, reason: 'the player picked the keyboard');
      expect(tester.takeException(), isNull);
    });

    testWidgets('pasted or typed non-digits are dropped from the answer', (
      tester,
    ) async {
      final model = await launch(
        tester,
        size: const Size(390, 844),
        usePad: true,
      );
      // A paste arrives as one editing update.
      tester.testTextInput.enterText('1 5 apples');
      await tester.pump();
      expect(fieldText(tester), '15');
      expect(model.draftInput, '15');

      // Minus and decimal point from a hardware keyboard change nothing.
      for (final typed in ['-15', '15.', '1.5']) {
        tester.testTextInput.enterText(typed);
        await tester.pump();
        expect(fieldText(tester), '15', reason: typed);
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(model.history.single.firstAnswer, 15);

      model.generateNextProblem();
      await tester.pumpAndSettle();
      tester.testTextInput.enterText('-.');
      await tester.pump();
      expect(fieldText(tester), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Enter a number first.'), findsOneWidget);
      expect(model.history, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('criterion 36: pad keys have semantics labels', (tester) async {
      await launch(tester, size: const Size(390, 844), usePad: true);
      for (final label in [
        for (var digit = 0; digit <= 9; digit++) '$digit',
        'Delete',
      ]) {
        expect(
          tester.getSemantics(padKey(label)),
          isSemantics(
            label: label,
            isButton: true,
            hasTapAction: true,
            isFocusable: true,
          ),
          reason: label,
        );
      }
      expect(
        tester.getSemantics(find.byKey(checkAnswerButtonKey)),
        isSemantics(label: 'Check answer', isButton: true, hasTapAction: true),
      );
    });

    testWidgets('motion plays without blocking input and does not loop', (
      tester,
    ) async {
      final model = await launch(
        tester,
        size: const Size(390, 844),
        usePad: true,
        game: const GameState(xp: 90),
      );
      await tapPad(tester, '9');
      await tester.tap(find.byKey(checkAnswerButtonKey));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue, reason: 'shake');
      await tapPad(tester, 'Delete');
      await tapPad(tester, '1');
      expect(fieldText(tester), '1');
      await tester.pumpAndSettle();

      model.generateNextProblem();
      await tester.pumpAndSettle();
      model.setDraftInput(formatNumber(model.current.result));
      model.submitAnswer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(celebrationPainter, findsOneWidget);
      expect(textOf(tester, hudXpKey), isNot(showsXp(100)), reason: 'counting');
      // The burst lets pointers through to the pad.
      await tapPad(tester, '4');
      expect(fieldText(tester), '${formatNumber(model.current.result)}4');
      await tester.pumpAndSettle();
      expect(celebrationPainter, findsNothing);
      expect(textOf(tester, hudXpKey), showsXp(100));
    });

    for (final on in [true, false]) {
      testWidgets('haptics follow the switch (${on ? 'on' : 'off'})', (
        tester,
      ) async {
        final felt = <Haptic>[];
        final model = await launch(
          tester,
          size: const Size(390, 844),
          usePad: true,
          haptic: felt.add,
          haptics: on,
          game: const GameState(xp: 90),
        );
        await tapPad(tester, '9');
        await tapPad(tester, 'Delete');
        await tapPad(tester, '1');
        await tester.tap(find.byKey(checkAnswerButtonKey));
        await tester.pumpAndSettle();
        await tapPad(tester, '5');
        await tester.tap(find.byKey(checkAnswerButtonKey));
        await tester.pumpAndSettle();
        model.generateNextProblem();
        model.setDraftInput(formatNumber(model.current.result));
        model.submitAnswer();
        await tester.pumpAndSettle();
        expect(
          felt,
          on
              ? [
                  Haptic.key,
                  Haptic.key,
                  Haptic.key,
                  Haptic.wrong,
                  Haptic.key,
                  Haptic.correct,
                  Haptic.celebrate,
                ]
              : isEmpty,
        );
      });
    }

    testWidgets('the switches are saved and shown after a restart', (
      tester,
    ) async {
      final store = FakeStore();
      final model = await launch(tester, store: store);
      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(hapticsSwitchKey));
      await tester.pumpAndSettle();
      expect([model.sound, model.haptics], [true, false]);
      await tester.tap(find.byKey(soundSwitchKey));
      await tester.pumpAndSettle();
      expect([model.sound, model.haptics], [false, false]);
      final saved = Progress.decode((await store.read(progressKey))!);
      expect([saved.sound, saved.haptics], [false, false]);

      await bootstrap(store);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      for (final key in [soundSwitchKey, hapticsSwitchKey]) {
        expect(
          tester.getSemantics(find.byKey(key)),
          isSemantics(hasToggledState: true, isToggled: false),
        );
      }
    });

    // Visible means inside the screen's safe area and, for a control in a
    // scroll view, inside its viewport.
    void expectVisible(WidgetTester tester, Finder finder, Rect safe) {
      final rect = tester.getRect(finder);
      var shown = rect.intersect(safe);
      final element = finder.evaluate().single;
      if (Scrollable.maybeOf(element) case final scrollable?) {
        final view = scrollable.context.findRenderObject()! as RenderBox;
        shown = shown.intersect(view.localToGlobal(Offset.zero) & view.size);
      }
      expect(
        shown.width * shown.height,
        moreOrLessEquals(rect.width * rect.height, epsilon: .5),
        reason: '$finder: $shown of $rect',
      );
    }

    for (final (size, scale) in [
      (const Size(320, 640), 1.0),
      (const Size(320, 640), 2.0),
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 2.0),
      (const Size(800, 1000), 1.0),
      (const Size(800, 1000), 2.0),
      (const Size(1440, 900), 1.0),
      (const Size(1440, 900), 2.0),
      (const Size(390, 844), 1.0),
    ]) {
      for (final padding in [
        EdgeInsets.zero,
        const EdgeInsets.only(top: 59, bottom: 34),
      ]) {
        testWidgets('pad layout at ${size.width.toInt()}x'
            '${size.height.toInt()}, text scale $scale, '
            'safe area ${padding.top.toInt()}/${padding.bottom.toInt()}', (
          tester,
        ) async {
          await launch(
            tester,
            size: size,
            scale: scale,
            padding: padding,
            usePad: true,
          );
          expect(tester.takeException(), isNull);
          final safe = padding.deflateRect(Offset.zero & size);
          for (final key in padKeys()) {
            await tester.ensureVisible(key);
            await tester.pumpAndSettle();
            final rect = tester.getRect(key);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expectVisible(tester, key, safe);
          }
          if (scale == 1 &&
              (padding == EdgeInsets.zero || size.height >= 800)) {
            // At normal text size the question, the field and the whole pad
            // are in view together, with no scrolling by the player. (A
            // phone with 59/34 insets is taller than 640.)
            await launch(
              tester,
              size: size,
              scale: scale,
              padding: padding,
              usePad: true,
            );
            for (final finder in [
              find.byKey(questionOnProblemsPageKey),
              find.byType(TextField),
              ...padKeys(),
            ]) {
              expectVisible(tester, finder, safe);
            }
            // A check brings its feedback into view above the pad.
            tester.testTextInput.enterText('15');
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pumpAndSettle();
            for (final finder in [
              find.text('You got it!'),
              find.byType(TextField),
              ...padKeys(),
            ]) {
              expectVisible(tester, finder, safe);
            }
          }
          final next = find.byKey(nextQuestionButtonKey);
          await tester.ensureVisible(next);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}

extension on String {
  String ifEmpty(String Function() other) => this.isEmpty ? other() : this;
}

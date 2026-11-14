import 'dart:async';

import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart' as app;
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';
import 'package:simple_math_tester/sound_player.dart';

/// Writes [progress] as the saved document through the real plugin, then
/// launches the real app on it, so no test depends on another or on data
/// left by earlier runs. Pass a document with a tier unless the test is
/// about the tier picker.
Future<void> startWith(WidgetTester tester, Progress progress) =>
    startWithRaw(tester, progress.encode());

/// Like [startWith], for a document the app may not be able to read.
Future<void> startWithRaw(WidgetTester tester, String document) async {
  final store = SharedPreferencesStore();
  // A save still in flight from the previous test could land after this
  // write, so the write is repeated until it reads back.
  for (var i = 0; i < 5; i++) {
    await store.write(progressKey, document);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (await store.read(progressKey) == document) break;
  }
  await launch();
  await tester.pumpAndSettle();
}

/// The real entry point's startup on the real plugin, without audio: the
/// test devices may have no sound output.
Future<void> launch() =>
    app.bootstrap(SharedPreferencesStore(), const SilentSoundPlayer());

/// Closes and reopens the app once the saved document passes [saved]: the
/// new app reads only what the old one wrote.
Future<void> restartWhenSaved(
  WidgetTester tester,
  bool Function(Progress progress) saved,
) async {
  await waitForSaved(saved);
  await launch();
  await tester.pumpAndSettle();
}

/// The saved document once it passes [test]; saves are written
/// asynchronously after each change.
Future<Progress> waitForSaved(bool Function(Progress progress) test) async {
  late Progress progress;
  for (var i = 0; i < 100; i++) {
    progress = await savedProgress();
    if (test(progress)) return progress;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('The saved document never matched; last: ${progress.encode()}');
}

Future<Progress> savedProgress() async =>
    Progress.decode((await SharedPreferencesStore().read(progressKey))!);

/// Runs the real app widget on a model the test builds, for what the real
/// entry point cannot reach in reasonable time: a clock to move, ticks to
/// send, and vibrations and sounds to count. Nothing is written through the
/// plugin.
Future<MathTesterModel> startHarness(
  WidgetTester tester, {
  required Progress progress,
  required DateTime Function() clock,
  Stream<void> Function()? ticker,
  void Function(Haptic)? haptic,
  SoundPlayer sounds = const SilentSoundPlayer(),
  MemoryProgressStore? store,
}) async {
  final model = MathTesterModel(
    progress: progress,
    clock: clock,
    ticker: ticker,
    haptic: haptic,
    sounds: sounds,
    store: store ?? MemoryProgressStore(),
  );
  runApp(
    ChangeNotifierProvider.value(
      value: model,
      child: const app.MathTesterApp(),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

MathTesterModel modelOf(WidgetTester tester) =>
    tester.element(find.byKey(homePageKey)).read<MathTesterModel>();

/// Taps [finder] after scrolling it into view; phone screens hide much of
/// the page below the fold.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, Key key) =>
    tapVisible(tester, find.byKey(key));

/// Types [text] into the answer field through the same entry point the
/// platform's keyboard uses. tester.enterText cannot be used: integration
/// tests have no fake text input, and the framework drops its client id -1
/// message when asserts are off, so in release and profile builds the field
/// stayed empty. The field's input formatters still apply.
Future<void> typeAnswer(WidgetTester tester, String text) async {
  await tapVisible(tester, find.byType(TextField));
  tester
      .state<EditableTextState>(find.byType(EditableText))
      .updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
  await tester.pump();
}

/// Types [answer] as the app shows numbers (4.0 is typed 4) and checks it.
Future<void> submit(WidgetTester tester, num answer) async {
  await typeAnswer(tester, formatNumber(answer));
  await tapKey(tester, checkAnswerButtonKey);
}

/// Enter in the answer field: the field's action is done, and a keyboard's
/// Enter sends the same one.
Future<void> pressEnter(WidgetTester tester) async {
  tester
      .state<EditableTextState>(find.byType(EditableText))
      .performAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Whether the answer field has the focus. Check it before [typeAnswer],
/// which taps the field first. While another window has the desktop's
/// focus the app is inactive and Flutter holds the focus aside until it
/// resumes, so the app is resumed first.
Future<bool> answerFocused(WidgetTester tester) async {
  if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }
  return tester
      .widget<EditableText>(find.byType(EditableText))
      .focusNode
      .hasFocus;
}

/// The text on the Next button: Skip before a check.
Finder nextButtonText(String text) => find.descendant(
  of: find.byKey(nextQuestionButtonKey),
  matching: find.text(text),
);

Future<void> nextQuestion(WidgetTester tester) =>
    tapKey(tester, nextQuestionButtonKey);

Future<void> openHistory(WidgetTester tester) =>
    tapKey(tester, myAnswersNavKey);

Future<void> returnToPractice(WidgetTester tester) =>
    tapKey(tester, practiceNavKey);

Future<void> openSettings(WidgetTester tester) =>
    tapKey(tester, settingsButtonKey);

/// Closes the settings sheet with a tap on the barrier halfway between the
/// top of the screen and the sheet, wherever the sheet ends with large text
/// or a small phone. A sheet that fills the screen leaves no barrier to tap,
/// so there the system back action closes it.
Future<void> closeSettings(WidgetTester tester) async {
  final sheet = tester.getRect(find.byType(BottomSheet));
  if (sheet.top > 24) {
    await tester.tapAt(Offset(sheet.center.dx, sheet.top / 2));
  } else {
    await tester.binding.handlePopRoute();
  }
  await tester.pumpAndSettle();
}

/// The operation toggle for [type].
Finder operationToggle(OperationType type) =>
    find.byKey(operationToggleKey(type));

/// A digit key of the on-screen number pad.
Finder padKey(String digit) => find.byKey(padDigitKey(digit));

/// The number pad's Delete key.
Finder get padDelete => find.byKey(padDeleteKey);

/// The text of the [Text] widget keyed [key].
String textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// Matches a text that shows [number] whole, not as part of a longer number,
/// so a test can check a value without repeating the copy around it.
Matcher showsNumber(num number) => matches(
  RegExp('(^|[^0-9.])${RegExp.escape(formatNumber(number))}(\$|[^0-9.])'),
);

/// Matches a text whose only numbers are [numbers], in that order.
Matcher showsNumbers(List<num> numbers) => matches(
  RegExp(
    '^[^0-9]*'
    '${numbers.map((n) => RegExp.escape(formatNumber(n))).join('[^0-9]+')}'
    '[^0-9]*\$',
  ),
);

/// Matches the header's level and XP text for [xp]: level first, then XP.
Matcher showsXp(int xp) => showsNumbers([playerLevel(xp), xp]);

String answerFieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

String questionOnScreen(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(questionOnProblemsPageKey)).data!;

bool revealEnabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.byKey(revealStepButtonKey)).enabled;

/// How many of the current problem's solution steps are on screen.
int visibleSteps(WidgetTester tester) =>
    modelOf(tester).steps
        .where((step) => find.text(step).evaluate().isNotEmpty)
        .length;

// History rows are built lazily, so on a phone-sized screen a row below the
// header, the stats card or earlier rows does not exist until the list is
// scrolled to it. Each visit starts at the top, so rows are checked top to
// bottom.
Future<Finder> inHistory(WidgetTester tester, Finder finder) async {
  final list = find.descendant(
    of: find.byKey(resultsPageKey),
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -100));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  return finder;
}

// find.bySemanticsLabel reads RenderObject.debugSemantics, which is always
// null in release builds, so it never matches there. This counts the nodes
// of the live semantics tree, which exists in every build mode.
int semanticsNodesLabelled(WidgetTester tester, String label) {
  var count = 0;
  bool visit(SemanticsNode node) {
    if (node.label == label) count++;
    node.visitChildren(visit);
    return true;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return count;
}

String today() => localDate(DateTime.now());

String daysAgo(int days) =>
    localDate(DateTime.now().subtract(Duration(days: days)));

/// A checked attempt of [problem] answered with [answer] (null: skipped).
Attempt attempt(Problem problem, num? answer) => Attempt(
  problem,
  firstAnswer: answer,
  elapsedMs: 1500,
  answeredAt: DateTime(2026, 11, 13, 18),
);

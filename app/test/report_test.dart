import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/legal.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/report.dart';
import 'package:simple_math_tester/report_dialog.dart';
import 'package:simple_math_tester/rules.dart';

import 'en.dart';
import 'fake_store.dart';

/// Records every report and answers with [outcome]; the app's only request
/// goes through here in every test, so a count of [bodies] is a count of
/// requests.
class FakeReports implements ReportClient {
  final bodies = <String>[];
  ReportOutcome outcome = ReportOutcome.sent;

  @override
  Future<ReportOutcome> send(String body) async {
    bodies.add(body);
    return outcome;
  }
}

const questionKeys = {
  'type',
  'kind',
  'variant',
  'params',
  'level',
  'reason',
  'version',
  'platform',
  'locale',
};
const problemKeys = {'type', 'category', 'version', 'platform', 'locale'};

final _algebra = OperationType.algebra.source as AlgebraSource;
final _geometry = OperationType.geometry.source as GeometrySource;
final equation = _algebra.build(OperationType.algebra, 'missingSecondAddend', [
  3,
  4,
], level: 2)!;
final rectangle = _geometry.build(
  OperationType.geometry,
  'rectanglePerimeter',
  [5, 3],
)!;
const sum = ArithmeticProblem(12, 3, OperationType.plus, 15);

/// The old layout, without the one-time new-kind card.
final _seen = [for (final kind in OperationType.values) kind.name];

Map<String, Object?> decoded(String body) =>
    jsonDecode(body) as Map<String, Object?>;

void main() {
  late FakeReports reports;
  late FakeStore store;
  setUp(() {
    reports = FakeReports();
    store = FakeStore();
  });

  Progress saved() => Progress.decode(store.values[progressKey]!);

  group('the model', () {
    MathTesterModel model([Progress? progress]) => MathTesterModel(
      initialProblem: equation,
      progress: progress,
      store: store,
      reportClient: reports,
    );

    test('marking and unmarking save on the device and send nothing', () {
      final m = model();
      m.markSuspect(equation);
      expect(m.suspectOf(equation)?.sent, isFalse);
      expect(reports.bodies, isEmpty);
      m.unmarkSuspect(equation);
      expect(m.suspectOf(equation), isNull);
      expect(reports.bodies, isEmpty);
    });

    test('an arithmetic question has no code and cannot be marked', () {
      final m = model();
      m.markSuspect(sum);
      expect(m.suspectOf(sum), isNull);
      expect(SuspectQuestion.of(sum), isNull);
    });

    test('a question report is one request with exactly the contract '
        'fields; the mark is saved as sent', () async {
      final m = model()..markSuspect(equation);
      expect(
        await m.sendQuestionReport(equation, 'wrongAnswer', 'pt_PT'),
        ReportOutcome.sent,
      );
      expect(reports.bodies, hasLength(1));
      expect(decoded(reports.bodies.single), {
        'type': 'question',
        'kind': 'algebra',
        'variant': 'missingSecondAddend',
        'params': [3, 4],
        'level': 2,
        'reason': 'wrongAnswer',
        'version': appVersion,
        'platform': reportPlatform,
        'locale': 'pt_PT',
      });
      expect(decoded(reports.bodies.single).keys.toSet(), questionKeys);
      expect(m.suspectOf(equation)!.sent, isTrue);
      await pumpEventQueue();
      expect(saved().suspects.single.sent, isTrue);
    });

    test('a failed report keeps the mark, not sent', () async {
      reports.outcome = ReportOutcome.failed;
      final m = model()..markSuspect(equation);
      expect(
        await m.sendQuestionReport(equation, 'unclearQuestion', 'en'),
        ReportOutcome.failed,
      );
      expect(reports.bodies, hasLength(1));
      expect(m.suspectOf(equation)!.sent, isFalse);
    });

    test('a problem report is one request with exactly the contract '
        'fields', () async {
      final m = model();
      await m.sendProblemReport('display', 'de');
      expect(reports.bodies, hasLength(1));
      expect(decoded(reports.bodies.single), {
        'type': 'problem',
        'category': 'display',
        'version': appVersion,
        'platform': reportPlatform,
        'locale': 'de',
      });
      expect(decoded(reports.bodies.single).keys.toSet(), problemKeys);
    });

    test('every algebra and geometry question, at every level, has a code '
        'the report function accepts', () {
      final allow = jsonDecode(
        File('../functions/report-allowlist.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final random = Random(150);
      for (final kind in [OperationType.algebra, OperationType.geometry]) {
        final variants = <String>{};
        for (var level = 1; level <= kind.highestLevel; level++) {
          for (var i = 0; i < 200; i++) {
            final code = SuspectQuestion.of(kind.generate(random, level))!;
            expect(code.kind, kind.name);
            expect(allow[kind.name] as List, contains(code.variant));
            expect(code.level, inInclusiveRange(1, 5));
            variants.add(code.variant);
          }
        }
        expect(variants, unorderedEquals(allow[kind.name] as List));
      }
    });

    test('geometry adds the drawing reason; algebra does not', () {
      expect(questionReasons('algebra'), [
        'wrongAnswer',
        'unclearQuestion',
        'wrongHint',
      ]);
      expect(questionReasons('geometry'), contains('wrongDrawing'));
    });
  });

  group('the HTTP client', () {
    for (final (status, outcome) in [
      (201, ReportOutcome.sent),
      (200, ReportOutcome.sent),
      (400, ReportOutcome.failed),
      (429, ReportOutcome.failed),
      (500, ReportOutcome.failed),
      (502, ReportOutcome.failed),
    ]) {
      test('$status is $outcome', () async {
        final requests = <http.Request>[];
        final client = HttpReportClient(
          MockClient((request) async {
            requests.add(request);
            return http.Response('plain text', status);
          }),
        );
        expect(await client.send('{"type":"problem"}'), outcome);
        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.url, reportEndpoint);
        expect(request.headers['content-type'], startsWith('application/json'));
        expect(request.body, '{"type":"problem"}');
      });
    }

    test('no connection fails, without a retry', () async {
      var calls = 0;
      final client = HttpReportClient(
        MockClient((_) async {
          calls++;
          throw http.ClientException('offline');
        }),
      );
      expect(await client.send('{}'), ReportOutcome.failed);
      expect(calls, 1);
    });

    testWidgets('no answer within the timeout fails', (tester) async {
      final client = HttpReportClient(
        MockClient((_) => Completer<http.Response>().future),
      );
      ReportOutcome? outcome;
      unawaited(client.send('{}').then((value) => outcome = value));
      await tester.pump(HttpReportClient.timeout - const Duration(seconds: 1));
      expect(outcome, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(outcome, ReportOutcome.failed);
    });
  });

  group('saved marks', () {
    final mark = SuspectQuestion.of(equation)!;

    test('round trip, left out while empty', () {
      final again = Progress.decode(Progress(suspects: [mark]).encode());
      expect(again.suspects.single.toJson(), mark.toJson());
      expect(Progress().encode(), isNot(contains('suspectQuestions')));
    });

    test('at most ${Progress.suspectCap}, the oldest dropped', () {
      var progress = Progress();
      for (var i = 0; i <= Progress.suspectCap; i++) {
        progress = progress.withSuspect(
          SuspectQuestion(kind: 'algebra', variant: 'v', params: [i], level: 1),
        );
      }
      expect(progress.suspects, hasLength(Progress.suspectCap));
      expect(progress.suspects.first.params, [1]);
      expect(Progress.decode(progress.encode()).suspects, hasLength(200));
    });

    test('marking the same question again keeps one mark in place', () {
      final progress = Progress(suspects: [mark])
          .withSuspect(mark.asSent())
          .withSuspect(mark.asSent());
      expect(progress.suspects.single.sent, isTrue);
    });

    test('an older build keeps the field untouched, and this build gets it '
        'back', () {
      final written = Progress(suspects: [mark.asSent()]).encode();
      // To a build without marks, the field is one it does not know.
      final older = written.replaceAll(
        '"suspectQuestions"',
        '"fromANewerBuild"',
      );
      final decoded = Progress.decode(older);
      expect(decoded.suspects, isEmpty);
      // Unknown fields are written first; the content is the same.
      expect(jsonDecode(decoded.encode()), jsonDecode(older));
      final again = Progress.decode(
        decoded.encode().replaceAll('"fromANewerBuild"', '"suspectQuestions"'),
      );
      expect(again.encode(), written);
      expect(again.suspects.single.sent, isTrue);
    });

    test('an entry this build cannot read is kept as it is', () {
      final unknown = {
        'kind': 'algebra',
        'variant': 'v',
        'params': [1],
        'level': 1,
        'sent': false,
        'reason': 'fromANewerBuild',
      };
      final source = jsonEncode({
        'suspectQuestions': [mark.toJson(), unknown],
      });
      final decoded = Progress.decode(source);
      expect(decoded.suspects, hasLength(1));
      expect((jsonDecode(decoded.encode()) as Map)['suspectQuestions'], [
        mark.toJson(),
        unknown,
      ]);
    });
  });

  group('on screen', () {
    Future<MathTesterModel> launch(
      WidgetTester tester, {
      Problem? problem,
      Progress? progress,
      Size size = const Size(1000, 900),
      double scale = 1,
      // Practice starts as after a tap on Start; false stays before it.
      bool start = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = MathTesterModel(
        initialProblem: problem ?? equation,
        progress:
            progress ??
            Progress(
              tier: Tier.easy,
              selectedOperations: {OperationType.algebra},
              seenKinds: _seen,
            ),
        store: store,
        reportClient: reports,
        ticker: () => const Stream.empty(),
      );
      addTearDown(model.dispose);
      if (start) model.startPractice();
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

    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byKey(homePageKey)));

    /// The number the grown-up check shows in words.
    int shownNumber(WidgetTester tester) {
      final word = tester.widget<Text>(find.byKey(reportCheckWordKey)).data;
      return checkNumbers(l10n(tester)).firstWhere((n) => n.$2 == word).$1;
    }

    Future<void> typeNumber(WidgetTester tester, int number) async {
      await tester.enterText(find.byKey(reportCheckFieldKey), '$number');
      await tap(tester, reportSendKey);
    }

    /// From the flag to the grown-up check, with [reason] picked.
    Future<void> toCheck(
      WidgetTester tester, {
      Key flag = reportFlagKey,
      String reason = 'wrongAnswer',
    }) async {
      await tap(tester, flag);
      await tap(tester, reportContinueKey);
      await tap(tester, reportOptionKey(reason));
      await tap(tester, reportContinueKey);
    }

    /// Scrolls My answers until the flag of history entry [index] is built.
    Future<void> showHistoryFlag(WidgetTester tester, int index) =>
        tester.scrollUntilVisible(
          find.byKey(historyFlagKey(index)),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(resultsPageKey),
                matching: find.byType(Scrollable),
              )
              .first,
        );

    IconData flagIcon(WidgetTester tester, [Key key = reportFlagKey]) => tester
        .widget<Icon>(
          find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
        )
        .icon!;

    testWidgets('the flag marks the question and opens the dialog; nothing '
        'is sent', (tester) async {
      final semantics = tester.ensureSemantics();
      final model = await launch(tester);
      expect(flagIcon(tester), Icons.outlined_flag);
      expect(
        tester.getSemantics(find.byKey(reportFlagKey)).tooltip,
        en.reportFlag,
      );

      await tap(tester, reportFlagKey);
      expect(find.byKey(reportDialogKey), findsOneWidget);
      expect(find.text(en.reportAskTitle), findsOneWidget);
      // It lists exactly what is sent.
      expect(
        find.text(
          '• ${en.reportSendsQuestion('algebra missingSecondAddend '
          '[3, 4] L2')}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('• ${en.reportSendsApp('1.0.0', reportPlatform, 'en')}'),
        findsOneWidget,
      );
      expect(find.text('• ${en.reportSendsNothingElse}'), findsOneWidget);
      expect(model.suspectOf(equation)?.sent, isFalse);
      await tester.pumpAndSettle();
      expect(saved().suspects, hasLength(1));
      expect(reports.bodies, isEmpty);

      await tap(tester, reportNotNowKey);
      expect(find.byKey(reportDialogKey), findsNothing);
      expect(flagIcon(tester), Icons.flag);
      expect(
        tester.getSemantics(find.byKey(reportFlagKey)).tooltip,
        en.reportFlagMarked,
      );
      expect(model.suspectOf(equation), isNotNull);
      expect(reports.bodies, isEmpty);
      semantics.dispose();
    });

    testWidgets('cancel at each step sends nothing and keeps the mark', (
      tester,
    ) async {
      final model = await launch(tester);
      // At the pick-list, back to the first step, then Not now.
      await tap(tester, reportFlagKey);
      await tap(tester, reportContinueKey);
      expect(
        tester.widget<FilledButton>(find.byKey(reportContinueKey)).onPressed,
        isNull,
        reason: 'nothing picked yet',
      );
      await tap(tester, reportBackKey);
      await tap(tester, reportNotNowKey);
      expect(reports.bodies, isEmpty);

      // At the grown-up check.
      await toCheck(tester);
      expect(find.byKey(reportCheckWordKey), findsOneWidget);
      await tap(tester, reportCancelKey);
      expect(find.byKey(reportDialogKey), findsNothing);

      // A tap outside the dialog at the pick-list.
      await tap(tester, reportFlagKey);
      await tap(tester, reportContinueKey);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(reportDialogKey), findsNothing);

      expect(reports.bodies, isEmpty);
      expect(model.suspectOf(equation)!.sent, isFalse);
    });

    testWidgets('Remove mark clears the flag and sends nothing', (
      tester,
    ) async {
      final model = await launch(tester);
      await tap(tester, reportFlagKey);
      await tap(tester, reportRemoveMarkKey);
      expect(model.suspectOf(equation), isNull);
      expect(flagIcon(tester), Icons.outlined_flag);
      expect(reports.bodies, isEmpty);
    });

    testWidgets('a wrong number sends nothing and shows a new one', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await launch(tester);
      await toCheck(tester);
      // A screen reader hears the title, the number in words and the
      // field's label.
      expect(find.bySemanticsLabel(en.reportCheckTitle), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(reportCheckWordKey)).label,
        checkNumbers(en).firstWhere((n) => n.$1 == shownNumber(tester)).$2,
      );
      expect(
        find.bySemanticsLabel(RegExp(en.reportCheckField)),
        findsOneWidget,
      );
      final first = shownNumber(tester);
      await typeNumber(tester, first + 1);
      expect(find.byKey(reportCheckWrongKey), findsOneWidget);
      expect(shownNumber(tester), isNot(first));
      // Zero and an empty field fail the same way.
      await typeNumber(tester, 0);
      await tap(tester, reportSendKey);
      expect(find.byKey(reportCheckWrongKey), findsOneWidget);
      expect(reports.bodies, isEmpty);
      semantics.dispose();
    });

    testWidgets('the right number sends exactly one report with the contract '
        'fields, and thanks the player', (tester) async {
      final model = await launch(tester);
      await toCheck(tester, reason: 'wrongHint');
      await typeNumber(tester, shownNumber(tester));
      expect(reports.bodies, hasLength(1));
      final body = decoded(reports.bodies.single);
      expect(body.keys.toSet(), questionKeys);
      expect(body['reason'], 'wrongHint');
      expect(body['locale'], 'en');
      expect(find.text(en.reportThanks), findsOneWidget);
      await tap(tester, reportCloseKey);
      expect(model.suspectOf(equation)!.sent, isTrue);
      expect(
        tester.getSemantics(find.byKey(reportFlagKey)).tooltip,
        en.reportFlagSent,
      );

      // A sent mark offers no second report.
      await tap(tester, reportFlagKey);
      expect(find.text(en.reportAlreadySent), findsOneWidget);
      expect(find.byKey(reportContinueKey), findsNothing);
      await tap(tester, reportCloseKey);
      expect(reports.bodies, hasLength(1));
    });

    testWidgets('a failed send keeps the mark and offers another try through '
        'the check', (tester) async {
      reports.outcome = ReportOutcome.failed;
      final model = await launch(tester);
      await toCheck(tester);
      await typeNumber(tester, shownNumber(tester));
      expect(reports.bodies, hasLength(1));
      expect(find.text(en.reportFailedQuestion), findsOneWidget);
      expect(model.suspectOf(equation)!.sent, isFalse);

      await tap(tester, reportTryAgainKey);
      expect(find.byKey(reportCheckWordKey), findsOneWidget);
      expect(reports.bodies, hasLength(1), reason: 'not before the check');
      reports.outcome = ReportOutcome.sent;
      await typeNumber(tester, shownNumber(tester));
      expect(reports.bodies, hasLength(2));
      expect(find.text(en.reportThanks), findsOneWidget);
    });

    testWidgets('geometry offers the drawing reason, algebra does not', (
      tester,
    ) async {
      await launch(tester);
      await tap(tester, reportFlagKey);
      await tap(tester, reportContinueKey);
      expect(find.byKey(reportOptionKey('wrongDrawing')), findsNothing);
      await tap(tester, reportBackKey);
      await tap(tester, reportNotNowKey);

      await launch(
        tester,
        problem: rectangle,
        progress: Progress(
          tier: Tier.easy,
          selectedOperations: {OperationType.geometry},
          seenKinds: _seen,
        ),
      );
      await toCheck(tester, reason: 'wrongDrawing');
      await typeNumber(tester, shownNumber(tester));
      expect(decoded(reports.bodies.single)['kind'], 'geometry');
      expect(decoded(reports.bodies.single)['reason'], 'wrongDrawing');
    });

    testWidgets('no flag on an arithmetic question or in a sprint', (
      tester,
    ) async {
      final model = await launch(
        tester,
        problem: sum,
        progress: Progress(tier: Tier.easy, seenKinds: _seen),
      );
      expect(find.byKey(reportFlagKey), findsNothing);
      // A sprint starts before Start.
      model.endPractice();
      model.startSprint();
      await tester.pumpAndSettle();
      expect(find.byKey(reportFlagKey), findsNothing);
      model.endSprint();
    });

    testWidgets('history entries carry the flag, filled when marked', (
      tester,
    ) async {
      final history = [
        Attempt(
          equation,
          firstAnswer: 5,
          answerHundredths: 500,
          elapsedMs: 4000,
          answeredAt: DateTime(2026, 11, 20),
        ),
        Attempt(
          sum,
          firstAnswer: 15,
          elapsedMs: 3000,
          answeredAt: DateTime(2026, 11, 20),
        ),
      ];
      for (final layout in LayoutMode.values) {
        for (final width in [400.0, 1000.0]) {
          reports.bodies.clear();
          final model = await launch(
            tester,
            problem: sum,
            start: false,
            size: Size(width, 900),
            progress: Progress(
              tier: Tier.easy,
              history: history,
              layoutMode: layout,
              seenKinds: _seen,
            ),
          );
          await tap(tester, myAnswersNavKey);
          await showHistoryFlag(tester, 0);
          expect(find.byKey(historyFlagKey(0)), findsOneWidget);
          expect(find.byKey(historyRowKey(1)), findsOneWidget);
          expect(find.byKey(historyFlagKey(1)), findsNothing);
          expect(flagIcon(tester, historyFlagKey(0)), Icons.outlined_flag);
          await tap(tester, historyFlagKey(0));
          await tap(tester, reportNotNowKey);
          expect(flagIcon(tester, historyFlagKey(0)), Icons.flag);
          expect(model.suspectOf(equation), isNotNull);
          expect(reports.bodies, isEmpty);
        }
      }
    });

    testWidgets('a mark survives a restart and can be sent from history', (
      tester,
    ) async {
      store = FakeStore({
        progressKey: Progress(
          tier: Tier.easy,
          seenKinds: _seen,
          history: [
            Attempt(
              equation,
              firstAnswer: 5,
              answerHundredths: 500,
              elapsedMs: 4000,
              answeredAt: DateTime(2026, 11, 20),
            ),
          ],
        ).encode(),
      });
      await bootstrap(store);
      await tester.pumpAndSettle();
      await tap(tester, myAnswersNavKey);
      await showHistoryFlag(tester, 0);
      await tap(tester, historyFlagKey(0));
      await tap(tester, reportNotNowKey);
      await tester.pumpAndSettle();
      expect(saved().suspects, hasLength(1));

      await bootstrap(store);
      await tester.pumpAndSettle();
      await tap(tester, myAnswersNavKey);
      await showHistoryFlag(tester, 0);
      expect(flagIcon(tester, historyFlagKey(0)), Icons.flag);
    });

    testWidgets('Send a problem report in settings: a category, the check '
        'and one request', (tester) async {
      await launch(tester, start: false);
      await tap(tester, settingsButtonKey);
      await tap(tester, sendProblemReportTileKey);
      expect(find.text('• ${en.reportSendsCategory}'), findsOneWidget);
      expect(reports.bodies, isEmpty);
      await tap(tester, reportContinueKey);
      for (final name in problemCategories) {
        expect(find.byKey(reportOptionKey(name)), findsOneWidget);
      }
      await tap(tester, reportOptionKey('sound'));
      await tap(tester, reportContinueKey);
      await typeNumber(tester, shownNumber(tester) + 1);
      expect(reports.bodies, isEmpty);
      await typeNumber(tester, shownNumber(tester));
      expect(reports.bodies, hasLength(1));
      final body = decoded(reports.bodies.single);
      expect(body.keys.toSet(), problemKeys);
      expect(body['category'], 'sound');
      expect(find.text(en.reportThanks), findsOneWidget);
    });

    testWidgets('a failed problem report says to try later', (tester) async {
      reports.outcome = ReportOutcome.failed;
      await launch(tester, start: false);
      await tap(tester, settingsButtonKey);
      await tap(tester, sendProblemReportTileKey);
      await tap(tester, reportContinueKey);
      await tap(tester, reportOptionKey('other'));
      await tap(tester, reportContinueKey);
      await typeNumber(tester, shownNumber(tester));
      expect(find.text(en.reportFailedProblem), findsOneWidget);
      expect(find.byKey(reportTryAgainKey), findsOneWidget);
    });

    group('every language fits small phones', () {
      setUpAll(() async {
        final manifest = jsonDecode(
          await rootBundle.loadString('FontManifest.json'),
        ) as List;
        for (final family in manifest.cast<Map<String, dynamic>>()) {
          final loader = FontLoader(family['family'] as String);
          for (final font in (family['fonts'] as List).cast<Map>()) {
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
                'text x$scale: flag, every step and both results', (
              tester,
            ) async {
              await launch(
                tester,
                problem: rectangle,
                size: size,
                scale: scale,
                progress: Progress(
                  tier: Tier.easy,
                  language: code,
                  selectedOperations: {OperationType.geometry},
                  seenKinds: _seen,
                ),
              );
              expect(find.byKey(reportFlagKey), findsOneWidget);
              await toCheck(tester, reason: 'wrongDrawing');
              await typeNumber(tester, shownNumber(tester) + 1);
              expect(find.byKey(reportCheckWrongKey), findsOneWidget);
              reports.outcome = ReportOutcome.failed;
              await typeNumber(tester, shownNumber(tester));
              expect(find.byKey(reportResultKey), findsOneWidget);
              await tap(tester, reportTryAgainKey);
              reports.outcome = ReportOutcome.sent;
              await typeNumber(tester, shownNumber(tester));
              expect(find.byKey(reportResultKey), findsOneWidget);
              await tap(tester, reportCloseKey);
              // The sent mark's dialog.
              await tap(tester, reportFlagKey);
              await tap(tester, reportCloseKey);
              // The problem report's first steps, from settings after End.
              await tap(tester, endPracticeButtonKey);
              await tap(tester, settingsButtonKey);
              await tap(tester, sendProblemReportTileKey);
              await tap(tester, reportContinueKey);
              await tap(tester, reportOptionKey('translation'));
              await tap(tester, reportBackKey);
              await tap(tester, reportCancelKey);
              expect(reports.bodies, hasLength(2));
              expect(decoded(reports.bodies.last)['locale'], code);
            });
          }
        }
      }
    });
  });
}

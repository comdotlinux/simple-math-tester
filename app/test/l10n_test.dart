import 'dart:convert';
import 'dart:io';

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
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';

import 'en.dart';
import 'fake_store.dart';

/// The argument names a message uses: `{name}` and `{name, plural, ...}`,
/// not the words that open a plural branch.
Set<String> placeholders(String message) => {
  for (final m in RegExp(r'\{(\w+)\s*[,}]').allMatches(message)) m[1]!,
};

Map<String, Object?> readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  group('translations', () {
    final template = readArb('lib/l10n/app_en.arb');
    final keys = template.keys.where((key) => !key.startsWith('@')).toSet();
    final arbs = Directory('lib/l10n')
        .listSync()
        .map((file) => file.path)
        .where((path) => path.endsWith('.arb') && !path.endsWith('_en.arb'))
        .toList();

    test('every supported language has an English name', () {
      expect(
        englishLanguageNames.keys,
        unorderedEquals(
          AppLocalizations.supportedLocales.map((l) => l.toString()),
        ),
      );
    });

    test('every supported language has an ARB file', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.toString()).toSet(),
        {'en', for (final path in arbs) readArb(path)['@@locale']},
      );
    });

    for (final path in arbs) {
      test('$path has every template key and the same placeholders', () {
        final arb = readArb(path);
        expect(
          arb.keys.where((key) => !key.startsWith('@')).toSet(),
          keys,
          reason: 'missing or extra keys',
        );
        for (final key in keys) {
          expect(
            placeholders(arb[key]! as String),
            placeholders(template[key]! as String),
            reason: key,
          );
          // Digits stay Western: no Devanagari, Telugu, Tamil, Malayalam or
          // Gurmukhi.
          expect(
            arb[key],
            isNot(matches(RegExp('[०-९౦-౯௦-௯൦-൯੦-੯]'))),
            reason: key,
          );
        }
      });
    }
  });

  group('language setting', () {
    testWidgets('follows the system language, English when unsupported', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await bootstrap(FakeStore());
      await tester.pumpAndSettle();
      final de = lookupAppLocalizations(const Locale('de'));
      expect(find.text(de.myAnswers), findsWidgets);

      tester.platformDispatcher.localesTestValue = const [Locale('es')];
      await tester.pumpAndSettle();
      expect(find.text(en.myAnswers), findsWidgets);
    });

    testWidgets('a language picked in Settings changes the text and is '
        'saved', (tester) async {
      final store = FakeStore({
        progressKey: Progress(tier: Tier.easy).encode(),
      });
      await bootstrap(store);
      await tester.pumpAndSettle();
      expect(find.text(en.practiceTitle), findsOneWidget);

      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      expect(find.text(en.languageSystem), findsWidgets);
      await tester.ensureVisible(find.byKey(languageTileKey));
      await tester.tap(find.byKey(languageTileKey));
      await tester.pumpAndSettle();
      // Each language is named in itself, with its English name beside it.
      expect(find.text('Deutsch'), findsOneWidget);
      expect(find.text('German'), findsOneWidget);
      expect(find.text('தமிழ்'), findsOneWidget);
      expect(find.text('Tamil'), findsOneWidget);
      await tester.ensureVisible(find.byKey(languageOptionKey('ta')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(languageOptionKey('ta')));
      await tester.pumpAndSettle();

      final ta = lookupAppLocalizations(const Locale('ta'));
      expect(find.text(ta.language), findsOneWidget);
      expect(find.text('தமிழ்'), findsOneWidget, reason: 'the row says it');
      expect(Progress.decode(store.values[progressKey]!).language, 'ta');

      // A restart keeps it.
      await bootstrap(store);
      await tester.pumpAndSettle();
      expect(find.text(ta.practiceTitle), findsOneWidget);
      expect(find.text(en.practiceTitle), findsNothing);

      // System again: the saved document drops the field.
      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(languageTileKey));
      await tester.tap(find.byKey(languageTileKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(languageOptionKey(null)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(languageOptionKey(null)));
      await tester.pumpAndSettle();
      expect(find.text(en.language), findsOneWidget);
      expect(Progress.decode(store.values[progressKey]!).language, isNull);
      expect(store.values[progressKey], isNot(contains('"language"')));
    });

    test('a missing, unknown or unsupported code follows the system', () {
      String? decoded(Object? language) => Progress.decode(
        jsonEncode({'schemaVersion': 2, 'language': ?language}),
      ).language;
      expect(decoded(null), isNull);
      expect(decoded('xx'), isNull);
      expect(decoded('pl'), 'pl');
      expect(decoded('pt_PT'), 'pt_PT');
      expect(decoded('pt_BR'), isNull, reason: 'Brazilian Portuguese is pt');
      expect(Progress(language: 'mr').withLanguage(null).language, isNull);
    });

    testWidgets('a long press on a language shows its full name and does not '
        'pick it', (tester) async {
      final semantics = tester.ensureSemantics();
      final store = FakeStore({
        progressKey: Progress(tier: Tier.easy).encode(),
      });
      await bootstrap(store);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(settingsButtonKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(languageTileKey));
      await tester.tap(find.byKey(languageTileKey));
      await tester.pumpAndSettle();
      final row = find.byKey(languageOptionKey('pt_PT'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      // A screen reader hears each name once, not again from the tooltip.
      expect(
        tester.getSemantics(row).label,
        'Português (Portugal)\nPortuguese (Portugal)',
      );

      await tester.longPress(row);
      await tester.pumpAndSettle();
      expect(
        find.text('Português (Portugal) · Portuguese (Portugal)'),
        findsOneWidget,
      );
      expect(row, findsOneWidget, reason: 'the list stays open');
      expect(Progress.decode(store.values[progressKey]!).language, isNull);
      semantics.dispose();
    });

    testWidgets('Portuguese: a phone in pt_PT gets European, pt_BR and pt '
        'Brazilian; a saved pt_PT wins over the system', (tester) async {
      String shown() =>
          AppLocalizations.of(tester.element(find.byKey(homePageKey)))
              .languageName;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await bootstrap(FakeStore());
      for (final (system, name) in [
        (const Locale('pt', 'PT'), 'Português (Portugal)'),
        (const Locale('pt', 'BR'), 'Português (Brasil)'),
        (const Locale('pt'), 'Português (Brasil)'),
      ]) {
        tester.platformDispatcher.localesTestValue = [system];
        await tester.pumpAndSettle();
        expect(shown(), name, reason: '$system');
      }

      await bootstrap(
        FakeStore({progressKey: Progress(language: 'pt_PT').encode()}),
      );
      await tester.pumpAndSettle();
      expect(shown(), 'Português (Portugal)');
    });
  });

  // Measured with the bundled fonts, as phone_layout_test does: the test
  // font draws every glyph a full em wide.
  group('every language fits a small phone', () {
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

    const size = Size(360, 640);
    final wrong = Attempt(
      const ArithmeticProblem(48, 27, OperationType.plus, 75),
      firstAnswer: 74,
      elapsedMs: 65000,
      answeredAt: DateTime(2026, 11, 14, 9),
    );

    Future<void> launch(WidgetTester tester, Progress progress) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = MathTesterModel(
        initialProblem: const ArithmeticProblem(
          4800,
          2700,
          OperationType.minus,
          2100,
        ),
        progress: progress,
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MathTesterApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toString();
      // Overflow is reported as an error, which fails the test.
      testWidgets('$code: practice, a wrong answer with every hint, settings '
          'and the language list', (tester) async {
        await launch(tester, Progress(tier: Tier.easy, language: code));
        await tester.enterText(find.byType(TextField), '1');
        await tap(tester, checkAnswerButtonKey);
        while (tester
            .widget<ButtonStyleButton>(find.byKey(revealStepButtonKey))
            .enabled) {
          await tap(tester, revealStepButtonKey);
        }
        expect(find.byKey(solutionStepsKey), findsOneWidget);

        await tap(tester, settingsButtonKey);
        await tap(tester, languageTileKey);
        await tester.ensureVisible(find.byKey(languageOptionKey(code)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(languageOptionKey(code)));
        await tester.pumpAndSettle();
      });

      testWidgets('$code: the tier picker and My answers', (tester) async {
        await launch(tester, Progress(language: code));
        expect(find.byKey(tierPickerKey), findsOneWidget);
        await tester.ensureVisible(find.byKey(tierOptionKey(Tier.harder)));
        await tester.pumpAndSettle();

        await launch(tester, Progress(tier: Tier.easy, language: code));
        await tap(tester, myAnswersNavKey);
        expect(find.byKey(noResultsOnResultsPageKey), findsOneWidget);

        await launch(
          tester,
          Progress(tier: Tier.easy, language: code, history: [wrong]),
        );
        await tap(tester, myAnswersNavKey);
        expect(find.byKey(historyCountKey), findsOneWidget);
      });
    }
  });
}

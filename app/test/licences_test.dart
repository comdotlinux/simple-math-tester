import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/legal.dart';
import 'package:simple_math_tester/main.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';

import 'en.dart';

/// Settings > Licences: the packages from Flutter's licence registry, then
/// the other attributions. Measured with the bundled Roboto, because the
/// test font draws every glyph a full em wide.
void main() {
  late List<LicenseEntry> notices;
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
    // The test binding registers no licences; give the registry the NOTICES
    // that `flutter test` generates, parsed the way the app's binding does.
    final text = utf8.decode(
      gzip.decode((await rootBundle.load('NOTICES.Z')).buffer.asUint8List()),
    );
    notices = [
      for (final license in text.split('\n${'-' * 80}\n'))
        if (license.indexOf('\n\n') case final split when split >= 0)
          LicenseEntryWithLineBreaks(
            license.substring(0, split).split('\n'),
            license.substring(split + 2),
          ),
    ];
    LicenseRegistry.addLicense(() => Stream.fromIterable(notices));
    // Cached for the page, which would otherwise read them on the fake clock.
    for (final (:licenseAsset, name: _, credit: _) in attributions) {
      if (licenseAsset != null) await rootBundle.loadString(licenseAsset);
    }
  });
  tearDownAll(LicenseRegistry.reset);

  final page = find.byKey(licencesPageKey);
  final list = find.descendant(of: page, matching: find.byType(Scrollable));

  Future<void> openLicences(
    WidgetTester tester, {
    Size size = const Size(412, 720),
    double scale = 1,
    Brightness brightness = Brightness.light,
    LayoutMode layout = LayoutMode.comfortable,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = MathTesterModel(
      initialProblem: const Problem(48, 27, OperationType.plus, 75),
      progress: Progress(tier: Tier.easy, layoutMode: layout),
      // Any link opened would be a network request.
      openLink: (uri) => fail('opened $uri'),
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
            platformBrightness: brightness,
          ),
          child: const MathTesterApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(settingsButtonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(licencesTileKey));
    await tester.pumpAndSettle();
    expect(find.text(en.licences), findsOneWidget);
    expect(find.text(en.licencesSubtitle), findsOneWidget);
    await tester.tap(find.byKey(licencesTileKey));
    await tester.pumpAndSettle();
  }

  // The licence files were loaded in setUpAll, outside the fake clock, so the
  // page's cached futures complete on the real event loop: give it a turn.
  Future<void> openAttribution(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: list);
    await tester.pumpAndSettle();
  }

  testWidgets('the tile opens the page; it lists the packages and opens '
      'their licence texts', (tester) async {
    await openLicences(tester);
    expect(page, findsOneWidget);
    expect(find.text(en.licencesTitle), findsOneWidget);
    expect(find.text(en.licencesLibraries), findsOneWidget);

    // Every package the app names under `dependencies:` (hosted, so not the
    // Flutter SDK's own), as pubspec.lock pins them.
    final direct = [
      for (final match in RegExp(
        r'^  (\w+):\n    dependency: "direct main"\n'
        r'    description:\n      name: \w+\n'
        r'      sha256: [^\n]+\n      url: [^\n]+\n    source: hosted',
        multiLine: true,
      ).allMatches(File('pubspec.lock').readAsStringSync()))
        match[1]!,
    ];
    expect(direct, containsAll(['material_ui', 'provider', 'url_launcher']));
    for (final name in direct) {
      await scrollTo(tester, find.text(name));
      expect(find.text(name), findsOneWidget);
    }

    await tester.scrollUntilVisible(
      find.text('provider'),
      -200,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('provider'));
    await tester.pumpAndSettle();
    final text = notices
        .firstWhere((entry) => entry.packages.contains('provider'))
        .paragraphs
        .first
        .text;
    expect(find.text(text), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(page, findsNothing);
    expect(find.byKey(settingsSheetKey), findsOneWidget);
  });

  testWidgets('every font licence file is under Other attributions, and '
      'opens to its text', (tester) async {
    final files = Directory('assets/fonts')
        .listSync()
        .map((file) => file.path)
        .where((path) => path.endsWith('_LICENSE.txt'))
        .toList();
    expect(files, isNotEmpty);
    expect(
      attributions.map((a) => a.licenseAsset),
      containsAll(files),
      reason: 'each font licence file has an entry',
    );

    await openLicences(tester);
    final heading = find.text(en.licencesOtherAttributions);
    await scrollTo(tester, heading);
    for (final (:name, :credit, :licenseAsset) in attributions) {
      await scrollTo(tester, find.text(name));
      expect(find.text(credit), findsWidgets);
      if (licenseAsset == null) continue;
      await openAttribution(tester, name);
      // The whole file, in paragraphs as for the packages.
      for (final paragraph in LicenseEntryWithLineBreaks(
        const [],
        File(licenseAsset).readAsStringSync(),
      ).paragraphs) {
        expect(find.text(paragraph.text), findsWidgets, reason: name);
      }
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final layout in LayoutMode.values) {
      testWidgets('no overflow at text 2.0 on a small phone, ${layout.name} '
          '${brightness.name}', (tester) async {
        await openLicences(
          tester,
          size: const Size(320, 640),
          scale: 2,
          brightness: brightness,
          layout: layout,
        );
        await scrollTo(tester, find.text('provider'));
        await tester.tap(find.text('provider'));
        await tester.pumpAndSettle();
        final roboto = attributions.first.name;
        await scrollTo(tester, find.text(roboto));
        await openAttribution(tester, roboto);
        expect(
          find.textContaining('Version 2.0, January 2004'),
          findsOneWidget,
        );
        await tester.drag(list, const Offset(0, -2000));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

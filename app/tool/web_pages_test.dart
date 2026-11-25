import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/legal.dart';

/// Writes `web/LANGUAGE/privacy.html` for every app language except English,
/// from the ARB texts through `privacyPolicy` (the same text the app shows).
/// The pages are not committed (they would go stale on every translation
/// change); CI runs this before `flutter build web`, so they land in
/// build/web and in the precache manifest. Run by hand from `app/`:
/// `flutter test tool/web_pages_test.dart`.
void main() {
  test('write the privacy page of every language', () {
    const origin = 'https://math.munich-tech.de';
    final english = File('web/privacy.html').readAsStringSync();
    // The styles are the English page's, so the look stays one.
    final style = RegExp(r'<style>[\s\S]*?</style>').firstMatch(english)![0]!;
    // "pt_PT" is written as the web tag "pt-PT".
    String tag(Locale l) => l.toLanguageTag();
    final locales = [
      for (final l in AppLocalizations.supportedLocales)
        if (tag(l) != 'en') l,
    ];
    String escape(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final alternates = [
      '<link rel="alternate" hreflang="en" href="$origin/privacy.html">',
      for (final l in locales)
        '<link rel="alternate" hreflang="${tag(l)}" '
            'href="$origin/${tag(l)}/privacy.html">',
    ].join('\n  ');

    for (final locale in locales) {
      final l = lookupAppLocalizations(locale);
      final lang = tag(locale);
      final dir = Bidi.isRtlLanguage(locale.languageCode) ? 'rtl' : 'ltr';
      final body = StringBuffer();
      for (final (i, (heading, paragraphs)) in privacyPolicy(l).indexed) {
        body.writeln(
          i == 0
              ? '  <h1>${escape(heading)}</h1>'
              : '\n  <h2>${escape(heading)}</h2>',
        );
        for (final p in paragraphs) {
          body.writeln('  <p>${escape(p)}</p>');
        }
      }
      // The frame strings of about and Impressum come with #268; until then the
      // nav labels without an ARB string stay English.
      final page =
          '''<!DOCTYPE html>
<html lang="$lang" dir="$dir">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escape(l.privacyTitle)} - Simple Math Tester</title>
  <link rel="icon" type="image/png" href="/favicon.png">
  $alternates
  $style
</head>
<body>
  <main>
  <div class="top">
    <a class="brand" href="/"><img src="/icons/Icon-192.png" alt="">Simple Math Tester</a>
    <nav aria-label="Pages"><a href="/">Open the app</a> <a href="/about.html">About</a> <a href="/$lang/privacy.html">${escape(l.privacyTitle)}</a> <a href="/impressum.html">${escape(l.impressum)}</a></nav>
  </div>
  <div class="card">
$body  </div>
  </main>
</body>
</html>
''';
      File('web/$lang/privacy.html')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(page);
    }
    expect(locales, isNotEmpty);
  });
}

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/legal.dart';

const _origin = 'https://math.munich-tech.de';

/// Languages of Cloudflare Turnstile's `data-language` (the two-letter codes of
/// developers.cloudflare.com/turnstile/reference/supported-languages). Any
/// other page language (Marathi, Telugu, ..., or `pt-PT`) uses `auto`.
const _turnstileLanguages = {
  'ar', 'bg', 'cs', 'da', 'de', 'el', 'es', 'fa', 'fi', 'fr', 'he', 'hi', //
  'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'ms', 'nb', 'nl', 'pl', 'pt',
  'ro', 'ru', 'sk', 'sl', 'sr', 'sv', 'sw', 'th', 'tl', 'tr', 'uk', 'vi',
  'zh', //
};

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _link(String text, String href) =>
    '<a href="$href">${_escape(text)}</a>';

/// A sentence with `{name}` markers: each becomes the given HTML (a link).
String _sentence(String s, Map<String, String> links) => links.entries.fold(
  _escape(s),
  (t, e) => t.replaceAll('{${e.key}}', e.value),
);

/// The nav links of one language, all to that language's pages.
String _links(AppLocalizations l, String lang, {bool impressum = true}) => [
  _link(l.webNavApp, '/'),
  _link(l.webNavAbout, '/$lang/about.html'),
  _link(l.privacyTitle, '/$lang/privacy.html'),
  if (impressum) _link(l.impressum, '/$lang/impressum.html'),
].join(' ');

String _top(AppLocalizations l, String lang) =>
    '''  <div class="top">
    <a class="brand" href="/"><img src="/icons/Icon-192.png" alt="">Simple Math Tester</a>
    <nav aria-label="Pages">${_links(l, lang)}</nav>
  </div>
''';

String _page({
  required String lang,
  required String dir,
  required String title,
  String? description,
  required String alternates,
  required String style,
  required String main,
  String scripts = '',
}) =>
    '''<!DOCTYPE html>
<html lang="$lang" dir="$dir">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
${description == null ? '' : '  <meta name="description" content="${_escape(description).replaceAll('"', '&quot;')}">\n'}  <link rel="icon" type="image/png" href="/favicon.png">
  $alternates
  $style
</head>
<body>
  <main>
$main  </main>
$scripts</body>
</html>
''';

/// Writes `web/LANGUAGE/{privacy,about,impressum}.html` for every app language
/// except English: the privacy text through `privacyPolicy` (the same text the
/// app shows), the page frames from the `web*` ARB texts. Styles and the
/// Impressum scripts are the English pages', so the look and the check stay
/// one. The pages are not committed (they would go stale on every translation
/// change); CI runs this before `flutter build web`, so they land in build/web
/// and in the precache manifest. Run by hand from `app/`:
/// `flutter test tool/web_pages_test.dart`.
void main() {
  String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ');
  RegExp styleTag() => RegExp(r'<style>[\s\S]*?</style>');

  test('the English about and Impressum pages say what the ARB says', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final about = squash(File('web/about.html').readAsStringSync());
    final impressum = squash(File('web/impressum.html').readAsStringSync());
    for (final text in [
      en.webNavAbout,
      en.webAboutHeading,
      en.webAboutBody,
      en.webGetTheApp,
      en.webUseInBrowser,
      en.webGoodToKnow,
      en.webBadgeAppStoreAlt,
      en.webBadgeGooglePlayAlt,
    ]) {
      expect(about, contains(_escape(text)));
    }
    expect(about, contains(en.webAboutDescription));
    for (final text in [
      en.webImpressumLegalNotice,
      en.webImpressumProviderHeading,
      en.webImpressumProviderIntro,
      en.webImpressumNoticeTitle,
      en.webImpressumNoticeBody,
      en.webImpressumStatus,
      en.webImpressumDetails,
      en.webImpressumError,
      en.webImpressumRetry,
      en.webImpressumAboutHeading,
      en.webImpressumAboutBody,
      en.webImpressumAboutItem1,
      en.webImpressumAboutItem2,
      en.webImpressumWhyHeading,
    ]) {
      expect(impressum, contains(_escape(text)));
    }
  });

  test('write the privacy, about and Impressum page of every language', () {
    final privacyStyle = styleTag().firstMatch(
      File('web/privacy.html').readAsStringSync(),
    )![0]!;
    final englishAbout = File('web/about.html').readAsStringSync();
    final aboutStyle = styleTag().firstMatch(englishAbout)![0]!;
    // The trademark line stays English.
    final trademarks = RegExp(r'<p class="legal">([\s\S]*?)</p>')
        .firstMatch(englishAbout)![1]!;
    final englishImpressum = File('web/impressum.html').readAsStringSync();
    final impressumStyle = styleTag().firstMatch(englishImpressum)![0]!;
    final impressumScripts =
        '  ${RegExp(r'<script>[\s\S]*?</script>').firstMatch(englishImpressum)![0]}\n'
        '  ${RegExp(r'<script src=[\s\S]*?</script>').firstMatch(englishImpressum)![0]}\n';

    // "pt_PT" is written as the web tag "pt-PT".
    String tag(Locale l) => l.toLanguageTag();
    final locales = [
      for (final l in AppLocalizations.supportedLocales)
        if (tag(l) != 'en') l,
    ];
    String alternates(String page) => [
      '<link rel="alternate" hreflang="en" href="$_origin/$page.html">',
      for (final l in locales)
        '<link rel="alternate" hreflang="${tag(l)}" '
            'href="$_origin/${tag(l)}/$page.html">',
    ].join('\n  ');

    for (final locale in locales) {
      final l = lookupAppLocalizations(locale);
      final lang = tag(locale);
      final dir = Bidi.isRtlLanguage(locale.languageCode) ? 'rtl' : 'ltr';
      void write(String page, String html) => File('web/$lang/$page.html')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(html);

      final body = StringBuffer();
      for (final (i, (heading, paragraphs)) in privacyPolicy(l).indexed) {
        body.writeln(
          i == 0
              ? '  <h1>${_escape(heading)}</h1>'
              : '\n  <h2>${_escape(heading)}</h2>',
        );
        for (final p in paragraphs) {
          body.writeln('  <p>${_escape(p)}</p>');
        }
      }
      write(
        'privacy',
        _page(
          lang: lang,
          dir: dir,
          title: '${_escape(l.privacyTitle)} - Simple Math Tester',
          alternates: alternates('privacy'),
          style: privacyStyle,
          main: '${_top(l, lang)}  <div class="card">\n$body  </div>\n',
        ),
      );

      final privacyLink = _link(l.webPrivacyLink, '/$lang/privacy.html');
      write(
        'about',
        _page(
          lang: lang,
          dir: dir,
          title: '${_escape(l.webNavAbout)} - Simple Math Tester',
          description: l.webAboutDescription,
          alternates: alternates('about'),
          style: aboutStyle,
          // The badges are the English official artwork until localised ones exist.
          main:
              '''${_top(l, lang)}  <div class="card">
  <h1>${_escape(l.webAboutHeading)}</h1>
  <p>${_escape(l.webAboutBody)}</p>

  <h2>${_escape(l.webGetTheApp)}</h2>
  <ul class="stores">
    <li><a class="badge" href="https://apps.apple.com/app/id6838034519"><img src="/badges/app-store-en.svg" alt="${_escape(l.webBadgeAppStoreAlt)}" height="48"></a></li>
    <li><a class="badge" href="https://play.google.com/store/apps/details?id=com.linux.simplemathtester"><img class="gp" src="/badges/google-play-en.png" alt="${_escape(l.webBadgeGooglePlayAlt)}" height="71"></a></li>
    <li><a class="btn" href="/">${_escape(l.webUseInBrowser)}</a></li>
  </ul>

  <h2>${_escape(l.webGoodToKnow)}</h2>
  <p>${_sentence(l.webReadPrivacyImpressum('{privacy}', '{impressum}'), {'privacy': privacyLink, 'impressum': _link(l.impressum, '/$lang/impressum.html')})}</p>
  <p class="legal">$trademarks</p>
  </div>
''',
        ),
      );

      // Only the frame is translated; the provider text comes from
      // /api/impressum after the check and is never in these files.
      write(
        'impressum',
        _page(
          lang: lang,
          dir: dir,
          title: '${_escape(l.impressum)} - Simple Math Tester',
          alternates: alternates('impressum'),
          style: impressumStyle,
          main:
              '''    <header>
      <img src="/icons/Icon-192.png" alt="">
      <div>
        <h1>${_escape(l.impressum)}</h1>
        <p>${_escape(l.webImpressumLegalNotice)}</p>
      </div>
    </header>

    <section class="card" aria-labelledby="provider-heading">
      <h2 id="provider-heading">${_escape(l.webImpressumProviderHeading)}</h2>
      <p class="muted">${_escape(l.webImpressumProviderIntro)}</p>
      <div class="notice" role="note">
        <span><strong>${_escape(l.webImpressumNoticeTitle)}</strong>
          ${_escape(l.webImpressumNoticeBody)}</span>
      </div>
      <p id="status">${_escape(l.webImpressumStatus)}</p>
      <div class="cf-turnstile"
        data-sitekey="0x4AAAAAAGAwdjaKCxdqM7v7"
        data-language="${_turnstileLanguages.contains(lang) ? lang : 'auto'}"
        data-callback="onPassed"
        data-expired-callback="retry"
        data-error-callback="onTurnstileError"></div>
      <div id="details" hidden>
        <div class="details-head">
          <span class="label">${_escape(l.webImpressumDetails)}</span>
        </div>
        <pre class="details" id="text"></pre>
      </div>
      <p id="error" hidden>
        ${_escape(l.webImpressumError)}
        <button type="button" onclick="retry()">${_escape(l.webImpressumRetry)}</button>
      </p>
    </section>

    <section class="card" aria-labelledby="about-heading">
      <h2 id="about-heading">${_escape(l.webImpressumAboutHeading)}</h2>
      <p>${_escape(l.webImpressumAboutBody)}</p>
      <ul>
        <li>${_escape(l.webImpressumAboutItem1)}</li>
        <li>${_escape(l.webImpressumAboutItem2)}</li>
      </ul>
    </section>

    <section class="card" aria-labelledby="why-heading">
      <h2 id="why-heading">${_escape(l.webImpressumWhyHeading)}</h2>
      <p>${_sentence(l.webImpressumWhyBody('{privacy}'), {'privacy': privacyLink})}</p>
    </section>

    <nav aria-label="More">${_links(l, lang, impressum: false)}</nav>
''',
          scripts: impressumScripts,
        ),
      );
    }
    expect(locales, isNotEmpty);
  });
}

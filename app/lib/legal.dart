import 'package:url_launcher/url_launcher.dart';

/// The provider identification on the production site. Its text sits behind
/// a bot check there, never in this repository, so the app only links to it.
final impressumUrl = Uri.parse(
  'https://simple-math-tester.pages.dev/impressum',
);

/// Hands [uri] to the system browser, outside the app.
Future<bool> openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The privacy policy shown in the app, so it works offline. Each entry is a
/// heading and its paragraphs, in the order of `web/privacy.html`; a test
/// keeps the two identical (the page's links are plain text here).
const privacyPolicy = <(String, List<String>)>[
  (
    'Privacy policy',
    [
      'Simple Math Tester is a free arithmetic practice app for children, '
          'without ads. This policy covers the Android and iOS apps and the '
          'web version. Last updated: 14 November 2026.',
    ],
  ),
  (
    'What the app collects',
    [
      'Nothing. The app\'s own code collects no personal data and sends '
          'nothing anywhere. There are no accounts, no analytics, no '
          'advertising and no tracking.',
    ],
  ),
  (
    'What the app stores on your device',
    [
      'To keep your progress between sessions, the app saves your answers, '
          'your level in each kind of exercise and your settings (such as '
          'sound and vibration) on your own device: in the app\'s private '
          'storage on Android and iOS, and in your browser\'s local storage '
          'on the web. This data never leaves the device. Uninstalling the '
          'app, or clearing the site\'s data in the browser, deletes it.',
      'The app works offline. The Android app does not request internet '
          'access.',
    ],
  ),
  (
    'The web version',
    [
      'The web version is served by Cloudflare Pages. Like any web host, '
          'Cloudflare receives your IP address and the usual request details '
          '(such as browser type and the page requested) when your browser '
          'loads the site, in order to deliver it and protect it from abuse. '
          'See the Cloudflare privacy policy.',
      'All files the app needs, fonts included, come from the app\'s own '
          'site; the app loads nothing from other websites. After the first '
          'visit your browser keeps a copy of the app so it also starts '
          'offline. This copy contains only the app\'s files, not personal '
          'data.',
    ],
  ),
  (
    'The Impressum page',
    [
      'The Impressum (the provider identification) is a separate page on '
          'the same site. The app opens it in your browser only when you '
          'choose Impressum in the settings. That page, and only that page, '
          'loads Cloudflare Turnstile, which receives the visitor\'s IP '
          'address and browser signals to tell people from bots. See the '
          'Cloudflare privacy policy.',
    ],
  ),
  (
    'Children',
    [
      'The app is made for children and collects no data from anyone, '
          'children included.',
    ],
  ),
  (
    'Changes and contact',
    [
      'If this policy changes, the new version is published in the app and '
          'on the web version\'s privacy page with a new date. For questions, '
          'write to the developer e-mail address shown on the app\'s Google '
          'Play listing.',
    ],
  ),
];

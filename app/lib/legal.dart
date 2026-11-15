import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n/app_localizations.dart';

/// The provider identification on the production site. Its text sits behind
/// a bot check there, never in this repository, so the app only links to it.
final impressumUrl = Uri.parse('https://math.munich-tech.de/impressum');

/// The app version: Flutter defines this from `--build-name`, or from the
/// pubspec version when none is given.
const appVersion = String.fromEnvironment(
  'FLUTTER_BUILD_NAME',
  defaultValue: 'unknown',
);

/// A new GitHub issue, prefilled with the version and platform only: never
/// progress, answers or anything personal.
Uri get problemReportUrl =>
    Uri.https('github.com', '/comdotlinux/simple-math-tester/issues/new', {
      'title': 'Problem: ',
      'body':
          'What happened?\n\n\nWhat did you expect?\n\n\n'
          'App version: $appVersion\n'
          'Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}\n',
    });

/// The GitHub release of this version, with its notes. A build without a
/// tagged version name (the web build from main) gets the list of releases.
Uri get releaseNotesUrl => Uri.https(
  'github.com',
  RegExp(r'^\d+\.\d+\.\d+$').hasMatch(appVersion) && appVersion != '1.0.0'
      ? '/comdotlinux/simple-math-tester/releases/tag/v$appVersion'
      : '/comdotlinux/simple-math-tester/releases',
);

/// Whether the app offers a monthly reminder to check for updates: Android
/// only, where it opens Google Play. The web app updates itself.
// SCREENSHOT ONLY, never merge: shows the reminder on web.
bool get updateRemindersSupported => true;

/// This app's store page, tried in order: the Play Store app, then the Play
/// web page. An App Store link for iOS would go here too.
final storeUrls = [
  Uri(
    scheme: 'market',
    host: 'details',
    queryParameters: {'id': 'com.linux.simplemathtester'},
  ),
  Uri.https('play.google.com', '/store/apps/details', {
    'id': 'com.linux.simplemathtester',
  }),
];

/// Hands [uri] to the system browser, outside the app.
Future<bool> openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The privacy policy shown in the app, so it works offline. Each entry is a
/// heading and its paragraphs, in the order of `web/privacy.html`; a test
/// keeps the English text and the page identical (the page's links are plain
/// text here).
List<(String, List<String>)> privacyPolicy(AppLocalizations l) => [
  (l.privacyTitle, [l.privacyIntro]),
  (l.privacyCollectsHeading, [l.privacyCollects]),
  (l.privacyStoresHeading, [l.privacyStores, l.privacyOffline]),
  (l.privacyWebHeading, [l.privacyWebHost, l.privacyWebFiles]),
  (l.privacyImpressumHeading, [l.privacyImpressum]),
  (l.privacyReportHeading, [l.privacyReport]),
  (l.privacyChildrenHeading, [l.privacyChildren]),
  (l.privacyChangesHeading, [l.privacyChanges]),
];

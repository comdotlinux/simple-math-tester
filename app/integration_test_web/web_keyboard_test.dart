// Criterion 39 on web. This file imports web-only libraries, so it lives
// outside integration_test/ (which the Linux, Android and iOS jobs run as a
// whole folder) and only the Chrome job runs it, through `flutter drive`.
import 'dart:ui_web' as ui_web;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/main.dart' as app;
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/progress_store.dart';
import 'package:simple_math_tester/rules.dart';
import 'package:simple_math_tester/sound_player.dart';
import 'package:web/web.dart' as web;

/// The `inputmode` of Flutter's focused text-editing element, once [wanted]
/// accepts it. Text input commands reach the engine asynchronously, so this
/// waits up to five seconds.
Future<String?> inputmodeOnceIt(
  WidgetTester tester,
  bool Function(String? mode) wanted,
) async {
  String? mode;
  for (var i = 0; i < 50; i++) {
    await tester.pump();
    final element = web.document.activeElement;
    final editing =
        element != null && element.classList.contains('flt-text-editing');
    mode = editing ? element.getAttribute('inputmode') : null;
    if (editing && wanted(mode)) return mode;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return mode;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Desktop browsers have no soft keyboard, and the engine writes inputmode
  // only on mobile, so the test runs the engine's Android text editing path
  // (the one a phone's Chrome takes). Semantics stays off: with it on, the
  // engine edits through the semantics tree, as with a screen reader.
  testWidgets(
    'criterion 39: inputmode is "none" while the number pad shows',
    semanticsEnabled: false,
    (tester) async {
      ui_web.browser.debugOperatingSystemOverride =
          ui_web.OperatingSystem.android;
      addTearDown(() => ui_web.browser.debugOperatingSystemOverride = null);
      await SharedPreferencesStore().write(
        progressKey,
        Progress(tier: Tier.easy).encode(),
      );
      await app.bootstrap(SharedPreferencesStore(), const SilentSoundPlayer());
      await tester.pumpAndSettle();

      expect(find.byKey(numberPadKey), findsOneWidget);
      expect(await inputmodeOnceIt(tester, (mode) => mode == 'none'), 'none');

      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
      expect(find.byKey(numberPadKey), findsNothing);
      expect(
        await inputmodeOnceIt(tester, (mode) => mode != 'none'),
        'numeric',
      );

      await tester.tap(find.byKey(keyboardSwitchKey));
      await tester.pumpAndSettle();
      expect(find.byKey(numberPadKey), findsOneWidget);
      expect(await inputmodeOnceIt(tester, (mode) => mode == 'none'), 'none');
    },
  );
}

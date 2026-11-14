import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/keys.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';
import 'package:simple_math_tester/sound_player.dart';

import '../support/helpers.dart';

/// Records each sound instead of playing it.
class CountingSoundPlayer implements SoundPlayer {
  final played = <Sound>[];

  @override
  Future<void> play(Sound sound) async => played.add(sound);
}

bool soundSwitchOn(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byKey(soundSwitchKey)).value;

void soundJourneys() {
  group('sound', () {
    testWidgets('the Sound switch shows in settings, on by default', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));

      await openSettings(tester);

      expect(find.byKey(soundSwitchKey), findsOneWidget);
      expect(find.text('Sound'), findsOneWidget);
      expect(soundSwitchOn(tester), isTrue);
    });

    testWidgets('turning Sound off is saved and survives a restart', (
      tester,
    ) async {
      await startWith(tester, Progress(tier: Tier.easy));
      await openSettings(tester);

      await tapKey(tester, soundSwitchKey);

      expect(soundSwitchOn(tester), isFalse);
      expect(modelOf(tester).sound, isFalse);
      await closeSettings(tester);

      await restartWhenSaved(tester, (p) => !p.sound);
      await openSettings(tester);
      expect(soundSwitchOn(tester), isFalse);
    });

    testWidgets(
      'with Sound off no sound plays; with it on, one per checked answer',
      (tester) async {
        final sounds = CountingSoundPlayer();
        final model = await startHarness(
          tester,
          progress: Progress(tier: Tier.easy, sound: false),
          clock: DateTime.now,
          sounds: sounds,
        );

        await submit(tester, model.current.result + 1);
        await submit(tester, model.current.result);
        expect(sounds.played, isEmpty);
        await nextQuestion(tester);

        await openSettings(tester);
        await tapKey(tester, soundSwitchKey);
        await closeSettings(tester);
        await submit(tester, model.current.result + 1);
        expect(sounds.played, [Sound.wrong]);
        await submit(tester, model.current.result);
        expect(sounds.played, hasLength(2));
      },
    );
  });
}

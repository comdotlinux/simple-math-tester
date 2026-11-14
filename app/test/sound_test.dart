import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/math_tester_model.dart';
import 'package:simple_math_tester/operations.dart';
import 'package:simple_math_tester/progress.dart';
import 'package:simple_math_tester/rules.dart';
import 'package:simple_math_tester/sound_player.dart';

class RecordingPlayer implements SoundPlayer {
  final played = <Sound>[];

  @override
  Future<void> play(Sound sound) async => played.add(sound);
}

class FailingPlayer implements SoundPlayer {
  FailingPlayer({required this.sync});

  final bool sync;
  int calls = 0;

  @override
  Future<void> play(Sound sound) {
    calls++;
    if (sync) throw StateError('no audio device');
    return Future.error(StateError('no audio device'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 11, 14, 9);
  const level2 = Problem(2, 3, OperationType.plus, 5, level: 2);

  MathTesterModel modelWith(
    SoundPlayer player, {
    bool sound = true,
    GameState game = const GameState(),
  }) {
    final model = MathTesterModel(
      initialProblem: level2,
      nextProblem: () => level2,
      clock: () => start,
      progress: Progress(tier: Tier.easy, game: game, sound: sound),
      sounds: player,
    );
    addTearDown(model.dispose);
    return model;
  }

  void check(MathTesterModel model, String input) {
    model.setDraftInput(input);
    model.submitAnswer();
  }

  // 90 XP + a level 2 answer (20 XP) crosses level 2 at 100 XP.
  const nearLevel = GameState(xp: 90);
  // The tenth answer of today reaches the goal; 10 + 20 XP stays level 1.
  const nearGoal = GameState(
    xp: 10,
    dailyCount: 9,
    lastActiveDate: '2026-11-14',
  );

  group('criterion 40: sounds follow the switch', () {
    for (final (name, game, input, expected) in [
      ('a correct first check', const GameState(), '5', Sound.correct),
      ('a wrong first check', const GameState(), '4', Sound.wrong),
      ('a level-up', nearLevel, '5', Sound.levelUp),
      ('the daily goal', nearGoal, '5', Sound.goal),
      (
        'a level-up together with the goal',
        const GameState(xp: 90, dailyCount: 9, lastActiveDate: '2026-11-14'),
        '5',
        Sound.levelUp,
      ),
    ]) {
      test('$name plays ${expected.name} once', () async {
        final player = RecordingPlayer();
        check(modelWith(player, game: game), input);
        await pumpEventQueue();
        expect(player.played, [expected]);
      });

      test('$name plays nothing with the switch off', () async {
        final player = RecordingPlayer();
        check(modelWith(player, game: game, sound: false), input);
        await pumpEventQueue();
        expect(player.played, isEmpty);
      });
    }

    test('invalid input and Next play nothing; a retry plays again', () async {
      final player = RecordingPlayer();
      final model = modelWith(player);
      check(model, '');
      check(model, 'abc');
      model.generateNextProblem();
      check(model, '4');
      check(model, '5');
      await pumpEventQueue();
      expect(player.played, [Sound.wrong, Sound.correct]);
    });

    test('turning the switch off silences the next check', () async {
      final player = RecordingPlayer();
      final model = modelWith(player);
      check(model, '5');
      model.setSound(false);
      model.generateNextProblem();
      check(model, '5');
      await pumpEventQueue();
      expect(player.played, [Sound.correct]);
    });
  });

  group('criterion 41: a failing player', () {
    for (final sync in [true, false]) {
      test('that throws ${sync ? 'at once' : 'later'} changes no result and '
          'is reported once', () async {
        final reported = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = previous);
        final player = FailingPlayer(sync: sync);
        final model = modelWith(player, game: nearLevel);

        model.setDraftInput('5');
        expect(model.submitAnswer(), isTrue);
        expect(model.answerCorrect, isTrue);
        expect(model.history.single.correct, isTrue);
        expect(model.game.xp, 110);
        expect(model.celebrations, 1);
        // The failure is handled after the check returns, like any answer.
        await pumpEventQueue();
        model.generateNextProblem();
        check(model, '4');
        await pumpEventQueue();

        expect(model.answerCorrect, isFalse);
        expect(player.calls, 1, reason: 'silent after the first failure');
        expect(reported, hasLength(1));
        expect(reported.single.exception, isA<StateError>());
      });
    }
  });

  group('criterion 42: AudioplayersSoundPlayer', () {
    test(
      'sets the audio context once, before any clip loads or plays',
      () async {
        final log = <String>[];
        final player = AudioplayersSoundPlayer(
          setUp: () async => log.add('context'),
          load: (path) async {
            log.add('load $path');
            return () async => log.add('play $path');
          },
        );
        await player.play(Sound.correct);
        await player.play(Sound.goal);
        expect(log, [
          'context',
          'load sounds/correct.wav',
          'load sounds/wrong.wav',
          'load sounds/level_up.wav',
          'load sounds/goal.wav',
          'play sounds/correct.wav',
          'play sounds/goal.wav',
        ]);
      },
    );

    test('a failed setup fails play and is not unhandled', () async {
      final player = AudioplayersSoundPlayer(
        setUp: () async => throw StateError('no audio'),
        load: (path) async => () async {},
      );
      await expectLater(player.play(Sound.wrong), throwsStateError);
    });

    test('the context is iOS ambient and Android focus none', () {
      expect(feedbackAudioContext.iOS.category, AVAudioSessionCategory.ambient);
      expect(feedbackAudioContext.android.audioFocus, AndroidAudioFocus.none);
    });

    test('every clip is declared in pubspec.yaml', () async {
      for (final sound in Sound.values) {
        final data = await rootBundle.load('assets/sounds/${sound.file}');
        expect(data.lengthInBytes, greaterThan(1000), reason: sound.file);
        expect(
          await bundledSoundPath('sounds/${sound.file}'),
          'sounds/${sound.file}',
        );
      }
    });

    test('a content-hashed web build plays the renamed file', () async {
      final bundle = _ManifestBundle({
        'assets/sounds/correct.wav': [
          {'asset': 'assets/sounds/correct.dece6f76.wav'},
        ],
      });
      expect(
        await bundledSoundPath('sounds/correct.wav', bundle),
        'sounds/correct.dece6f76.wav',
      );
      expect(
        await bundledSoundPath('sounds/goal.wav', bundle),
        'sounds/goal.wav',
        reason: 'a name missing from the manifest is used as is',
      );
    });
  });
}

/// Serves only an `AssetManifest.bin` with the given entries.
class _ManifestBundle extends CachingAssetBundle {
  _ManifestBundle(this.entries);

  final Map<String, List<Map<String, String>>> entries;

  @override
  Future<ByteData> load(String key) async {
    expect(key, 'AssetManifest.bin');
    return const StandardMessageCodec().encodeMessage(entries)!;
  }
}

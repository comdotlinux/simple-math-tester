import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a sound marks; each has its own clip under `assets/sounds/`.
enum Sound {
  correct('correct.wav'),
  wrong('wrong.wav'),
  levelUp('level_up.wav'),
  goal('goal.wav');

  const Sound(this.file);
  final String file;
}

abstract interface class SoundPlayer {
  /// Starts [sound]; completes once it has started, or with the error.
  Future<void> play(Sound sound);
}

class SilentSoundPlayer implements SoundPlayer {
  const SilentSoundPlayer();

  @override
  Future<void> play(Sound sound) async {}
}

/// iOS: mixes with other audio and obeys the silent switch. Android: plays
/// as a UI sound without taking audio focus.
final feedbackAudioContext = AudioContext(
  android: const AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.assistanceSonification,
    audioFocus: AndroidAudioFocus.none,
  ),
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
);

/// Sets the audio context once, then preloads one [AudioPool] per clip.
/// Loading starts at construction, so the first answer does not wait for it.
class AudioplayersSoundPlayer implements SoundPlayer {
  AudioplayersSoundPlayer({
    @visibleForTesting Future<void> Function()? setUp,
    @visibleForTesting Future<Future<void> Function()> Function(String)? load,
  }) {
    // ignore() only marks a failed load as handled; play() still sees it.
    _clips = _prepare(setUp ?? _setGlobalContext, load ?? _loadPool)..ignore();
  }

  late final Future<Map<Sound, Future<void> Function()>> _clips;

  static Future<void> _setGlobalContext() =>
      AudioPlayer.global.setAudioContext(feedbackAudioContext);

  static Future<Future<void> Function()> _loadPool(String path) async {
    final bundled = await bundledSoundPath(path);
    // On web an audio element fetches its file with a Range header, which
    // the service worker leaves to the network; bytes read through the
    // asset bundle come from its cache, so sound also plays offline.
    final source = kIsWeb
        ? BytesSource(
            (await rootBundle.load('assets/$bundled')).buffer.asUint8List(),
            mimeType: 'audio/wav',
          )
        : AssetSource(bundled);
    final pool = await AudioPool.create(source: source, maxPlayers: 3);
    return pool.start;
  }

  static Future<Map<Sound, Future<void> Function()>> _prepare(
    Future<void> Function() setUp,
    Future<Future<void> Function()> Function(String) load,
  ) async {
    await setUp();
    return {for (final s in Sound.values) s: await load('sounds/${s.file}')};
  }

  @override
  Future<void> play(Sound sound) async => (await _clips)[sound]!();
}

/// The file actually bundled for [path] (relative to `assets/`, as
/// audioplayers takes it): `flutter build web --web-content-hash` renames
/// `sounds/correct.wav` to `sounds/correct.<hash>.wav` and records the new
/// name in the asset manifest. Elsewhere the name is unchanged.
Future<String> bundledSoundPath(String path, [AssetBundle? bundle]) async {
  const prefix = 'assets/';
  final manifest = await AssetManifest.loadFromAssetBundle(
    bundle ?? rootBundle,
  );
  final bundled =
      manifest.getAssetVariants('$prefix$path')?.firstOrNull?.key ??
      '$prefix$path';
  return bundled.substring(prefix.length);
}

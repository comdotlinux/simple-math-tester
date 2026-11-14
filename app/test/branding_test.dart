import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// PNG colour type from the IHDR chunk: 2 is RGB, 6 is RGBA.
int _colorType(String path) => File(path).readAsBytesSync()[25];

/// Largest distance from the centre of any pixel that differs from the
/// corner pixel, as a fraction of the image width.
Future<double> _contentRadius(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final px = (await image.toByteData())!.buffer.asUint8List();
  final w = image.width;
  var best = 0.0;
  for (var i = 0; i < px.length; i += 4) {
    final differs = [0, 1, 2, 3].any((c) => (px[i + c] - px[c]).abs() > 8);
    if (!differs) continue;
    final x = (i ~/ 4) % w + 0.5 - w / 2;
    final y = (i ~/ 4) ~/ w + 0.5 - w / 2;
    best = max(best, sqrt(x * x + y * y));
  }
  return best / w;
}

void main() {
  test('iOS marketing icon has no alpha channel', () {
    const path =
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png';
    expect(_colorType(path), 2);
  });

  test('Android adaptive icon layers exist for every density', () {
    expect(
      File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
          .readAsStringSync(),
      allOf(
        contains('<background'),
        contains('<foreground'),
        contains('<monochrome'),
      ),
    );
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final n in [
        'ic_launcher',
        'ic_launcher_foreground',
        'ic_launcher_monochrome',
      ]) {
        expect(
          File('android/app/src/main/res/mipmap-$d/$n.png').existsSync(),
          isTrue,
          reason: '$d $n',
        );
      }
    }
  });

  test('web manifest icons exist', () {
    for (final n in ['192', '512', 'maskable-192', 'maskable-512']) {
      expect(File('web/icons/Icon-$n.png').existsSync(), isTrue, reason: n);
    }
  });

  testWidgets('icon artwork stays inside the mask safe circles', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res/mipmap-xxxhdpi';
      // Android adaptive layers: 66 of 108 dp diameter survives every mask.
      for (final n in ['ic_launcher_foreground', 'ic_launcher_monochrome']) {
        expect(
          await _contentRadius('$res/$n.png'),
          lessThan(33 / 108),
          reason: n,
        );
      }
      // Web maskable: content inside a circle of radius 40% of the width.
      expect(
        await _contentRadius('web/icons/Icon-maskable-512.png'),
        lessThan(0.4),
      );
    });
  });
}

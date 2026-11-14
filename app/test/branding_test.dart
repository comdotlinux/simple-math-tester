import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PNG colour type from the IHDR chunk: 2 is RGB, 6 is RGBA.
int _colorType(String path) => File(path).readAsBytesSync()[25];

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
}

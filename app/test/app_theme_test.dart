import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/app_theme.dart';

double contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

List<Color> schemeColors(ColorScheme scheme) {
  final builder = DiagnosticPropertiesBuilder();
  scheme.debugFillProperties(builder);
  return [
    for (final property in builder.properties)
      if (property.value case final Color color) color,
  ];
}

Iterable<File> libFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

void main() {
  const themes = {
    Brightness.light: AppTokens.light,
    Brightness.dark: AppTokens.dark,
  };

  test('criterion 32: no Gradient class anywhere in lib', () {
    for (final file in libFiles()) {
      expect(
        file.readAsStringSync(),
        isNot(contains('Gradient')),
        reason: '$file',
      );
    }
  });

  test('criterion 32: no purple to magenta colour in schemes or tokens', () {
    for (final MapEntry(key: brightness, value: tokens) in themes.entries) {
      final scheme = buildAppTheme(brightness).colorScheme;
      final colors = [...schemeColors(scheme), ...tokens.colors.values];
      // A full scheme has dozens of roles; a short list means the collector broke.
      expect(schemeColors(scheme).length, greaterThan(40));
      for (final color in colors) {
        final hsv = HSVColor.fromColor(color);
        if (hsv.saturation < .15) continue;
        expect(
          hsv.hue < 250 || hsv.hue > 320,
          isTrue,
          reason: '$brightness $color has hue ${hsv.hue}',
        );
      }
    }
  });

  test('both token sets define every role', () {
    for (final tokens in themes.values) {
      expect(tokens.colors.keys.toSet(), AppColor.values.toSet());
    }
  });

  test('criterion 33: every contrast pair reaches 4.5 to 1 in both themes', () {
    for (final MapEntry(key: brightness, value: tokens) in themes.entries) {
      for (final (foreground, background) in AppTokens.contrastPairs) {
        expect(
          contrast(tokens.colors[foreground]!, tokens.colors[background]!),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness $foreground on $background',
        );
      }
    }
  });

  test('criterion 33: ink, muted ink and every on-role are in a pair', () {
    final foregrounds = {for (final (fg, _) in AppTokens.contrastPairs) fg};
    for (final role in AppColor.values) {
      if (role.name.startsWith('on') ||
          role == AppColor.ink ||
          role == AppColor.inkMuted) {
        expect(foregrounds, contains(role));
      }
    }
  });

  test('the scheme reads its colours from the tokens', () {
    for (final MapEntry(key: brightness, value: tokens) in themes.entries) {
      final theme = buildAppTheme(brightness);
      expect(theme.extension<AppTokens>(), tokens);
      expect(theme.colorScheme.brightness, brightness);
      expect(theme.colorScheme.primary, tokens.primary);
      expect(theme.colorScheme.onSurface, tokens.ink);
      expect(theme.scaffoldBackgroundColor, tokens.surface);
    }
  });

  test('keyboard focus thickens every button edge to ink', () {
    for (final MapEntry(key: brightness, value: tokens) in themes.entries) {
      final theme = buildAppTheme(brightness);
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
        theme.iconButtonTheme.style!,
      ]) {
        final focused = style.side!.resolve({WidgetState.focused})!;
        expect(focused.color, tokens.ink);
        expect(focused.width, 4);
        expect(
          style.side!.resolve({})!.width,
          lessThan(focused.width),
          reason: '$brightness',
        );
      }
      expect(theme.inputDecorationTheme.focusedBorder!.borderSide.width, 4);
    }
  });

  test('no widget hard-codes a colour outside app_theme.dart', () {
    final literal = RegExp(r'Color\(0x|Colors\.');
    for (final file in libFiles()) {
      if (file.path.endsWith('app_theme.dart')) continue;
      expect(
        literal.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: '$file',
      );
    }
  });

  test('copyWith and lerp behave', () {
    const red = Color(0xFFFF0000);
    final changed = AppTokens.light.copyWith(colors: {AppColor.xp: red});
    expect(changed.xp, red);
    expect(changed.ink, AppTokens.light.ink);
    expect(AppTokens.light.lerp(null, .5), AppTokens.light);
    expect(AppTokens.light.lerp(changed, 1).xp, red);
    expect(
      AppTokens.light.lerp(AppTokens.dark, 1).surface,
      AppTokens.dark.surface,
    );
  });
}

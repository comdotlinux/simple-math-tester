import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/app_theme.dart';

void main() {
  test('light tokens equal the AppColors constants', () {
    const t = AppTokens.light;
    expect(t.canvas, AppColors.canvas);
    expect(t.paper, AppColors.paper);
    expect(t.ink, AppColors.ink);
    expect(t.muted, AppColors.muted);
    expect(t.teal, AppColors.teal);
    expect(t.mint, AppColors.mint);
    expect(t.yellow, AppColors.yellow);
    expect(t.peach, AppColors.peach);
    expect(t.error, AppColors.error);
    expect(t.border, AppColors.border);
  });

  test('buildAppTheme carries the light tokens', () {
    expect(buildAppTheme().extension<AppTokens>(), AppTokens.light);
  });

  test('copyWith and lerp behave', () {
    const red = Color(0xFFFF0000);
    expect(AppTokens.light.copyWith(mint: red).mint, red);
    expect(AppTokens.light.copyWith(mint: red).ink, AppColors.ink);
    expect(AppTokens.light.lerp(null, .5), AppTokens.light);
    expect(
      AppTokens.light.lerp(AppTokens.light.copyWith(mint: red), 1).mint,
      red,
    );
  });
}

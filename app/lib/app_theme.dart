import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF7F5EE);
  static const paper = Color(0xFFFFFEF9);
  static const ink = Color(0xFF203B36);
  static const muted = Color(0xFF526760);
  static const teal = Color(0xFF226453);
  static const mint = Color(0xFFE1EEE4);
  static const yellow = Color(0xFFF1CC68);
  static const peach = Color(0xFFF7DDD1);
  static const error = Color(0xFF9F382C);
  static const border = Color(0xFFD9DED3);
}

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.canvas,
    required this.paper,
    required this.ink,
    required this.muted,
    required this.teal,
    required this.mint,
    required this.yellow,
    required this.peach,
    required this.error,
    required this.border,
  });

  static const light = AppTokens(
    canvas: AppColors.canvas,
    paper: AppColors.paper,
    ink: AppColors.ink,
    muted: AppColors.muted,
    teal: AppColors.teal,
    mint: AppColors.mint,
    yellow: AppColors.yellow,
    peach: AppColors.peach,
    error: AppColors.error,
    border: AppColors.border,
  );

  final Color canvas;
  final Color paper;
  final Color ink;
  final Color muted;
  final Color teal;
  final Color mint;
  final Color yellow;
  final Color peach;
  final Color error;
  final Color border;

  @override
  AppTokens copyWith({
    Color? canvas,
    Color? paper,
    Color? ink,
    Color? muted,
    Color? teal,
    Color? mint,
    Color? yellow,
    Color? peach,
    Color? error,
    Color? border,
  }) => AppTokens(
    canvas: canvas ?? this.canvas,
    paper: paper ?? this.paper,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    teal: teal ?? this.teal,
    mint: mint ?? this.mint,
    yellow: yellow ?? this.yellow,
    peach: peach ?? this.peach,
    error: error ?? this.error,
    border: border ?? this.border,
  );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      peach: Color.lerp(peach, other.peach, t)!,
      error: Color.lerp(error, other.error, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    primary: AppColors.teal,
    onPrimary: AppColors.paper,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    error: AppColors.error,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 40,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            color: AppColors.ink,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
            color: AppColors.ink,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          bodyLarge: const TextStyle(
            fontSize: 17,
            height: 1.5,
            color: AppColors.ink,
          ),
          bodyMedium: const TextStyle(
            fontSize: 16,
            height: 1.4,
            color: AppColors.ink,
          ),
        )
        .apply(
          fontFamily: 'Roboto',
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        side: const BorderSide(color: AppColors.muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.muted),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.muted),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.teal, width: 2.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.paper,
      indicatorColor: AppColors.mint,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.paper,
      indicatorColor: AppColors.mint,
      selectedIconTheme: IconThemeData(color: AppColors.teal),
      unselectedIconTheme: IconThemeData(color: AppColors.muted),
      selectedLabelTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    dividerColor: AppColors.border,
    extensions: const [AppTokens.light],
  );
}

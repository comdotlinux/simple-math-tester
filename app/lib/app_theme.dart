import 'package:material_ui/material_ui.dart';

/// Every colour role. An `on…` role is the text and icon colour drawn on
/// top of the role it names.
enum AppColor {
  surface,
  surfaceRaised,
  surfaceSunken,
  ink,
  inkMuted,
  outline,
  shadow,
  primary,
  onPrimary,
  operation,
  onOperation,
  correct,
  onCorrect,
  wrong,
  onWrong,
  streak,
  onStreak,
  xp,
  onXp,
  combo,
  onCombo,
  sprint,
  onSprint,
}

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens(this.colors);

  /// Light playful: bright accents on a warm sunny page, navy ink outlines
  /// and navy slabs under raised things.
  static const light = AppTokens({
    AppColor.surface: Color(0xFFFFF6E3),
    AppColor.surfaceRaised: Color(0xFFFFFFFF),
    AppColor.surfaceSunken: Color(0xFFF5E7C8),
    AppColor.ink: Color(0xFF18213B),
    AppColor.inkMuted: Color(0xFF4D5672),
    AppColor.outline: Color(0xFF18213B),
    AppColor.shadow: Color(0xFF18213B),
    AppColor.primary: Color(0xFFFFC83A),
    AppColor.onPrimary: Color(0xFF18213B),
    AppColor.operation: Color(0xFF5B9DFF),
    AppColor.onOperation: Color(0xFF18213B),
    AppColor.correct: Color(0xFF35D07F),
    AppColor.onCorrect: Color(0xFF18213B),
    AppColor.wrong: Color(0xFFFF6B57),
    AppColor.onWrong: Color(0xFF18213B),
    AppColor.streak: Color(0xFFFF9A2F),
    AppColor.onStreak: Color(0xFF18213B),
    AppColor.xp: Color(0xFF1FCBB8),
    AppColor.onXp: Color(0xFF18213B),
    AppColor.combo: Color(0xFFB6E63A),
    AppColor.onCombo: Color(0xFF18213B),
    AppColor.sprint: Color(0xFF3CC8F2),
    AppColor.onSprint: Color(0xFF18213B),
  });

  /// Dark neon: the same roles as vivid fills on a near-black page, with
  /// near-black text on them.
  static const dark = AppTokens({
    AppColor.surface: Color(0xFF0B0F17),
    AppColor.surfaceRaised: Color(0xFF161C29),
    AppColor.surfaceSunken: Color(0xFF212A3B),
    AppColor.ink: Color(0xFFF5F2E9),
    AppColor.inkMuted: Color(0xFFA8B1C5),
    AppColor.outline: Color(0xFF5CE1E6),
    AppColor.shadow: Color(0xFF1C5A66),
    AppColor.primary: Color(0xFFFFD43B),
    AppColor.onPrimary: Color(0xFF0B0F17),
    AppColor.operation: Color(0xFF4FA3FF),
    AppColor.onOperation: Color(0xFF0B0F17),
    AppColor.correct: Color(0xFF3BF08C),
    AppColor.onCorrect: Color(0xFF0B0F17),
    AppColor.wrong: Color(0xFFFF5F57),
    AppColor.onWrong: Color(0xFF0B0F17),
    AppColor.streak: Color(0xFFFFA032),
    AppColor.onStreak: Color(0xFF0B0F17),
    AppColor.xp: Color(0xFF2FEAD5),
    AppColor.onXp: Color(0xFF0B0F17),
    AppColor.combo: Color(0xFFC8FF3D),
    AppColor.onCombo: Color(0xFF0B0F17),
    AppColor.sprint: Color(0xFF38DCFF),
    AppColor.onSprint: Color(0xFF0B0F17),
  });

  /// The (text or icon, background) pairs widgets draw; each must reach
  /// 4.5 to 1 in both themes.
  static const contrastPairs = [
    (AppColor.ink, AppColor.surface),
    (AppColor.ink, AppColor.surfaceRaised),
    (AppColor.ink, AppColor.surfaceSunken),
    (AppColor.inkMuted, AppColor.surface),
    (AppColor.inkMuted, AppColor.surfaceRaised),
    (AppColor.inkMuted, AppColor.surfaceSunken),
    (AppColor.surface, AppColor.ink),
    (AppColor.onPrimary, AppColor.primary),
    (AppColor.onOperation, AppColor.operation),
    (AppColor.onCorrect, AppColor.correct),
    (AppColor.onWrong, AppColor.wrong),
    (AppColor.onStreak, AppColor.streak),
    (AppColor.onXp, AppColor.xp),
    (AppColor.onCombo, AppColor.combo),
    (AppColor.onSprint, AppColor.sprint),
  ];

  /// Corner radii, and the hard shadow: a solid slab [depth] px below a
  /// raised surface that shrinks to [pressedDepth] while it is pressed.
  static const radiusCard = 28.0;
  static const radiusControl = 18.0;
  static const depth = 5.0;
  static const pressedDepth = 1.0;
  static const outlineWidth = 2.0;

  final Map<AppColor, Color> colors;

  Color get surface => colors[AppColor.surface]!;
  Color get surfaceRaised => colors[AppColor.surfaceRaised]!;
  Color get surfaceSunken => colors[AppColor.surfaceSunken]!;
  Color get ink => colors[AppColor.ink]!;
  Color get inkMuted => colors[AppColor.inkMuted]!;
  Color get outline => colors[AppColor.outline]!;
  Color get shadow => colors[AppColor.shadow]!;
  Color get primary => colors[AppColor.primary]!;
  Color get onPrimary => colors[AppColor.onPrimary]!;
  Color get operation => colors[AppColor.operation]!;
  Color get onOperation => colors[AppColor.onOperation]!;
  Color get correct => colors[AppColor.correct]!;
  Color get onCorrect => colors[AppColor.onCorrect]!;
  Color get wrong => colors[AppColor.wrong]!;
  Color get onWrong => colors[AppColor.onWrong]!;
  Color get streak => colors[AppColor.streak]!;
  Color get onStreak => colors[AppColor.onStreak]!;
  Color get xp => colors[AppColor.xp]!;
  Color get onXp => colors[AppColor.onXp]!;
  Color get combo => colors[AppColor.combo]!;
  Color get onCombo => colors[AppColor.onCombo]!;
  Color get sprint => colors[AppColor.sprint]!;
  Color get onSprint => colors[AppColor.onSprint]!;

  @override
  AppTokens copyWith({Map<AppColor, Color>? colors}) =>
      AppTokens({...this.colors, ...?colors});

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens({
      for (final role in AppColor.values)
        role: Color.lerp(colors[role], other.colors[role], t)!,
    });
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

ThemeData buildAppTheme(Brightness brightness) {
  final t = brightness == Brightness.light ? AppTokens.light : AppTokens.dark;
  // Written out in full so no generated colour can land in the purple range.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.primary,
    onPrimary: t.onPrimary,
    primaryContainer: t.primary,
    onPrimaryContainer: t.onPrimary,
    primaryFixed: t.primary,
    primaryFixedDim: t.primary,
    onPrimaryFixed: t.onPrimary,
    onPrimaryFixedVariant: t.onPrimary,
    secondary: t.operation,
    onSecondary: t.onOperation,
    secondaryContainer: t.operation,
    onSecondaryContainer: t.onOperation,
    secondaryFixed: t.operation,
    secondaryFixedDim: t.operation,
    onSecondaryFixed: t.onOperation,
    onSecondaryFixedVariant: t.onOperation,
    tertiary: t.xp,
    onTertiary: t.onXp,
    tertiaryContainer: t.xp,
    onTertiaryContainer: t.onXp,
    tertiaryFixed: t.xp,
    tertiaryFixedDim: t.xp,
    onTertiaryFixed: t.onXp,
    onTertiaryFixedVariant: t.onXp,
    error: t.wrong,
    onError: t.onWrong,
    errorContainer: t.wrong,
    onErrorContainer: t.onWrong,
    surface: t.surface,
    onSurface: t.ink,
    surfaceDim: t.surfaceSunken,
    surfaceBright: t.surfaceRaised,
    surfaceContainerLowest: t.surfaceRaised,
    surfaceContainerLow: t.surfaceRaised,
    surfaceContainer: t.surfaceRaised,
    surfaceContainerHigh: t.surfaceSunken,
    surfaceContainerHighest: t.surfaceSunken,
    onSurfaceVariant: t.inkMuted,
    outline: t.outline,
    outlineVariant: t.outline,
    shadow: t.shadow,
    scrim: t.shadow,
    inverseSurface: t.ink,
    onInverseSurface: t.surface,
    inversePrimary: t.primary,
    surfaceTint: t.surface,
  );
  final control = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppTokens.radiusControl),
  );
  final card = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppTokens.radiusCard),
    side: BorderSide(color: t.outline, width: AppTokens.outlineWidth),
  );
  // A thicker ink edge marks keyboard focus on every button, in both themes.
  final buttonSide = WidgetStateProperty.resolveWith(
    (states) => BorderSide(
      color: states.contains(WidgetState.focused) ? t.ink : t.outline,
      width: states.contains(WidgetState.focused) ? 4 : AppTokens.outlineWidth,
    ),
  );
  // Disabled controls use opaque muted colours from contrastPairs, never a
  // translucent fade.
  WidgetStateProperty<Color> enabledOr(Color enabled, Color disabled) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? disabled : enabled,
      );
  const buttonText = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Roboto',
  );
  const tabular = [FontFeature.tabularFigures()];
  return base.copyWith(
    scaffoldBackgroundColor: t.surface,
    textTheme: base.textTheme
        .copyWith(
          // The question: the biggest, heaviest thing on screen.
          displayLarge: const TextStyle(
            fontSize: 64,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            fontFeatures: tabular,
          ),
          displaySmall: const TextStyle(
            fontSize: 36,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            fontFeatures: tabular,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: const TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w700,
            fontFeatures: tabular,
          ),
          bodyLarge: const TextStyle(fontSize: 18, height: 1.45),
          bodyMedium: const TextStyle(fontSize: 16, height: 1.4),
          labelLarge: buttonText,
          // Small section labels above a value.
          labelMedium: const TextStyle(
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w500,
            letterSpacing: .3,
          ),
        )
        .apply(fontFamily: 'Roboto', bodyColor: t.ink, displayColor: t.ink),
    iconTheme: IconThemeData(color: t.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 56)),
        padding: const WidgetStatePropertyAll(buttonPadding),
        textStyle: const WidgetStatePropertyAll(buttonText),
        backgroundColor: enabledOr(t.primary, t.surfaceSunken),
        foregroundColor: enabledOr(t.onPrimary, t.inkMuted),
        overlayColor: WidgetStatePropertyAll(t.ink.withValues(alpha: .1)),
        side: buttonSide,
        shape: WidgetStatePropertyAll(control),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 56)),
        padding: const WidgetStatePropertyAll(buttonPadding),
        textStyle: const WidgetStatePropertyAll(buttonText),
        backgroundColor: enabledOr(t.surfaceRaised, t.surfaceSunken),
        foregroundColor: enabledOr(t.ink, t.inkMuted),
        overlayColor: WidgetStatePropertyAll(t.ink.withValues(alpha: .08)),
        side: buttonSide,
        shape: WidgetStatePropertyAll(control),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            foregroundColor: t.ink,
            disabledForegroundColor: t.inkMuted,
            textStyle: buttonText,
            shape: control,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? BorderSide(color: t.ink, width: 4)
                  : BorderSide.none,
            ),
          ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(52, 52),
        backgroundColor: t.surfaceRaised,
        foregroundColor: t.ink,
        disabledBackgroundColor: t.surfaceSunken,
        disabledForegroundColor: t.inkMuted,
        shape: control,
      ).copyWith(side: buttonSide),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      labelStyle: TextStyle(
        fontFamily: 'Roboto',
        color: t.inkMuted,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: TextStyle(
        fontFamily: 'Roboto',
        color: t.ink,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(fontFamily: 'Roboto', color: t.inkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        borderSide: BorderSide(color: t.outline, width: AppTokens.outlineWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        borderSide: BorderSide(color: t.outline, width: AppTokens.outlineWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        borderSide: BorderSide(color: t.ink, width: 4),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.ink,
      selectionColor: t.operation.withValues(alpha: .45),
      selectionHandleColor: t.operation,
    ),
    cardTheme: CardThemeData(
      color: t.surfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: card,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surfaceRaised,
      modalBackgroundColor: t.surfaceRaised,
      dragHandleColor: t.outline,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusCard),
        ),
        side: BorderSide(color: t.outline, width: AppTokens.outlineWidth),
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: t.ink,
      iconColor: t.ink,
      selectedColor: t.onPrimary,
      selectedTileColor: t.primary,
      minVerticalPadding: 12,
      shape: control,
      titleTextStyle: buttonText,
      subtitleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        color: t.inkMuted,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: TextStyle(
        fontFamily: 'Roboto',
        color: t.surface,
        fontSize: 16,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surfaceRaised,
      surfaceTintColor: t.surfaceRaised,
      elevation: 0,
      height: 72,
      indicatorColor: t.primary,
      indicatorShape: StadiumBorder(
        side: BorderSide(color: t.outline, width: AppTokens.outlineWidth),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? t.onPrimary : t.ink,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: t.ink,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.surfaceRaised,
      indicatorColor: t.primary,
      indicatorShape: StadiumBorder(
        side: BorderSide(color: t.outline, width: AppTokens.outlineWidth),
      ),
      selectedIconTheme: IconThemeData(color: t.onPrimary),
      unselectedIconTheme: IconThemeData(color: t.ink),
      selectedLabelTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: t.ink,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: t.ink,
      ),
    ),
    dividerColor: t.outline,
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: t.surfaceSunken,
      circularTrackColor: t.surfaceSunken,
    ),
    extensions: [t],
  );
}

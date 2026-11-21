import 'dart:ui' show Locale;

import 'app_theme.dart' show AppPalette;
import 'figure.dart';
import 'l10n/app_localizations.dart';
import 'operations.dart';
import 'rules.dart';

extension OperationLabel on OperationType {
  String label(AppLocalizations l) => switch (this) {
    OperationType.plus => l.operationAddition,
    OperationType.minus => l.operationSubtraction,
    OperationType.multiply => l.operationMultiplication,
    OperationType.divide => l.operationDivision,
    OperationType.algebra => l.operationAlgebra,
    OperationType.geometry => l.operationGeometry,
  };
}

extension ProblemLabel on Problem {
  /// The question as text in the pinned band, the history and the review:
  /// a figure is its sentence, others are [Problem.question].
  String shown(AppLocalizations l) => switch (this) {
    FigureProblem(:final figure) => figureSentence(l, figure),
    _ => question,
  };

  /// [shown] for screen readers: the blank is a word, not a "white square".
  String spoken(AppLocalizations l) =>
      shown(l).replaceAll(EquationProblem.blank, l.blank);
}

/// The text form of [figure]: the shape, every label and what is asked,
/// such as "Rectangle, sides 5 and 3. Perimeter?". Read from the labels
/// themselves, so it says what the figure shows. Also the figure's
/// semantics label and the line in the history.
String figureSentence(AppLocalizations l, Figure figure) {
  final sides = [for (final label in figure.labels) label.text];
  final shape = switch (figure.shape) {
    FigureShape.square => l.figureSquare(sides[0]),
    FigureShape.rectangle => l.figureRectangle(sides[0], sides[1]),
    FigureShape.triangle => l.figureTriangle(sides[0], sides[1], sides[2]),
  };
  return l.figureQuestion(shape, figurePromptText(l, figure.prompt));
}

/// The short line under the figure, such as "Perimeter?".
String figurePromptText(AppLocalizations l, FigurePrompt prompt) =>
    switch (prompt) {
      FigurePrompt.perimeter => l.figurePerimeter,
      FigurePrompt.area => l.figureArea,
    };

extension TierLabel on Tier {
  String label(AppLocalizations l) => switch (this) {
    Tier.easy => l.tierEasy,
    Tier.medium => l.tierMedium,
    Tier.hard => l.tierHard,
    Tier.harder => l.tierHarder,
  };
}

extension PaletteLabel on AppPalette {
  String label(AppLocalizations l) => switch (this) {
    AppPalette.sunny => l.paletteSunny,
    AppPalette.ocean => l.paletteOcean,
    AppPalette.forest => l.paletteForest,
    AppPalette.berry => l.paletteBerry,
    AppPalette.sunset => l.paletteSunset,
  };
}

/// A time span as minutes and seconds, such as "1 minute 5 seconds", or
/// "1m, 5s" when [abbreviated]. Longer spans stay in minutes.
String formatElapsed(AppLocalizations l, int ms, {bool abbreviated = false}) {
  final minutes = ms ~/ 60000;
  final seconds = ms ~/ 1000 % 60;
  return [
    if (minutes > 0)
      abbreviated
          ? l.durationMinutesShort(minutes)
          : l.durationMinutes(minutes),
    if (seconds > 0 || minutes == 0)
      abbreviated
          ? l.durationSecondsShort(seconds)
          : l.durationSeconds(seconds),
  ].join(abbreviated ? ', ' : ' ');
}

/// The supported locale saved as [code], its [Locale.toString] such as "de"
/// or "pt_PT".
Locale appLocale(String code) => AppLocalizations.supportedLocales.firstWhere(
  (locale) => locale.toString() == code,
);

/// Each app language's name in English, shown under its own name in the
/// language picker, keyed like [appLocale]. A test keeps it in step with the
/// supported locales.
const englishLanguageNames = {
  'en': 'English',
  'de': 'German',
  'pl': 'Polish',
  'hi': 'Hindi',
  'mr': 'Marathi',
  'te': 'Telugu',
  'ta': 'Tamil',
  'ml': 'Malayalam',
  'fr': 'French',
  'ro': 'Romanian',
  'uk': 'Ukrainian',
  'pt': 'Portuguese (Brazil)',
  'pt_PT': 'Portuguese (Portugal)',
  'pa': 'Punjabi',
};

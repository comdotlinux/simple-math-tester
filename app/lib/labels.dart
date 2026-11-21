import 'dart:ui' show Locale;

import 'app_theme.dart' show AppPalette;
import 'figure.dart';
import 'hundredths.dart';
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
  /// The question as text on the card, in the pinned band, the history and
  /// the review: a figure is its sentence, an equation's condition is a line
  /// of words under it ("n is positive"), others are [Problem.question].
  String shown(AppLocalizations l) => switch (this) {
    FigureProblem(:final figure) => figureSentence(l, figure),
    EquationProblem() => question.replaceFirst(
      ', ${EquationProblem.positive}',
      '\n${l.equationPositive}',
    ),
    _ => question,
  };

  /// [shown] for screen readers: the blank is a word, not a "white square",
  /// and in an equation `2n` or `3(n − 2)` say their multiplication
  /// (`2 × n`), so a number is not read into the letter; `7²` and `√49` are
  /// read as words ("7 squared", "square root of 49").
  String spoken(AppLocalizations l) {
    final text = shown(l).replaceAll(EquationProblem.blank, l.blank);
    return this is EquationProblem
        ? text
              .replaceAllMapped(RegExp(r'(\d)(?=[n(])'), (m) => '${m[1]} × ')
              .replaceAllMapped(
                RegExp(r'(\d+|n)²'),
                (m) => l.spokenSquared(m[1]!),
              )
              .replaceAllMapped(
                RegExp(r'√(\d+)'),
                (m) => l.spokenSquareRoot(m[1]!),
              )
              .replaceAll('\n', ', ')
        : text;
  }
}

/// The text form of [figure]: the shape, every label and what is asked,
/// such as "Rectangle, sides 5 and 3. Perimeter?". Read from the labels
/// themselves, so it says what the figure shows; the asked angle is left
/// to the prompt. Also the figure's semantics label and the line in the
/// history.
String figureSentence(AppLocalizations l, Figure figure) {
  final sides = [for (final label in figure.labels) label.text(l.localeName)];
  final angles = [
    for (final angle in figure.angles)
      if (angle.degrees != null) angle.text,
  ];
  final shape = switch (figure.shape) {
    FigureShape.square => l.figureSquare(sides[0]),
    FigureShape.rectangle when figure.diagonal => l.figureRectangleDiagonal(
      sides[0],
      sides[1],
    ),
    FigureShape.rectangle => l.figureRectangle(sides[0], sides[1]),
    FigureShape.triangle when angles.isNotEmpty => l.figureTriangleAngles(
      angles[0],
      angles[1],
    ),
    FigureShape.triangle => l.figureTriangle(sides[0], sides[1], sides[2]),
    FigureShape.rightTriangle when sides.length == 3 =>
      l.figureRightTriangleSides(sides[0], sides[1], sides[2]),
    FigureShape.rightTriangle => l.figureRightTriangle(sides[0], sides[1]),
    FigureShape.lShape => l.figureLShape(
      sides[0],
      sides[1],
      sides[2],
      sides[3],
    ),
    FigureShape.straightAngle => l.figureStraightAngle(angles[0]),
    FigureShape.rightAngle => l.figureRightAngle(angles[0]),
    // The ? two angles on from the given one is opposite it.
    FigureShape.crossingLines
        when (figure.angles[1].corner - figure.angles[0].corner) % 4 == 2 =>
      l.figureCrossingOpposite(angles[0]),
    FigureShape.crossingLines => l.figureCrossingNeighbour(angles[0]),
    FigureShape.aroundPoint => l.figureAroundPoint(angles[0], angles[1]),
    FigureShape.circle =>
      figure.vertices.contains(figure.centre)
          ? l.figureCircleRadius(sides[0])
          : l.figureCircleDiameter(sides[0]),
  };
  return l.figureQuestion(shape, figurePromptText(l, figure));
}

/// The short line under the figure, such as "Perimeter?", with the given
/// perimeter or area when a side is asked, and "Use π = 3.14." for a
/// circle.
String figurePromptText(AppLocalizations l, Figure figure) {
  String number(int hundredths) => formatHundredths(hundredths, l.localeName);
  final prompt = switch (figure.prompt) {
    FigurePrompt.perimeter => l.figurePerimeter,
    FigurePrompt.area => l.figureArea,
    FigurePrompt.sideFromPerimeter => l.figureSideFromPerimeter(
      number(figure.total!),
    ),
    FigurePrompt.sideFromArea => l.figureSideFromArea(number(figure.total!)),
    FigurePrompt.angle => l.figureAngle,
    FigurePrompt.circumference => l.figureCircumference,
    FigurePrompt.length => l.figureLength,
  };
  return switch (figure.pi) {
    final pi? => '$prompt ${l.figureUsePi(number(pi))}',
    null => prompt,
  };
}

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

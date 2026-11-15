import 'l10n/app_localizations.dart';
import 'operations.dart';
import 'rules.dart';

extension OperationLabel on OperationType {
  String label(AppLocalizations l) => switch (this) {
    OperationType.plus => l.operationAddition,
    OperationType.minus => l.operationSubtraction,
    OperationType.multiply => l.operationMultiplication,
    OperationType.divide => l.operationDivision,
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

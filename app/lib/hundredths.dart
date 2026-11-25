/// Answers that can be negative or decimal, held as a whole number of
/// hundredths (`-2.5` is `-250`). Text is read and written by string code
/// only: floating point is not exact (`3.14 * 3 * 3` is
/// `28.259999999999998`), so no double ever decides such an answer.
library;

import 'package:intl/intl.dart';

import 'digits.dart';

/// The minus sign the app shows, as in its subtraction sign.
const minusSign = '−';

/// An optional leading minus (`-` or `−`), digits, and at most one decimal
/// separator (`.` or `,`) with at most two digits after it.
final _number = RegExp(r'^[-−]?([0-9]*)(?:[.,]([0-9]{0,2}))?$');

/// More digits than this before the separator are not a number, so the
/// value stays exact also on the web, where an int is a double.
const _maxWholeDigits = 12;

/// [text] typed by a child as a whole number of hundredths, or null when it
/// is not a number. Surrounding spaces are ignored. `3.`, `,5`, `2.50`,
/// `−3` and `-0` (which is 0) parse; `-`, `.`, `-.`, `1e1`, `+5`, `1.2.3`
/// and a third decimal place (`1.234`, never rounded) do not.
int? parseHundredths(String text) {
  final trimmed = asciiDigits(text).trim();
  final match = _number.firstMatch(trimmed);
  if (match == null) return null;
  final whole = match[1]!;
  final fraction = match[2] ?? '';
  if (whole.isEmpty && fraction.isEmpty) return null;
  if (whole.length > _maxWholeDigits) return null;
  final value =
      int.parse(whole.isEmpty ? '0' : whole) * 100 +
      int.parse(fraction.padRight(2, '0'));
  return trimmed.startsWith(RegExp('[-−]')) ? -value : value;
}

/// Whether [text] is a number for [parseHundredths] or could still become
/// one by typing more, such as `-`, `,` or `3.`. The answer field admits
/// only such text.
bool canCompleteHundredths(String text) => _number.hasMatch(asciiDigits(text));

/// [hundredths] as a number for the text form, history and saved data:
/// a whole number as an int, others as the nearest double (`250` is `2.5`).
/// Never compared: answers of such kinds are compared in hundredths.
num numberOfHundredths(int hundredths) =>
    hundredths % 100 == 0 ? hundredths ~/ 100 : hundredths / 100;

/// The decimal separator of the language [localeName], such as `.` for
/// `en` and `,` for `de`.
String decimalSeparator(String localeName) =>
    NumberFormat.decimalPattern(localeName).symbols.DECIMAL_SEP;

/// [hundredths] as the shortest text: Western digits, the language's
/// decimal separator, no trailing zeros, and [minusSign] when negative
/// (`250` is `2.5`, `300` is `3`, `-25` is `−0.25`).
String formatHundredths(int hundredths, String localeName) {
  final digits = hundredths.abs();
  final whole = '${digits ~/ 100}';
  final cents = digits % 100;
  final sign = hundredths < 0 ? minusSign : '';
  if (cents == 0) return '$sign$whole';
  final fraction = cents % 10 == 0
      ? '${cents ~/ 10}'
      : '$cents'.padLeft(2, '0');
  return '$sign$whole${decimalSeparator(localeName)}$fraction';
}

/// Digits of the scripts the app's languages use. Display may show them;
/// report codes and saved data stay ASCII. Done by code point, not by intl's
/// NumberFormat, whose digits differ from locale to locale.
library;

import 'package:flutter/services.dart';

/// The code point of the digit zero (the next nine follow it) for each
/// language code that does not write 0-9.
const zeroOfLanguage = <String, int>{
  'ar': 0x0660,
  'ur': 0x06F0,
  'fa': 0x06F0,
  'bn': 0x09E6,
  'gu': 0x0AE6,
  'mr': 0x0966,
  'hi': 0x0966,
  'pa': 0x0A66,
  'te': 0x0C66,
  'ta': 0x0BE6,
  'ml': 0x0D66,
};

/// Languages shown in their own digits unless the "Numbers" setting (#277)
/// says 0-9.
const _nativeDigitLanguages = {'ar', 'ur', 'bn', 'gu', 'mr'};

/// The language whose digits to show for the page language [languageCode]:
/// itself where native digits are on, else `en` (0-9). The one place #277
/// wires its setting into.
String digitsLanguage(String languageCode) =>
    _nativeDigitLanguages.contains(languageCode) ? languageCode : 'en';

/// The Arabic decimal separator, which [asciiDigits] turns into `.`.
const _arabicDecimal = '٫';

final _zeros = zeroOfLanguage.values.toSet();

/// [text] with ASCII 0-9 in the digits of [languageCode], or unchanged for a
/// language that writes 0-9.
String localDigits(String text, String languageCode) {
  final zero = zeroOfLanguage[languageCode];
  if (zero == null) return text;
  return String.fromCharCodes(
    text.runes.map((r) => r >= 0x30 && r <= 0x39 ? zero + r - 0x30 : r),
  );
}

/// [text] with every digit of those scripts as ASCII 0-9 and the Arabic
/// decimal separator as `.`. Same length, so a selection stays valid.
String asciiDigits(String text) {
  return String.fromCharCodes(
    text.replaceAll(_arabicDecimal, '.').runes.map((r) {
      for (final zero in _zeros) {
        if (r >= zero && r <= zero + 9) return 0x30 + r - zero;
      }
      return r;
    }),
  );
}

/// Turns native digits typed or pasted into ASCII, so the answer fields
/// accept both kinds. Put it before any filter.
final nativeDigitsToAscii = TextInputFormatter.withFunction(
  (old, edited) => edited.copyWith(text: asciiDigits(edited.text)),
);

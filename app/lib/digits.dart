/// Digits of the scripts the app's languages use. Display may show them;
/// report codes and saved data stay ASCII. Done by code point, not by intl's
/// NumberFormat, whose digits differ from locale to locale.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

/// The language whose digits [languageCode] shows by default: itself where
/// native digits are on by default, else `en` (0-9). On screen the
/// "Numbers" setting decides, through [DigitScope].
String digitsLanguage(String languageCode) =>
    showsNativeDigits(null, languageCode) ? languageCode : 'en';

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

/// Languages whose own digits show by default; the other languages in
/// [zeroOfLanguage] show 0-9 until the child chooses otherwise.
const nativeDigitsByDefault = {'ar', 'ur', 'bn', 'gu', 'mr'};

/// Whether numbers show in [languageCode]'s own digits: the child's choice
/// [setting], or the language's default when null.
bool showsNativeDigits(bool? setting, String languageCode) =>
    zeroOfLanguage.containsKey(languageCode) &&
    (setting ?? nativeDigitsByDefault.contains(languageCode));

/// The digits of the page below it: the language code whose digits the
/// page's text shows, or null for 0-9.
class DigitScope extends InheritedWidget {
  const DigitScope({super.key, required this.language, required super.child});

  final String? language;

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DigitScope>()?.language;

  @override
  bool updateShouldNotify(DigitScope old) => language != old.language;
}

/// [text] in the digits the page shows, for a semantics label or a tooltip.
String shownDigits(BuildContext context, String text) {
  final language = DigitScope.of(context);
  return language == null ? text : localDigits(text, language);
}

/// [span] with [convert] applied to the text of every [TextSpan] in it and
/// to its semantics label.
InlineSpan convertDigits(InlineSpan span, String Function(String) convert) =>
    switch (span) {
      TextSpan(:final text, :final children) => TextSpan(
        text: text == null ? null : convert(text),
        children: children?.map((c) => convertDigits(c, convert)).toList(),
        style: span.style,
        recognizer: span.recognizer,
        semanticsLabel: span.semanticsLabel == null
            ? null
            : convert(span.semanticsLabel!),
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        locale: span.locale,
        spellOut: span.spellOut,
      ),
      _ => span,
    };

/// A field controller whose text stays ASCII (so parsing, saving and the
/// number pad see 0-9) but is drawn in the page's digits. Same length, so
/// the caret and selection stay valid.
class DigitsController extends TextEditingController {
  DigitsController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final span = super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
    final language = DigitScope.of(context);
    return language == null
        ? span
        : convertDigits(span, (t) => localDigits(t, language)) as TextSpan;
  }
}

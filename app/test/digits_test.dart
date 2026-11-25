import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/digits.dart';
import 'package:simple_math_tester/hundredths.dart';

void main() {
  const ascii = '0123456789';
  const native = {
    'ar': '٠١٢٣٤٥٦٧٨٩',
    'ur': '۰۱۲۳۴۵۶۷۸۹',
    'bn': '০১২৩৪৫৬৭৮৯',
    'gu': '૦૧૨૩૪૫૬૭૮૯',
    'mr': '०१२३४५६७८९',
    'hi': '०१२३४५६७८९',
    'pa': '੦੧੨੩੪੫੬੭੮੯',
    'te': '౦౧౨౩౪౫౬౭౮౯',
    'ta': '௦௧௨௩௪௫௬௭௮௯',
    'ml': '൦൧൨൩൪൫൬൭൮൯',
  };

  test('localDigits and asciiDigits are inverse for each language', () {
    native.forEach((code, digits) {
      expect(localDigits(ascii, code), digits, reason: code);
      expect(asciiDigits(digits), ascii, reason: code);
      expect(asciiDigits(localDigits('a 12-3,4.5 b', code)), 'a 12-3,4.5 b');
    });
  });

  test('a language with 0-9 and other text stay unchanged', () {
    expect(localDigits('12,5 x', 'en'), '12,5 x');
    expect(asciiDigits('abc 7'), 'abc 7');
  });

  test('the Arabic decimal separator becomes a point', () {
    expect(asciiDigits('٣٫١٤'), '3.14');
  });

  test('answers parse with native digits', () {
    expect(parseHundredths('٤٢'), 4200);
    expect(parseHundredths('−٢٫٥'), -250);
    expect(parseHundredths('२,५'), 250);
    expect(parseHundredths('১২.৫০'), 1250);
    expect(canCompleteHundredths('-٣٫'), isTrue);
    expect(canCompleteHundredths('٣٫١٢٣'), isFalse);
  });

  test('the formatter writes native digits as ASCII', () {
    final out = nativeDigitsToAscii.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '٣٫٥'),
    );
    expect(out.text, '3.5');
  });
}

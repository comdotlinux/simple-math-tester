import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/hundredths.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';

void main() {
  final languages = [
    for (final locale in AppLocalizations.supportedLocales)
      lookupAppLocalizations(locale).localeName,
  ];

  group('parseHundredths', () {
    test('reads digits, one minus, one separator and two decimals', () {
      const accepted = {
        '0': 0,
        '-0': 0,
        '−0': 0,
        '7': 700,
        '42': 4200,
        '3.': 300,
        '3,': 300,
        ',5': 50,
        '.5': 50,
        '-.5': -50,
        '2.50': 250,
        '2,5': 250,
        '0.05': 5,
        '−3': -300,
        '-3': -300,
        '−2.5': -250,
        '-2,5': -250,
        '-0,25': -25,
        '007': 700,
        ' 12 ': 1200,
        '999999999999.99': 99999999999999,
      };
      for (final MapEntry(:key, :value) in accepted.entries) {
        expect(parseHundredths(key), value, reason: key);
      }
    });

    test('is not a number for anything else', () {
      const rejected = [
        '',
        ' ',
        '\t',
        '-',
        '−',
        '.',
        ',',
        '-.',
        '−,',
        '1e1',
        '+5',
        '1.2.3',
        '1,2.3',
        '--1',
        '-−1',
        '1-',
        '1 2',
        '1.234',
        '0,001',
        '1.2e3',
        'NaN',
        'Infinity',
        '١',
        '٣.٥',
        '१२',
        '1000000000000',
      ];
      for (final text in rejected) {
        expect(parseHundredths(text), isNull, reason: text);
      }
    });
  });

  test('canCompleteHundredths admits what typing can still complete', () {
    for (final text in ['', '-', '−', '.', ',', '-.', '3.', '-2,5', '0.05']) {
      expect(canCompleteHundredths(text), isTrue, reason: text);
    }
    for (final text in ['+', '1e', '1.2.', '--', '1-', '0.001', 'a', ' ']) {
      expect(canCompleteHundredths(text), isFalse, reason: text);
    }
  });

  test('formatHundredths writes the shortest text with the language '
      'separator and the minus sign', () {
    expect(formatHundredths(250, 'en'), '2.5');
    expect(formatHundredths(250, 'de'), '2,5');
    expect(formatHundredths(300, 'en'), '3');
    expect(formatHundredths(0, 'de'), '0');
    expect(formatHundredths(-25, 'en'), '−0.25');
    expect(formatHundredths(-25, 'pt_PT'), '−0,25');
    expect(formatHundredths(5, 'en'), '0.05');
    expect(formatHundredths(-1000, 'fr'), '−10');
    expect(formatHundredths(2826, 'en'), '28.26');
    expect(decimalSeparator('en'), '.');
    expect(decimalSeparator('de'), ',');
  });

  test('every language writes Western digits and . or , only', () {
    for (final language in languages) {
      expect(decimalSeparator(language), anyOf('.', ','), reason: language);
      expect(
        formatHundredths(-123456789, language),
        matches(RegExp(r'^−1234567[.,]89$')),
        reason: language,
      );
    }
  });

  test('in every language, format then parse gives the same hundredths', () {
    for (final language in languages) {
      for (var k = -40000; k <= 40000; k++) {
        final text = formatHundredths(k, language);
        if (parseHundredths(text) != k) {
          fail('$language: $k was written as $text');
        }
      }
    }
  });
}

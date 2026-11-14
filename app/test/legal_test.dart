import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/legal.dart';

void main() {
  test('the in-app privacy policy equals web/privacy.html', () {
    final html = File('web/privacy.html').readAsStringSync();
    String text(String markup) => markup
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final fromHtml = [
      for (final m in RegExp(
        r'<(h1|h2|p)>(.*?)</\1>',
        dotAll: true,
      ).allMatches(html))
        '${m[1] == 'p' ? 'p' : 'h'}: ${text(m[2]!)}',
    ];
    final inApp = [
      for (final (heading, paragraphs) in privacyPolicy) ...[
        'h: $heading',
        for (final p in paragraphs) 'p: $p',
      ],
    ];

    expect(inApp, fromHtml);
    expect(html, isNot(contains('&')), reason: 'entities would not match');
  });

  test('the only web address in lib/ is the Impressum', () {
    final addresses = {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          ...RegExp(
            r"https?://[^\s'"
            '"]+',
          ).allMatches(file.readAsStringSync()).map((m) => m[0]),
    };
    expect(addresses, {impressumUrl.toString()});
  });
}

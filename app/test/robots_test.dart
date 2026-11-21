import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web/robots.txt allows search, refuses AI training and keeps '
      'crawlers out of /api/', () {
    final lines = File('web/robots.txt').readAsLinesSync();
    expect(lines.where((line) => !line.startsWith('#')), [
      'User-agent: *',
      'Content-Signal: search=yes, ai-train=no',
      'Allow: /',
      'Disallow: /api/',
    ]);
  });
}

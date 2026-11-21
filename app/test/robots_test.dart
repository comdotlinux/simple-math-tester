import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web/robots.txt allows the site and keeps crawlers out of /api/', () {
    final lines = File('web/robots.txt').readAsLinesSync();
    expect(lines, ['User-agent: *', 'Allow: /', 'Disallow: /api/']);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_math_tester/geometry.dart';
import 'package:simple_math_tester/l10n/app_localizations.dart';
import 'package:simple_math_tester/operations.dart';

/// The report function (functions/api/report.js) accepts only the names in
/// this file; a family or language added to the app must be added there too.
final allow = jsonDecode(
  File('../functions/report-allowlist.json').readAsStringSync(),
) as Map<String, Object?>;

List<String> names(String key) => (allow[key] as List).cast<String>();

void main() {
  final algebra = OperationType.algebra.source as AlgebraSource;

  test('the report allow-list has every algebra family', () {
    expect(names('algebra'), unorderedEquals(algebra.families.keys));
    expect(names('algebra').toSet(), hasLength(names('algebra').length));
  });

  test('the report allow-list has every geometry family', () {
    expect(
      names('geometry'),
      unorderedEquals(GeometryFamily.values.map((family) => family.name)),
    );
    expect(names('geometry').toSet(), hasLength(names('geometry').length));
  });

  test('the report allow-list has every app language as Locale.toString', () {
    expect(
      names('locales'),
      unorderedEquals(AppLocalizations.supportedLocales.map((l) => '$l')),
    );
  });

  test('every question fits the report param limits', () {
    final min = allow['paramMin'] as int;
    final max = allow['paramMax'] as int;
    final count = allow['maxParams'] as int;
    void check(List<int> params, String variant) {
      expect(params.length, inInclusiveRange(1, count), reason: variant);
      for (final p in params) {
        expect(p, inInclusiveRange(min, max), reason: '$variant $params');
      }
    }

    for (final level in algebra.levels) {
      for (final (variant, ranges) in level) {
        check([for (final (low, _) in ranges) low], variant);
        check([for (final (_, high) in ranges) high], variant);
      }
    }
    for (final family in GeometryFamily.values) {
      for (final params in family.space) {
        check(params, family.name);
      }
    }
  });
}

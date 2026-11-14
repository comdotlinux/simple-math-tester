import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_math_tester/celebration.dart';

void main() {
  const size = Size(412, 720);

  test('the burst starts from all eight points, evenly', () {
    final start = CelebrationPainter.positions(size, 0, 7);
    expect(start, hasLength(180));
    final points = [
      for (final o in CelebrationPainter.origins)
        Offset(o.dx * size.width, o.dy * size.height),
    ];
    for (final p in start) {
      expect(points, contains(p));
    }
    for (final point in points) {
      expect(start.where((p) => p == point).length, inInclusiveRange(22, 23));
    }
  });

  test('mid-burst the pieces fill both sides, the top and the bottom', () {
    final mid = CelebrationPainter.positions(size, .4, 7);
    bool any(bool Function(Offset) where) => mid.any(where);
    final third = size.width / 3;
    expect(any((p) => p.dx < third), isTrue, reason: 'left');
    expect(any((p) => p.dx > 2 * third), isTrue, reason: 'right');
    bool middle(Offset p) => p.dx >= third && p.dx <= 2 * third;
    expect(any((p) => middle(p) && p.dy < size.height / 3), isTrue);
    expect(any((p) => middle(p) && p.dy > 2 * size.height / 3), isTrue);
  });
}

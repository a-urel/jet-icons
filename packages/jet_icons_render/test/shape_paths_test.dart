import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';

void main() {
  test('macBodyPath bounds', () {
    expect(
      macBodyPath(1024).getBounds(),
      const Rect.fromLTWH(100, 100, 824, 824),
    );
  });

  test('macBodyPath scales with size', () {
    expect(macBodyPath(512).getBounds(), const Rect.fromLTWH(50, 50, 412, 412));
  });

  test('roundedSquare has no margin and cut corners', () {
    final p = shapePath(IconShape.roundedSquare, 100);
    expect(p.getBounds(), const Rect.fromLTWH(0, 0, 100, 100));
    expect(p.contains(const Offset(50, 50)), isTrue);
    expect(p.contains(const Offset(50, 0.5)), isTrue);
    expect(p.contains(const Offset(1, 1)), isFalse);
    // radius 22.37: a point just inside the corner arc.
    expect(p.contains(const Offset(8, 8)), isTrue);
  });

  test('circle shape', () {
    final p = shapePath(IconShape.circle, 100);
    expect(p.getBounds(), const Rect.fromLTWH(0, 0, 100, 100));
    expect(p.contains(const Offset(10, 10)), isFalse);
    expect(p.contains(const Offset(50, 1)), isTrue);
  });

  test('square and none are the full square', () {
    for (final s in [IconShape.square, IconShape.none]) {
      final p = shapePath(s, 100);
      expect(p.getBounds(), const Rect.fromLTWH(0, 0, 100, 100));
      expect(p.contains(const Offset(0.5, 0.5)), isTrue);
    }
  });

  test('android mask paths fill the square and cut corners', () {
    for (final m in AndroidMask.values) {
      final p = androidMaskPath(m, 108);
      final b = p.getBounds();
      expect(b.left, closeTo(0, 0.01), reason: '$m');
      expect(b.top, closeTo(0, 0.01), reason: '$m');
      expect(b.width, closeTo(108, 0.01), reason: '$m');
      expect(b.height, closeTo(108, 0.01), reason: '$m');
      expect(p.contains(const Offset(54, 54)), isTrue, reason: '$m');
      expect(p.contains(const Offset(1, 1)), isFalse, reason: '$m');
    }
    // A squircle bulges past the inscribed circle on the diagonal.
    final squircle = androidMaskPath(AndroidMask.squircle, 108);
    expect(squircle.contains(const Offset(14, 14)), isTrue);
    expect(
      androidMaskPath(AndroidMask.circle, 108).contains(const Offset(14, 14)),
      isFalse,
    );
  });
}

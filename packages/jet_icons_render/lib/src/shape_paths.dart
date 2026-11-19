import 'dart:math' as math;
import 'dart:ui';

import 'package:jet_icons_core/jet_icons_core.dart';

/// Corner radius of the rounded-square mask, as a fraction of the edge.
const double roundedSquareRadiusFraction = 0.2237;

/// Mask path of [shape] for a [size] x [size] output, anchored at 0,0.
/// `square` and `none` are the full square.
Path shapePath(IconShape shape, double size) {
  final rect = Rect.fromLTWH(0, 0, size, size);
  return switch (shape) {
    IconShape.roundedSquare =>
      Path()..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(roundedSquareRadiusFraction * size),
        ),
      ),
    IconShape.circle => Path()..addOval(rect),
    IconShape.square || IconShape.none => Path()..addRect(rect),
  };
}

/// macOS icon body: on the 1024 canvas, an 824 x 824 rounded square inset
/// by 100 with corner radius 185.4; scaled to [size].
Path macBodyPath(double size) {
  final k = size / canvasSize;
  return Path()..addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(100 * k, 100 * k, 824 * k, 824 * k),
      Radius.circular(185.4 * k),
    ),
  );
}

/// Launcher masks Android may apply to adaptive icons.
enum AndroidMask { circle, squircle, roundedSquare }

/// Approximate Android launcher mask for a [size] x [size] preview. Only for
/// previews; exports never apply it (the launcher does).
Path androidMaskPath(AndroidMask mask, double size) {
  final rect = Rect.fromLTWH(0, 0, size, size);
  return switch (mask) {
    AndroidMask.circle => Path()..addOval(rect),
    AndroidMask.roundedSquare =>
      Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(0.2 * size))),
    AndroidMask.squircle => _superellipse(size, 4),
  };
}

/// |x|^n + |y|^n = 1, fitted to the square.
Path _superellipse(double size, double n) {
  const steps = 128;
  final r = size / 2;
  final path = Path();
  for (var i = 0; i < steps; i++) {
    final t = 2 * math.pi * i / steps;
    final c = math.cos(t), s = math.sin(t);
    final x = r + r * c.sign * math.pow(c.abs(), 2 / n);
    final y = r + r * s.sign * math.pow(s.abs(), 2 / n);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  return path..close();
}

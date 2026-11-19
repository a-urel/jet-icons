import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:path_parsing/path_parsing.dart';

/// Bounds of [e] in its own local space (before its transform).
ui.Rect localBounds(IconElement e) => switch (e) {
  PathElement() => _pathBounds(e.d),
  RasterElement() => ui.Rect.fromLTWH(
    0,
    0,
    e.width.toDouble(),
    e.height.toDouble(),
  ),
  RawSvgElement() => ui.Rect.fromLTWH(0, 0, e.vbWidth, e.vbHeight),
  GroupElement() => _union([for (final c in e.children) elementBounds(c)]),
};

/// Bounds of [e] in its parent's space: [localBounds] mapped through the
/// element's transform, as an axis-aligned box.
ui.Rect elementBounds(IconElement e) =>
    transformRect(e.transform, localBounds(e));

/// Axis-aligned bounding box of [r] after [t].
ui.Rect transformRect(Transform2D t, ui.Rect r) {
  if (t == Transform2D.identity) return r;
  final xs = <double>[];
  final ys = <double>[];
  for (final p in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
    xs.add(t.a * p.dx + t.c * p.dy + t.e);
    ys.add(t.b * p.dx + t.d * p.dy + t.f);
  }
  return ui.Rect.fromLTRB(
    xs.reduce(math.min),
    ys.reduce(math.min),
    xs.reduce(math.max),
    ys.reduce(math.max),
  );
}

ui.Rect _union(List<ui.Rect> rects) {
  if (rects.isEmpty) return ui.Rect.zero;
  return rects.reduce((a, b) => a.expandToInclude(b));
}

ui.Rect _pathBounds(String d) {
  final proxy = _BoundsProxy();
  try {
    writeSvgPathDataToPath(d, proxy);
  } catch (_) {
    return ui.Rect.zero;
  }
  return proxy.path.getBounds();
}

class _BoundsProxy extends PathProxy {
  final ui.Path path = ui.Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

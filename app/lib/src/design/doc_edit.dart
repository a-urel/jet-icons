import 'dart:ui' as ui;

import 'package:jet_icons_core/jet_icons_core.dart';

import 'element_bounds.dart';

const _center = canvasSize / 2;

/// The layer of [kind]; a derived (`null`) monochrome reads as empty.
Layer layerOf(IconDocument d, LayerKind kind) => switch (kind) {
  LayerKind.background => d.background,
  LayerKind.foreground => d.foreground,
  LayerKind.monochrome => d.monochrome ?? const Layer(null, []),
};

IconDocument withLayer(IconDocument d, LayerKind kind, Layer layer) =>
    switch (kind) {
      LayerKind.background => d.copyWith(background: layer),
      LayerKind.foreground => d.copyWith(foreground: layer),
      LayerKind.monochrome => d.copyWith(monochrome: layer),
    };

/// Applies [fn] to the element [id] (searched deeply) of layer [kind].
IconDocument updateElement(
  IconDocument d,
  LayerKind kind,
  String id,
  IconElement Function(IconElement) fn,
) {
  final layer = layerOf(d, kind);
  return withLayer(
    d,
    kind,
    layer.copyWith(elements: _map(layer.elements, id, fn)),
  );
}

List<IconElement> _map(
  List<IconElement> list,
  String id,
  IconElement Function(IconElement) fn,
) => [
  for (final e in list)
    if (e.id == id)
      fn(e)
    else if (e is GroupElement)
      e.copyWith(children: _map(e.children, id, fn))
    else
      e,
];

/// Moves [e] by a canvas-space delta; the translate is prepended so it
/// happens in the parent space.
IconElement translated(IconElement e, double dx, double dy) =>
    withTransform(e, Transform2D.translate(dx, dy).multiply(e.transform));

/// Scales [e] uniformly by [k] about [center] (parent space).
IconElement scaledAbout(IconElement e, double k, ui.Offset center) {
  final about = Transform2D.translate(center.dx, center.dy)
      .multiply(Transform2D.scale(k))
      .multiply(Transform2D.translate(-center.dx, -center.dy));
  return withTransform(e, about.multiply(e.transform));
}

IconElement withTransform(IconElement e, Transform2D t) => switch (e) {
  PathElement() => e.copyWith(transform: t),
  GroupElement() => e.copyWith(transform: t),
  RasterElement() => e.copyWith(transform: t),
  RawSvgElement() => e.copyWith(transform: t),
};

IconElement withOpacity(IconElement e, double o) => switch (e) {
  PathElement() => e.copyWith(opacity: o),
  GroupElement() => e.copyWith(opacity: o),
  RasterElement() => e.copyWith(opacity: o),
  RawSvgElement() => e.copyWith(opacity: o),
};

IconElement withHidden(IconElement e, bool h) => switch (e) {
  PathElement() => e.copyWith(hidden: h),
  GroupElement() => e.copyWith(hidden: h),
  RasterElement() => e.copyWith(hidden: h),
  RawSvgElement() => e.copyWith(hidden: h),
};

/// Maps a parent-space rect of a layer with [scale] to canvas space (the
/// layer content scales about the canvas center).
ui.Rect toCanvasSpace(ui.Rect r, double scale) => ui.Rect.fromLTRB(
  _center + (r.left - _center) * scale,
  _center + (r.top - _center) * scale,
  _center + (r.right - _center) * scale,
  _center + (r.bottom - _center) * scale,
);

/// Topmost visible top-level element of [layer] whose canvas-space bounds
/// contain [p].
IconElement? hitTest(Layer layer, ui.Offset p) {
  for (final e in layer.elements.reversed) {
    if (e.hidden) continue;
    if (toCanvasSpace(elementBounds(e), layer.scale).contains(p)) return e;
  }
  return null;
}

/// Every raster / raw SVG leaf element anywhere in [doc], including group
/// children and detached override layers.
List<IconElement> assetElements(IconDocument doc) {
  final out = <IconElement>[];
  void visit(List<IconElement> list) {
    for (final e in list) {
      if (e is GroupElement) {
        visit(e.children);
      } else if (e is RasterElement || e is RawSvgElement) {
        out.add(e);
      }
    }
  }

  for (final l in [doc.background, doc.foreground, doc.monochrome]) {
    if (l != null) visit(l.elements);
  }
  for (final o in doc.overrides) {
    for (final l in o.detached.values) {
      visit(l.elements);
    }
  }
  return out;
}

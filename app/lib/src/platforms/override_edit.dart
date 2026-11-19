import 'package:jet_icons_core/jet_icons_core.dart';

import '../shared/ids.dart';

/// Canvas size layers are resolved at when no size range is set.
const _fullSize = canvasSize;

/// Which field of a [LayerPatch] to clear.
enum LayerPatchField { scale, fill, hidden }

/// Which field of an [ElementPatch] to clear.
enum ElementPatchField { hidden, opacity, fill, transform }

bool _matches(
  PlatformOverride o,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
) => o.platform == p && o.variant == v && o.sizeRange == r;

/// The override identified by `(platform, variant, sizeRange)`, if any.
PlatformOverride? findOverride(
  IconDocument doc,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
) {
  for (final o in doc.overrides) {
    if (_matches(o, p, v, r)) return o;
  }
  return null;
}

bool _isEmpty(PlatformOverride o) =>
    o.layerPatches.isEmpty && o.elementPatches.isEmpty && o.detached.isEmpty;

/// Applies [change] to the override for the key, creating it when missing.
/// An override left without patches and detached layers is removed.
IconDocument updateOverride(
  IconDocument doc,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
  PlatformOverride Function(PlatformOverride current) change,
) {
  final index = doc.overrides.indexWhere((o) => _matches(o, p, v, r));
  final current = index < 0
      ? PlatformOverride(p, variant: v, sizeRange: r)
      : doc.overrides[index];
  final next = change(current);
  final list = [...doc.overrides];
  if (_isEmpty(next)) {
    if (index < 0) return doc;
    list.removeAt(index);
  } else if (index < 0) {
    list.add(next);
  } else {
    list[index] = next;
  }
  return doc.copyWith(overrides: list);
}

/// Sets the given (non-null) fields of the patch for [layer], merging with
/// an existing patch.
IconDocument setLayerPatch(
  IconDocument doc,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
  LayerKind layer, {
  double? scale,
  Fill? fill,
  bool? hidden,
}) => updateOverride(doc, p, v, r, (o) {
  final old = _layerPatch(o, layer);
  final merged = LayerPatch(
    layer,
    scale: scale ?? old?.scale,
    fill: fill ?? old?.fill,
    hidden: hidden ?? old?.hidden,
  );
  return o.copyWith(layerPatches: _replaceLayerPatch(o, merged));
});

/// Clears [field] of the patch for [layer]; a patch left empty is removed.
IconDocument clearLayerPatchField(
  IconDocument doc,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
  LayerKind layer,
  LayerPatchField field,
) => updateOverride(doc, p, v, r, (o) {
  final old = _layerPatch(o, layer);
  if (old == null) return o;
  final cleared = LayerPatch(
    layer,
    scale: field == LayerPatchField.scale ? null : old.scale,
    fill: field == LayerPatchField.fill ? null : old.fill,
    hidden: field == LayerPatchField.hidden ? null : old.hidden,
  );
  return o.copyWith(layerPatches: _replaceLayerPatch(o, cleared));
});

LayerPatch? _layerPatch(PlatformOverride o, LayerKind layer) {
  for (final p in o.layerPatches) {
    if (p.layer == layer) return p;
  }
  return null;
}

bool _layerPatchEmpty(LayerPatch p) =>
    p.scale == null && p.fill == null && p.hidden == null;

List<LayerPatch> _replaceLayerPatch(PlatformOverride o, LayerPatch next) {
  final out = <LayerPatch>[];
  var placed = false;
  for (final p in o.layerPatches) {
    if (p.layer != next.layer) {
      out.add(p);
    } else if (!placed) {
      placed = true;
      if (!_layerPatchEmpty(next)) out.add(next);
    }
  }
  if (!placed && !_layerPatchEmpty(next)) out.add(next);
  return out;
}

/// Sets the given (non-null) fields of the patch for element [id], merging
/// with an existing patch.
IconDocument setElementPatch(
  IconDocument doc,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
  String id, {
  bool? hidden,
  double? opacity,
  Fill? fill,
  Transform2D? transform,
}) => updateOverride(doc, p, v, r, (o) {
  final old = _elementPatch(o, id);
  final merged = ElementPatch(
    id,
    hidden: hidden ?? old?.hidden,
    opacity: opacity ?? old?.opacity,
    fill: fill ?? old?.fill,
    transform: transform ?? old?.transform,
  );
  return o.copyWith(elementPatches: _replaceElementPatch(o, merged));
});

/// Clears [field] of the patch for element [id]; a patch left empty is
/// removed.
IconDocument clearElementPatchField(
  IconDocument doc,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
  String id,
  ElementPatchField field,
) => updateOverride(doc, p, v, r, (o) {
  final old = _elementPatch(o, id);
  if (old == null) return o;
  final cleared = ElementPatch(
    id,
    hidden: field == ElementPatchField.hidden ? null : old.hidden,
    opacity: field == ElementPatchField.opacity ? null : old.opacity,
    fill: field == ElementPatchField.fill ? null : old.fill,
    transform: field == ElementPatchField.transform ? null : old.transform,
  );
  return o.copyWith(elementPatches: _replaceElementPatch(o, cleared));
});

ElementPatch? _elementPatch(PlatformOverride o, String id) {
  for (final p in o.elementPatches) {
    if (p.elementId == id) return p;
  }
  return null;
}

bool _elementPatchEmpty(ElementPatch p) =>
    p.hidden == null &&
    p.opacity == null &&
    p.fill == null &&
    p.transform == null;

List<ElementPatch> _replaceElementPatch(PlatformOverride o, ElementPatch next) {
  final out = <ElementPatch>[];
  var placed = false;
  for (final p in o.elementPatches) {
    if (p.elementId != next.elementId) {
      out.add(p);
    } else if (!placed) {
      placed = true;
      if (!_elementPatchEmpty(next)) out.add(next);
    }
  }
  if (!placed && !_elementPatchEmpty(next)) out.add(next);
  return out;
}

/// Detaches [kind] for the key: `detached[kind]` becomes a copy of the layer
/// as currently resolved (common design plus the other overrides, without
/// this override) at the range min, or 1024 without a range. The copy gets
/// fresh element ids unique across the document.
IconDocument detachLayer(
  IconDocument doc,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
  LayerKind kind,
) {
  final without = doc.copyWith(
    overrides: [
      for (final o in doc.overrides)
        if (!_matches(o, p, v, r)) o,
    ],
  );
  final resolved = resolveIcon(
    without,
    platform: p,
    variant: v ?? IconVariant.light,
    sizePx: r?.minPx ?? _fullSize,
  );
  final base = switch (kind) {
    LayerKind.background => resolved.background,
    LayerKind.foreground => resolved.foreground,
    LayerKind.monochrome => resolved.monochrome,
  };
  final copy = withFreshIds(base, allElementIds(doc));
  return updateOverride(
    doc,
    p,
    v,
    r,
    (o) => o.copyWith(detached: {...o.detached, kind: copy}),
  );
}

/// Removes `detached[kind]`; the override disappears when nothing is left.
IconDocument reattachLayer(
  IconDocument doc,
  IconPlatform p,
  IconVariant? v,
  SizeRange? r,
  LayerKind kind,
) => updateOverride(
  doc,
  p,
  v,
  r,
  (o) => o.copyWith(
    detached: {
      for (final e in o.detached.entries)
        if (e.key != kind) e.key: e.value,
    },
  ),
);

/// Every element of [layer] depth first as `(id, depth, element)`.
List<(String, int, IconElement)> elementIdsOf(Layer layer) {
  final out = <(String, int, IconElement)>[];
  void walk(List<IconElement> list, int depth) {
    for (final e in list) {
      out.add((e.id, depth, e));
      if (e is GroupElement) walk(e.children, depth + 1);
    }
  }

  walk(layer.elements, 0);
  return out;
}

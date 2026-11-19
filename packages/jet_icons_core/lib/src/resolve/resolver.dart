import 'package:meta/meta.dart';

import '../model/document.dart';
import '../model/element.dart';
import '../model/layer.dart';
import '../model/override.dart';

/// The effective layers to render for one (platform, variant, size).
@immutable
class ResolvedIcon {
  const ResolvedIcon(this.background, this.foreground, this.monochrome);

  final Layer background;
  final Layer foreground;
  final Layer monochrome;

  @override
  bool operator ==(Object other) =>
      other is ResolvedIcon &&
      other.background == background &&
      other.foreground == foreground &&
      other.monochrome == monochrome;

  @override
  int get hashCode => Object.hash(background, foreground, monochrome);
}

const _emptyLayer = Layer(null, []);

/// Resolves [doc] for [platform], [variant] and [sizePx] (spec 7.1).
///
/// Starts from the common design, then applies matching overrides in three
/// groups: platform-wide, variant-specific, then size-range; list order
/// within each group.
ResolvedIcon resolveIcon(
  IconDocument doc, {
  required IconPlatform platform,
  IconVariant variant = IconVariant.light,
  required int sizePx,
}) {
  var layers = <LayerKind, Layer>{
    LayerKind.background: variant == IconVariant.dark
        ? _emptyLayer
        : doc.background,
    LayerKind.foreground: doc.foreground,
    LayerKind.monochrome: doc.monochrome ?? doc.foreground,
  };

  final forPlatform = doc.overrides.where((o) => o.platform == platform);
  final ordered = [
    ...forPlatform.where((o) => o.variant == null && o.sizeRange == null),
    ...forPlatform.where((o) => o.variant == variant && o.sizeRange == null),
    ...forPlatform.where(
      (o) =>
          o.sizeRange != null &&
          (o.variant == null || o.variant == variant) &&
          o.sizeRange!.contains(sizePx),
    ),
  ];
  for (final o in ordered) {
    layers = _apply(layers, o);
  }

  return ResolvedIcon(
    layers[LayerKind.background]!,
    layers[LayerKind.foreground]!,
    layers[LayerKind.monochrome]!,
  );
}

Map<LayerKind, Layer> _apply(Map<LayerKind, Layer> input, PlatformOverride o) {
  final layers = {...input};
  o.detached.forEach((kind, layer) => layers[kind] = layer);
  for (final p in o.layerPatches) {
    final layer = layers[p.layer]!;
    if (p.hidden == true) {
      layers[p.layer] = _emptyLayer;
      continue;
    }
    layers[p.layer] = layer.copyWith(
      fill: p.fill ?? layer.fill,
      scale: p.scale,
    );
  }
  for (final p in o.elementPatches) {
    for (final kind in LayerKind.values) {
      final layer = layers[kind]!;
      layers[kind] = layer.copyWith(
        elements: _patchElements(layer.elements, p),
      );
    }
  }
  return layers;
}

List<IconElement> _patchElements(List<IconElement> list, ElementPatch p) => [
  for (final e in list) _patchElement(e, p),
];

IconElement _patchElement(IconElement e, ElementPatch p) {
  if (e.id == p.elementId) {
    return _applyElementPatch(e, p);
  }
  if (e is GroupElement) {
    return e.copyWith(children: _patchElements(e.children, p));
  }
  return e;
}

IconElement _applyElementPatch(IconElement e, ElementPatch p) {
  final hidden = p.hidden ?? e.hidden;
  final opacity = p.opacity ?? e.opacity;
  final transform = p.transform ?? e.transform;
  return switch (e) {
    PathElement() => e.copyWith(
      hidden: hidden,
      opacity: opacity,
      transform: transform,
      fill: p.fill ?? e.fill,
    ),
    GroupElement() => e.copyWith(
      hidden: hidden,
      opacity: opacity,
      transform: transform,
    ),
    RasterElement() => e.copyWith(
      hidden: hidden,
      opacity: opacity,
      transform: transform,
    ),
    RawSvgElement() => e.copyWith(
      hidden: hidden,
      opacity: opacity,
      transform: transform,
    ),
  };
}

/// Finds the element with [id] in [layer], searching group children deeply.
IconElement? findElement(Layer layer, String id) => _find(layer.elements, id);

IconElement? _find(List<IconElement> list, String id) {
  for (final e in list) {
    if (e.id == id) return e;
    if (e is GroupElement) {
      final hit = _find(e.children, id);
      if (hit != null) return hit;
    }
  }
  return null;
}

/// Platform mask shape: windows/linux/web use the document's choice
/// (default rounded square); other platforms are always square.
IconShape shapeFor(IconDocument doc, IconPlatform platform) =>
    doc.shapeFor(platform);

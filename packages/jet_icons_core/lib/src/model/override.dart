import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'fill.dart';
import 'layer.dart';
import 'transform.dart';
import 'unset.dart';

enum IconPlatform { ios, android, macos, windows, web, linux }

enum IconVariant { light, dark, tinted }

/// Platform icon mask. [none] = no background, foreground only.
enum IconShape { roundedSquare, square, circle, none }

/// Inclusive pixel size range.
@immutable
class SizeRange {
  const SizeRange(this.minPx, this.maxPx);

  final int minPx;
  final int maxPx;

  bool contains(int px) => px >= minPx && px <= maxPx;

  SizeRange copyWith({int? minPx, int? maxPx}) =>
      SizeRange(minPx ?? this.minPx, maxPx ?? this.maxPx);

  @override
  bool operator ==(Object other) =>
      other is SizeRange && other.minPx == minPx && other.maxPx == maxPx;

  @override
  int get hashCode => Object.hash(minPx, maxPx);
}

/// Null fields mean "no change".
@immutable
class LayerPatch {
  const LayerPatch(this.layer, {this.scale, this.fill, this.hidden});

  final LayerKind layer;
  final double? scale;
  final Fill? fill;
  final bool? hidden;

  LayerPatch copyWith({
    LayerKind? layer,
    double? scale,
    Fill? fill,
    bool? hidden,
  }) => LayerPatch(
    layer ?? this.layer,
    scale: scale ?? this.scale,
    fill: fill ?? this.fill,
    hidden: hidden ?? this.hidden,
  );

  @override
  bool operator ==(Object other) =>
      other is LayerPatch &&
      other.layer == layer &&
      other.scale == scale &&
      other.fill == fill &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(layer, scale, fill, hidden);
}

/// Null fields mean "no change".
@immutable
class ElementPatch {
  const ElementPatch(
    this.elementId, {
    this.hidden,
    this.opacity,
    this.fill,
    this.transform,
  });

  final String elementId;
  final bool? hidden;
  final double? opacity;
  final Fill? fill;
  final Transform2D? transform;

  ElementPatch copyWith({
    String? elementId,
    bool? hidden,
    double? opacity,
    Fill? fill,
    Transform2D? transform,
  }) => ElementPatch(
    elementId ?? this.elementId,
    hidden: hidden ?? this.hidden,
    opacity: opacity ?? this.opacity,
    fill: fill ?? this.fill,
    transform: transform ?? this.transform,
  );

  @override
  bool operator ==(Object other) =>
      other is ElementPatch &&
      other.elementId == elementId &&
      other.hidden == hidden &&
      other.opacity == opacity &&
      other.fill == fill &&
      other.transform == transform;

  @override
  int get hashCode => Object.hash(elementId, hidden, opacity, fill, transform);
}

/// Per-platform tweaks applied on top of the base document. [detached]
/// replaces a whole layer for that platform.
@immutable
class PlatformOverride {
  const PlatformOverride(
    this.platform, {
    this.variant,
    this.sizeRange,
    this.layerPatches = const [],
    this.elementPatches = const [],
    this.detached = const {},
  });

  final IconPlatform platform;
  final IconVariant? variant;
  final SizeRange? sizeRange;
  final List<LayerPatch> layerPatches;
  final List<ElementPatch> elementPatches;
  final Map<LayerKind, Layer> detached;

  /// `variant` / `sizeRange` use the [unset] sentinel so `null` clears them.
  PlatformOverride copyWith({
    IconPlatform? platform,
    Object? variant = unset,
    Object? sizeRange = unset,
    List<LayerPatch>? layerPatches,
    List<ElementPatch>? elementPatches,
    Map<LayerKind, Layer>? detached,
  }) => PlatformOverride(
    platform ?? this.platform,
    variant: identical(variant, unset) ? this.variant : variant as IconVariant?,
    sizeRange: identical(sizeRange, unset)
        ? this.sizeRange
        : sizeRange as SizeRange?,
    layerPatches: layerPatches ?? this.layerPatches,
    elementPatches: elementPatches ?? this.elementPatches,
    detached: detached ?? this.detached,
  );

  @override
  bool operator ==(Object other) =>
      other is PlatformOverride &&
      other.platform == platform &&
      other.variant == variant &&
      other.sizeRange == sizeRange &&
      const ListEquality<LayerPatch>().equals(
        other.layerPatches,
        layerPatches,
      ) &&
      const ListEquality<ElementPatch>().equals(
        other.elementPatches,
        elementPatches,
      ) &&
      const MapEquality<LayerKind, Layer>().equals(other.detached, detached);

  @override
  int get hashCode => Object.hash(
    platform,
    variant,
    sizeRange,
    const ListEquality<LayerPatch>().hash(layerPatches),
    const ListEquality<ElementPatch>().hash(elementPatches),
    const MapEquality<LayerKind, Layer>().hash(detached),
  );
}

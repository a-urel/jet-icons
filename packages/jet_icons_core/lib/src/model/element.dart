import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'fill.dart';
import 'transform.dart';
import 'unset.dart';

/// A drawable node of a layer. All elements are immutable value objects.
@immutable
sealed class IconElement {
  const IconElement({
    required this.id,
    required this.name,
    this.transform = Transform2D.identity,
    this.opacity = 1.0,
    this.hidden = false,
  });

  final String id;
  final String name;
  final Transform2D transform;
  final double opacity;
  final bool hidden;
}

class PathElement extends IconElement {
  const PathElement({
    required super.id,
    required super.name,
    super.transform,
    super.opacity,
    super.hidden,
    required this.d,
    this.fill,
    this.stroke,
  });

  /// SVG path data.
  final String d;
  final Fill? fill;
  final Stroke? stroke;

  /// `fill` / `stroke` use the [unset] sentinel so `null` clears them.
  PathElement copyWith({
    String? id,
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? hidden,
    String? d,
    Object? fill = unset,
    Object? stroke = unset,
  }) => PathElement(
    id: id ?? this.id,
    name: name ?? this.name,
    transform: transform ?? this.transform,
    opacity: opacity ?? this.opacity,
    hidden: hidden ?? this.hidden,
    d: d ?? this.d,
    fill: identical(fill, unset) ? this.fill : fill as Fill?,
    stroke: identical(stroke, unset) ? this.stroke : stroke as Stroke?,
  );

  @override
  bool operator ==(Object other) =>
      other is PathElement &&
      other.id == id &&
      other.name == name &&
      other.transform == transform &&
      other.opacity == opacity &&
      other.hidden == hidden &&
      other.d == d &&
      other.fill == fill &&
      other.stroke == stroke;

  @override
  int get hashCode =>
      Object.hash(id, name, transform, opacity, hidden, d, fill, stroke);
}

class GroupElement extends IconElement {
  const GroupElement({
    required super.id,
    required super.name,
    super.transform,
    super.opacity,
    super.hidden,
    required this.children,
  });

  final List<IconElement> children;

  GroupElement copyWith({
    String? id,
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? hidden,
    List<IconElement>? children,
  }) => GroupElement(
    id: id ?? this.id,
    name: name ?? this.name,
    transform: transform ?? this.transform,
    opacity: opacity ?? this.opacity,
    hidden: hidden ?? this.hidden,
    children: children ?? this.children,
  );

  @override
  bool operator ==(Object other) =>
      other is GroupElement &&
      other.id == id &&
      other.name == name &&
      other.transform == transform &&
      other.opacity == opacity &&
      other.hidden == hidden &&
      const ListEquality<IconElement>().equals(other.children, children);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transform,
    opacity,
    hidden,
    const ListEquality<IconElement>().hash(children),
  );
}

class RasterElement extends IconElement {
  const RasterElement({
    required super.id,
    required super.name,
    super.transform,
    super.opacity,
    super.hidden,
    required this.png,
    required this.width,
    required this.height,
  });

  final Uint8List png;
  final int width;
  final int height;

  RasterElement copyWith({
    String? id,
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? hidden,
    Uint8List? png,
    int? width,
    int? height,
  }) => RasterElement(
    id: id ?? this.id,
    name: name ?? this.name,
    transform: transform ?? this.transform,
    opacity: opacity ?? this.opacity,
    hidden: hidden ?? this.hidden,
    png: png ?? this.png,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  @override
  bool operator ==(Object other) =>
      other is RasterElement &&
      other.id == id &&
      other.name == name &&
      other.transform == transform &&
      other.opacity == opacity &&
      other.hidden == hidden &&
      const ListEquality<int>().equals(other.png, png) &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transform,
    opacity,
    hidden,
    const ListEquality<int>().hash(png),
    width,
    height,
  );
}

/// A whole SVG document kept verbatim (SVGs the importer cannot map to paths).
class RawSvgElement extends IconElement {
  const RawSvgElement({
    required super.id,
    required super.name,
    super.transform,
    super.opacity,
    super.hidden,
    required this.svg,
    required this.vbX,
    required this.vbY,
    required this.vbWidth,
    required this.vbHeight,
  });

  final String svg;
  final double vbX, vbY, vbWidth, vbHeight;

  RawSvgElement copyWith({
    String? id,
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? hidden,
    String? svg,
    double? vbX,
    double? vbY,
    double? vbWidth,
    double? vbHeight,
  }) => RawSvgElement(
    id: id ?? this.id,
    name: name ?? this.name,
    transform: transform ?? this.transform,
    opacity: opacity ?? this.opacity,
    hidden: hidden ?? this.hidden,
    svg: svg ?? this.svg,
    vbX: vbX ?? this.vbX,
    vbY: vbY ?? this.vbY,
    vbWidth: vbWidth ?? this.vbWidth,
    vbHeight: vbHeight ?? this.vbHeight,
  );

  @override
  bool operator ==(Object other) =>
      other is RawSvgElement &&
      other.id == id &&
      other.name == name &&
      other.transform == transform &&
      other.opacity == opacity &&
      other.hidden == hidden &&
      other.svg == svg &&
      other.vbX == vbX &&
      other.vbY == vbY &&
      other.vbWidth == vbWidth &&
      other.vbHeight == vbHeight;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transform,
    opacity,
    hidden,
    svg,
    vbX,
    vbY,
    vbWidth,
    vbHeight,
  );
}

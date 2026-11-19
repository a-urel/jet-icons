import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'color.dart';
import 'fill.dart';
import 'layer.dart';
import 'override.dart';
import 'unset.dart';

/// Design canvas edge length; all coordinates and transforms use this unit.
const int canvasSize = 1024;

/// `.jeticon` format version written by this library.
const int currentFormatVersion = 1;

const _deep = DeepCollectionEquality();

@immutable
class IconDocument {
  const IconDocument(
    this.background,
    this.foreground,
    this.monochrome,
    this.shapes,
    this.overrides,
    this.extra,
  );

  /// White background, empty foreground, default shapes.
  factory IconDocument.empty() => const IconDocument(
    Layer(SolidFill(JColor(0xFFFFFFFF)), []),
    Layer(null, []),
    null,
    {
      IconPlatform.windows: IconShape.roundedSquare,
      IconPlatform.linux: IconShape.roundedSquare,
      IconPlatform.web: IconShape.roundedSquare,
    },
    [],
    {},
  );

  final Layer background;
  final Layer foreground;

  /// `null` means derived from [foreground].
  final Layer? monochrome;

  /// Only windows, linux and web are used; a missing key is `roundedSquare`.
  final Map<IconPlatform, IconShape> shapes;
  final List<PlatformOverride> overrides;

  /// Unknown top-level `.jeticon` fields, preserved across read/write.
  final Map<String, Object?> extra;

  IconShape shapeFor(IconPlatform platform) =>
      shapes[platform] ?? IconShape.roundedSquare;

  /// `monochrome` uses the [unset] sentinel so `null` clears it.
  IconDocument copyWith({
    Layer? background,
    Layer? foreground,
    Object? monochrome = unset,
    Map<IconPlatform, IconShape>? shapes,
    List<PlatformOverride>? overrides,
    Map<String, Object?>? extra,
  }) => IconDocument(
    background ?? this.background,
    foreground ?? this.foreground,
    identical(monochrome, unset) ? this.monochrome : monochrome as Layer?,
    shapes ?? this.shapes,
    overrides ?? this.overrides,
    extra ?? this.extra,
  );

  @override
  bool operator ==(Object other) =>
      other is IconDocument &&
      other.background == background &&
      other.foreground == foreground &&
      other.monochrome == monochrome &&
      _deep.equals(other.shapes, shapes) &&
      _deep.equals(other.overrides, overrides) &&
      _deep.equals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    background,
    foreground,
    monochrome,
    _deep.hash(shapes),
    _deep.hash(overrides),
    _deep.hash(extra),
  );
}

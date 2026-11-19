import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'element.dart';
import 'fill.dart';
import 'unset.dart';

enum LayerKind { background, foreground, monochrome }

/// One icon layer. [fill] covers the whole canvas; [scale] scales the
/// content around the canvas center (used for padding overrides).
@immutable
class Layer {
  const Layer(this.fill, this.elements, {this.scale = 1.0});

  final Fill? fill;
  final List<IconElement> elements;
  final double scale;

  /// `fill` uses the [unset] sentinel so `null` clears it.
  Layer copyWith({
    Object? fill = unset,
    List<IconElement>? elements,
    double? scale,
  }) => Layer(
    identical(fill, unset) ? this.fill : fill as Fill?,
    elements ?? this.elements,
    scale: scale ?? this.scale,
  );

  @override
  bool operator ==(Object other) =>
      other is Layer &&
      other.fill == fill &&
      other.scale == scale &&
      const ListEquality<IconElement>().equals(other.elements, elements);

  @override
  int get hashCode => Object.hash(
    fill,
    scale,
    const ListEquality<IconElement>().hash(elements),
  );
}

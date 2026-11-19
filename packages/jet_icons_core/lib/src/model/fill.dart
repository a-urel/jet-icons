import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'color.dart';

const _listEq = ListEquality<GradientStop>();

@immutable
class GradientStop {
  const GradientStop(this.offset, this.color);

  final double offset;
  final JColor color;

  GradientStop copyWith({double? offset, JColor? color}) =>
      GradientStop(offset ?? this.offset, color ?? this.color);

  @override
  bool operator ==(Object other) =>
      other is GradientStop && other.offset == offset && other.color == color;

  @override
  int get hashCode => Object.hash(offset, color);
}

/// A paint. Coordinates are in the element's local space (same as its path `d`); the renderer applies the element transform to the fill.
@immutable
sealed class Fill {
  const Fill();
}

class SolidFill extends Fill {
  const SolidFill(this.color);

  final JColor color;

  SolidFill copyWith({JColor? color}) => SolidFill(color ?? this.color);

  @override
  bool operator ==(Object other) => other is SolidFill && other.color == color;

  @override
  int get hashCode => color.hashCode;
}

class LinearGradientFill extends Fill {
  const LinearGradientFill(this.stops, this.x1, this.y1, this.x2, this.y2);

  final List<GradientStop> stops;
  final double x1, y1, x2, y2;

  LinearGradientFill copyWith({
    List<GradientStop>? stops,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
  }) => LinearGradientFill(
    stops ?? this.stops,
    x1 ?? this.x1,
    y1 ?? this.y1,
    x2 ?? this.x2,
    y2 ?? this.y2,
  );

  @override
  bool operator ==(Object other) =>
      other is LinearGradientFill &&
      _listEq.equals(other.stops, stops) &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2;

  @override
  int get hashCode => Object.hash(_listEq.hash(stops), x1, y1, x2, y2);
}

class RadialGradientFill extends Fill {
  const RadialGradientFill(this.stops, this.cx, this.cy, this.r);

  final List<GradientStop> stops;
  final double cx, cy, r;

  RadialGradientFill copyWith({
    List<GradientStop>? stops,
    double? cx,
    double? cy,
    double? r,
  }) => RadialGradientFill(
    stops ?? this.stops,
    cx ?? this.cx,
    cy ?? this.cy,
    r ?? this.r,
  );

  @override
  bool operator ==(Object other) =>
      other is RadialGradientFill &&
      _listEq.equals(other.stops, stops) &&
      other.cx == cx &&
      other.cy == cy &&
      other.r == r;

  @override
  int get hashCode => Object.hash(_listEq.hash(stops), cx, cy, r);
}

@immutable
class Stroke {
  const Stroke(this.color, this.width);

  final JColor color;
  final double width;

  Stroke copyWith({JColor? color, double? width}) =>
      Stroke(color ?? this.color, width ?? this.width);

  @override
  bool operator ==(Object other) =>
      other is Stroke && other.color == color && other.width == width;

  @override
  int get hashCode => Object.hash(color, width);
}

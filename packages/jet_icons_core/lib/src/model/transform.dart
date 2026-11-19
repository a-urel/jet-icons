import 'dart:math' as math;

import 'package:meta/meta.dart';

/// 2D affine transform, SVG matrix convention `matrix(a b c d e f)`:
/// x' = a*x + c*y + e, y' = b*x + d*y + f.
@immutable
class Transform2D {
  const Transform2D(this.a, this.b, this.c, this.d, this.e, this.f);

  static const Transform2D identity = Transform2D(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, e, f;

  /// `this * o`: [o] is applied first, then this transform.
  Transform2D multiply(Transform2D o) => Transform2D(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );

  static Transform2D translate(double x, double y) =>
      Transform2D(1, 0, 0, 1, x, y);

  static Transform2D scale(double sx, [double? sy]) =>
      Transform2D(sx, 0, 0, sy ?? sx, 0, 0);

  static Transform2D rotate(double radians) {
    final cosR = math.cos(radians), sinR = math.sin(radians);
    return Transform2D(cosR, sinR, -sinR, cosR, 0, 0);
  }

  Transform2D copyWith({
    double? a,
    double? b,
    double? c,
    double? d,
    double? e,
    double? f,
  }) => Transform2D(
    a ?? this.a,
    b ?? this.b,
    c ?? this.c,
    d ?? this.d,
    e ?? this.e,
    f ?? this.f,
  );

  List<double> toList() => [a, b, c, d, e, f];

  @override
  bool operator ==(Object other) =>
      other is Transform2D &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e &&
      other.f == f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);

  @override
  String toString() => 'Transform2D($a, $b, $c, $d, $e, $f)';
}

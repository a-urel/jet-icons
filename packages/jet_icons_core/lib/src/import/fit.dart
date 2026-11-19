import '../model/document.dart';
import '../model/transform.dart';

/// Centers a [width] x [height] item on the canvas, scaled so its longer edge
/// is `canvasSize * fraction`.
Transform2D fitToCanvas(double width, double height, {double fraction = 0.6}) {
  final longest = width > height ? width : height;
  final s = canvasSize * fraction / longest;
  return Transform2D(
    s,
    0,
    0,
    s,
    canvasSize / 2 - width / 2 * s,
    canvasSize / 2 - height / 2 * s,
  );
}

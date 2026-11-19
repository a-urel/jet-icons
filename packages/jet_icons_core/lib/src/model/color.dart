import 'package:meta/meta.dart';

/// An ARGB color stored as a 32-bit integer (`0xAARRGGBB`).
@immutable
class JColor {
  const JColor(this.argb);

  final int argb;

  /// Formats as `#AARRGGBB` (uppercase).
  String toHex() =>
      '#${(argb & 0xFFFFFFFF).toRadixString(16).toUpperCase().padLeft(8, '0')}';

  /// Parses `#RGB`, `#RRGGBB` or `#AARRGGBB`. Throws [FormatException].
  static JColor parse(String hex) {
    if (!hex.startsWith('#')) {
      throw FormatException('Color must start with "#"', hex);
    }
    final digits = hex.substring(1);
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(digits)) {
      throw FormatException('Invalid color digits', hex);
    }
    switch (digits.length) {
      case 3:
        final r = digits[0], g = digits[1], b = digits[2];
        return JColor(int.parse('FF$r$r$g$g$b$b', radix: 16));
      case 6:
        return JColor(int.parse('FF$digits', radix: 16));
      case 8:
        return JColor(int.parse(digits, radix: 16));
      default:
        throw FormatException('Color must have 3, 6 or 8 hex digits', hex);
    }
  }

  JColor copyWith({int? argb}) => JColor(argb ?? this.argb);

  @override
  bool operator ==(Object other) => other is JColor && other.argb == argb;

  @override
  int get hashCode => argb.hashCode;

  @override
  String toString() => 'JColor(${toHex()})';
}

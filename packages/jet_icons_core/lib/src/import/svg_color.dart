import '../model/color.dart';

const _named = <String, int>{
  'black': 0x000000,
  'silver': 0xC0C0C0,
  'gray': 0x808080,
  'grey': 0x808080,
  'white': 0xFFFFFF,
  'maroon': 0x800000,
  'red': 0xFF0000,
  'purple': 0x800080,
  'fuchsia': 0xFF00FF,
  'green': 0x008000,
  'lime': 0x00FF00,
  'olive': 0x808000,
  'yellow': 0xFFFF00,
  'navy': 0x000080,
  'blue': 0x0000FF,
  'teal': 0x008080,
  'aqua': 0x00FFFF,
  'orange': 0xFFA500,
};

/// Parses `#rgb`, `#rrggbb`, `rgb(r,g,b)`, the CSS2 named colors,
/// `transparent` and `currentColor` (black). Returns `null` for anything else.
JColor? parseSvgColor(String raw) {
  final s = raw.trim();
  final lower = s.toLowerCase();
  if (lower == 'currentcolor') return const JColor(0xFF000000);
  if (lower == 'transparent') return const JColor(0x00000000);
  final named = _named[lower];
  if (named != null) return JColor(0xFF000000 | named);
  if (s.startsWith('#')) {
    if (s.length != 4 && s.length != 7) return null;
    try {
      return JColor.parse(s);
    } on FormatException {
      return null;
    }
  }
  final m = RegExp(
    r'^rgb\(\s*([\d.]+%?)\s*,\s*([\d.]+%?)\s*,\s*([\d.]+%?)\s*\)$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m == null) return null;
  var argb = 0xFF000000;
  for (var i = 1; i <= 3; i++) {
    final part = m.group(i)!;
    final pct = part.endsWith('%');
    final v = double.tryParse(pct ? part.substring(0, part.length - 1) : part);
    if (v == null) return null;
    final channel = (pct ? v * 255 / 100 : v).round().clamp(0, 255);
    argb |= channel << (8 * (3 - i));
  }
  return JColor(argb);
}

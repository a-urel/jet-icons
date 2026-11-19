import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../model/transform.dart';

final _numberRe = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

/// Parses a number optionally followed by a unit suffix (`px` and others are
/// ignored). Returns `null` if absent, unparsable or a percentage.
double? parseLength(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  final m = RegExp('^(${_numberRe.pattern})([a-zA-Z]*)\$').firstMatch(s);
  if (m == null) return null;
  return double.tryParse(m.group(1)!);
}

/// Parses a whitespace/comma separated list of numbers, `null` if any junk.
List<double>? parseNumberList(String raw) {
  final out = <double>[];
  var end = 0;
  for (final m in _numberRe.allMatches(raw)) {
    if (raw
        .substring(end, m.start)
        .replaceAll(RegExp(r'[\s,]'), '')
        .isNotEmpty) {
      return null;
    }
    out.add(double.parse(m.group(0)!));
    end = m.end;
  }
  if (raw.substring(end).replaceAll(RegExp(r'[\s,]'), '').isNotEmpty) {
    return null;
  }
  return out;
}

/// Opacity as a number or percentage; `null` if absent or invalid.
double? parseOpacity(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.endsWith('%')) {
    final v = double.tryParse(s.substring(0, s.length - 1));
    return v == null ? null : v / 100;
  }
  return double.tryParse(s);
}

/// A gradient coordinate: a number, or a percentage of [percentBase].
double gradientCoord(String? raw, double def, double percentBase) {
  if (raw == null) return def * percentBase;
  final s = raw.trim();
  if (s.endsWith('%')) {
    final v = double.tryParse(s.substring(0, s.length - 1));
    return v == null ? def * percentBase : v / 100 * percentBase;
  }
  return parseLength(s) ?? def * percentBase;
}

/// Formats a number for path data: no `.0`, no float noise, no `-0`.
String fmt(double v) {
  final r = double.parse(v.toStringAsFixed(6));
  if (r == r.truncateToDouble() && r.abs() < 1e15) {
    return r.toInt().toString();
  }
  return r.toString();
}

class ShapePath {
  const ShapePath(this.d, this.bounds);

  final String d;

  /// `[x, y, width, height]` for shapes that support `objectBoundingBox`
  /// gradients (rect, circle, ellipse); `null` otherwise.
  final List<double>? bounds;
}

/// Converts a basic shape (or `path`) to path data. Returns `null` when the
/// element renders nothing (missing/zero size, no data).
ShapePath? shapeToPath(XmlElement e, String tag) {
  double n(String name) => parseLength(e.getAttribute(name)) ?? 0;
  switch (tag) {
    case 'path':
      final d = e.getAttribute('d')?.trim();
      return (d == null || d.isEmpty) ? null : ShapePath(d, null);
    case 'rect':
      final x = n('x'), y = n('y'), w = n('width'), h = n('height');
      if (w <= 0 || h <= 0) return null;
      var rx = parseLength(e.getAttribute('rx'));
      var ry = parseLength(e.getAttribute('ry'));
      rx ??= ry;
      ry ??= rx;
      rx = math.min(math.max(rx ?? 0, 0), w / 2);
      ry = math.min(math.max(ry ?? 0, 0), h / 2);
      final bounds = [x, y, w, h];
      if (rx == 0 || ry == 0) {
        return ShapePath(
          'M${fmt(x)} ${fmt(y)}H${fmt(x + w)}V${fmt(y + h)}H${fmt(x)}Z',
          bounds,
        );
      }
      final a = 'A${fmt(rx)} ${fmt(ry)} 0 0 1 ';
      return ShapePath(
        'M${fmt(x + rx)} ${fmt(y)}H${fmt(x + w - rx)}'
        '$a${fmt(x + w)} ${fmt(y + ry)}V${fmt(y + h - ry)}'
        '$a${fmt(x + w - rx)} ${fmt(y + h)}H${fmt(x + rx)}'
        '$a${fmt(x)} ${fmt(y + h - ry)}V${fmt(y + ry)}'
        '$a${fmt(x + rx)} ${fmt(y)}Z',
        bounds,
      );
    case 'circle':
      final r = n('r');
      if (r <= 0) return null;
      return _ellipse(n('cx'), n('cy'), r, r);
    case 'ellipse':
      final rx = n('rx'), ry = n('ry');
      if (rx <= 0 || ry <= 0) return null;
      return _ellipse(n('cx'), n('cy'), rx, ry);
    case 'line':
      return ShapePath(
        'M${fmt(n('x1'))} ${fmt(n('y1'))}L${fmt(n('x2'))} ${fmt(n('y2'))}',
        null,
      );
    case 'polyline' || 'polygon':
      final pts = parseNumberList(e.getAttribute('points') ?? '');
      if (pts == null || pts.length < 4) return null;
      final b = StringBuffer();
      for (var i = 0; i + 1 < pts.length; i += 2) {
        b.write('${i == 0 ? 'M' : 'L'}${fmt(pts[i])} ${fmt(pts[i + 1])}');
      }
      if (tag == 'polygon') b.write('Z');
      return ShapePath(b.toString(), null);
  }
  return null;
}

ShapePath _ellipse(double cx, double cy, double rx, double ry) {
  final arc = 'A${fmt(rx)} ${fmt(ry)} 0 1 1 ';
  return ShapePath(
    'M${fmt(cx + rx)} ${fmt(cy)}$arc${fmt(cx - rx)} ${fmt(cy)}'
    '$arc${fmt(cx + rx)} ${fmt(cy)}Z',
    [cx - rx, cy - ry, rx * 2, ry * 2],
  );
}

class TransformResult {
  const TransformResult(this.transform, [this.unsupportedTag]);

  final Transform2D transform;

  /// Set when the attribute used a function the model cannot express.
  final String? unsupportedTag;
}

/// Parses an SVG `transform` list (`matrix`, `translate`, `scale`, `rotate`),
/// composed left to right.
TransformResult parseTransform(String raw) {
  final fn = RegExp(r'\s*([A-Za-z]+)\s*\(([^)]*)\)\s*,?');
  var t = Transform2D.identity;
  var end = 0;
  for (final m in fn.allMatches(raw)) {
    if (m.start != end) {
      return const TransformResult(Transform2D.identity, 'transform');
    }
    end = m.end;
    final name = m.group(1)!;
    final a = parseNumberList(m.group(2)!);
    if (a == null) {
      return const TransformResult(Transform2D.identity, 'transform');
    }
    final Transform2D next;
    switch ((name, a.length)) {
      case ('matrix', 6):
        next = Transform2D(a[0], a[1], a[2], a[3], a[4], a[5]);
      case ('translate', 1):
        next = Transform2D.translate(a[0], 0);
      case ('translate', 2):
        next = Transform2D.translate(a[0], a[1]);
      case ('scale', 1):
        next = Transform2D.scale(a[0]);
      case ('scale', 2):
        next = Transform2D.scale(a[0], a[1]);
      case ('rotate', 1):
        next = _rotate(a[0]);
      case ('rotate', 3):
        next = Transform2D.translate(
          a[1],
          a[2],
        ).multiply(_rotate(a[0])).multiply(Transform2D.translate(-a[1], -a[2]));
      case ('matrix' || 'translate' || 'scale' || 'rotate', _):
        return const TransformResult(Transform2D.identity, 'transform');
      default:
        return TransformResult(Transform2D.identity, name);
    }
    t = t.multiply(next);
  }
  if (raw.substring(end).replaceAll(RegExp(r'[\s,]'), '').isNotEmpty) {
    return const TransformResult(Transform2D.identity, 'transform');
  }
  return TransformResult(_clean(t));
}

Transform2D _rotate(double degrees) =>
    Transform2D.rotate(degrees * math.pi / 180);

/// Removes float noise such as `cos(90deg) = 6e-17`.
Transform2D _clean(Transform2D t) {
  double c(double v) {
    final r = double.parse(v.toStringAsFixed(12));
    return r == 0 ? 0 : r;
  }

  return Transform2D(c(t.a), c(t.b), c(t.c), c(t.d), c(t.e), c(t.f));
}

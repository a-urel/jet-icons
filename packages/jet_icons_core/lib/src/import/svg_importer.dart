import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../model/color.dart';
import '../model/document.dart';
import '../model/element.dart';
import '../model/fill.dart';
import '../model/transform.dart';
import 'fit.dart';
import 'import_result.dart';
import 'svg_color.dart';
import 'svg_shapes.dart';

const _gradientTags = {'linearGradient', 'radialGradient'};

/// Elements that are understood. Everything else makes the file unsupported.
const _supportedTags = {
  'svg',
  'g',
  'path',
  'rect',
  'circle',
  'ellipse',
  'line',
  'polyline',
  'polygon',
  'defs',
  'stop',
  'title',
  'desc',
  'metadata',
  ..._gradientTags,
};

/// Attributes / style properties that are understood by no part of the model.
const _unsupportedProps = {
  'class',
  'filter',
  'mask',
  'clip-path',
  'stroke-dasharray',
  'marker-start',
  'marker-mid',
  'marker-end',
};

/// Imports [svg]. A fully supported file becomes an editable [GroupElement];
/// anything else is kept whole as a [RawSvgElement] with an
/// [UnsupportedSvgFeatures] warning. Throws [FormatException] for malformed
/// XML or a non-`svg` root.
ImportResult importSvg(String svg, {required String id, String name = 'SVG'}) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(svg);
  } on XmlException catch (e) {
    throw FormatException('Malformed SVG: ${e.message}', svg);
  }
  final root = doc.rootElement;
  if (root.name.local != 'svg') {
    throw FormatException('Root element is <${root.name.local}>, not <svg>');
  }
  final vb = _viewBox(root);
  final importer = _Importer(root, id, vb);
  final children = <IconElement>[];
  importer.visitChildren(root, const _Style(), children, render: true);
  final tags = importer.unsupported.toList();
  if (tags.isNotEmpty) {
    return ImportResult(
      RawSvgElement(
        id: id,
        name: name,
        transform: fitToCanvas(vb.width, vb.height),
        svg: svg,
        vbX: vb.x,
        vbY: vb.y,
        vbWidth: vb.width,
        vbHeight: vb.height,
      ),
      [UnsupportedSvgFeatures(tags)],
    );
  }
  return ImportResult(
    GroupElement(
      id: id,
      name: name,
      // `multiply` applies the right operand first: viewBox origin is moved
      // to 0,0, then the content is fitted on the canvas.
      transform: fitToCanvas(
        vb.width,
        vb.height,
      ).multiply(Transform2D.translate(-vb.x, -vb.y)),
      opacity: importer.opacityOf(root),
      children: children,
    ),
    const [],
  );
}

class _ViewBox {
  const _ViewBox(this.x, this.y, this.width, this.height);
  final double x, y, width, height;
}

_ViewBox _viewBox(XmlElement root) {
  final raw = root.getAttribute('viewBox');
  if (raw != null) {
    final n = parseNumberList(raw);
    if (n != null && n.length == 4 && n[2] > 0 && n[3] > 0) {
      return _ViewBox(n[0], n[1], n[2], n[3]);
    }
  }
  final w = parseLength(root.getAttribute('width'));
  final h = parseLength(root.getAttribute('height'));
  if (w != null && h != null && w > 0 && h > 0) return _ViewBox(0, 0, w, h);
  return _ViewBox(0, 0, canvasSize.toDouble(), canvasSize.toDouble());
}

/// Inherited paint state (raw property strings, resolved per shape).
class _Style {
  const _Style({
    this.fill = '#000000',
    this.stroke = 'none',
    this.strokeWidth = 1,
    this.fillOpacity = 1,
    this.strokeOpacity = 1,
  });

  final String fill;
  final String stroke;
  final double strokeWidth;
  final double fillOpacity;
  final double strokeOpacity;
}

class _Bounds {
  const _Bounds(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
}

class _Importer {
  _Importer(XmlElement root, this.rootId, this.vb) {
    for (final e in root.descendantElements) {
      final elId = e.getAttribute('id');
      if (elId != null && _gradientTags.contains(e.name.local)) {
        gradients.putIfAbsent(elId, () => e);
      }
    }
  }

  final String rootId;
  final _ViewBox vb;
  final gradients = <String, XmlElement>{};

  /// Insertion-ordered, deduplicated.
  final unsupported = <String>{};
  var _counter = 0;

  String _nextId() => '$rootId-${++_counter}';

  /// Property lookup: `style` declaration wins over the presentation attribute.
  String? prop(XmlElement e, String name) {
    final fromStyle = _styleOf(e)[name];
    if (fromStyle != null) return fromStyle;
    return e.getAttribute(name);
  }

  Map<String, String> _styleOf(XmlElement e) {
    final raw = e.getAttribute('style');
    if (raw == null) return const {};
    final out = <String, String>{};
    for (final decl in raw.split(';')) {
      final i = decl.indexOf(':');
      if (i < 0) continue;
      final key = decl.substring(0, i).trim().toLowerCase();
      var value = decl.substring(i + 1).trim();
      value = value.replaceAll(RegExp(r'\s*!important$'), '');
      if (key.isNotEmpty) out[key] = value;
    }
    return out;
  }

  double opacityOf(XmlElement e) =>
      (parseOpacity(prop(e, 'opacity')) ?? 1).clamp(0.0, 1.0);

  void _checkProps(XmlElement e) {
    for (final a in e.attributes) {
      if (_unsupportedProps.contains(a.name.qualified)) {
        unsupported.add(a.name.qualified);
      }
    }
    for (final key in _styleOf(e).keys) {
      if (_unsupportedProps.contains(key)) unsupported.add(key);
    }
    if (prop(e, 'fill-rule')?.trim() == 'evenodd') unsupported.add('fill-rule');
  }

  void visitChildren(
    XmlElement parent,
    _Style inherited,
    List<IconElement> out, {
    required bool render,
  }) {
    _checkProps(parent);
    final style = render ? _inherit(parent, inherited) : inherited;
    for (final child in parent.childElements) {
      _visit(child, style, out, render: render);
    }
  }

  _Style _inherit(XmlElement e, _Style s) {
    String? pick(String name) {
      final v = prop(e, name)?.trim();
      return (v == null || v.isEmpty || v == 'inherit') ? null : v;
    }

    return _Style(
      fill: pick('fill') ?? s.fill,
      stroke: pick('stroke') ?? s.stroke,
      strokeWidth: parseLength(pick('stroke-width')) ?? s.strokeWidth,
      fillOpacity:
          parseOpacity(pick('fill-opacity'))?.clamp(0.0, 1.0) ?? s.fillOpacity,
      strokeOpacity:
          parseOpacity(pick('stroke-opacity'))?.clamp(0.0, 1.0) ??
          s.strokeOpacity,
    );
  }

  void _visit(
    XmlElement e,
    _Style inherited,
    List<IconElement> out, {
    required bool render,
  }) {
    final prefix = e.name.prefix;
    if (prefix != null && prefix != 'svg') return; // foreign namespace
    final tag = e.name.local;
    if (!_supportedTags.contains(tag)) {
      unsupported.add(tag);
      return;
    }
    switch (tag) {
      case 'title' || 'desc' || 'metadata' || 'stop':
        return;
      case 'svg':
        unsupported.add('svg'); // nested svg establishes a new viewport
        return;
      case 'defs':
        visitChildren(e, inherited, out, render: false);
      case 'linearGradient' || 'radialGradient':
        _checkGradient(e);
        visitChildren(e, inherited, out, render: false);
      case 'g':
        if (!render) {
          visitChildren(e, inherited, out, render: false);
          return;
        }
        _checkProps(e);
        final id = _nextId();
        final children = <IconElement>[];
        visitChildren(e, inherited, children, render: true);
        out.add(
          GroupElement(
            id: id,
            name: e.getAttribute('id') ?? tag,
            transform: _transformOf(e),
            opacity: opacityOf(e),
            hidden: _hidden(e),
            children: children,
          ),
        );
      default:
        _checkProps(e);
        if (!render) return;
        _shape(e, tag, _inherit(e, inherited), out);
    }
  }

  bool _hidden(XmlElement e) => prop(e, 'display')?.trim() == 'none';

  void _checkGradient(XmlElement g) {
    if (g.getAttribute('gradientTransform') != null) {
      unsupported.add('gradientTransform');
    }
    for (final a in g.attributes) {
      if (a.name.local == 'href') unsupported.add(a.name.qualified);
    }
    final spread = g.getAttribute('spreadMethod');
    if (spread != null && spread.trim() != 'pad') {
      unsupported.add('spreadMethod');
    }
  }

  Transform2D _transformOf(XmlElement e) {
    final raw = e.getAttribute('transform');
    if (raw == null) return Transform2D.identity;
    final result = parseTransform(raw);
    if (result.unsupportedTag != null) unsupported.add(result.unsupportedTag!);
    return result.transform;
  }

  void _shape(XmlElement e, String tag, _Style s, List<IconElement> out) {
    final shape = shapeToPath(e, tag);
    if (shape == null) return;
    final id = _nextId();
    final bounds = shape.bounds == null
        ? null
        : _Bounds(
            shape.bounds![0],
            shape.bounds![1],
            shape.bounds![2],
            shape.bounds![3],
          );
    final fill = _paintFill(s.fill, s.fillOpacity, bounds);
    final stroke = _stroke(s);
    out.add(
      PathElement(
        id: id,
        name: e.getAttribute('id') ?? tag,
        transform: _transformOf(e),
        opacity: opacityOf(e),
        hidden: _hidden(e),
        d: shape.d,
        fill: fill,
        stroke: stroke,
      ),
    );
  }

  Stroke? _stroke(_Style s) {
    final v = s.stroke.trim();
    if (v == 'none' || s.strokeWidth <= 0) return null;
    if (v.startsWith('url(')) {
      unsupported.add(v); // Stroke only models a solid color
      return null;
    }
    final color = parseSvgColor(v);
    if (color == null) {
      unsupported.add(v);
      return null;
    }
    return Stroke(_withOpacity(color, s.strokeOpacity), s.strokeWidth);
  }

  Fill? _paintFill(String raw, double opacity, _Bounds? bounds) {
    final v = raw.trim();
    if (v == 'none') return null;
    if (v.startsWith('url(')) return _gradientFill(v, opacity, bounds);
    final color = parseSvgColor(v);
    if (color == null) {
      unsupported.add(v);
      return null;
    }
    return SolidFill(_withOpacity(color, opacity));
  }

  Fill? _gradientFill(String paint, double opacity, _Bounds? bounds) {
    final ref = RegExp(
      r'^url\(\s*['
      "'"
      r'"]?#([^'
      "'"
      r'")\s]+)['
      "'"
      r'"]?\s*\)',
    ).firstMatch(paint);
    final g = ref == null ? null : gradients[ref.group(1)];
    if (g == null) {
      unsupported.add(paint);
      return null;
    }
    final userSpace =
        g.getAttribute('gradientUnits')?.trim() == 'userSpaceOnUse';
    if (!userSpace && bounds == null) {
      unsupported.add('gradientUnits=objectBoundingBox');
      return null;
    }
    final stops = _stops(g, opacity);
    if (stops.isEmpty) return null;
    if (stops.length == 1) return SolidFill(stops.single.color);

    // Maps a gradient coordinate to the element's local space.
    double mapX(String? raw, double def) {
      if (userSpace) return gradientCoord(raw, def, vb.width);
      return bounds!.x + gradientCoord(raw, def, 1) * bounds.w;
    }

    double mapY(String? raw, double def) {
      if (userSpace) return gradientCoord(raw, def, vb.height);
      return bounds!.y + gradientCoord(raw, def, 1) * bounds.h;
    }

    if (g.name.local == 'linearGradient') {
      return LinearGradientFill(
        stops,
        mapX(g.getAttribute('x1'), 0),
        mapY(g.getAttribute('y1'), 0),
        mapX(g.getAttribute('x2'), 1),
        mapY(g.getAttribute('y2'), 0),
      );
    }
    final double r;
    if (userSpace) {
      r = gradientCoord(
        g.getAttribute('r'),
        0.5,
        math.sqrt((vb.width * vb.width + vb.height * vb.height) / 2),
      );
    } else {
      // Non-square boxes give an elliptical gradient; approximate with the
      // mean edge length (exact for circles).
      r =
          gradientCoord(g.getAttribute('r'), 0.5, 1) *
          (bounds!.w + bounds.h) /
          2;
    }
    return RadialGradientFill(
      stops,
      mapX(g.getAttribute('cx'), 0.5),
      mapY(g.getAttribute('cy'), 0.5),
      r,
    );
  }

  List<GradientStop> _stops(XmlElement g, double opacity) {
    final stops = <GradientStop>[];
    for (final s in g.childElements.where((c) => c.name.local == 'stop')) {
      final offsetRaw = s.getAttribute('offset')?.trim() ?? '0';
      final offset =
          (offsetRaw.endsWith('%')
                  ? (double.tryParse(
                              offsetRaw.substring(0, offsetRaw.length - 1),
                            ) ??
                            0) /
                        100
                  : double.tryParse(offsetRaw) ?? 0)
              .clamp(0.0, 1.0);
      final colorRaw = prop(s, 'stop-color')?.trim() ?? '#000000';
      var color = parseSvgColor(colorRaw);
      if (color == null) {
        unsupported.add(colorRaw);
        color = const JColor(0xFF000000);
      }
      final stopOpacity = (parseOpacity(prop(s, 'stop-opacity')) ?? 1).clamp(
        0.0,
        1.0,
      );
      stops.add(
        GradientStop(offset, _withOpacity(color, stopOpacity * opacity)),
      );
    }
    return stops;
  }
}

JColor _withOpacity(JColor c, double opacity) {
  if (opacity >= 1) return c;
  final alpha = (((c.argb >> 24) & 0xFF) * opacity).round().clamp(0, 255);
  return JColor((alpha << 24) | (c.argb & 0x00FFFFFF));
}

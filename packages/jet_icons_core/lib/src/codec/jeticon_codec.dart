import 'dart:convert';
import 'dart:typed_data';

import '../model/color.dart';
import '../model/document.dart';
import '../model/element.dart';
import '../model/fill.dart';
import '../model/layer.dart';
import '../model/override.dart';
import '../model/transform.dart';

/// Thrown when a `.jeticon` source is malformed or from a newer format.
class JeticonFormatException implements Exception {
  JeticonFormatException(this.message);

  final String message;

  @override
  String toString() => 'JeticonFormatException: $message';
}

const _knownTopLevel = {
  'formatVersion',
  'canvasSize',
  'background',
  'foreground',
  'monochrome',
  'shapes',
  'overrides',
};

const _shapePlatforms = [
  IconPlatform.windows,
  IconPlatform.linux,
  IconPlatform.web,
];

// ---------------------------------------------------------------- encode

/// Serializes [doc] as pretty-printed (2 spaces) JSON with a fixed key order.
String encodeJeticon(IconDocument doc) {
  final map = <String, Object?>{
    'formatVersion': currentFormatVersion,
    'canvasSize': canvasSize,
    'background': _encodeLayer(doc.background),
    'foreground': _encodeLayer(doc.foreground),
    'monochrome': doc.monochrome == null ? null : _encodeLayer(doc.monochrome!),
    'shapes': {
      for (final p in _shapePlatforms)
        if (doc.shapes.containsKey(p)) p.name: doc.shapes[p]!.name,
    },
    'overrides': [for (final o in doc.overrides) _encodeOverride(o)],
    for (final e in doc.extra.entries)
      if (!_knownTopLevel.contains(e.key)) e.key: e.value,
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

Map<String, Object?> _encodeLayer(Layer l) => {
  'fill': l.fill == null ? null : _encodeFill(l.fill!),
  'scale': l.scale,
  'elements': [for (final e in l.elements) _encodeElement(e)],
};

Map<String, Object?> _encodeFill(Fill f) => switch (f) {
  SolidFill() => {'type': 'solid', 'color': f.color.toHex()},
  LinearGradientFill() => {
    'type': 'linear',
    'x1': f.x1,
    'y1': f.y1,
    'x2': f.x2,
    'y2': f.y2,
    'stops': _encodeStops(f.stops),
  },
  RadialGradientFill() => {
    'type': 'radial',
    'cx': f.cx,
    'cy': f.cy,
    'r': f.r,
    'stops': _encodeStops(f.stops),
  },
};

List<Object?> _encodeStops(List<GradientStop> stops) => [
  for (final s in stops) {'offset': s.offset, 'color': s.color.toHex()},
];

Map<String, Object?> _encodeElement(IconElement e) {
  final head = <String, Object?>{'id': e.id, 'name': e.name};
  final tail = <String, Object?>{
    'transform': e.transform.toList(),
    'opacity': e.opacity,
    'hidden': e.hidden,
  };
  return switch (e) {
    PathElement() => {
      'type': 'path',
      ...head,
      'd': e.d,
      'fill': e.fill == null ? null : _encodeFill(e.fill!),
      'stroke': e.stroke == null
          ? null
          : {'color': e.stroke!.color.toHex(), 'width': e.stroke!.width},
      ...tail,
    },
    GroupElement() => {
      'type': 'group',
      ...head,
      'children': [for (final c in e.children) _encodeElement(c)],
      ...tail,
    },
    RasterElement() => {
      'type': 'raster',
      ...head,
      'png': base64Encode(e.png),
      'width': e.width,
      'height': e.height,
      ...tail,
    },
    RawSvgElement() => {
      'type': 'rawSvg',
      ...head,
      'svg': e.svg,
      'viewBox': [e.vbX, e.vbY, e.vbWidth, e.vbHeight],
      ...tail,
    },
  };
}

Map<String, Object?> _encodeOverride(PlatformOverride o) => {
  'platform': o.platform.name,
  'variant': o.variant?.name,
  'sizeRange': o.sizeRange == null
      ? null
      : {'minPx': o.sizeRange!.minPx, 'maxPx': o.sizeRange!.maxPx},
  'layerPatches': [
    for (final p in o.layerPatches)
      {
        'layer': p.layer.name,
        'scale': p.scale,
        'fill': p.fill == null ? null : _encodeFill(p.fill!),
        'hidden': p.hidden,
      },
  ],
  'elementPatches': [
    for (final p in o.elementPatches)
      {
        'elementId': p.elementId,
        'hidden': p.hidden,
        'opacity': p.opacity,
        'fill': p.fill == null ? null : _encodeFill(p.fill!),
        'transform': p.transform?.toList(),
      },
  ],
  'detached': {
    for (final e in o.detached.entries) e.key.name: _encodeLayer(e.value),
  },
};

// ---------------------------------------------------------------- decode

/// Parses a `.jeticon` source. Throws [JeticonFormatException] on invalid
/// JSON, missing/ill-typed fields or a newer `formatVersion`.
IconDocument decodeJeticon(String source) {
  final Object? root;
  try {
    root = jsonDecode(source);
  } on FormatException catch (e) {
    throw JeticonFormatException('Invalid JSON: ${e.message}');
  }
  try {
    final m = _obj(root, 'document');
    final version = _int(m['formatVersion'], 'formatVersion');
    if (version > currentFormatVersion) {
      throw JeticonFormatException(
        'Unsupported formatVersion $version: this version of jet-icons '
        'supports up to $currentFormatVersion. Update the app to open this '
        'file.',
      );
    }
    if (m.containsKey('canvasSize')) _int(m['canvasSize'], 'canvasSize');
    final mono = m['monochrome'];
    final shapesJson = m['shapes'] == null
        ? const {}
        : _obj(m['shapes'], 'shapes');
    return IconDocument(
      _decodeLayer(m['background'], 'background'),
      _decodeLayer(m['foreground'], 'foreground'),
      mono == null ? null : _decodeLayer(mono, 'monochrome'),
      {
        for (final e in shapesJson.entries)
          _enum(IconPlatform.values, e.key, 'shapes key'): _enum(
            IconShape.values,
            e.value,
            'shapes.${e.key}',
          ),
      },
      [
        for (final (i, o) in _list(
          m['overrides'] ?? const [],
          'overrides',
        ).indexed)
          _decodeOverride(o, 'overrides[$i]'),
      ],
      {
        for (final e in m.entries)
          if (!_knownTopLevel.contains(e.key)) e.key: e.value,
      },
    );
  } on FormatException catch (e) {
    throw JeticonFormatException('Invalid value: ${e.message}');
  }
}

Map<String, Object?> _obj(Object? v, String path) {
  if (v is Map<String, Object?>) return v;
  throw JeticonFormatException('"$path" must be an object');
}

List<Object?> _list(Object? v, String path) {
  if (v is List<Object?>) return v;
  throw JeticonFormatException('"$path" must be a list');
}

Object _required(Map<String, Object?> m, String key, String path) {
  final v = m[key];
  if (v == null) {
    throw JeticonFormatException('Missing required field "$path.$key"');
  }
  return v;
}

String _str(Object? v, String path) {
  if (v is String) return v;
  throw JeticonFormatException('"$path" must be a string');
}

int _int(Object? v, String path) {
  if (v is int) return v;
  if (v is double && v == v.truncateToDouble()) return v.toInt();
  throw JeticonFormatException('"$path" must be an integer');
}

double _num(Object? v, String path) {
  if (v is num) return v.toDouble();
  throw JeticonFormatException('"$path" must be a number');
}

bool _bool(Object? v, String path) {
  if (v is bool) return v;
  throw JeticonFormatException('"$path" must be a boolean');
}

T _enum<T extends Enum>(List<T> values, Object? v, String path) {
  final s = _str(v, path);
  for (final e in values) {
    if (e.name == s) return e;
  }
  throw JeticonFormatException('Unknown value "$s" for "$path"');
}

JColor _color(Object? v, String path) => JColor.parse(_str(v, path));

Layer _decodeLayer(Object? v, String path) {
  final m = _obj(v, path);
  final fill = m['fill'];
  return Layer(fill == null ? null : _decodeFill(fill, '$path.fill'), [
    for (final (i, e) in _list(
      m['elements'] ?? const [],
      '$path.elements',
    ).indexed)
      _decodeElement(e, '$path.elements[$i]'),
  ], scale: m['scale'] == null ? 1.0 : _num(m['scale'], '$path.scale'));
}

Fill _decodeFill(Object? v, String path) {
  final m = _obj(v, path);
  List<GradientStop> stops() => [
    for (final (i, s) in _list(
      _required(m, 'stops', path),
      '$path.stops',
    ).indexed)
      GradientStop(
        _num(_obj(s, '$path.stops[$i]')['offset'], '$path.stops[$i].offset'),
        _color(_obj(s, '$path.stops[$i]')['color'], '$path.stops[$i].color'),
      ),
  ];
  double n(String k) => _num(_required(m, k, path), '$path.$k');
  return switch (_str(m['type'], '$path.type')) {
    'solid' => SolidFill(_color(_required(m, 'color', path), '$path.color')),
    'linear' => LinearGradientFill(stops(), n('x1'), n('y1'), n('x2'), n('y2')),
    'radial' => RadialGradientFill(stops(), n('cx'), n('cy'), n('r')),
    final t => throw JeticonFormatException(
      'Unknown fill type "$t" at "$path"',
    ),
  };
}

Transform2D _decodeTransform(Object? v, String path) {
  if (v == null) return Transform2D.identity;
  final l = _list(v, path);
  if (l.length != 6) {
    throw JeticonFormatException('"$path" must have 6 numbers');
  }
  final n = [for (final (i, x) in l.indexed) _num(x, '$path[$i]')];
  return Transform2D(n[0], n[1], n[2], n[3], n[4], n[5]);
}

IconElement _decodeElement(Object? v, String path) {
  final m = _obj(v, path);
  final id = _str(_required(m, 'id', path), '$path.id');
  final name = m['name'] == null ? '' : _str(m['name'], '$path.name');
  final transform = _decodeTransform(m['transform'], '$path.transform');
  final opacity = m['opacity'] == null
      ? 1.0
      : _num(m['opacity'], '$path.opacity');
  final hidden = m['hidden'] == null
      ? false
      : _bool(m['hidden'], '$path.hidden');
  switch (_str(m['type'], '$path.type')) {
    case 'path':
      final fill = m['fill'];
      final stroke = m['stroke'];
      return PathElement(
        id: id,
        name: name,
        transform: transform,
        opacity: opacity,
        hidden: hidden,
        d: _str(_required(m, 'd', path), '$path.d'),
        fill: fill == null ? null : _decodeFill(fill, '$path.fill'),
        stroke: stroke == null
            ? null
            : Stroke(
                _color(
                  _obj(stroke, '$path.stroke')['color'],
                  '$path.stroke.color',
                ),
                _num(
                  _obj(stroke, '$path.stroke')['width'],
                  '$path.stroke.width',
                ),
              ),
      );
    case 'group':
      return GroupElement(
        id: id,
        name: name,
        transform: transform,
        opacity: opacity,
        hidden: hidden,
        children: [
          for (final (i, c) in _list(
            m['children'] ?? const [],
            '$path.children',
          ).indexed)
            _decodeElement(c, '$path.children[$i]'),
        ],
      );
    case 'raster':
      final Uint8List png;
      try {
        png = base64Decode(_str(_required(m, 'png', path), '$path.png'));
      } on FormatException {
        throw JeticonFormatException('"$path.png" is not valid base64');
      }
      return RasterElement(
        id: id,
        name: name,
        transform: transform,
        opacity: opacity,
        hidden: hidden,
        png: png,
        width: _int(_required(m, 'width', path), '$path.width'),
        height: _int(_required(m, 'height', path), '$path.height'),
      );
    case 'rawSvg':
      final vb = _list(_required(m, 'viewBox', path), '$path.viewBox');
      if (vb.length != 4) {
        throw JeticonFormatException('"$path.viewBox" must have 4 numbers');
      }
      final n = [for (final (i, x) in vb.indexed) _num(x, '$path.viewBox[$i]')];
      return RawSvgElement(
        id: id,
        name: name,
        transform: transform,
        opacity: opacity,
        hidden: hidden,
        svg: _str(_required(m, 'svg', path), '$path.svg'),
        vbX: n[0],
        vbY: n[1],
        vbWidth: n[2],
        vbHeight: n[3],
      );
    case final t:
      throw JeticonFormatException('Unknown element type "$t" at "$path"');
  }
}

PlatformOverride _decodeOverride(Object? v, String path) {
  final m = _obj(v, path);
  final variant = m['variant'];
  final range = m['sizeRange'];
  final detached = m['detached'] == null
      ? const <String, Object?>{}
      : _obj(m['detached'], '$path.detached');
  return PlatformOverride(
    _enum(IconPlatform.values, m['platform'], '$path.platform'),
    variant: variant == null
        ? null
        : _enum(IconVariant.values, variant, '$path.variant'),
    sizeRange: range == null
        ? null
        : SizeRange(
            _int(
              _obj(range, '$path.sizeRange')['minPx'],
              '$path.sizeRange.minPx',
            ),
            _int(
              _obj(range, '$path.sizeRange')['maxPx'],
              '$path.sizeRange.maxPx',
            ),
          ),
    layerPatches: [
      for (final (i, p) in _list(
        m['layerPatches'] ?? const [],
        '$path.layerPatches',
      ).indexed)
        _decodeLayerPatch(p, '$path.layerPatches[$i]'),
    ],
    elementPatches: [
      for (final (i, p) in _list(
        m['elementPatches'] ?? const [],
        '$path.elementPatches',
      ).indexed)
        _decodeElementPatch(p, '$path.elementPatches[$i]'),
    ],
    detached: {
      for (final e in detached.entries)
        _enum(LayerKind.values, e.key, '$path.detached key'): _decodeLayer(
          e.value,
          '$path.detached.${e.key}',
        ),
    },
  );
}

LayerPatch _decodeLayerPatch(Object? v, String path) {
  final m = _obj(v, path);
  return LayerPatch(
    _enum(LayerKind.values, m['layer'], '$path.layer'),
    scale: m['scale'] == null ? null : _num(m['scale'], '$path.scale'),
    fill: m['fill'] == null ? null : _decodeFill(m['fill'], '$path.fill'),
    hidden: m['hidden'] == null ? null : _bool(m['hidden'], '$path.hidden'),
  );
}

ElementPatch _decodeElementPatch(Object? v, String path) {
  final m = _obj(v, path);
  return ElementPatch(
    _str(_required(m, 'elementId', path), '$path.elementId'),
    hidden: m['hidden'] == null ? null : _bool(m['hidden'], '$path.hidden'),
    opacity: m['opacity'] == null ? null : _num(m['opacity'], '$path.opacity'),
    fill: m['fill'] == null ? null : _decodeFill(m['fill'], '$path.fill'),
    transform: m['transform'] == null
        ? null
        : _decodeTransform(m['transform'], '$path.transform'),
  );
}

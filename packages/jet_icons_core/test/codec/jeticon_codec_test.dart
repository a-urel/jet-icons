import 'dart:typed_data';

import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:test/test.dart';

IconDocument sampleDocument() {
  final gradient = LinearGradientFill(
    const [
      GradientStop(0, JColor(0xFF4F7CFF)),
      GradientStop(1, JColor(0xFF8A5CFF)),
    ],
    0,
    0,
    1024,
    1024,
  );
  return IconDocument(
    const Layer(
      RadialGradientFill(
        [
          GradientStop(0, JColor(0xFFFFFFFF)),
          GradientStop(1, JColor(0xFF000000)),
        ],
        512,
        512,
        700,
      ),
      [],
    ),
    Layer(null, [
      PathElement(
        id: 'e1',
        name: 'Logo',
        d: 'M0 0L10 0Z',
        fill: gradient,
        stroke: const Stroke(JColor(0xFF112233), 4),
      ),
      GroupElement(
        id: 'g1',
        name: 'Group',
        transform: Transform2D.translate(10, 20),
        opacity: 0.5,
        hidden: true,
        children: [
          PathElement(
            id: 'e2',
            name: 'Inner',
            d: 'M1 1L2 2Z',
            fill: const SolidFill(JColor(0xFFFF0000)),
          ),
        ],
      ),
      RasterElement(
        id: 'r1',
        name: 'Raster',
        png: Uint8List.fromList([137, 80, 78, 71]),
        width: 64,
        height: 32,
      ),
      const RawSvgElement(
        id: 's1',
        name: 'Svg',
        svg: '<svg xmlns="http://www.w3.org/2000/svg"/>',
        vbX: 0,
        vbY: 0,
        vbWidth: 24,
        vbHeight: 24,
      ),
    ], scale: 0.8),
    const Layer(SolidFill(JColor(0xFFFFFFFF)), []),
    {IconPlatform.windows: IconShape.circle, IconPlatform.web: IconShape.none},
    [
      PlatformOverride(
        IconPlatform.android,
        variant: IconVariant.dark,
        sizeRange: const SizeRange(16, 48),
        layerPatches: const [
          LayerPatch(
            LayerKind.background,
            scale: 0.9,
            fill: SolidFill(JColor(0xFF000000)),
            hidden: false,
          ),
        ],
        elementPatches: [
          ElementPatch(
            'e1',
            hidden: true,
            opacity: 0.4,
            fill: const SolidFill(JColor(0xFF00FF00)),
            transform: Transform2D.scale(2),
          ),
        ],
        detached: const {
          LayerKind.foreground: Layer(null, [
            PathElement(id: 'd1', name: 'D', d: 'M0 0Z'),
          ]),
        },
      ),
    ],
    const {
      'futureThing': {'x': 1},
    },
  );
}

void main() {
  test('roundtrip preserves every element and fill type', () {
    final doc = sampleDocument();
    expect(decodeJeticon(encodeJeticon(doc)), doc);
  });

  test('output is stable and pretty-printed', () {
    final s = encodeJeticon(IconDocument.empty());
    expect(s, encodeJeticon(decodeJeticon(s)));
    expect(s.split('\n')[1], '  "formatVersion": 1,');
  });

  test('unknown top-level fields survive roundtrip', () {
    final src = encodeJeticon(IconDocument.empty())
        .replaceFirst('{', '{\n  "futureThing": {"x": 1},');
    expect(encodeJeticon(decodeJeticon(src)), contains('"futureThing"'));
  });

  test('newer formatVersion is rejected with clear message', () {
    final src = encodeJeticon(IconDocument.empty())
        .replaceFirst('"formatVersion": 1', '"formatVersion": 2');
    expect(
      () => decodeJeticon(src),
      throwsA(
        isA<JeticonFormatException>().having(
          (e) => e.message,
          'message',
          contains('2'),
        ),
      ),
    );
  });

  test('invalid json throws JeticonFormatException', () {
    expect(
      () => decodeJeticon('{not json'),
      throwsA(isA<JeticonFormatException>()),
    );
  });

  test('missing required field throws JeticonFormatException', () {
    expect(
      () => decodeJeticon('{"formatVersion": 1, "canvasSize": 1024}'),
      throwsA(isA<JeticonFormatException>()),
    );
  });

  test(
    'non-object root and wrong field types throw JeticonFormatException',
    () {
      expect(() => decodeJeticon('[]'), throwsA(isA<JeticonFormatException>()));
      final src = encodeJeticon(IconDocument.empty())
          .replaceFirst('"canvasSize": 1024', '"canvasSize": "x"');
      expect(() => decodeJeticon(src), throwsA(isA<JeticonFormatException>()));
    },
  );

  test('key order matches schema', () {
    final s = encodeJeticon(IconDocument.empty());
    final keys = RegExp(
      r'^  "(\w+)"',
      multiLine: true,
    ).allMatches(s).map((m) => m.group(1)).toList();
    expect(keys, [
      'formatVersion',
      'canvasSize',
      'background',
      'foreground',
      'monochrome',
      'shapes',
      'overrides',
    ]);
  });

  test('JColor parses short and long hex', () {
    expect(JColor.parse('#F00'), const JColor(0xFFFF0000));
    expect(JColor.parse('#FF8800'), const JColor(0xFFFF8800));
    expect(JColor.parse('#80112233').toHex(), '#80112233');
    expect(() => JColor.parse('red'), throwsFormatException);
  });

  test('Transform2D multiply, translate, scale, rotate', () {
    final t = Transform2D.translate(10, 0).multiply(Transform2D.scale(2));
    expect(t, const Transform2D(2, 0, 0, 2, 10, 0));
    expect(Transform2D.scale(3).d, 3);
    expect(Transform2D.identity.multiply(t), t);
    final r = Transform2D.rotate(3.141592653589793 / 2);
    expect(r.a, closeTo(0, 1e-12));
    expect(r.b, closeTo(1, 1e-12));
  });

  test('SizeRange is inclusive', () {
    const r = SizeRange(16, 32);
    expect(r.contains(16), isTrue);
    expect(r.contains(32), isTrue);
    expect(r.contains(33), isFalse);
  });

  test('copyWith can clear nullable fields', () {
    final doc = sampleDocument().copyWith(monochrome: null);
    expect(doc.monochrome, isNull);
    final layer = const Layer(SolidFill(JColor(0xFF000000)), []);
    expect(layer.copyWith(fill: null).fill, isNull);
    expect(layer.copyWith(scale: 2).fill, layer.fill);
  });

  test('value equality distinguishes differing documents', () {
    expect(sampleDocument(), sampleDocument());
    expect(sampleDocument().hashCode, sampleDocument().hashCode);
    expect(
      sampleDocument() == sampleDocument().copyWith(extra: const {}),
      isFalse,
    );
  });
}

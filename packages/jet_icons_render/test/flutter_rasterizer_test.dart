import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';

const _red = JColor(0xFFFF0000);
const _blue = JColor(0xFF0000FF);
const _fullSquare = 'M0 0H1024V1024H0Z';

/// Decoded RGBA pixels of a rendered icon.
class _Pixels {
  _Pixels(this.width, this.height, this.bytes);
  final int width, height;
  final ByteData bytes;

  /// (r, g, b, a) at [x], [y].
  List<int> at(int x, int y) {
    final i = (y * width + x) * 4;
    return [for (var k = 0; k < 4; k++) bytes.getUint8(i + k)];
  }
}

/// Renders through [FlutterIconRasterizer] (PNG), decodes it back and reads
/// the pixels. [straight] reads non-premultiplied RGBA.
Future<_Pixels> _render(
  ResolvedIcon icon,
  RenderRequest request, {
  bool straight = false,
}) async {
  final png = await const FlutterIconRasterizer().renderPng(icon, request);
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(
    format: straight
        ? ui.ImageByteFormat.rawStraightRgba
        : ui.ImageByteFormat.rawRgba,
  );
  final px = _Pixels(image.width, image.height, data!);
  image.dispose();
  return px;
}

Matcher _rgba(int r, int g, int b, int a, {int tolerance = 3}) =>
    predicate<List<int>>((p) {
      final want = [r, g, b, a];
      for (var i = 0; i < 4; i++) {
        if ((p[i] - want[i]).abs() > tolerance) return false;
      }
      return true;
    }, 'rgba($r, $g, $b, $a) ±$tolerance');

Matcher _alpha(int a, {int tolerance = 3}) => predicate<List<int>>(
  (p) => (p[3] - a).abs() <= tolerance,
  'alpha $a ±$tolerance',
);

PathElement _path(
  String id, {
  String d = _fullSquare,
  Fill? fill = const SolidFill(_blue),
  Stroke? stroke,
  Transform2D transform = Transform2D.identity,
  double opacity = 1,
  bool hidden = false,
}) => PathElement(
  id: id,
  name: id,
  d: d,
  fill: fill,
  stroke: stroke,
  transform: transform,
  opacity: opacity,
  hidden: hidden,
);

ResolvedIcon _icon({
  Layer background = const Layer(null, []),
  Layer foreground = const Layer(null, []),
  Layer? monochrome,
}) => ResolvedIcon(background, foreground, monochrome ?? foreground);

const _redBg = Layer(SolidFill(_red), []);

void main() {
  testWidgets('solid background fills full square', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(background: _redBg),
        const RenderRequest(64, Composition.full, IconShape.square),
      );
      expect(px.width, 64);
      expect(px.height, 64);
      expect(px.at(0, 0), _rgba(255, 0, 0, 255));
      expect(px.at(63, 63), _rgba(255, 0, 0, 255));
    });
  });

  testWidgets('roundedSquare leaves corners transparent', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(background: _redBg),
        const RenderRequest(64, Composition.full, IconShape.roundedSquare),
      );
      expect(px.at(0, 0), _alpha(0));
      expect(px.at(63, 63), _alpha(0));
      expect(px.at(32, 32), _rgba(255, 0, 0, 255));
    });
  });

  testWidgets('circle clips to the inscribed circle', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(background: _redBg),
        const RenderRequest(64, Composition.full, IconShape.circle),
      );
      expect(px.at(6, 6), _alpha(0));
      expect(px.at(32, 2), _rgba(255, 0, 0, 255));
    });
  });

  testWidgets('mac template insets body', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(background: _redBg),
        const RenderRequest(
          1024,
          Composition.full,
          IconShape.square,
          macTemplate: true,
        ),
      );
      expect(px.at(50, 512), _alpha(0));
      expect(px.at(512, 512), _rgba(255, 0, 0, 255));
      expect(px.at(110, 512), _rgba(255, 0, 0, 255));
      // The drop shadow sits just below the body.
      final shadow = px.at(512, 930);
      expect(shadow[3], greaterThan(0));
      expect(shadow[0], lessThan(10));
    });
  });

  testWidgets('mac template maps the whole design into the body', (t) async {
    await t.runAsync(() async {
      // A square on the design's left half (x 0..512).
      final px = await _render(
        _icon(
          background: _redBg,
          foreground: Layer(null, [_path('l', d: 'M0 0H512V1024H0Z')]),
        ),
        const RenderRequest(
          1024,
          Composition.full,
          IconShape.square,
          macTemplate: true,
        ),
      );
      // Design x=512 lands on output 100 + 512 * 824/1024 = 512.
      expect(px.at(480, 512), _rgba(0, 0, 255, 255));
      expect(px.at(540, 512), _rgba(255, 0, 0, 255));
    });
  });

  testWidgets('android contentScale shrinks foreground', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(foreground: Layer(null, [_path('fg')])),
        const RenderRequest(
          108,
          Composition.full,
          IconShape.square,
          contentScale: 72 / 108,
        ),
      );
      expect(px.at(5, 54), _alpha(0));
      expect(px.at(54, 54), _rgba(0, 0, 255, 255));
    });
  });

  testWidgets('layer fill covers the output despite content scale', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(background: const Layer(SolidFill(_red), [], scale: 0.5)),
        const RenderRequest(
          108,
          Composition.background,
          IconShape.square,
          contentScale: 72 / 108,
        ),
      );
      expect(px.at(1, 1), _rgba(255, 0, 0, 255));
    });
  });

  testWidgets('layer scale shrinks elements about the center', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(foreground: Layer(null, [_path('fg')], scale: 0.5)),
        const RenderRequest(100, Composition.foreground, IconShape.square),
      );
      expect(px.at(20, 50), _alpha(0));
      expect(px.at(30, 50), _rgba(0, 0, 255, 255));
    });
  });

  testWidgets('foreground and background compositions', (t) async {
    await t.runAsync(() async {
      final icon = _icon(
        background: _redBg,
        foreground: Layer(null, [_path('fg', d: 'M0 0H512V1024H0Z')]),
      );
      final fg = await _render(
        icon,
        const RenderRequest(64, Composition.foreground, IconShape.square),
      );
      expect(fg.at(10, 32), _rgba(0, 0, 255, 255));
      expect(fg.at(50, 32), _alpha(0));
      final bg = await _render(
        icon,
        const RenderRequest(64, Composition.background, IconShape.square),
      );
      expect(bg.at(10, 32), _rgba(255, 0, 0, 255));
      expect(bg.at(50, 32), _rgba(255, 0, 0, 255));
      final full = await _render(
        icon,
        const RenderRequest(64, Composition.full, IconShape.square),
      );
      expect(full.at(10, 32), _rgba(0, 0, 255, 255));
      expect(full.at(50, 32), _rgba(255, 0, 0, 255));
    });
  });

  testWidgets('monochrome renders white with alpha', (t) async {
    await t.runAsync(() async {
      final icon = _icon(
        background: _redBg,
        monochrome: Layer(null, [
          _path('solid', d: 'M0 0H512V512H0Z'),
          _path(
            'half',
            d: 'M512 512H1024V1024H512Z',
            fill: const SolidFill(JColor(0x800000FF)),
          ),
        ]),
      );
      final px = await _render(
        icon,
        const RenderRequest(64, Composition.monochrome, IconShape.square),
        straight: true,
      );
      expect(px.at(10, 10), _rgba(255, 255, 255, 255));
      expect(px.at(50, 50), _rgba(255, 255, 255, 128));
      expect(px.at(50, 10), _alpha(0));
    });
  });

  testWidgets('tinted is white monochrome over opaque black', (t) async {
    await t.runAsync(() async {
      final icon = _icon(
        background: _redBg,
        monochrome: Layer(null, [_path('m', d: 'M0 0H512V1024H0Z')]),
      );
      final px = await _render(
        icon,
        const RenderRequest(64, Composition.tinted, IconShape.square),
      );
      expect(px.at(10, 32), _rgba(255, 255, 255, 255));
      expect(px.at(50, 32), _rgba(0, 0, 0, 255));
    });
  });

  testWidgets('hidden element is not drawn', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(
          background: _redBg,
          foreground: Layer(null, [_path('fg', hidden: true)]),
        ),
        const RenderRequest(64, Composition.full, IconShape.square),
      );
      expect(px.at(32, 32), _rgba(255, 0, 0, 255));
    });
  });

  testWidgets('element opacity blends over the background', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(
          background: const Layer(SolidFill(JColor(0xFFFFFFFF)), []),
          foreground: Layer(null, [
            _path(
              'fg',
              fill: const SolidFill(JColor(0xFF000000)),
              opacity: 0.5,
            ),
          ]),
        ),
        const RenderRequest(64, Composition.full, IconShape.square),
      );
      expect(px.at(32, 32), _rgba(128, 128, 128, 255, tolerance: 4));
    });
  });

  testWidgets('group transforms nest with child transforms', (t) async {
    await t.runAsync(() async {
      // Child: 100x100 unit square moved by (100, 0); group scales by 2 and
      // moves by (0, 512) -> canvas rect x 200..400, y 512..712.
      final group = GroupElement(
        id: 'g',
        name: 'g',
        transform: Transform2D.translate(0, 512).multiply(Transform2D.scale(2)),
        children: [
          _path(
            'c',
            d: 'M0 0H100V100H0Z',
            transform: Transform2D.translate(100, 0),
          ),
        ],
      );
      final px = await _render(
        _icon(foreground: Layer(null, [group])),
        const RenderRequest(1024, Composition.foreground, IconShape.square),
      );
      expect(px.at(300, 612), _rgba(0, 0, 255, 255));
      expect(px.at(150, 612), _alpha(0));
      expect(px.at(300, 450), _alpha(0));
      expect(px.at(450, 612), _alpha(0));
    });
  });

  testWidgets('linear gradient is in element-local space', (t) async {
    await t.runAsync(() async {
      // Local square 0..100 with a red->blue gradient along x, scaled x10.
      final px = await _render(
        _icon(
          foreground: Layer(null, [
            _path(
              'g',
              d: 'M0 0H100V100H0Z',
              transform: Transform2D.scale(10.24),
              fill: const LinearGradientFill(
                [GradientStop(0, _red), GradientStop(1, _blue)],
                0,
                0,
                100,
                0,
              ),
            ),
          ]),
        ),
        const RenderRequest(100, Composition.foreground, IconShape.square),
      );
      final left = px.at(2, 50), right = px.at(97, 50);
      expect(left[0], greaterThan(230));
      expect(left[2], lessThan(25));
      expect(right[2], greaterThan(230));
      expect(right[0], lessThan(25));
    });
  });

  testWidgets('stroke is drawn over fill', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(
          foreground: Layer(null, [
            _path(
              's',
              d: 'M256 256H768V768H256Z',
              fill: null,
              stroke: const Stroke(_red, 64),
            ),
          ]),
        ),
        const RenderRequest(1024, Composition.foreground, IconShape.square),
      );
      expect(px.at(256, 512), _rgba(255, 0, 0, 255));
      expect(px.at(512, 512), _alpha(0));
    });
  });

  testWidgets('raster element draws into its width x height box', (t) async {
    await t.runAsync(() async {
      final png = await _solidPng(4, 4, const Color(0xFF00FF00));
      final px = await _render(
        _icon(
          foreground: Layer(null, [
            RasterElement(
              id: 'r',
              name: 'r',
              png: png,
              width: 4,
              height: 4,
              transform: Transform2D.scale(128),
            ),
          ]),
        ),
        const RenderRequest(64, Composition.foreground, IconShape.square),
      );
      expect(px.at(10, 10), _rgba(0, 255, 0, 255));
      expect(px.at(50, 50), _alpha(0));
    });
  });

  testWidgets('raw svg element renders', (t) async {
    await t.runAsync(() async {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" '
          'viewBox="0 0 10 10"><rect width="10" height="10" fill="#0f0"/></svg>';
      final px = await _render(
        _icon(
          foreground: Layer(null, [
            RawSvgElement(
              id: 'svg',
              name: 'svg',
              svg: svg,
              vbX: 0,
              vbY: 0,
              vbWidth: 10,
              vbHeight: 10,
              transform: fitToCanvas(10, 10),
            ),
          ]),
        ),
        const RenderRequest(100, Composition.foreground, IconShape.square),
      );
      // fitToCanvas: 60% of the canvas, centered -> x/y 20..80.
      expect(px.at(50, 50), _rgba(0, 255, 0, 255));
      expect(px.at(25, 25), _rgba(0, 255, 0, 255));
      expect(px.at(15, 50), _alpha(0));
      expect(px.at(85, 50), _alpha(0));
    });
  });

  testWidgets('invalid assets are skipped without throwing', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(
          background: _redBg,
          foreground: Layer(null, [
            RasterElement(
              id: 'r',
              name: 'r',
              png: Uint8List.fromList([1, 2, 3]),
              width: 4,
              height: 4,
            ),
            const RawSvgElement(
              id: 's',
              name: 's',
              svg: '<svg',
              vbX: 0,
              vbY: 0,
              vbWidth: 10,
              vbHeight: 10,
            ),
            _path('bad', d: 'M0 0 L foo'),
          ]),
        ),
        const RenderRequest(32, Composition.full, IconShape.square),
      );
      expect(px.at(16, 16), _rgba(255, 0, 0, 255));
    });
  });

  testWidgets('prepared assets include group children', (t) async {
    await t.runAsync(() async {
      final png = await _solidPng(2, 2, const Color(0xFF00FF00));
      final icon = _icon(
        monochrome: Layer(null, [
          GroupElement(
            id: 'g',
            name: 'g',
            children: [
              RasterElement(
                id: 'nested',
                name: 'n',
                png: png,
                width: 2,
                height: 2,
              ),
            ],
          ),
        ]),
      );
      final assets = await PreparedAssets.load(icon);
      expect(assets.raster('nested'), isNotNull);
      expect(assets.raster('missing'), isNull);
      expect(assets.svg('missing'), isNull);
      assets.dispose();
    });
  });

  testWidgets('flattenAlpha yields an opaque image', (t) async {
    await t.runAsync(() async {
      final px = await _render(
        _icon(
          foreground: Layer(null, [_path('fg', d: 'M384 384H640V640H384Z')]),
        ),
        const RenderRequest(
          64,
          Composition.full,
          IconShape.square,
          flattenAlpha: true,
        ),
      );
      for (var y = 0; y < 64; y += 7) {
        for (var x = 0; x < 64; x += 7) {
          expect(px.at(x, y), _alpha(255, tolerance: 0), reason: '($x, $y)');
        }
      }
      expect(px.at(0, 0), _rgba(255, 255, 255, 255));
      expect(px.at(32, 32), _rgba(0, 0, 255, 255));
    });
  });
}

Future<Uint8List> _solidPng(int w, int h, Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

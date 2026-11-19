import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:test/test.dart';

GroupElement _group(ImportResult r) => r.element as GroupElement;
PathElement _path(IconElement e) => e as PathElement;
List<String> _tags(ImportResult r) =>
    (r.warnings.single as UnsupportedSvgFeatures).tags;

void main() {
  group('fitToCanvas', () {
    test('centers and scales long edge to 60%', () {
      final t = fitToCanvas(100, 50);
      expect(t.a, closeTo(6.144, 1e-9));
      expect(t.d, closeTo(6.144, 1e-9));
      expect(t.e, closeTo(204.8, 1e-9));
      expect(t.f, closeTo(358.4, 1e-9));
    });
  });

  group('supported svg', () {
    test('simple svg becomes editable group with path', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><path d="M0 0H24V24Z" fill="#ff0000"/></svg>',
        id: 'i1',
      );
      expect(r.element, isA<GroupElement>());
      expect(r.warnings, isEmpty);
      final p = _path(_group(r).children.single);
      expect((p.fill as SolidFill).color, JColor.parse('#FFFF0000'));
      expect(p.d, 'M0 0H24V24Z');
      expect(p.id, 'i1-1');
      expect(p.name, 'path');
      expect(r.element.id, 'i1');
      expect(r.element.name, 'SVG');
    });

    test('viewBox offset is translated before fitting', () {
      final r = importSvg(
        '<svg viewBox="10 20 100 50"><path d="M0 0"/></svg>',
        id: 'i',
      );
      final expected = fitToCanvas(
        100,
        50,
      ).multiply(Transform2D.translate(-10, -20));
      expect(r.element.transform, expected);
      // viewBox origin maps to the top-left of the fitted box.
      final t = r.element.transform;
      expect(t.a * 10 + t.e, closeTo(fitToCanvas(100, 50).e, 1e-9));
      expect(t.d * 20 + t.f, closeTo(fitToCanvas(100, 50).f, 1e-9));
    });

    test('rect and circle converted to paths', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><rect x="1" y="2" width="10" height="4"/>'
        '<circle cx="12" cy="12" r="5"/></svg>',
        id: 'i',
      );
      final kids = _group(r).children;
      expect(kids.every((c) => c is PathElement), isTrue);
      expect(_path(kids[0]).d, 'M1 2H11V6H1Z');
      expect(_path(kids[1]).d, 'M17 12A5 5 0 1 1 7 12A5 5 0 1 1 17 12Z');
    });

    test('rounded rect uses arcs, rx defaults ry and is clamped', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><rect width="10" height="4" rx="1.5"/>'
        '<rect width="10" height="4" rx="50"/></svg>',
        id: 'i',
      );
      final kids = _group(r).children;
      expect(
        _path(kids[0]).d,
        'M1.5 0H8.5A1.5 1.5 0 0 1 10 1.5V2.5A1.5 1.5 0 0 1 8.5 4H1.5'
        'A1.5 1.5 0 0 1 0 2.5V1.5A1.5 1.5 0 0 1 1.5 0Z',
      );
      expect(_path(kids[1]).d, contains('A5 2 0 0 1'));
    });

    test('ellipse, line, polyline and polygon', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24">'
        '<ellipse cx="10" cy="10" rx="4" ry="2"/>'
        '<line x1="0" y1="0" x2="5" y2="5" stroke="#000"/>'
        '<polyline points="0,0 5,5 10,0"/>'
        '<polygon points="0 0 5 5 10 0"/></svg>',
        id: 'i',
      );
      final k = _group(r).children.map(_path).toList();
      expect(k[0].d, 'M14 10A4 2 0 1 1 6 10A4 2 0 1 1 14 10Z');
      expect(k[1].d, 'M0 0L5 5');
      expect(k[2].d, 'M0 0L5 5L10 0');
      expect(k[3].d, 'M0 0L5 5L10 0Z');
    });

    test('generated numbers have no trailing noise', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><rect x="0.1" y="0.2" width="0.2" height="1"/></svg>',
        id: 'i',
      );
      expect(_path(_group(r).children.single).d, 'M0.1 0.2H0.3V1.2H0.1Z');
    });

    test('nested groups, ids, names and transforms', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><g id="outer" transform="translate(2 3)" opacity="0.5">'
        '<path d="M0 0"/><g><path id="deep" d="M1 1"/></g></g><path d="M2 2"/></svg>',
        id: 'i',
      );
      final top = _group(r).children;
      final outer = top[0] as GroupElement;
      expect(outer.id, 'i-1');
      expect(outer.name, 'outer');
      expect(outer.opacity, 0.5);
      expect(outer.transform, Transform2D.translate(2, 3));
      expect(outer.children[0].id, 'i-2');
      final inner = outer.children[1] as GroupElement;
      expect(inner.id, 'i-3');
      expect(inner.name, 'g');
      expect(inner.children.single.id, 'i-4');
      expect(inner.children.single.name, 'deep');
      expect(top[1].id, 'i-5');
    });

    test('transform functions compose left to right', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><path d="M0 0" transform="translate(10,0) scale(2)"/>'
        '<path d="M0 0" transform="matrix(1 0 0 1 5 6)"/>'
        '<path d="M0 0" transform="rotate(90)"/>'
        '<path d="M0 0" transform="rotate(90 10 10)"/></svg>',
        id: 'i',
      );
      final k = _group(r).children;
      expect(k[0].transform, const Transform2D(2, 0, 0, 2, 10, 0));
      expect(k[1].transform, const Transform2D(1, 0, 0, 1, 5, 6));
      expect(k[2].transform, const Transform2D(0, 1, -1, 0, 0, 0));
      expect(k[3].transform, const Transform2D(0, 1, -1, 0, 20, 0));
    });

    test('paint inherits, opacity does not, default fill is black', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24" fill="#00ff00"><g fill-opacity="0.5" stroke="#0000ff" stroke-width="3" opacity="0.4">'
        '<path d="M0 0"/><path d="M1 1" fill="none" stroke-opacity="0.5"/></g>'
        '<path d="M2 2" fill="inherit"/></svg>',
        id: 'i',
      );
      final g = _group(r).children[0] as GroupElement;
      final a = _path(g.children[0]);
      expect(a.fill, const SolidFill(JColor(0x8000FF00)));
      expect(a.stroke, const Stroke(JColor(0xFF0000FF), 3));
      expect(a.opacity, 1.0);
      final b = _path(g.children[1]);
      expect(b.fill, isNull);
      expect(b.stroke!.color, const JColor(0x800000FF));
      expect(g.opacity, 0.4);
    });

    test('default fill black, default stroke none, element opacity', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><path d="M0 0" opacity="0.25"/></svg>',
        id: 'i',
      );
      final p = _path(_group(r).children.single);
      expect(p.fill, const SolidFill(JColor(0xFF000000)));
      expect(p.stroke, isNull);
      expect(p.opacity, 0.25);
    });

    test('style attribute overrides presentation attributes', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><path d="M0 0" fill="#ff0000" '
        'style="fill:#0000ff; stroke:#00ff00;stroke-width:2;opacity:0.5"/></svg>',
        id: 'i',
      );
      final p = _path(_group(r).children.single);
      expect(p.fill, const SolidFill(JColor(0xFF0000FF)));
      expect(p.stroke, const Stroke(JColor(0xFF00FF00), 2));
      expect(p.opacity, 0.5);
    });

    test('color syntaxes', () {
      Fill? fillOf(String c) {
        final r = importSvg(
          '<svg viewBox="0 0 1 1"><path d="M0 0" fill="$c"/></svg>',
          id: 'i',
        );
        return _path(_group(r).children.single).fill;
      }

      expect(fillOf('#f00'), const SolidFill(JColor(0xFFFF0000)));
      expect(fillOf('#00ff7f'), const SolidFill(JColor(0xFF00FF7F)));
      expect(fillOf('rgb(1, 2, 3)'), const SolidFill(JColor(0xFF010203)));
      expect(fillOf('Red'), const SolidFill(JColor(0xFFFF0000)));
      expect(fillOf('navy'), const SolidFill(JColor(0xFF000080)));
      expect(fillOf('transparent'), const SolidFill(JColor(0x00000000)));
      expect(fillOf('currentColor'), const SolidFill(JColor(0xFF000000)));
    });

    test('unknown color syntax is unsupported and tagged by the string', () {
      final r = importSvg(
        '<svg viewBox="0 0 1 1"><path d="M0 0" fill="hsl(10,10%,10%)"/></svg>',
        id: 'i',
      );
      expect(r.element, isA<RawSvgElement>());
      expect(_tags(r), ['hsl(10,10%,10%)']);
    });

    test('title, desc, metadata and foreign namespaces are ignored', () {
      final r = importSvg(
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:sodipodi="x" viewBox="0 0 24 24">'
        '<title>t</title><desc>d</desc><metadata/><sodipodi:namedview/>'
        '<path d="M0 0"/></svg>',
        id: 'i',
      );
      expect(r.warnings, isEmpty);
      expect(_group(r).children, hasLength(1));
    });

    test('shapes inside defs are not rendered', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><defs><path d="M9 9"/></defs><path d="M0 0"/></svg>',
        id: 'i',
      );
      expect(_group(r).children, hasLength(1));
    });

    test('display none hides the element', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><path d="M0 0" display="none"/></svg>',
        id: 'i',
      );
      expect(_group(r).children.single.hidden, isTrue);
    });
  });

  group('gradients', () {
    test('gradient reference resolved', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><defs>'
        '<linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="24" y2="0">'
        '<stop offset="0" stop-color="#ff0000"/><stop offset="100%" style="stop-color:#0000ff;stop-opacity:0.5"/>'
        '</linearGradient></defs><path d="M0 0H24V24Z" fill="url(#g)" fill-opacity="0.5"/></svg>',
        id: 'i',
      );
      expect(r.warnings, isEmpty);
      final f = _path(_group(r).children.single).fill as LinearGradientFill;
      expect(f.stops, hasLength(2));
      expect(f.stops[0], const GradientStop(0, JColor(0x80FF0000)));
      // stop-opacity 0.5 * fill-opacity 0.5 = 0.25 -> 64
      expect(f.stops[1], const GradientStop(1, JColor(0x400000FF)));
      expect([f.x1, f.y1, f.x2, f.y2], [0, 0, 24, 0]);
    });

    test('radial userSpaceOnUse', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><radialGradient id="g" gradientUnits="userSpaceOnUse" cx="12" cy="12" r="6">'
        '<stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></radialGradient>'
        '<path d="M0 0" fill="url(#g)"/></svg>',
        id: 'i',
      );
      final f = _path(_group(r).children.single).fill as RadialGradientFill;
      expect([f.cx, f.cy, f.r], [12, 12, 6]);
    });

    test('objectBoundingBox maps to rect bounds', () {
      final r = importSvg(
        '<svg viewBox="0 0 100 100"><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></linearGradient>'
        '<rect x="10" y="20" width="40" height="60" fill="url(#g)"/></svg>',
        id: 'i',
      );
      final f = _path(_group(r).children.single).fill as LinearGradientFill;
      expect([f.x1, f.y1, f.x2, f.y2], [10, 20, 50, 80]);
    });

    test('objectBoundingBox maps to circle and ellipse bounds', () {
      final r = importSvg(
        '<svg viewBox="0 0 100 100"><radialGradient id="g">'
        '<stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#000"/></radialGradient>'
        '<circle cx="50" cy="40" r="10" fill="url(#g)"/>'
        '<ellipse cx="50" cy="40" rx="10" ry="10" fill="url(#g)"/></svg>',
        id: 'i',
      );
      for (final c in _group(r).children) {
        final f = _path(c).fill as RadialGradientFill;
        expect([f.cx, f.cy, f.r], [50, 40, 10]);
      }
    });

    test('objectBoundingBox on a path makes the file raw', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><linearGradient id="g">'
        '<stop offset="0" stop-color="#fff"/></linearGradient>'
        '<path d="M0 0" fill="url(#g)"/></svg>',
        id: 'i',
      );
      expect(r.element, isA<RawSvgElement>());
      expect(_tags(r), ['gradientUnits=objectBoundingBox']);
    });

    test('gradientTransform, href and spreadMethod are unsupported', () {
      final r = importSvg(
        '<svg xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 24 24">'
        '<linearGradient id="a" gradientTransform="rotate(5)"/>'
        '<linearGradient id="b" xlink:href="#a"/>'
        '<linearGradient id="c" spreadMethod="reflect"/>'
        '<linearGradient id="d" spreadMethod="pad"/></svg>',
        id: 'i',
      );
      expect(_tags(r), ['gradientTransform', 'xlink:href', 'spreadMethod']);
    });

    test('missing gradient reference is unsupported', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><path d="M0 0" fill="url(#nope)"/></svg>',
        id: 'i',
      );
      expect(r.element, isA<RawSvgElement>());
      expect(_tags(r), ['url(#nope)']);
    });
  });

  group('raw fallback', () {
    test('svg with text is kept as raw svg with warning', () {
      const svg = '<svg viewBox="0 0 10 10"><text>A</text></svg>';
      final r = importSvg(svg, id: 'i2');
      final e = r.element as RawSvgElement;
      expect(e.svg, svg);
      expect(e.id, 'i2');
      expect([e.vbX, e.vbY, e.vbWidth, e.vbHeight], [0, 0, 10, 10]);
      expect(e.transform, fitToCanvas(10, 10));
      expect(_tags(r), contains('text'));
    });

    test('raw viewBox offset is stored, transform is fit only', () {
      final r = importSvg('<svg viewBox="5 6 20 10"><filter/></svg>', id: 'i');
      final e = r.element as RawSvgElement;
      expect([e.vbX, e.vbY, e.vbWidth, e.vbHeight], [5, 6, 20, 10]);
      expect(e.transform, fitToCanvas(20, 10));
    });

    test('tags are deduplicated in first-seen order', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><g class="a"><text/><mask/><text/>'
        '<path d="M0 0" filter="url(#f)" class="b"/></g><use/></svg>',
        id: 'i',
      );
      expect(_tags(r), ['class', 'text', 'mask', 'filter', 'use']);
    });

    test('style element, clip-path and unsupported transform', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><style>.a{}</style>'
        '<path d="M0 0" clip-path="url(#c)" transform="skewX(5)"/>'
        '<path d="M0 0" style="filter:blur(2px)"/></svg>',
        id: 'i',
      );
      expect(_tags(r), ['style', 'clip-path', 'skewX', 'filter']);
    });

    test('evenodd fill-rule is unsupported', () {
      final r = importSvg(
        '<svg viewBox="0 0 24 24"><path d="M0 0" fill-rule="evenodd"/></svg>',
        id: 'i',
      );
      expect(_tags(r), ['fill-rule']);
    });
  });

  group('size', () {
    test('svg without viewBox uses width/height with px unit', () {
      final r = importSvg(
        '<svg width="48px" height="24px"><path d="M0 0H48V24Z"/></svg>',
        id: 'i3',
      );
      expect(r.element.transform, fitToCanvas(48, 24));
    });

    test('other unit suffixes are converted to plain numbers', () {
      final r = importSvg(
        '<svg width="48pt" height="24pt"><path d="M0 0"/></svg>',
        id: 'i',
      );
      expect(r.element.transform, fitToCanvas(48, 24));
    });

    test('no size at all falls back to 1024', () {
      final r = importSvg('<svg><path d="M0 0"/></svg>', id: 'i');
      expect(r.element.transform, fitToCanvas(1024, 1024));
    });

    test('viewBox wins over width/height', () {
      final r = importSvg(
        '<svg width="10" height="10" viewBox="0 0 24 12"><path d="M0 0"/></svg>',
        id: 'i',
      );
      expect(r.element.transform, fitToCanvas(24, 12));
    });
  });

  group('errors', () {
    test('malformed xml throws FormatException', () {
      expect(
        () => importSvg('<svg><path</svg>', id: 'i'),
        throwsFormatException,
      );
      expect(() => importSvg('', id: 'i'), throwsFormatException);
    });

    test('non-svg root throws FormatException', () {
      expect(() => importSvg('<html/>', id: 'i'), throwsFormatException);
    });
  });
}

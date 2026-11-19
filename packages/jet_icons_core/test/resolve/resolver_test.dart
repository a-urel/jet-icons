import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:test/test.dart';

void main() {
  const red = SolidFill(JColor(0xFFFF0000));
  const blue = SolidFill(JColor(0xFF0000FF));
  const green = SolidFill(JColor(0xFF00FF00));

  final doc = IconDocument.empty().copyWith(
    background: const Layer(SolidFill(JColor(0xFF112233)), []),
    foreground: const Layer(null, [
      PathElement(id: 'main', name: 'main', d: 'M0 0H10V10Z', fill: red),
      GroupElement(
        id: 'grp',
        name: 'grp',
        children: [
          PathElement(id: 'detail', name: 'detail', d: 'M1 1H2V2Z', fill: red),
        ],
      ),
    ]),
  );

  test('no overrides returns common design, monochrome derived from fg', () {
    final r = resolveIcon(doc, platform: IconPlatform.ios, sizePx: 1024);
    expect(r.background, doc.background);
    expect(r.foreground, doc.foreground);
    expect(r.monochrome, doc.foreground);
  });

  test('explicit monochrome is used when present', () {
    const mono = Layer(null, []);
    final d = doc.copyWith(monochrome: mono);
    expect(
      resolveIcon(d, platform: IconPlatform.ios, sizePx: 1024).monochrome,
      mono,
    );
  });

  test('platform patch changes only patched property', () {
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.macos,
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.8)],
        ),
      ],
    );
    final r = resolveIcon(d, platform: IconPlatform.macos, sizePx: 512);
    expect(r.foreground.scale, 0.8);
    expect(r.foreground.elements, doc.foreground.elements);
    expect(
      resolveIcon(d, platform: IconPlatform.ios, sizePx: 1024).foreground.scale,
      1.0,
    );
  });

  test('common edits flow through un-patched properties', () {
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.macos,
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.8)],
        ),
      ],
    );
    final edited = d.copyWith(
      foreground: d.foreground.copyWith(
        elements: [
          (d.foreground.elements.first as PathElement).copyWith(fill: blue),
          d.foreground.elements.last,
        ],
      ),
    );
    final r = resolveIcon(edited, platform: IconPlatform.macos, sizePx: 512);
    expect(r.foreground.scale, 0.8);
    expect((r.foreground.elements.first as PathElement).fill, blue);
  });

  test('size range override applies only inside range', () {
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.windows,
          sizeRange: const SizeRange(16, 32),
          elementPatches: [ElementPatch('detail', hidden: true)],
        ),
      ],
    );
    expect(
      findElement(
        resolveIcon(d, platform: IconPlatform.windows, sizePx: 16).foreground,
        'detail',
      )!.hidden,
      isTrue,
    );
    expect(
      findElement(
        resolveIcon(d, platform: IconPlatform.windows, sizePx: 48).foreground,
        'detail',
      )!.hidden,
      isFalse,
    );
  });

  test('element patch applies opacity, fill and transform', () {
    const t = Transform2D(2, 0, 0, 2, 0, 0);
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.ios,
          elementPatches: [
            ElementPatch('main', opacity: 0.5, fill: green, transform: t),
          ],
        ),
      ],
    );
    final e =
        findElement(
              resolveIcon(
                d,
                platform: IconPlatform.ios,
                sizePx: 1024,
              ).foreground,
              'main',
            )!
            as PathElement;
    expect(e.opacity, 0.5);
    expect(e.fill, green);
    expect(e.transform, t);
    expect(e.d, 'M0 0H10V10Z');
  });

  test('detached layer replaces common layer', () {
    const detachedBg = Layer(blue, []);
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.android,
          detached: {LayerKind.background: detachedBg},
        ),
      ],
    );
    final changed = d.copyWith(background: const Layer(red, []));
    expect(
      resolveIcon(d, platform: IconPlatform.android, sizePx: 432).background,
      detachedBg,
    );
    expect(
      resolveIcon(
        changed,
        platform: IconPlatform.android,
        sizePx: 432,
      ).background,
      detachedBg,
    );
    expect(
      resolveIcon(changed, platform: IconPlatform.ios, sizePx: 432).background,
      changed.background,
    );
  });

  test('layer patch hidden empties the layer; fill patch sets fill', () {
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.ios,
          layerPatches: [
            LayerPatch(LayerKind.foreground, hidden: true),
            LayerPatch(LayerKind.background, fill: green),
          ],
        ),
      ],
    );
    final r = resolveIcon(d, platform: IconPlatform.ios, sizePx: 1024);
    expect(r.foreground, const Layer(null, []));
    expect(r.background.fill, green);
  });

  test('dark variant defaults to transparent background', () {
    final r = resolveIcon(
      doc,
      platform: IconPlatform.ios,
      variant: IconVariant.dark,
      sizePx: 1024,
    );
    expect(r.background.fill, isNull);
    expect(r.background.elements, isEmpty);
  });

  test('override order: platform-wide, then variant, then size range', () {
    final d = doc.copyWith(
      overrides: [
        // Listed first but must apply last (size-range group).
        PlatformOverride(
          IconPlatform.windows,
          sizeRange: const SizeRange(0, 100),
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.3)],
        ),
        PlatformOverride(
          IconPlatform.windows,
          variant: IconVariant.dark,
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.6)],
        ),
        PlatformOverride(
          IconPlatform.windows,
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.9)],
        ),
      ],
    );
    double scaleAt(IconVariant v, int px) => resolveIcon(
      d,
      platform: IconPlatform.windows,
      variant: v,
      sizePx: px,
    ).foreground.scale;
    expect(scaleAt(IconVariant.light, 1024), 0.9);
    expect(scaleAt(IconVariant.dark, 1024), 0.6);
    expect(scaleAt(IconVariant.dark, 50), 0.3);
    expect(scaleAt(IconVariant.light, 50), 0.3);
  });

  test('same-group overrides apply in list order', () {
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.ios,
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.5)],
        ),
        PlatformOverride(
          IconPlatform.ios,
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.7)],
        ),
      ],
    );
    expect(
      resolveIcon(d, platform: IconPlatform.ios, sizePx: 1024).foreground.scale,
      0.7,
    );
  });

  test('variant-specific override ignored for other variants', () {
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.ios,
          variant: IconVariant.dark,
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.5)],
        ),
      ],
    );
    expect(
      resolveIcon(d, platform: IconPlatform.ios, sizePx: 1024).foreground.scale,
      1.0,
    );
  });

  test('detached applies before patches within an override', () {
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.android,
          detached: {LayerKind.foreground: const Layer(null, [])},
          layerPatches: [LayerPatch(LayerKind.foreground, scale: 0.5)],
        ),
      ],
    );
    final r = resolveIcon(d, platform: IconPlatform.android, sizePx: 432);
    expect(r.foreground.elements, isEmpty);
    expect(r.foreground.scale, 0.5);
  });

  test('patch for deleted element id is ignored', () {
    final d = doc.copyWith(
      overrides: [
        PlatformOverride(
          IconPlatform.ios,
          elementPatches: [ElementPatch('gone', hidden: true)],
        ),
      ],
    );
    expect(
      () => resolveIcon(d, platform: IconPlatform.ios, sizePx: 1024),
      returnsNormally,
    );
    expect(
      resolveIcon(d, platform: IconPlatform.ios, sizePx: 1024).foreground,
      doc.foreground,
    );
  });

  test('findElement searches groups; null when missing', () {
    expect(findElement(doc.foreground, 'detail'), isA<PathElement>());
    expect(findElement(doc.foreground, 'grp'), isA<GroupElement>());
    expect(findElement(doc.foreground, 'nope'), isNull);
  });

  test('ResolvedIcon has value equality', () {
    final a = resolveIcon(doc, platform: IconPlatform.ios, sizePx: 1024);
    final b = resolveIcon(doc, platform: IconPlatform.ios, sizePx: 1024);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(
        resolveIcon(
          doc,
          platform: IconPlatform.ios,
          variant: IconVariant.dark,
          sizePx: 1024,
        ),
      ),
    );
  });

  test('shapeFor defaults', () {
    expect(
      shapeFor(IconDocument.empty(), IconPlatform.windows),
      IconShape.roundedSquare,
    );
    expect(shapeFor(IconDocument.empty(), IconPlatform.ios), IconShape.square);
    expect(
      shapeFor(
        const IconDocument(
          Layer(null, []),
          Layer(null, []),
          null,
          {
            IconPlatform.web: IconShape.circle,
            IconPlatform.ios: IconShape.circle,
          },
          [],
          {},
        ),
        IconPlatform.web,
      ),
      IconShape.circle,
    );
    expect(
      shapeFor(
        const IconDocument(Layer(null, []), Layer(null, []), null, {}, [], {}),
        IconPlatform.linux,
      ),
      IconShape.roundedSquare,
    );
  });

  test('shapeFor ignores shapes entries for non-desktop/web platforms', () {
    final d = IconDocument.empty().copyWith(
      shapes: {IconPlatform.ios: IconShape.circle},
    );
    expect(shapeFor(d, IconPlatform.ios), IconShape.square);
    expect(d.shapeFor(IconPlatform.android), IconShape.square);
  });
}

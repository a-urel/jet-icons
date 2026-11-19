import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:test/test.dart';

void main() {
  test('ios has light/dark/tinted 1024 and Contents.json', () {
    final o = outputsFor(IconPlatform.ios, IconDocument.empty());
    expect(
      o.map((f) => f.path),
      containsAll([
        'ios/AppIcon.appiconset/AppIcon-1024.png',
        'ios/AppIcon.appiconset/AppIcon-1024-dark.png',
        'ios/AppIcon.appiconset/AppIcon-1024-tinted.png',
        'ios/AppIcon.appiconset/Contents.json',
      ]),
    );
    final imgs = o.whereType<ImageOutput>().toList();
    expect(imgs.map((i) => i.variant), [
      IconVariant.light,
      IconVariant.dark,
      IconVariant.tinted,
    ]);
    expect(imgs.map((i) => i.request.flattenAlpha), [true, false, true]);
    expect(imgs[2].request.composition, Composition.tinted);
    expect(o.last, isA<TextOutput>());
  });

  test('android adaptive layers at 108dp densities', () {
    final o = outputsFor(IconPlatform.android, IconDocument.empty());
    List<int> sizes(String name) => o
        .whereType<ImageOutput>()
        .where((f) => f.path.endsWith('/$name'))
        .map((f) => f.request.sizePx)
        .toList();
    expect(sizes('ic_launcher_foreground.png'), [108, 162, 216, 324, 432]);
    expect(sizes('ic_launcher_background.png'), [108, 162, 216, 324, 432]);
    expect(sizes('ic_launcher_monochrome.png'), [108, 162, 216, 324, 432]);
    expect(sizes('ic_launcher.png'), [48, 72, 96, 144, 192]);
    expect(sizes('ic_launcher_round.png'), [48, 72, 96, 144, 192]);
    final fg = o.whereType<ImageOutput>().firstWhere(
      (f) => f.path.endsWith('ic_launcher_foreground.png'),
    );
    expect(fg.request.contentScale, 72 / 108);
    expect(fg.request.composition, Composition.foreground);
    final play = o.whereType<ImageOutput>().firstWhere(
      (f) => f.path == 'android/play_store_512.png',
    );
    expect(play.request.flattenAlpha, isTrue);
    expect(
      o.map((f) => f.path),
      containsAll([
        'android/res/mipmap-anydpi-v26/ic_launcher.xml',
        'android/res/mipmap-anydpi-v26/ic_launcher_round.xml',
      ]),
    );
  });

  test('windows ico sizes and shape follows document', () {
    final d = IconDocument.empty().copyWith(
      shapes: {IconPlatform.windows: IconShape.circle},
    );
    final ico = outputsFor(IconPlatform.windows, d).single as ContainerOutput;
    expect(ico.kind, ContainerKind.ico);
    expect(ico.images.map((r) => r.sizePx), [16, 24, 32, 48, 64, 128, 256]);
    expect(ico.images.every((r) => r.shape == IconShape.circle), isTrue);
  });

  test('shape none renders foreground only', () {
    final d = IconDocument.empty().copyWith(
      shapes: {IconPlatform.linux: IconShape.none},
    );
    final imgs = outputsFor(
      IconPlatform.linux,
      d,
    ).whereType<ImageOutput>().toList();
    expect(imgs, hasLength(9));
    expect(
      imgs.every(
        (i) =>
            i.request.composition == Composition.foreground &&
            i.request.shape == IconShape.none,
      ),
      isTrue,
    );
  });

  test('macOS outputs use mac template', () {
    final o = outputsFor(IconPlatform.macos, IconDocument.empty());
    final reqs = [
      ...o.whereType<ImageOutput>().map((i) => i.request),
      ...o.whereType<ContainerOutput>().expand((c) => c.images),
    ];
    expect(reqs, hasLength(14));
    expect(reqs.every((r) => r.macTemplate), isTrue);
    final icns = o.whereType<ContainerOutput>().single;
    expect(icns.kind, ContainerKind.icns);
    expect(icns.images.map((r) => r.sizePx), [16, 32, 64, 128, 256, 512, 1024]);
  });

  test('web outputs', () {
    final o = outputsFor(IconPlatform.web, IconDocument.empty());
    final ico = o.whereType<ContainerOutput>().single;
    expect(ico.images.map((r) => r.sizePx), [16, 32, 48]);
    final byPath = {for (final i in o.whereType<ImageOutput>()) i.path: i};
    expect(
      byPath['web/icons/Icon-192.png']!.request.shape,
      IconShape.roundedSquare,
    );
    for (final p in [
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
      'web/apple-touch-icon.png',
    ]) {
      expect(byPath[p]!.request.shape, IconShape.square);
      expect(byPath[p]!.request.flattenAlpha, isTrue);
    }
    expect(byPath['web/apple-touch-icon.png']!.request.sizePx, 180);
    expect(o.map((f) => f.path), contains('web/manifest-icons.json'));
  });

  test('RenderRequest and outputs have value equality', () {
    const a = RenderRequest(16, Composition.full, IconShape.square);
    const b = RenderRequest(16, Composition.full, IconShape.square);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      outputsFor(IconPlatform.macos, IconDocument.empty()),
      outputsFor(IconPlatform.macos, IconDocument.empty()),
    );
  });

  test('every platform paths are unique and prefixed by platform folder', () {
    for (final p in IconPlatform.values) {
      final paths = outputsFor(
        p,
        IconDocument.empty(),
      ).map((f) => f.path).toList();
      expect(paths.toSet().length, paths.length);
      expect(paths.every((s) => s.startsWith('${p.name}/')), isTrue);
    }
  });
}

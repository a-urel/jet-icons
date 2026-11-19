import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:test/test.dart';

class FakeRasterizer implements IconRasterizer {
  final calls = <(ResolvedIcon, RenderRequest)>[];

  @override
  Future<Uint8List> renderPng(ResolvedIcon icon, RenderRequest request) async {
    calls.add((icon, request));
    final image = img.Image(
      width: request.sizePx,
      height: request.sizePx,
      numChannels: 4,
    );
    img.fill(image, color: img.ColorRgba8(200, 30, 30, 255));
    return Uint8List.fromList(img.encodePng(image));
  }
}

class ThrowingRasterizer implements IconRasterizer {
  @override
  Future<Uint8List> renderPng(ResolvedIcon icon, RenderRequest request) =>
      throw StateError('boom');
}

void main() {
  const logo = PathElement(
    id: 'logo',
    name: 'logo',
    d: 'M0 0H10V10Z',
    fill: SolidFill(JColor(0xFFFFFFFF)),
  );
  final doc = IconDocument.empty().copyWith(
    foreground: const Layer(null, [logo]),
  );

  test('export contains every planned path', () async {
    final platforms = {IconPlatform.ios, IconPlatform.windows};
    final b = await runExport(doc, platforms, FakeRasterizer());
    expect(b.files.keys.toSet(), plannedPaths(doc, platforms).toSet());
  });

  test('bundle order follows platform enum order', () async {
    final platforms = {IconPlatform.windows, IconPlatform.ios};
    final b = await runExport(doc, platforms, FakeRasterizer());
    expect(b.files.keys.toList(), plannedPaths(doc, platforms));
    expect(b.files.keys.first, startsWith('ios/'));
  });

  test('flattenAlpha outputs have no alpha channel', () async {
    final b = await runExport(doc, {IconPlatform.ios}, FakeRasterizer());
    final light = img.decodePng(
      b.files['ios/AppIcon.appiconset/AppIcon-1024.png']!,
    )!;
    expect(light.numChannels, 3);
    final dark = img.decodePng(
      b.files['ios/AppIcon.appiconset/AppIcon-1024-dark.png']!,
    )!;
    expect(dark.numChannels, 4);
  });

  test(
    'size-range override reaches rasterizer only for matching sizes',
    () async {
      final d = doc.copyWith(
        overrides: [
          PlatformOverride(
            IconPlatform.windows,
            sizeRange: const SizeRange(0, 20),
            elementPatches: [ElementPatch('logo', hidden: true)],
          ),
        ],
      );
      final fake = FakeRasterizer();
      await runExport(d, {IconPlatform.windows}, fake);
      bool hidden(ResolvedIcon i) =>
          (i.foreground.elements.single as PathElement).hidden;
      final by = {for (final (i, r) in fake.calls) r.sizePx: hidden(i)};
      expect(by[16], isTrue);
      expect(by[48], isFalse);
    },
  );

  test('ico and icns containers are encoded', () async {
    final b = await runExport(doc, {
      IconPlatform.windows,
      IconPlatform.macos,
    }, FakeRasterizer());
    final ico = b.files['windows/app_icon.ico']!;
    expect(ico.sublist(0, 4), [0, 0, 1, 0]);
    final icnsPath = b.files.keys.firstWhere((p) => p.endsWith('.icns'));
    expect(String.fromCharCodes(b.files[icnsPath]!.sublist(0, 4)), 'icns');
  });

  test('text outputs are utf-8', () async {
    final b = await runExport(doc, {IconPlatform.ios}, FakeRasterizer());
    final text = outputsFor(IconPlatform.ios, doc).whereType<TextOutput>();
    for (final t in text) {
      expect(b.files[t.path], Uint8List.fromList(t.content.codeUnits));
    }
  });

  test('progress counts every rasterizer call', () async {
    final fake = FakeRasterizer();
    final events = <(int, int)>[];
    await runExport(
      doc,
      {IconPlatform.ios, IconPlatform.windows},
      fake,
      onProgress: (d, t) => events.add((d, t)),
    );
    final total = fake.calls.length;
    expect(events.length, total);
    expect(events.first, (1, total));
    expect(events.last, (total, total));
  });

  test('zero renders reports (0, 0) once', () async {
    final events = <(int, int)>[];
    final b = await runExport(
      doc,
      {},
      FakeRasterizer(),
      onProgress: (d, t) => events.add((d, t)),
    );
    expect(b.files, isEmpty);
    expect(events, [(0, 0)]);
  });

  test('rasterizer exception propagates unchanged', () {
    expect(
      runExport(doc, {IconPlatform.ios}, ThrowingRasterizer()),
      throwsA(isA<StateError>()),
    );
  });

  test('zip roundtrips file list', () async {
    final b = await runExport(doc, {IconPlatform.ios}, FakeRasterizer());
    final archive = ZipDecoder().decodeBytes(encodeZip(b));
    expect(archive.files.map((f) => f.name).toList(), b.files.keys.toList());
    final f = archive.files.first;
    expect(f.content, b.files[f.name]);
  });
}

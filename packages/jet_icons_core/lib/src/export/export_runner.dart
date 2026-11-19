import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:meta/meta.dart';

import '../encoders/icns.dart';
import '../encoders/ico.dart';
import '../encoders/png_alpha.dart';
import '../model/document.dart';
import '../model/override.dart';
import '../platforms/output.dart';
import '../platforms/outputs.dart';
import '../resolve/resolver.dart';
import 'rasterizer.dart';

/// Exported files keyed by their path inside the export root, in output order.
@immutable
class ExportBundle {
  const ExportBundle(this.files);

  final Map<String, Uint8List> files;
}

/// The paths [runExport] will produce, in the same order.
List<String> plannedPaths(IconDocument doc, Set<IconPlatform> platforms) => [
  for (final o in _outputs(doc, platforms)) o.path,
];

Iterable<OutputFile> _outputs(
  IconDocument doc,
  Set<IconPlatform> platforms,
) sync* {
  for (final p in IconPlatform.values) {
    if (platforms.contains(p)) yield* outputsFor(p, doc);
  }
}

/// Renders and encodes every output for [platforms]. Renders run sequentially;
/// rasterizer errors propagate unchanged.
Future<ExportBundle> runExport(
  IconDocument doc,
  Set<IconPlatform> platforms,
  IconRasterizer rasterizer, {
  void Function(int done, int total)? onProgress,
}) async {
  final outputs = _outputs(doc, platforms).toList();
  final total = outputs.fold<int>(
    0,
    (n, o) =>
        n +
        switch (o) {
          ImageOutput() => 1,
          ContainerOutput(:final images) => images.length,
          TextOutput() => 0,
        },
  );
  if (total == 0) onProgress?.call(0, 0);

  var done = 0;
  Future<Uint8List> render(
    OutputFile o,
    IconVariant variant,
    RenderRequest request,
  ) async {
    final icon = resolveIcon(
      doc,
      platform: o.platform,
      variant: variant,
      sizePx: request.sizePx,
    );
    var png = await rasterizer.renderPng(icon, request);
    if (request.flattenAlpha) png = stripAlpha(png);
    onProgress?.call(++done, total);
    return png;
  }

  final files = <String, Uint8List>{};
  for (final o in outputs) {
    switch (o) {
      case ImageOutput():
        files[o.path] = await render(o, o.variant, o.request);
      case ContainerOutput():
        final pngs = <(int, Uint8List)>[];
        for (final r in o.images) {
          pngs.add((r.sizePx, await render(o, IconVariant.light, r)));
        }
        files[o.path] = switch (o.kind) {
          ContainerKind.ico => encodeIco(pngs),
          ContainerKind.icns => encodeIcns({
            for (final (size, png) in pngs) size: png,
          }),
        };
      case TextOutput():
        files[o.path] = Uint8List.fromList(utf8.encode(o.content));
    }
  }
  return ExportBundle(files);
}

/// Zips [bundle] with files at their bundle paths.
Uint8List encodeZip(ExportBundle bundle) {
  final archive = Archive();
  for (final e in bundle.files.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

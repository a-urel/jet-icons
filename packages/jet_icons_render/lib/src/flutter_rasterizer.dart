import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:jet_icons_core/jet_icons_core.dart';

import 'icon_painter.dart';
import 'prepared_assets.dart';

/// [IconRasterizer] backed by [IconPainter] on a `dart:ui` canvas.
class FlutterIconRasterizer implements IconRasterizer {
  const FlutterIconRasterizer();

  @override
  Future<Uint8List> renderPng(ResolvedIcon icon, RenderRequest request) async {
    final assets = await PreparedAssets.load(icon);
    final size = request.sizePx;
    final recorder = ui.PictureRecorder();
    IconPainter(
      icon,
      request,
      assets,
    ).paint(ui.Canvas(recorder), ui.Size(size.toDouble(), size.toDouble()));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(size, size);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('PNG encoding failed for $request');
        }
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
      assets.dispose();
    }
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:path_parsing/path_parsing.dart';

import 'prepared_assets.dart';
import 'shape_paths.dart';

/// Draws a [ResolvedIcon] as [request] describes onto a square canvas. The
/// paint size's width is the output edge (the rasterizer uses
/// `request.sizePx`); the 1024-unit design canvas is scaled to it.
///
/// Shared by the editor canvas, previews and export, so what is shown is
/// what is exported.
class IconPainter extends CustomPainter {
  IconPainter(this.icon, this.request, this.assets);

  final ResolvedIcon icon;
  final RenderRequest request;
  final PreparedAssets assets;

  static const double _center = canvasSize / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width;
    final k = px / canvasSize;
    final full = Rect.fromLTWH(0, 0, px, px);

    if (request.flattenAlpha) {
      canvas.drawRect(full, Paint()..color = const Color(0xFFFFFFFF));
    }

    canvas.save();
    if (request.macTemplate) {
      final body = macBodyPath(px);
      canvas.drawPath(
        body.shift(Offset(0, 10 * k)),
        Paint()
          ..color = const Color(0x4D000000)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            Shadow.convertRadiusToSigma(20 * k),
          ),
      );
      canvas
        ..clipPath(body)
        ..translate(100 * k, 100 * k);
      _paintComposition(canvas, 824 * k);
    } else {
      if (request.shape == IconShape.roundedSquare ||
          request.shape == IconShape.circle) {
        canvas.clipPath(shapePath(request.shape, px));
      }
      _paintComposition(canvas, px);
    }
    canvas.restore();
  }

  /// Composes the layers into the 0,0 .. [px],[px] square.
  void _paintComposition(Canvas canvas, double px) {
    switch (request.composition) {
      case Composition.full:
        _paintLayer(canvas, icon.background, px);
        _paintLayer(canvas, icon.foreground, px);
      case Composition.foreground:
        _paintLayer(canvas, icon.foreground, px);
      case Composition.background:
        _paintLayer(canvas, icon.background, px);
      case Composition.monochrome:
        _paintMonochrome(canvas, px);
      case Composition.tinted:
        canvas.drawRect(
          Rect.fromLTWH(0, 0, px, px),
          Paint()..color = const Color(0xFF000000),
        );
        _paintMonochrome(canvas, px);
    }
  }

  /// Monochrome layer as white, keeping its alpha.
  void _paintMonochrome(Canvas canvas, double px) {
    final rect = Rect.fromLTWH(0, 0, px, px);
    canvas.saveLayer(rect, Paint());
    _paintLayer(canvas, icon.monochrome, px);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
  }

  void _paintLayer(Canvas canvas, Layer layer, double px) {
    canvas.save();
    canvas.scale(px / canvasSize);
    final fill = layer.fill;
    if (fill != null) {
      final paint = _paintFor(fill);
      if (paint != null) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, canvasSize.toDouble(), canvasSize.toDouble()),
          paint,
        );
      }
    }
    final s = request.contentScale * layer.scale;
    canvas
      ..translate(_center, _center)
      ..scale(s)
      ..translate(-_center, -_center);
    for (final e in layer.elements) {
      _paintElement(canvas, e);
    }
    canvas.restore();
  }

  void _paintElement(Canvas canvas, IconElement e) {
    if (e.hidden || e.opacity <= 0) return;
    canvas.save();
    if (e.transform != Transform2D.identity) {
      canvas.transform(_matrix(e.transform));
    }
    if (e.opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, e.opacity),
      );
    }
    switch (e) {
      case PathElement():
        _paintPath(canvas, e);
      case GroupElement():
        for (final c in e.children) {
          _paintElement(canvas, c);
        }
      case RasterElement():
        final image = assets.raster(e.id);
        if (image != null) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            Rect.fromLTWH(0, 0, e.width.toDouble(), e.height.toDouble()),
            Paint()..filterQuality = FilterQuality.high,
          );
        }
      case RawSvgElement():
        final picture = assets.svg(e.id);
        if (picture != null) canvas.drawPicture(picture);
    }
    if (e.opacity < 1) canvas.restore();
    canvas.restore();
  }

  void _paintPath(Canvas canvas, PathElement e) {
    final path = _parsePath(e.d);
    if (path == null) return;
    final fill = e.fill;
    if (fill != null) {
      final paint = _paintFor(fill);
      if (paint != null) canvas.drawPath(path, paint);
    }
    final stroke = e.stroke;
    if (stroke != null && stroke.width > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.width
          ..color = Color(stroke.color.argb),
      );
    }
  }

  @override
  bool shouldRepaint(IconPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.request != request ||
      oldDelegate.assets != assets;
}

/// Paint for [fill], whose coordinates are in the current (local) space.
/// `null` for a gradient without stops.
Paint? _paintFor(Fill fill) {
  switch (fill) {
    case SolidFill(:final color):
      return Paint()..color = Color(color.argb);
    case LinearGradientFill(
      :final stops,
      :final x1,
      :final y1,
      :final x2,
      :final y2,
    ):
      if (stops.isEmpty) return null;
      if (stops.length == 1) return Paint()..color = Color(stops[0].color.argb);
      return Paint()
        ..shader = ui.Gradient.linear(
          Offset(x1, y1),
          Offset(x2, y2),
          [for (final s in stops) Color(s.color.argb)],
          [for (final s in stops) s.offset],
        );
    case RadialGradientFill(:final stops, :final cx, :final cy, :final r):
      if (stops.isEmpty) return null;
      if (stops.length == 1 || r <= 0) {
        return Paint()..color = Color(stops.last.color.argb);
      }
      return Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          r,
          [for (final s in stops) Color(s.color.argb)],
          [for (final s in stops) s.offset],
        );
  }
}

/// Column-major 4x4 of the SVG matrix (a b c d e f).
Float64List _matrix(Transform2D t) => Float64List.fromList([
  t.a, t.b, 0, 0, //
  t.c, t.d, 0, 0, //
  0, 0, 1, 0, //
  t.e, t.f, 0, 1, //
]);

/// Parses SVG path data; `null` when it is malformed.
Path? _parsePath(String d) {
  final proxy = _PathProxy();
  try {
    writeSvgPathDataToPath(d, proxy);
  } catch (_) {
    return null;
  }
  return proxy.path;
}

class _PathProxy extends PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

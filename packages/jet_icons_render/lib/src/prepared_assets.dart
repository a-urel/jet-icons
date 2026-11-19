import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:jet_icons_core/jet_icons_core.dart';

/// Decoded images and SVG pictures an [ResolvedIcon] needs, keyed by element
/// id. Assets that fail to decode are simply absent; the painter skips them.
class PreparedAssets {
  PreparedAssets._(this._rasters, this._svgs, this._owned);

  /// No assets (e.g. before [load] completes).
  PreparedAssets.empty() : this._({}, {}, []);

  final Map<String, ui.Image> _rasters;
  final Map<String, ui.Picture> _svgs;
  final List<ui.Picture> _owned;

  /// Decodes every [RasterElement] and [RawSvgElement] in all three layers,
  /// including group children.
  static Future<PreparedAssets> load(ResolvedIcon icon) async {
    final rasters = <String, ui.Image>{};
    final svgs = <String, ui.Picture>{};
    final owned = <ui.Picture>[];
    final elements = <IconElement>[];
    void collect(List<IconElement> list) {
      for (final e in list) {
        if (e is GroupElement) {
          collect(e.children);
        } else if (e is RasterElement || e is RawSvgElement) {
          elements.add(e);
        }
      }
    }

    collect(icon.background.elements);
    collect(icon.foreground.elements);
    collect(icon.monochrome.elements);

    for (final e in elements) {
      if (rasters.containsKey(e.id) || svgs.containsKey(e.id)) continue;
      switch (e) {
        case RasterElement():
          final image = await _decodeImage(e);
          if (image != null) rasters[e.id] = image;
        case RawSvgElement():
          final info = await _loadSvg(e);
          if (info == null) continue;
          owned.add(info.picture);
          svgs[e.id] = _fitToViewBox(info, e);
        default:
      }
    }
    return PreparedAssets._(rasters, svgs, owned);
  }

  /// Decoded image of the [RasterElement] with [elementId].
  ui.Image? raster(String elementId) => _rasters[elementId];

  /// Picture of the [RawSvgElement] with [elementId], in viewBox units:
  /// it spans 0,0 .. vbWidth,vbHeight.
  ui.Picture? svg(String elementId) => _svgs[elementId];

  /// Releases the native images and pictures.
  void dispose() {
    for (final i in _rasters.values) {
      i.dispose();
    }
    for (final p in [..._svgs.values, ..._owned]) {
      p.dispose();
    }
    _rasters.clear();
    _svgs.clear();
    _owned.clear();
  }

  static Future<ui.Image?> _decodeImage(RasterElement e) async {
    try {
      final codec = await ui.instantiateImageCodec(e.png);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<PictureInfo?> _loadSvg(RawSvgElement e) async {
    try {
      return await vg.loadPicture(SvgStringLoader(e.svg), null);
    } catch (_) {
      return null;
    }
  }

  /// flutter_svg draws in the SVG's width/height space; rescale so the
  /// picture spans the viewBox size, the space the element transform expects.
  static ui.Picture _fitToViewBox(PictureInfo info, RawSvgElement e) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (info.size.width > 0 && info.size.height > 0) {
      canvas.scale(e.vbWidth / info.size.width, e.vbHeight / info.size.height);
    }
    canvas.drawPicture(info.picture);
    return recorder.endRecording();
  }
}

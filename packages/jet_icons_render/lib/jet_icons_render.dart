/// Flutter renderer of jet-icons: draws a `ResolvedIcon` onto a canvas and
/// rasterizes it to PNG. The same painter backs the editor, previews and
/// export.
library;

export 'src/flutter_rasterizer.dart' show FlutterIconRasterizer;
export 'src/icon_painter.dart' show IconPainter;
export 'src/prepared_assets.dart' show PreparedAssets;
export 'src/shape_paths.dart'
    show AndroidMask, androidMaskPath, macBodyPath, shapePath;

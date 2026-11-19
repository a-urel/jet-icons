import 'dart:typed_data';

import '../platforms/output.dart';
import '../resolve/resolver.dart';

/// Renders a [ResolvedIcon] to PNG bytes. Implemented outside core (Flutter).
abstract interface class IconRasterizer {
  Future<Uint8List> renderPng(ResolvedIcon icon, RenderRequest request);
}

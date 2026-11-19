import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Re-encodes [png] as a 3-channel (RGB) PNG with no alpha channel.
Uint8List stripAlpha(Uint8List png) {
  final decoded = img.decodePng(png);
  if (decoded == null) throw ArgumentError('Not a valid PNG.');
  final rgb = decoded.convert(numChannels: 3);
  return Uint8List.fromList(img.encodePng(rgb));
}

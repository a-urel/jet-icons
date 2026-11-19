import 'dart:typed_data';

/// Encodes PNG images into a single PNG-embedded `.ico` file.
///
/// Each image is `(size, png)` with `size` in 1-256 pixels. Throws
/// [ArgumentError] for sizes outside that range or an empty list.
Uint8List encodeIco(List<(int size, Uint8List png)> images) {
  if (images.isEmpty) throw ArgumentError('At least one image is required.');
  for (final (size, _) in images) {
    if (size < 1 || size > 256) {
      throw ArgumentError.value(size, 'size', 'ICO sizes must be 1-256');
    }
  }
  final headerLength = 6 + 16 * images.length;
  final total = images.fold<int>(headerLength, (sum, e) => sum + e.$2.length);
  final out = Uint8List(total);
  final view = ByteData.sublistView(out);
  view.setUint16(0, 0, Endian.little);
  view.setUint16(2, 1, Endian.little);
  view.setUint16(4, images.length, Endian.little);
  var offset = headerLength;
  for (var i = 0; i < images.length; i++) {
    final (size, png) = images[i];
    final e = 6 + 16 * i;
    out[e] = size == 256 ? 0 : size;
    out[e + 1] = size == 256 ? 0 : size;
    out[e + 2] = 0;
    out[e + 3] = 0;
    view.setUint16(e + 4, 1, Endian.little);
    view.setUint16(e + 6, 32, Endian.little);
    view.setUint32(e + 8, png.length, Endian.little);
    view.setUint32(e + 12, offset, Endian.little);
    out.setRange(offset, offset + png.length, png);
    offset += png.length;
  }
  return out;
}

import 'dart:typed_data';

import '../model/element.dart';
import 'fit.dart';
import 'import_result.dart';

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
const _recommendedPx = 1024;

/// Imports PNG bytes as a [RasterElement]. Reads width/height from the IHDR
/// chunk without decoding. Throws [FormatException] if [png] is not a PNG.
ImportResult importPng(
  Uint8List png, {
  required String id,
  String name = 'PNG',
}) {
  if (png.length < 24) {
    throw const FormatException('Not a PNG: data too short');
  }
  for (var i = 0; i < _pngSignature.length; i++) {
    if (png[i] != _pngSignature[i]) {
      throw const FormatException('Not a PNG: bad signature');
    }
  }
  // IHDR chunk: length(4) type(4) then width(4) height(4), big-endian.
  if (String.fromCharCodes(png, 12, 16) != 'IHDR') {
    throw const FormatException('Not a PNG: missing IHDR chunk');
  }
  final data = ByteData.sublistView(png);
  final width = data.getUint32(16, Endian.big);
  final height = data.getUint32(20, Endian.big);
  if (width == 0 || height == 0) {
    throw const FormatException('Invalid PNG: zero dimension');
  }
  final element = RasterElement(
    id: id,
    name: name,
    transform: fitToCanvas(width.toDouble(), height.toDouble()),
    png: png,
    width: width,
    height: height,
  );
  final longest = width > height ? width : height;
  return ImportResult(element, [
    if (longest < _recommendedPx) LowResolution(width, height, _recommendedPx),
  ]);
}

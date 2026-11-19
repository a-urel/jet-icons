import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:test/test.dart';

Uint8List _png(int w, int h) =>
    Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

void main() {
  test('png below 1024 warns low resolution', () {
    final r = importPng(_png(512, 256), id: 'p');
    expect(r.warnings.single, const LowResolution(512, 256, 1024));
    final e = r.element as RasterElement;
    expect(e.width, 512);
    expect(e.height, 256);
    expect(e.name, 'PNG');
    expect(e.transform, fitToCanvas(512, 256));
  });

  test('png at 1024 has no warning', () {
    expect(importPng(_png(1024, 8), id: 'p').warnings, isEmpty);
  });

  test('non-png bytes throw FormatException', () {
    expect(() => importPng(Uint8List(8), id: 'p'), throwsFormatException);
    expect(() => importPng(Uint8List(64), id: 'p'), throwsFormatException);
  });

  test('truncated png after signature throws FormatException', () {
    final bytes = _png(4, 4).sublist(0, 20);
    expect(() => importPng(bytes, id: 'p'), throwsFormatException);
  });
}

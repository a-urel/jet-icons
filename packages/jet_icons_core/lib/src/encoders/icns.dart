import 'dart:convert';
import 'dart:typed_data';

const _types = <(int, String)>[
  (16, 'icp4'),
  (32, 'icp5'),
  (32, 'ic11'),
  (64, 'ic12'),
  (128, 'ic07'),
  (256, 'ic08'),
  (256, 'ic13'),
  (512, 'ic09'),
  (512, 'ic14'),
  (1024, 'ic10'),
];

/// Encodes PNGs keyed by pixel size into a big-endian `.icns` container.
///
/// A size that has two ICNS types gets one entry per type with the same PNG
/// bytes. Throws [ArgumentError] for sizes ICNS cannot represent.
Uint8List encodeIcns(Map<int, Uint8List> pngBySize) {
  final known = _types.map((t) => t.$1).toSet();
  for (final size in pngBySize.keys) {
    if (!known.contains(size)) {
      throw ArgumentError.value(size, 'pngBySize', 'Unsupported ICNS size');
    }
  }
  final entries = <(String, Uint8List)>[
    for (final (size, type) in _types)
      if (pngBySize[size] case final png?) (type, png),
  ];
  final total = entries.fold<int>(8, (sum, e) => sum + 8 + e.$2.length);
  final out = Uint8List(total);
  final view = ByteData.sublistView(out);
  out.setRange(0, 4, ascii.encode('icns'));
  view.setUint32(4, total);
  var o = 8;
  for (final (type, png) in entries) {
    out.setRange(o, o + 4, ascii.encode(type));
    view.setUint32(o + 4, png.length + 8);
    out.setRange(o + 8, o + 8 + png.length, png);
    o += 8 + png.length;
  }
  return out;
}

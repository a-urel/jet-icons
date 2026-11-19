import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:test/test.dart';

Uint8List solidPng(int size, {int alpha = 255}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(10, 20, 30, alpha));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('ico', () {
    final png16 = solidPng(16);
    final png256 = solidPng(256);

    test('header and 256 encoded as 0', () {
      final b = encodeIco([(16, png16), (256, png256)]);
      final v = ByteData.sublistView(b);
      expect(v.getUint16(0, Endian.little), 0);
      expect(v.getUint16(2, Endian.little), 1);
      expect(v.getUint16(4, Endian.little), 2);
      expect(b[6], 16);
      expect(b[7], 16);
      expect(b[6 + 16], 0);
      expect(b[6 + 16 + 1], 0);
      expect(v.getUint16(6 + 4, Endian.little), 1); // planes
      expect(v.getUint16(6 + 6, Endian.little), 32); // bitCount
      expect(v.getUint32(6 + 8, Endian.little), png16.length);
      expect(v.getUint32(6 + 12, Endian.little), 6 + 16 * 2);
      expect(
        v.getUint32(6 + 16 + 12, Endian.little),
        6 + 16 * 2 + png16.length,
      );
      expect(b.length, 6 + 32 + png16.length + png256.length);
      expect(b.sublist(6 + 32, 6 + 32 + png16.length), png16);
    });

    test('rejects sizes outside 1-256', () {
      expect(() => encodeIco([(0, png16)]), throwsArgumentError);
      expect(() => encodeIco([(257, png16)]), throwsArgumentError);
    });
  });

  group('icns', () {
    test('magic, total length, ic10 for 1024', () {
      final png = solidPng(4);
      final b = encodeIcns({1024: png});
      expect(ascii.decode(b.sublist(0, 4)), 'icns');
      expect(ByteData.sublistView(b).getUint32(4), b.length);
      expect(ascii.decode(b.sublist(8, 12)), 'ic10');
      expect(ByteData.sublistView(b).getUint32(12), png.length + 8);
    });

    test('sizes with two types write two entries in brief order', () {
      final png = solidPng(4);
      final b = encodeIcns({256: png, 16: png, 32: png});
      final types = <String>[];
      var o = 8;
      final v = ByteData.sublistView(b);
      while (o < b.length) {
        types.add(ascii.decode(b.sublist(o, o + 4)));
        o += v.getUint32(o + 4);
      }
      expect(types, ['icp4', 'icp5', 'ic11', 'ic08', 'ic13']);
      expect(o, b.length);
    });

    test('64 px is only ic12 (icp6 maps to a 48 px slot)', () {
      final b = encodeIcns({64: solidPng(4)});
      final types = <String>[];
      var o = 8;
      final v = ByteData.sublistView(b);
      while (o < b.length) {
        types.add(ascii.decode(b.sublist(o, o + 4)));
        o += v.getUint32(o + 4);
      }
      expect(types, ['ic12']);
    });

    test('rejects unsupported size', () {
      expect(() => encodeIcns({48: solidPng(4)}), throwsArgumentError);
    });
  });

  group('contents json', () {
    test('ios has dark and tinted appearances', () {
      final text = iosContentsJson();
      expect(text, contains('\n  "images"'));
      final j = jsonDecode(text) as Map;
      final images = j['images'] as List;
      expect(images.length, 3);
      expect((images[0] as Map).containsKey('appearances'), isFalse);
      expect(images[1]['filename'], 'AppIcon-1024-dark.png');
      expect(images[2]['appearances'][0]['value'], 'tinted');
      expect(j['info'], {'author': 'jet-icons', 'version': 1});
    });

    test('macos has 10 entries with expected files', () {
      final j = jsonDecode(macosContentsJson()) as Map;
      final images = (j['images'] as List).cast<Map>();
      expect(images.length, 10);
      final first = images.first;
      expect(first['size'], '16x16');
      expect(first['scale'], '1x');
      expect(first['filename'], 'app_icon_16.png');
      expect(first['idiom'], 'mac');
      final last = images.last;
      expect(last['size'], '512x512');
      expect(last['scale'], '2x');
      expect(last['filename'], 'app_icon_1024.png');
      expect(
        images
            .where((e) => e['size'] == '16x16' && e['scale'] == '2x')
            .single['filename'],
        'app_icon_32.png',
      );
      expect(j['info'], {'author': 'jet-icons', 'version': 1});
    });
  });

  test('adaptive xml contains monochrome only when requested', () {
    final withMono = adaptiveIconXml(includeMonochrome: true);
    expect(withMono, startsWith('<?xml version="1.0" encoding="utf-8"?>'));
    expect(withMono, contains('<monochrome'));
    expect(withMono, contains('@mipmap/ic_launcher_monochrome'));
    final without = adaptiveIconXml(includeMonochrome: false);
    expect(without, isNot(contains('<monochrome')));
    expect(without, contains('@mipmap/ic_launcher_background'));
    expect(without, contains('@mipmap/ic_launcher_foreground'));
  });

  test('web manifest icons', () {
    final j = jsonDecode(webManifestIcons()) as Map;
    final icons = (j['icons'] as List).cast<Map>();
    expect(icons.map((e) => e['src']), [
      'icons/Icon-192.png',
      'icons/Icon-512.png',
      'icons/Icon-maskable-192.png',
      'icons/Icon-maskable-512.png',
    ]);
    expect(icons.map((e) => e['sizes']), [
      '192x192',
      '512x512',
      '192x192',
      '512x512',
    ]);
    expect(icons.map((e) => e['purpose']), [
      'any',
      'any',
      'maskable',
      'maskable',
    ]);
    expect(icons.every((e) => e['type'] == 'image/png'), isTrue);
  });

  test('stripAlpha yields 3-channel png', () {
    final out = img.decodePng(stripAlpha(solidPng(8, alpha: 0)))!;
    expect(out.numChannels, 3);
    expect(out.width, 8);
  });
}

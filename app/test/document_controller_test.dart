import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons/src/document_controller.dart';
import 'package:jet_icons_core/jet_icons_core.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="M0 0H24V24H0Z" fill="#ff0000"/></svg>';

Uint8List _svgBytes() => Uint8List.fromList(utf8.encode(_svg));

IconDocument _docWithBg(int argb) => IconDocument.empty().copyWith(
  background: Layer(SolidFill(JColor(argb)), const []),
);

PathElement _path(String id) => PathElement(id: id, name: id, d: 'M0 0H1V1Z');

void main() {
  group('history', () {
    test('apply/undo/redo', () {
      final c = DocumentController();
      final d1 = _docWithBg(0xFF111111);
      final d2 = _docWithBg(0xFF222222);
      c.apply(d1);
      c.apply(d2);
      expect(c.dirty, isTrue);
      c.undo();
      expect(c.doc, d1);
      expect(c.canRedo, isTrue);
      c.redo();
      expect(c.doc, d2);
      expect(c.canRedo, isFalse);
    });

    test('apply clears redo and notifies', () {
      final c = DocumentController();
      c.apply(_docWithBg(0xFF111111));
      c.undo();
      var n = 0;
      c.addListener(() => n++);
      c.apply(_docWithBg(0xFF333333));
      expect(c.canRedo, isFalse);
      expect(n, 1);
    });

    test('undo history capped at 100', () {
      final c = DocumentController();
      for (var i = 0; i < 150; i++) {
        c.apply(_docWithBg(0xFF000000 + i));
      }
      var undos = 0;
      while (c.canUndo) {
        c.undo();
        undos++;
      }
      expect(undos, 100);
    });

    test('undo clears selection of an element that no longer exists', () {
      final c = DocumentController();
      final d0 = c.doc;
      c.apply(d0.copyWith(foreground: Layer(null, [_path('e1')])));
      c.select(LayerKind.foreground, 'e1');
      expect(c.selectedElementId, 'e1');
      c.undo();
      expect(c.selectedElementId, isNull);
    });

    test('undo keeps selection of an element that still exists', () {
      final c = DocumentController();
      c.apply(c.doc.copyWith(foreground: Layer(null, [_path('e1')])));
      c.apply(c.doc.copyWith(background: const Layer(null, [])));
      c.select(LayerKind.foreground, 'e1');
      c.undo();
      expect(c.selectedElementId, 'e1');
    });

    test('select notifies and stores layer', () {
      final c = DocumentController();
      var n = 0;
      c.addListener(() => n++);
      c.select(LayerKind.monochrome);
      expect(c.selectedLayer, LayerKind.monochrome);
      expect(c.selectedElementId, isNull);
      expect(n, 1);
    });
  });

  group('importBytes', () {
    test('svg adds element to foreground and selects it', () {
      final c = DocumentController();
      final warnings = c.importBytes(
        'logo.SVG',
        _svgBytes(),
        LayerKind.foreground,
      );
      expect(warnings, isEmpty);
      expect(c.doc.foreground.elements, hasLength(1));
      expect(c.doc.foreground.elements.single.id, 'e1');
      expect(c.selectedElementId, 'e1');
      expect(c.selectedLayer, LayerKind.foreground);
      expect(c.dirty, isTrue);
    });

    test('one undo removes the whole import', () {
      final c = DocumentController();
      final before = c.doc;
      c.importBytes('a.svg', _svgBytes(), LayerKind.foreground);
      c.undo();
      expect(c.doc, before);
      expect(c.canUndo, isFalse);
    });

    test('ids skip every id used anywhere in the document', () {
      final c = DocumentController();
      final detached = Layer(null, [_path('e3')]);
      c.apply(
        c.doc.copyWith(
          foreground: Layer(null, [
            _path('e1'),
            GroupElement(id: 'g', name: 'g', children: [_path('e2')]),
          ]),
          overrides: [
            PlatformOverride(
              IconPlatform.ios,
              detached: {LayerKind.background: detached},
            ),
          ],
        ),
      );
      c.importBytes('a.svg', _svgBytes(), LayerKind.foreground);
      expect(c.doc.foreground.elements.last.id, 'e4');
    });

    test('monochrome target starts from empty layer when null', () {
      final c = DocumentController();
      expect(c.doc.monochrome, isNull);
      c.importBytes('a.svg', _svgBytes(), LayerKind.monochrome);
      expect(c.doc.monochrome, isNotNull);
      expect(c.doc.monochrome!.elements, hasLength(1));
      expect(c.selectedLayer, LayerKind.monochrome);
    });

    test('png import returns low resolution warning', () {
      final c = DocumentController();
      final png = Uint8List(32)
        ..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..setAll(12, 'IHDR'.codeUnits);
      ByteData.sublistView(png)
        ..setUint32(16, 10)
        ..setUint32(20, 10);
      final warnings = c.importBytes('a.png', png, LayerKind.background);
      expect(warnings.single, isA<LowResolution>());
      expect(c.doc.background.elements.single, isA<RasterElement>());
    });

    test('unknown extension throws ArgumentError and changes nothing', () {
      final c = DocumentController();
      expect(
        () => c.importBytes('a.jpg', Uint8List(0), LayerKind.foreground),
        throwsArgumentError,
      );
      expect(c.canUndo, isFalse);
    });
  });

  group('file io', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('jet_icons_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('open invalid file keeps current doc', () async {
      final c = DocumentController();
      c.apply(_docWithBg(0xFF111111));
      final before = c.doc;
      final f = File('${tmp.path}/bad.jeticon')..writeAsStringSync('{bad');
      await expectLater(c.open(f.path), throwsA(isA<JeticonFormatException>()));
      expect(c.doc, before);
      expect(c.filePath, isNull);
    });

    test('save then open roundtrips and clears dirty', () async {
      final c = DocumentController();
      c.importBytes('a.svg', _svgBytes(), LayerKind.foreground);
      final path = '${tmp.path}/x.jeticon';
      await c.save(path);
      expect(c.dirty, isFalse);
      expect(c.filePath, path);

      final c2 = DocumentController();
      c2.apply(_docWithBg(0xFF111111));
      await c2.open(path);
      expect(c2.doc, c.doc);
      expect(c2.filePath, path);
      expect(c2.dirty, isFalse);
      expect(c2.canUndo, isFalse);
      expect(c2.canRedo, isFalse);
    });

    test('save without path reuses filePath', () async {
      final c = DocumentController();
      final path = '${tmp.path}/x.jeticon';
      await c.save(path);
      c.apply(_docWithBg(0xFF222222));
      expect(c.dirty, isTrue);
      await c.save();
      expect(c.dirty, isFalse);
      expect(decodeJeticon(File(path).readAsStringSync()), c.doc);
    });

    test('save without any path throws StateError', () async {
      final c = DocumentController();
      await expectLater(c.save(), throwsStateError);
    });
  });
}

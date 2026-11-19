import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jet_icons/src/document_controller.dart';
import 'package:jet_icons/src/export/export_io.dart';
import 'package:jet_icons/src/export/export_tab.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

class _FakeRasterizer implements IconRasterizer {
  @override
  Future<Uint8List> renderPng(ResolvedIcon icon, RenderRequest request) async =>
      Uint8List.fromList(
        img.encodePng(img.Image(width: request.sizePx, height: request.sizePx)),
      );
}

DocumentController _controller() => DocumentController(
  IconDocument.empty().copyWith(
    foreground: const Layer(null, [
      PathElement(
        id: 'e1',
        name: 'sekil',
        d: 'M100 100 L300 100 L300 300 L100 300 Z',
        fill: SolidFill(JColor(0xFF000000)),
      ),
    ]),
  ),
);

class _Calls {
  final writes = <(String, Uint8List)>[];
  final folders = <(String, bool)>[];
  final reveals = <String>[];
}

ExportIo _io(
  _Calls calls, {
  String? zipPath = '/tmp/out',
  Set<String> existing = const {},
  String? dir = '/tmp/parent',
  Future<Directory> Function(ExportBundle, Directory, {bool overwrite})?
  writeFolder,
}) => ExportIo(
  pickZipPath: () async => zipPath,
  pickDirectory: () async => dir,
  writeFolder:
      writeFolder ??
      (b, d, {overwrite = false}) async {
        calls.folders.add((d.path, overwrite));
        return Directory('${d.path}/jet-icons-export');
      },
  writeFile: (p, b) async => calls.writes.add((p, b)),
  exists: (p) async => existing.contains(p),
  revealFolder: (p) async => calls.reveals.add(p),
);

Future<void> _pump(WidgetTester t, DocumentController c, ExportIo io) async {
  t.view.physicalSize = const Size(1200, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExportTab(controller: c, rasterizer: _FakeRasterizer(), io: io),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _only(WidgetTester t, IconPlatform keep) async {
  for (final p in IconPlatform.values) {
    if (p == keep) continue;
    await t.tap(find.byKey(Key('export-platform-${p.name}')));
  }
  await t.pump();
}

void main() {
  testWidgets('file list reflects selected platforms', (t) async {
    final c = _controller();
    await _pump(t, c, _io(_Calls()));
    expect(
      find.text(
        '${plannedPaths(c.doc, IconPlatform.values.toSet()).length} dosya yazılacak',
      ),
      findsOneWidget,
    );
    await _only(t, IconPlatform.windows);
    expect(find.text('windows/app_icon.ico'), findsOneWidget);
    expect(find.text('1 dosya yazılacak'), findsOneWidget);
    expect(find.textContaining('ios/'), findsNothing);
  });

  testWidgets('no platform selected disables export', (t) async {
    await _pump(t, _controller(), _io(_Calls()));
    for (final p in IconPlatform.values) {
      await t.tap(find.byKey(Key('export-platform-${p.name}')));
    }
    await t.pump();
    expect(
      t.widget<FilledButton>(find.byKey(const Key('export-button'))).onPressed,
      isNull,
    );
  });

  testWidgets('zip export appends .zip and reports success', (t) async {
    final calls = _Calls();
    await _pump(t, _controller(), _io(calls));
    await _only(t, IconPlatform.windows);
    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    expect(calls.writes.single.$1, '/tmp/out.zip');
    expect(calls.writes.single.$2.sublist(0, 2), [0x50, 0x4B]);
    expect(find.text('Dışa aktarıldı: /tmp/out.zip'), findsOneWidget);
  });

  testWidgets('adjusted zip path that exists asks before overwriting', (
    t,
  ) async {
    final calls = _Calls();
    await _pump(t, _controller(), _io(calls, existing: {'/tmp/out.zip'}));
    await _only(t, IconPlatform.windows);
    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    expect(
      find.text('/tmp/out.zip zaten var. Üzerine yazılsın mı?'),
      findsOneWidget,
    );
    expect(calls.writes, isEmpty);

    await t.tap(find.text('İptal'));
    await _settle(t);
    expect(calls.writes, isEmpty);
    expect(find.byType(SnackBar), findsNothing);

    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    await t.tap(find.text('Üzerine yaz'));
    await _settle(t);
    expect(calls.writes.single.$1, '/tmp/out.zip');
  });

  testWidgets('picked .zip path is not re-confirmed', (t) async {
    final calls = _Calls();
    await _pump(
      t,
      _controller(),
      _io(calls, zipPath: '/tmp/out.zip', existing: {'/tmp/out.zip'}),
    );
    await _only(t, IconPlatform.windows);
    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    expect(find.text('Üzerine yaz'), findsNothing);
    expect(calls.writes.single.$1, '/tmp/out.zip');
  });

  testWidgets('cancelled picker does nothing', (t) async {
    final calls = _Calls();
    await _pump(t, _controller(), _io(calls, zipPath: null));
    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    expect(calls.writes, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('folder mode writes and offers reveal', (t) async {
    final calls = _Calls();
    await _pump(t, _controller(), _io(calls));
    await _only(t, IconPlatform.windows);
    await t.tap(find.text('Klasör'));
    await t.pump();
    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    expect(calls.folders.single, ('/tmp/parent', false));
    expect(
      find.text('Dışa aktarıldı: /tmp/parent/jet-icons-export'),
      findsOneWidget,
    );
    await t.tap(find.text('Klasörü göster'));
    await t.pump();
    expect(calls.reveals.single, '/tmp/parent/jet-icons-export');
  });

  testWidgets('existing folder asks before overwrite', (t) async {
    final calls = _Calls();
    var n = 0;
    final io = _io(
      calls,
      writeFolder: (b, d, {overwrite = false}) async {
        calls.folders.add((d.path, overwrite));
        n++;
        if (!overwrite) throw ExportTargetExistsException('/tmp/x/dir');
        return Directory('/tmp/x/dir');
      },
    );
    await _pump(t, _controller(), io);
    await _only(t, IconPlatform.windows);
    await t.tap(find.text('Klasör'));
    await t.pump();
    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    expect(
      find.text(
        '/tmp/x/dir zaten var ve boş değil. Aynı adlı dosyaların üzerine '
        'yazılsın mı? Diğer dosyalara dokunulmaz.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('İptal'));
    await _settle(t);
    expect(n, 1);
    expect(find.byType(SnackBar), findsNothing);

    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    await t.tap(find.text('Üzerine yaz'));
    await _settle(t);
    expect(calls.folders.last.$2, true);
    expect(n, 3);
    expect(find.text('Dışa aktarıldı: /tmp/x/dir'), findsOneWidget);
  });

  testWidgets('other errors show a failure snackbar', (t) async {
    final calls = _Calls();
    final io = _io(
      calls,
      writeFolder: (b, d, {overwrite = false}) async =>
          throw const FileSystemException('disk dolu'),
    );
    await _pump(t, _controller(), io);
    await _only(t, IconPlatform.windows);
    await t.tap(find.text('Klasör'));
    await t.pump();
    await t.tap(find.byKey(const Key('export-button')));
    await _settle(t);
    expect(find.textContaining('Dışa aktarma başarısız:'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('export-button'))).onPressed,
      isNotNull,
    );
  });
}

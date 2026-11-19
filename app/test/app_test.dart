import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons/src/app.dart';
import 'package:jet_icons/src/document_controller.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester t,
  DocumentController c, {
  PickOpenPath? open,
  PickSavePath? save,
}) => t.pumpWidget(
  JetIconsApp(
    controller: c,
    pickOpenPath: open ?? () async => null,
    pickSavePath: save ?? () async => null,
  ),
);

Future<void> _chord(
  WidgetTester t,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  final mod = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await t.sendKeyDownEvent(mod);
  if (shift) await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyEvent(key);
  if (shift) await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyUpEvent(mod);
  await t.pump();
}

/// Lets real file IO started from a widget callback finish.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }
}

void main() {
  testWidgets('app shows three tabs', (t) async {
    await _pump(t, DocumentController());
    expect(find.byKey(const Key('tab-design')), findsOneWidget);
    expect(find.byKey(const Key('tab-platforms')), findsOneWidget);
    expect(find.byKey(const Key('tab-export')), findsOneWidget);
    expect(find.text('Tasarla'), findsWidgets);
    expect(find.text('Platformlar'), findsWidgets);
    expect(find.text('Dışa aktar'), findsWidgets);
  });

  testWidgets('app bar actions have Turkish tooltips', (t) async {
    await _pump(t, DocumentController());
    for (final tip in ['Aç', 'Kaydet', 'Farklı kaydet', 'Geri al', 'Yinele']) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
    }
  });

  testWidgets('undo/redo shortcuts drive the controller', (t) async {
    final c = DocumentController();
    final d1 = c.doc.copyWith(background: const Layer(null, []));
    c.apply(d1);
    await _pump(t, c);
    await _chord(t, LogicalKeyboardKey.keyZ);
    expect(c.canUndo, isFalse);
    expect(c.canRedo, isTrue);
    await _chord(t, LogicalKeyboardKey.keyZ, shift: true);
    expect(c.doc, d1);
  });

  testWidgets('title shows file name and dirty marker', (t) async {
    final c = DocumentController();
    await _pump(t, c);
    expect(t.widget<MaterialApp>(find.byType(MaterialApp)).title, 'jet-icons');
    c.apply(c.doc.copyWith(background: const Layer(null, [])));
    await t.pump();
    expect(
      t.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'jet-icons •',
    );
  });

  testWidgets('opening an invalid file shows a snackbar', (t) async {
    final dir = Directory.systemTemp.createTempSync('jet_icons_app_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/bad.jeticon')..writeAsStringSync('{bad');
    final c = DocumentController();
    await _pump(t, c, open: () async => bad.path);

    await t.tap(find.byKey(const Key('action-open')));
    await _settle(t);

    expect(
      find.textContaining('Dosya açılamadı: Invalid JSON'),
      findsOneWidget,
    );
  });

  testWidgets('save without path routes to Save As', (t) async {
    final dir = Directory.systemTemp.createTempSync('jet_icons_app_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final target = '${dir.path}/out.jeticon';
    final c = DocumentController();
    await _pump(t, c, save: () async => target);

    await t.tap(find.byKey(const Key('action-save')));
    await _settle(t);

    expect(c.filePath, target);
    expect(File(target).existsSync(), isTrue);
    expect(
      t.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'jet-icons — out.jeticon',
    );
  });

  testWidgets('save failure from an unencodable value shows a snackbar', (
    t,
  ) async {
    final dir = Directory.systemTemp.createTempSync('jet_icons_app_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = DocumentController(
      IconDocument.empty().copyWith(extra: {'bad': Object()}),
    );
    await _pump(t, c, save: () async => '${dir.path}/out.jeticon');

    await t.tap(find.byKey(const Key('action-save')));
    await _settle(t);

    expect(find.textContaining('Kaydedilemedi:'), findsOneWidget);
  });

  group('open with unsaved changes', () {
    late Directory dir;
    late File good;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('jet_icons_app_test');
      good = File('${dir.path}/good.jeticon')
        ..writeAsStringSync(encodeJeticon(IconDocument.empty()));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    DocumentController dirty() {
      final c = DocumentController();
      c.apply(c.doc.copyWith(background: const Layer(null, [])));
      return c;
    }

    testWidgets('cancel keeps the document and never picks a file', (t) async {
      var picked = 0;
      final c = dirty();
      await _pump(
        t,
        c,
        open: () async {
          picked++;
          return good.path;
        },
      );
      await t.tap(find.byKey(const Key('action-open')));
      await t.pumpAndSettle();
      expect(find.text('Kaydedilmemiş değişiklikler'), findsOneWidget);
      expect(
        find.text('Açık dosyadaki değişiklikler kaybolacak. Devam edilsin mi?'),
        findsOneWidget,
      );
      await t.tap(find.text('İptal'));
      await t.pumpAndSettle();
      expect(picked, 0);
      expect(c.dirty, isTrue);
      expect(c.filePath, isNull);
    });

    testWidgets('continue opens the file', (t) async {
      final c = dirty();
      await _pump(t, c, open: () async => good.path);
      await t.tap(find.byKey(const Key('action-open')));
      await t.pumpAndSettle();
      await t.tap(find.text('Devam et'));
      await _settle(t);
      expect(c.filePath, good.path);
      expect(c.dirty, isFalse);
    });

    testWidgets('clean document opens without a dialog', (t) async {
      final c = DocumentController();
      await _pump(t, c, open: () async => good.path);
      await t.tap(find.byKey(const Key('action-open')));
      await _settle(t);
      expect(find.text('Kaydedilmemiş değişiklikler'), findsNothing);
      expect(c.filePath, good.path);
    });
  });
}

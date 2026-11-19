import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

import 'design/design_tab.dart';
import 'document_controller.dart';
import 'export/export_tab.dart';
import 'platforms/platforms_tab.dart';

const _jeticonType = XTypeGroup(label: 'jet-icons', extensions: ['jeticon']);

/// Asks the user for an existing `.jeticon` path; `null` when cancelled.
typedef PickOpenPath = Future<String?> Function();

/// Asks the user where to save; `null` when cancelled.
typedef PickSavePath = Future<String?> Function();

Future<String?> _defaultPickOpenPath() async =>
    (await openFile(acceptedTypeGroups: const [_jeticonType]))?.path;

Future<String?> _defaultPickSavePath() async => (await getSaveLocation(
  acceptedTypeGroups: const [_jeticonType],
  suggestedName: 'icon.jeticon',
))?.path;

class JetIconsApp extends StatelessWidget {
  const JetIconsApp({
    super.key,
    required this.controller,
    this.pickOpenPath = _defaultPickOpenPath,
    this.pickSavePath = _defaultPickSavePath,
  });

  final DocumentController controller;
  final PickOpenPath pickOpenPath;
  final PickSavePath pickSavePath;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: windowTitle(controller),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: _Shell(
          controller: controller,
          pickOpenPath: pickOpenPath,
          pickSavePath: pickSavePath,
        ),
      ),
    );
  }
}

/// `jet-icons — <file name> •` (the file name only once saved/opened, the dot
/// only while there are unsaved changes).
String windowTitle(DocumentController c) {
  final path = c.filePath;
  final name = path?.split(RegExp(r'[/\\]')).last;
  return ['jet-icons', if (name != null) ' — $name', if (c.dirty) ' •'].join();
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.controller,
    required this.pickOpenPath,
    required this.pickSavePath,
  });

  final DocumentController controller;
  final PickOpenPath pickOpenPath;
  final PickSavePath pickSavePath;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await pickOpenPath();
    if (path == null) return;
    try {
      await controller.open(path);
    } on JeticonFormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Dosya açılamadı: ${e.message}')),
      );
    } on FileSystemException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Dosya açılamadı: ${e.message}')),
      );
    }
  }

  Future<void> _save(BuildContext context) async {
    if (controller.filePath == null) return _saveAs(context);
    await _write(context, null);
  }

  Future<void> _saveAs(BuildContext context) async {
    final path = await pickSavePath();
    if (path == null || !context.mounted) return;
    await _write(context, path);
  }

  Future<void> _write(BuildContext context, String? path) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.save(path);
    } on FileSystemException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Dosya kaydedilemedi: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    SingleActivator key(LogicalKeyboardKey k, {bool shift = false}) =>
        SingleActivator(k, meta: mac, control: !mac, shift: shift);

    return CallbackShortcuts(
      bindings: {
        key(LogicalKeyboardKey.keyZ): controller.undo,
        key(LogicalKeyboardKey.keyZ, shift: true): controller.redo,
        key(LogicalKeyboardKey.keyS): () => _save(context),
        key(LogicalKeyboardKey.keyO): () => _open(context),
      },
      child: Focus(
        autofocus: true,
        child: DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('jet-icons'),
              actions: [
                IconButton(
                  key: const Key('action-open'),
                  tooltip: 'Aç',
                  icon: const Icon(Icons.folder_open),
                  onPressed: () => _open(context),
                ),
                IconButton(
                  key: const Key('action-save'),
                  tooltip: 'Kaydet',
                  icon: const Icon(Icons.save),
                  onPressed: () => _save(context),
                ),
                IconButton(
                  key: const Key('action-save-as'),
                  tooltip: 'Farklı kaydet',
                  icon: const Icon(Icons.save_as),
                  onPressed: () => _saveAs(context),
                ),
                IconButton(
                  key: const Key('action-undo'),
                  tooltip: 'Geri al',
                  icon: const Icon(Icons.undo),
                  onPressed: controller.canUndo ? controller.undo : null,
                ),
                IconButton(
                  key: const Key('action-redo'),
                  tooltip: 'Yinele',
                  icon: const Icon(Icons.redo),
                  onPressed: controller.canRedo ? controller.redo : null,
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(key: Key('tab-design'), text: 'Tasarla'),
                  Tab(key: Key('tab-platforms'), text: 'Platformlar'),
                  Tab(key: Key('tab-export'), text: 'Dışa aktar'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                DesignTab(controller: controller),
                PlatformsTab(controller: controller),
                ExportTab(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

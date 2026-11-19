import 'dart:io';

import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';
import 'package:material_ui/material_ui.dart';

import '../document_controller.dart';
import 'export_io.dart';

enum _Mode { zip, folder }

/// The "Dışa aktar" tab: pick platforms, see what will be written, export to
/// a zip or a folder.
class ExportTab extends StatefulWidget {
  const ExportTab({
    super.key,
    required this.controller,
    this.rasterizer,
    this.io,
  });

  final DocumentController controller;
  final IconRasterizer? rasterizer;
  final ExportIo? io;

  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  final Set<IconPlatform> _selected = {...IconPlatform.values};
  _Mode _mode = _Mode.zip;
  bool _busy = false;
  double? _progress;

  late final IconRasterizer _rasterizer =
      widget.rasterizer ?? const FlutterIconRasterizer();
  late final ExportIo _io = widget.io ?? const ExportIo();

  Future<ExportBundle> _render() => runExport(
    widget.controller.doc,
    {..._selected},
    _rasterizer,
    onProgress: (done, total) {
      if (mounted) setState(() => _progress = total == 0 ? 1 : done / total);
    },
  );

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final String? path;
      switch (_mode) {
        case _Mode.zip:
          path = await _exportZip();
        case _Mode.folder:
          path = await _exportFolder();
      }
      if (path == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Dışa aktarıldı: $path'),
          action: _mode == _Mode.folder
              ? SnackBarAction(
                  label: 'Klasörü göster',
                  onPressed: () => _io.revealFolder(path!),
                )
              : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Dışa aktarma başarısız: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<String?> _exportZip() async {
    var path = await _io.pickZipPath();
    if (path == null) return null;
    if (!path.toLowerCase().endsWith('.zip')) path = '$path.zip';
    final bundle = await _render();
    await _io.writeFile(path, encodeZip(bundle));
    return path;
  }

  Future<String?> _exportFolder() async {
    final parent = await _io.pickDirectory();
    if (parent == null) return null;
    final bundle = await _render();
    try {
      return (await _io.writeFolder(bundle, Directory(parent))).path;
    } on ExportTargetExistsException catch (e) {
      if (!mounted || !await _confirmOverwrite(e.targetPath)) return null;
      return (await _io.writeFolder(
        bundle,
        Directory(parent),
        overwrite: true,
      )).path;
    }
  }

  Future<bool> _confirmOverwrite(String path) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(
            '$path zaten var ve boş değil. Aynı adlı dosyaların üzerine '
            'yazılsın mı? Diğer dosyalara dokunulmaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Üzerine yaz'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final paths = plannedPaths(widget.controller.doc, _selected);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                children: [
                  for (final p in IconPlatform.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          key: Key('export-platform-${p.name}'),
                          value: _selected.contains(p),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                  v == true
                                      ? _selected.add(p)
                                      : _selected.remove(p);
                                }),
                        ),
                        Text(p.name),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(value: _Mode.zip, label: Text('Zip')),
                  ButtonSegment(value: _Mode.folder, label: Text('Klasör')),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 12),
              Text(
                '${paths.length} dosya yazılacak',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(children: [for (final p in paths) Text(p)]),
              ),
              if (_busy) LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('export-button'),
                onPressed: _busy || _selected.isEmpty ? null : _export,
                child: const Text('Dışa aktar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

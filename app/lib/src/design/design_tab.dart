import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

import '../document_controller.dart';
import '../shared/doc_assets.dart';
import 'canvas_view.dart';
import 'layers_panel.dart';
import 'preview_strip.dart';
import 'properties_panel.dart';

/// Picks a logo file to import; `null` when cancelled.
typedef PickImportFile = Future<(String name, Uint8List bytes)?> Function();

Future<(String, Uint8List)?> _defaultPickImportFile() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Logo', extensions: ['svg', 'png']),
    ],
  );
  if (file == null) return null;
  return (file.name, await file.readAsBytes());
}

/// "Tasarla" tab: layers (left), canvas (center), properties (right) and
/// per-platform previews (bottom).
class DesignTab extends StatefulWidget {
  const DesignTab({super.key, required this.controller, this.pickImportFile});

  final DocumentController controller;
  final PickImportFile? pickImportFile;

  @override
  State<DesignTab> createState() => _DesignTabState();
}

class _DesignTabState extends State<DesignTab> with DocAssetsMixin<DesignTab> {
  bool _safeZone = false;
  bool _macBody = false;

  DocumentController get _c => widget.controller;

  @override
  DocumentController get docController => widget.controller;

  @override
  void initState() {
    super.initState();
    initDocAssets();
  }

  @override
  void didUpdateWidget(DesignTab old) {
    super.didUpdateWidget(old);
    rebindDocAssets(old.controller);
  }

  @override
  void dispose() {
    disposeDocAssets();
    super.dispose();
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await (widget.pickImportFile ?? _defaultPickImportFile)();
    if (picked == null) return;
    try {
      final warnings = _c.importBytes(picked.$1, picked.$2, _c.selectedLayer);
      for (final w in warnings) {
        messenger.showSnackBar(SnackBar(content: Text(_warningText(w))));
      }
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('İçe aktarılamadı: ${e.message}')),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('İçe aktarılamadı: ${e.message}')),
      );
    }
  }

  static String _warningText(ImportWarning w) => switch (w) {
    UnsupportedSvgFeatures(:final tags) =>
      "Bu SVG'de düzenlenemeyen öğeler var: ${tags.join(', ')}",
    LowResolution(:final width, :final height, :final recommended) =>
      'Görsel $width×$height — en az $recommended×$recommended önerilir',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: LayersPanel(controller: _c, onImport: _import),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        children: [
                          _guide(
                            'Güvenli bölge',
                            const Key('guide-safe-zone'),
                            _safeZone,
                            (v) => setState(() => _safeZone = v),
                          ),
                          _guide(
                            'macOS gövdesi',
                            const Key('guide-mac-body'),
                            _macBody,
                            (v) => setState(() => _macBody = v),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: CanvasView(
                            controller: _c,
                            assets: assets,
                            showSafeZone: _safeZone,
                            showMacBody: _macBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(width: 280, child: PropertiesPanel(controller: _c)),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 96,
            child: PreviewStrip(doc: _c.doc, assets: assets),
          ),
        ],
      ),
    );
  }

  Widget _guide(String label, Key key, bool value, ValueChanged<bool> on) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(key: key, value: value, onChanged: on),
          Text(label),
        ],
      );
}

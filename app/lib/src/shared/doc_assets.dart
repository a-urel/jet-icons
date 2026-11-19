import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';
import 'package:material_ui/material_ui.dart';

import '../design/doc_edit.dart';
import '../document_controller.dart';

/// Keeps a [PreparedAssets] in sync with the document of
/// [docController]: reloads the decoded rasters / SVG pictures whenever the
/// set of such elements changes, and disposes them with the state.
///
/// Call [initDocAssets] from `initState`, [rebindDocAssets] from
/// `didUpdateWidget` when the controller may have changed, and
/// [disposeDocAssets] from `dispose`.
mixin DocAssetsMixin<T extends StatefulWidget> on State<T> {
  PreparedAssets assets = PreparedAssets.empty();
  String _assetKey = '';
  int _generation = 0;

  DocumentController get docController;

  void initDocAssets() {
    docController.addListener(_refreshAssets);
    _refreshAssets();
  }

  void rebindDocAssets(DocumentController old) {
    if (old == docController) return;
    old.removeListener(_refreshAssets);
    docController.addListener(_refreshAssets);
    _refreshAssets();
  }

  void disposeDocAssets() {
    docController.removeListener(_refreshAssets);
    _generation++;
    assets.dispose();
  }

  void _refreshAssets() {
    final elements = assetElements(docController.doc);
    final key = (elements.map((e) => e.id).toList()..sort()).join('\u0000');
    if (key == _assetKey) return;
    _assetKey = key;
    final generation = ++_generation;
    if (elements.isEmpty) {
      final old = assets;
      setState(() => assets = PreparedAssets.empty());
      old.dispose();
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    PreparedAssets.load(
          ResolvedIcon(
            Layer(null, elements),
            const Layer(null, []),
            const Layer(null, []),
          ),
        )
        .then((loaded) {
          if (!mounted || generation != _generation) {
            loaded.dispose();
            return;
          }
          final old = assets;
          setState(() => assets = loaded);
          old.dispose();
        })
        .catchError((Object _) {
          if (!mounted || generation != _generation) return;
          // Keep painting without assets; the next asset-set change retries.
          messenger?.showSnackBar(
            const SnackBar(content: Text('Görsel yüklenemedi')),
          );
        });
  }
}

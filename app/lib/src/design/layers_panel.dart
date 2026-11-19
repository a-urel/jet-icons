import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

import '../document_controller.dart';
import 'doc_edit.dart';

/// Left panel: layers with their elements, import button and the
/// monochrome derive switch.
class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.controller,
    required this.onImport,
  });

  final DocumentController controller;
  final VoidCallback onImport;

  void _toggleHidden(LayerKind kind, IconElement e) => controller.apply(
    updateElement(controller.doc, kind, e.id, (x) => withHidden(x, !x.hidden)),
  );

  void _delete(LayerKind kind, IconElement e) {
    final wasSelected = controller.selectedElementId == e.id;
    controller.apply(removeElement(controller.doc, kind, e.id));
    if (wasSelected) controller.select(kind);
  }

  @override
  Widget build(BuildContext context) {
    final doc = controller.doc;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        FilledButton.icon(
          key: const Key('import-button'),
          onPressed: onImport,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('İçe aktar'),
        ),
        const SizedBox(height: 8),
        _header(context, LayerKind.background, 'Arka plan'),
        ..._elements(context, LayerKind.background),
        _header(context, LayerKind.foreground, 'Ön plan'),
        ..._elements(context, LayerKind.foreground),
        _header(
          context,
          LayerKind.monochrome,
          'Monokrom',
          trailing: Row(
            children: [
              const Expanded(child: Text('Ön plandan türet')),
              Switch(
                key: const Key('derive-mono-switch'),
                value: doc.monochrome == null,
                onChanged: (derive) => controller.apply(
                  doc.copyWith(
                    monochrome: derive ? null : const Layer(null, []),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (doc.monochrome != null) ..._elements(context, LayerKind.monochrome),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    LayerKind kind,
    String title, {
    Widget? trailing,
  }) {
    final selected =
        controller.selectedLayer == kind &&
        controller.selectedElementId == null;
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Colors.transparent,
      child: InkWell(
        key: Key('layer-${kind.name}'),
        onTap: () => controller.select(kind),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _elements(BuildContext context, LayerKind kind) => [
    for (final e in layerOf(controller.doc, kind).elements)
      ListTile(
        key: Key('element-${e.id}'),
        dense: true,
        selected:
            controller.selectedLayer == kind &&
            controller.selectedElementId == e.id,
        contentPadding: const EdgeInsets.only(left: 12),
        title: Text(e.name, overflow: TextOverflow.ellipsis),
        onTap: () => controller.select(kind, e.id),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('hide-${e.id}'),
              tooltip: e.hidden ? 'Göster' : 'Gizle',
              icon: Icon(e.hidden ? Icons.visibility_off : Icons.visibility),
              onPressed: () => _toggleHidden(kind, e),
            ),
            IconButton(
              key: Key('delete-${e.id}'),
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(kind, e),
            ),
          ],
        ),
      ),
  ];
}

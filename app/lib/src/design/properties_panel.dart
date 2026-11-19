import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

import '../document_controller.dart';
import 'doc_edit.dart';
import 'element_bounds.dart';
import 'fill_editor.dart';

const _canvasArea = ui.Rect.fromLTWH(0, 0, 1024, 1024);
const _bgRadius = 724.0;

/// Right panel: fill of the selected layer, or opacity / scale / fill /
/// delete of the selected element, plus the layer padding (`scale`).
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key, required this.controller});

  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final kind = c.selectedLayer;
    final layer = layerOf(c.doc, kind);
    final id = c.selectedElementId;
    final element = id == null ? null : findElement(layer, id);
    final hasLayer = kind != LayerKind.monochrome || c.doc.monochrome != null;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (element != null) ..._elementSection(context, kind, element),
        if (element == null && kind == LayerKind.background) ...[
          Text('Dolgu', style: Theme.of(context).textTheme.titleSmall),
          FillEditor(
            key: const Key('background-fill'),
            fill: layer.fill,
            area: _canvasArea,
            radialRadius: _bgRadius,
            onChanged: (f) =>
                c.apply(withLayer(c.doc, kind, layer.copyWith(fill: f))),
          ),
        ],
        if (hasLayer) ...[
          const SizedBox(height: 16),
          Text('Kenar boşluğu', style: Theme.of(context).textTheme.titleSmall),
          Slider(
            key: const Key('layer-scale'),
            min: 0.25,
            max: 1.5,
            value: layer.scale.clamp(0.25, 1.5),
            label: '${(layer.scale * 100).round()}%',
            onChangeStart: (_) => c.beginGesture(),
            onChanged: (v) =>
                c.preview(withLayer(c.doc, kind, layer.copyWith(scale: v))),
            onChangeEnd: (_) => c.endGesture(),
          ),
        ],
        if (element == null && kind != LayerKind.background && !hasLayer)
          const Text('Monokrom katman ön plandan türetiliyor.'),
      ],
    );
  }

  List<Widget> _elementSection(
    BuildContext context,
    LayerKind kind,
    IconElement e,
  ) {
    final c = controller;
    final title = Theme.of(context).textTheme.titleSmall;
    return [
      Text(e.name, style: title, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 12),
      Text('Opaklık', style: title),
      Slider(
        key: const Key('opacity-slider'),
        value: e.opacity.clamp(0.0, 1.0),
        label: '${(e.opacity * 100).round()}%',
        onChangeStart: (_) => c.beginGesture(),
        onChanged: (v) => c.preview(
          updateElement(c.doc, kind, e.id, (x) => withOpacity(x, v)),
        ),
        onChangeEnd: (_) => c.endGesture(),
      ),
      Text('Ölçek', style: title),
      _ScaleField(
        key: ValueKey('scale-field-${e.id}'),
        onScale: (k) {
          final center = elementBounds(e).center;
          c.apply(
            updateElement(c.doc, kind, e.id, (x) => scaledAbout(x, k, center)),
          );
        },
      ),
      if (e is PathElement) ...[
        const SizedBox(height: 12),
        Text('Dolgu', style: title),
        FillEditor(
          key: Key('element-fill-${e.id}'),
          fill: e.fill,
          area: localBounds(e),
          onChanged: (f) => c.apply(
            updateElement(
              c.doc,
              kind,
              e.id,
              (x) => (x as PathElement).copyWith(fill: f),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('delete-selected'),
        onPressed: () {
          c.apply(removeElement(c.doc, kind, e.id));
          c.select(kind);
        },
        icon: const Icon(Icons.delete_outline),
        label: const Text('Sil'),
      ),
    ];
  }
}

const _minScalePct = 1.0;
const _maxScalePct = 10000.0;

/// Percentage field: relative to the current size (clamped to 1%-10000%), applied on submit,
/// then reset to 100.
class _ScaleField extends StatefulWidget {
  const _ScaleField({super.key, required this.onScale});

  final ValueChanged<double> onScale;

  @override
  State<_ScaleField> createState() => _ScaleFieldState();
}

class _ScaleFieldState extends State<_ScaleField> {
  final _text = TextEditingController(text: '100');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final pct = double.tryParse(value.replaceAll(',', '.'));
    if (pct != null && pct.isFinite && pct > 0 && pct != 100) {
      widget.onScale(pct.clamp(_minScalePct, _maxScalePct) / 100);
    }
    _text.text = '100';
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('scale-field'),
    controller: _text,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: const InputDecoration(isDense: true, suffixText: '%'),
    onSubmitted: _submit,
  );
}

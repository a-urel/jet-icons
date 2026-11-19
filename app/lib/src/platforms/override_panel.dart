import 'dart:ui' as ui;

import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

import '../design/doc_edit.dart';
import '../design/fill_editor.dart';
import '../document_controller.dart';
import 'override_edit.dart';

const _canvasArea = ui.Rect.fromLTWH(0, 0, 1024, 1024);
const _bgRadius = 724.0;

/// Output sizes that per-size overrides can be scoped to.
const rangeSizes = <IconPlatform, List<int>>{
  IconPlatform.windows: [16, 24, 32, 48, 64, 128, 256],
  IconPlatform.linux: [16, 22, 24, 32, 48, 64, 128, 256, 512],
  IconPlatform.web: [16, 32, 48, 180, 192, 512],
};

const _layerNames = {
  LayerKind.background: 'Arka plan',
  LayerKind.foreground: 'Ön plan',
  LayerKind.monochrome: 'Monokrom',
};

/// Right panel of the platforms tab: size range, layer patches, element
/// patches and detach / reattach for the override identified by
/// `(platform, variant, range)`.
class OverridePanel extends StatelessWidget {
  const OverridePanel({
    super.key,
    required this.controller,
    required this.platform,
    required this.variant,
    required this.range,
    required this.onRangeChanged,
  });

  final DocumentController controller;
  final IconPlatform platform;

  /// Override variant: only iOS uses one.
  final IconVariant? variant;
  final SizeRange? range;
  final ValueChanged<SizeRange?> onRangeChanged;

  DocumentController get _c => controller;

  List<LayerKind> get _kinds => [
    LayerKind.background,
    LayerKind.foreground,
    if (platform == IconPlatform.android ||
        (platform == IconPlatform.ios && variant == IconVariant.tinted))
      LayerKind.monochrome,
  ];

  @override
  Widget build(BuildContext context) {
    final sizes = rangeSizes[platform];
    final title = Theme.of(context).textTheme.titleSmall;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (sizes != null) ...[
          Text('Boyut aralığı', style: title),
          _RangePicker(sizes: sizes, range: range, onChanged: onRangeChanged),
          const SizedBox(height: 8),
        ],
        for (final kind in _kinds) ..._layerSection(context, kind),
      ],
    );
  }

  List<Widget> _layerSection(BuildContext context, LayerKind kind) {
    final c = _c;
    final theme = Theme.of(context);
    final override = findOverride(c.doc, platform, variant, range);
    final patch = override?.layerPatches
        .where((p) => p.layer == kind)
        .firstOrNull;
    final detached = override?.detached[kind];
    final resolved = resolveIcon(
      c.doc,
      platform: platform,
      variant: variant ?? IconVariant.light,
      sizePx: range?.minPx ?? canvasSize,
    );
    final layer = switch (kind) {
      LayerKind.background => resolved.background,
      LayerKind.foreground => resolved.foreground,
      LayerKind.monochrome => resolved.monochrome,
    };
    final base =
        detached ??
        (kind == LayerKind.monochrome
            ? c.doc.monochrome
            : layerOf(c.doc, kind));

    Widget reset(String field, VoidCallback onTap) => TextButton(
      key: Key('reset-${kind.name}-$field'),
      onPressed: onTap,
      child: const Text('Ortak tasarıma dön'),
    );

    return [
      const Divider(height: 24),
      Row(
        children: [
          Text(_layerNames[kind]!, style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          if (detached != null)
            Chip(
              key: Key('detached-badge-${kind.name}'),
              label: const Text('Ayrılmış'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      if (detached == null)
        OutlinedButton(
          key: Key('detach-${kind.name}'),
          onPressed: () =>
              c.apply(detachLayer(c.doc, platform, variant, range, kind)),
          child: const Text('Katmanı ayır'),
        )
      else
        OutlinedButton(
          key: Key('reattach-${kind.name}'),
          onPressed: () =>
              c.apply(reattachLayer(c.doc, platform, variant, range, kind)),
          child: const Text('Ortak tasarıma geri bağla'),
        ),
      Row(
        children: [
          const Expanded(child: Text('Gizle')),
          Switch(
            key: Key('hide-${kind.name}'),
            value: patch?.hidden == true,
            onChanged: (v) => c.apply(
              v
                  ? setLayerPatch(
                      c.doc,
                      platform,
                      variant,
                      range,
                      kind,
                      hidden: true,
                    )
                  : clearLayerPatchField(
                      c.doc,
                      platform,
                      variant,
                      range,
                      kind,
                      LayerPatchField.hidden,
                    ),
            ),
          ),
        ],
      ),
      if (patch?.hidden != null)
        reset(
          'hidden',
          () => c.apply(
            clearLayerPatchField(
              c.doc,
              platform,
              variant,
              range,
              kind,
              LayerPatchField.hidden,
            ),
          ),
        ),
      if (kind == LayerKind.background) ...[
        const SizedBox(height: 8),
        Text('Arka plan dolgusu', style: theme.textTheme.labelLarge),
        FillEditor(
          key: const Key('override-bg-fill'),
          fill: layer.fill,
          area: _canvasArea,
          radialRadius: _bgRadius,
          onChanged: (f) => c.apply(
            setLayerPatch(c.doc, platform, variant, range, kind, fill: f),
          ),
        ),
        if (patch?.fill != null)
          reset(
            'fill',
            () => c.apply(
              clearLayerPatchField(
                c.doc,
                platform,
                variant,
                range,
                kind,
                LayerPatchField.fill,
              ),
            ),
          ),
      ] else ...[
        const SizedBox(height: 8),
        Text('Kenar boşluğu', style: theme.textTheme.labelLarge),
        Slider(
          key: Key('scale-${kind.name}'),
          min: 0.25,
          max: 1.5,
          value: layer.scale.clamp(0.25, 1.5),
          label: '${(layer.scale * 100).round()}%',
          onChangeStart: (_) => c.beginGesture(),
          onChanged: (v) => c.preview(
            setLayerPatch(c.doc, platform, variant, range, kind, scale: v),
          ),
          onChangeEnd: (_) => c.endGesture(),
        ),
        if (patch?.scale != null)
          reset(
            'scale',
            () => c.apply(
              clearLayerPatchField(
                c.doc,
                platform,
                variant,
                range,
                kind,
                LayerPatchField.scale,
              ),
            ),
          ),
      ],
      if (base != null && base.elements.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Öğeler', style: theme.textTheme.labelLarge),
        for (final (id, depth, e) in elementIdsOf(base))
          _elementRow(context, override, id, depth, e),
      ],
    ];
  }

  Widget _elementRow(
    BuildContext context,
    PlatformOverride? override,
    String id,
    int depth,
    IconElement e,
  ) {
    final c = _c;
    final patch = override?.elementPatches
        .where((p) => p.elementId == id)
        .firstOrNull;
    final opacity = patch?.opacity ?? e.opacity;
    Widget reset(String field, ElementPatchField f) => TextButton(
      key: Key('reset-el-$id-$field'),
      onPressed: () => c.apply(
        clearElementPatchField(c.doc, platform, variant, range, id, f),
      ),
      child: const Text('Ortak tasarıma dön'),
    );
    return Padding(
      padding: EdgeInsets.only(left: 12.0 * depth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis)),
              const Text('Gizle'),
              Switch(
                key: Key('el-hide-$id'),
                value: (patch?.hidden ?? e.hidden) == true,
                onChanged: (v) => c.apply(
                  setElementPatch(
                    c.doc,
                    platform,
                    variant,
                    range,
                    id,
                    hidden: v,
                  ),
                ),
              ),
            ],
          ),
          if (patch?.hidden != null) reset('hidden', ElementPatchField.hidden),
          Row(
            children: [
              const Text('Opaklık'),
              Expanded(
                child: Slider(
                  key: Key('el-opacity-$id'),
                  value: opacity.clamp(0.0, 1.0),
                  label: '${(opacity * 100).round()}%',
                  onChangeStart: (_) => c.beginGesture(),
                  onChanged: (v) => c.preview(
                    setElementPatch(
                      c.doc,
                      platform,
                      variant,
                      range,
                      id,
                      opacity: v,
                    ),
                  ),
                  onChangeEnd: (_) => c.endGesture(),
                ),
              ),
            ],
          ),
          if (patch?.opacity != null)
            reset('opacity', ElementPatchField.opacity),
        ],
      ),
    );
  }
}

/// Min / max dropdowns over a platform's output sizes. `0` stands for
/// "Tüm boyutlar" (no range).
class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.sizes,
    required this.range,
    required this.onChanged,
  });

  final List<int> sizes;
  final SizeRange? range;
  final ValueChanged<SizeRange?> onChanged;

  void _pick({int? min, int? max}) {
    if (min == 0 || max == 0) return onChanged(null);
    var lo = min ?? range?.minPx ?? sizes.first;
    var hi = max ?? range?.maxPx ?? sizes.last;
    if (lo > hi) (lo, hi) = (hi, lo);
    onChanged(SizeRange(lo, hi));
  }

  Widget _dropdown(Key key, int? value, ValueChanged<int> onPick) =>
      DropdownButton<int>(
        key: key,
        isExpanded: true,
        value: value ?? 0,
        items: [
          const DropdownMenuItem(value: 0, child: Text('Tüm boyutlar')),
          for (final s in sizes) DropdownMenuItem(value: s, child: Text('$s')),
        ],
        onChanged: (v) {
          if (v != null) onPick(v);
        },
      );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _dropdown(
          const Key('range-min'),
          range?.minPx,
          (v) => _pick(min: v),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('–'),
      ),
      Expanded(
        child: _dropdown(
          const Key('range-max'),
          range?.maxPx,
          (v) => _pick(max: v),
        ),
      ),
    ],
  );
}

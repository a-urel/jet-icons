import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

import '../document_controller.dart';
import '../shared/doc_assets.dart';
import 'override_panel.dart';
import 'platform_previews.dart';

const _platformNames = {
  IconPlatform.ios: 'iOS',
  IconPlatform.android: 'Android',
  IconPlatform.macos: 'macOS',
  IconPlatform.windows: 'Windows',
  IconPlatform.web: 'Web',
  IconPlatform.linux: 'Linux',
};

const _shapeLabels = {
  IconShape.roundedSquare: 'Yuvarlatılmış kare',
  IconShape.square: 'Kare',
  IconShape.circle: 'Daire',
  IconShape.none: 'Arka plansız',
};

const _variantLabels = {
  IconVariant.light: 'Açık',
  IconVariant.dark: 'Koyu',
  IconVariant.tinted: 'Tinted',
};

/// "Platformlar" tab: platform list (left), large previews with the shape
/// and variant pickers (center) and the override panel (right).
class PlatformsTab extends StatefulWidget {
  const PlatformsTab({super.key, required this.controller});

  final DocumentController controller;

  @override
  State<PlatformsTab> createState() => _PlatformsTabState();
}

class _PlatformsTabState extends State<PlatformsTab>
    with DocAssetsMixin<PlatformsTab> {
  IconPlatform _platform = IconPlatform.ios;
  IconVariant _variant = IconVariant.light;
  SizeRange? _range;

  @override
  DocumentController get docController => widget.controller;

  @override
  void initState() {
    super.initState();
    initDocAssets();
  }

  @override
  void didUpdateWidget(PlatformsTab old) {
    super.didUpdateWidget(old);
    rebindDocAssets(old.controller);
  }

  @override
  void dispose() {
    disposeDocAssets();
    super.dispose();
  }

  bool get _hasShape =>
      _platform == IconPlatform.windows ||
      _platform == IconPlatform.linux ||
      _platform == IconPlatform.web;

  /// Only iOS has per-variant overrides.
  IconVariant? get _overrideVariant =>
      _platform == IconPlatform.ios ? _variant : null;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Row(
        children: [
          SizedBox(
            width: 180,
            child: ListView(
              children: [
                for (final p in IconPlatform.values)
                  ListTile(
                    key: Key('platform-${p.name}'),
                    selected: p == _platform,
                    title: Text(_platformNames[p]!),
                    onTap: () => setState(() {
                      _platform = p;
                      _range = null;
                    }),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_platform == IconPlatform.ios) ...[
                  SegmentedButton<IconVariant>(
                    key: const Key('variant-picker'),
                    segments: [
                      for (final v in IconVariant.values)
                        ButtonSegment(
                          value: v,
                          label: Text(_variantLabels[v]!),
                        ),
                    ],
                    selected: {_variant},
                    onSelectionChanged: (s) =>
                        setState(() => _variant = s.first),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_hasShape) ...[
                  SegmentedButton<IconShape>(
                    key: const Key('shape-picker'),
                    segments: [
                      for (final s in IconShape.values)
                        ButtonSegment(value: s, label: Text(_shapeLabels[s]!)),
                    ],
                    selected: {c.doc.shapeFor(_platform)},
                    onSelectionChanged: (s) => c.apply(
                      c.doc.copyWith(
                        shapes: {...c.doc.shapes, _platform: s.first},
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                PlatformPreviews(
                  doc: c.doc,
                  platform: _platform,
                  assets: assets,
                  selectedVariant: _overrideVariant,
                  range: _range,
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 340,
            child: OverridePanel(
              controller: c,
              platform: _platform,
              variant: _overrideVariant,
              range: _range,
              onRangeChanged: (r) => setState(() => _range = r),
            ),
          ),
        ],
      ),
    );
  }
}

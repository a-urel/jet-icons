import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';
import 'package:material_ui/material_ui.dart';

const _tile = 48.0;

/// Bottom strip: a 48 px preview per platform, each resolved with that
/// platform's overrides.
class PreviewStrip extends StatelessWidget {
  const PreviewStrip({super.key, required this.doc, this.assets});

  final IconDocument doc;
  final PreparedAssets? assets;

  static const _labels = {
    IconPlatform.ios: 'iOS',
    IconPlatform.android: 'Android',
    IconPlatform.macos: 'macOS',
    IconPlatform.windows: 'Windows',
    IconPlatform.web: 'Web',
    IconPlatform.linux: 'Linux',
  };

  RenderRequest _request(IconPlatform p) {
    switch (p) {
      case IconPlatform.ios:
        return const RenderRequest(48, Composition.full, IconShape.square);
      case IconPlatform.android:
        return const RenderRequest(48, Composition.full, IconShape.circle);
      case IconPlatform.macos:
        return const RenderRequest(
          48,
          Composition.full,
          IconShape.square,
          macTemplate: true,
        );
      case IconPlatform.windows:
      case IconPlatform.web:
      case IconPlatform.linux:
        final shape = shapeFor(doc, p);
        return RenderRequest(
          48,
          shape == IconShape.none ? Composition.foreground : Composition.full,
          shape,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepared = assets ?? PreparedAssets.empty();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final p in IconPlatform.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  key: ValueKey('preview-${p.name}'),
                  width: _tile,
                  height: _tile,
                  child: _paint(p, prepared),
                ),
                const SizedBox(height: 4),
                Text(_labels[p]!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }

  Widget _paint(IconPlatform p, PreparedAssets prepared) {
    final icon = resolveIcon(doc, platform: p, sizePx: 48);
    final paint = CustomPaint(
      painter: IconPainter(icon, _request(p), prepared),
    );
    if (p != IconPlatform.ios) return paint;
    return ClipRRect(
      borderRadius: BorderRadius.circular(0.2237 * _tile),
      child: paint,
    );
  }
}

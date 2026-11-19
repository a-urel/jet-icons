import 'dart:ui' as ui;

import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';
import 'package:material_ui/material_ui.dart';

import 'preview_spec.dart';

/// Large previews of one platform, laid out in rows by [previewsFor].
class PlatformPreviews extends StatelessWidget {
  const PlatformPreviews({
    super.key,
    required this.doc,
    required this.platform,
    required this.assets,
    this.selectedVariant,
    this.range,
  });

  final IconDocument doc;
  final IconPlatform platform;
  final PreparedAssets assets;

  /// iOS only: the variant tile that is the current override target.
  final IconVariant? selectedVariant;

  /// Selected size range; previews then resolve at its min size.
  final SizeRange? range;

  @override
  Widget build(BuildContext context) {
    final rows = previewsFor(platform, doc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [for (final tile in row) _tile(context, tile)],
            ),
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, PreviewTile tile) {
    final size = tile.size.toDouble();
    final selected =
        tile.variant == selectedVariant && platform == IconPlatform.ios;
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: ValueKey('preview-${platform.name}-${tile.id}'),
          width: size,
          height: size,
          child: _content(tile, size),
        ),
        const SizedBox(height: 6),
        Text(
          tile.label,
          style: selected
              ? style?.copyWith(fontWeight: FontWeight.bold)
              : style,
        ),
      ],
    );
  }

  Widget _content(PreviewTile tile, double size) {
    final icon = resolveIcon(
      doc,
      platform: platform,
      variant: tile.variant,
      sizePx: range?.minPx ?? tile.resolveSize,
    );
    Widget painted = CustomPaint(
      size: Size.square(size),
      painter: IconPainter(icon, tile.request, assets),
    );
    switch (tile.frame) {
      case IosFrame():
        painted = ClipRRect(
          borderRadius: BorderRadius.circular(0.2237 * size),
          child: painted,
        );
      case AndroidFrame(:final mask, :final dark):
        painted = ClipPath(
          clipper: _PathClipper(androidMaskPath(mask, size)),
          child: dark
              ? ColoredBox(color: const Color(0xFF303030), child: painted)
              : painted,
        );
      case NoFrame():
    }
    final safe = tile.safeZoneFraction;
    if (safe == null) return painted;
    return Stack(
      children: [
        Positioned.fill(child: painted),
        Positioned.fill(
          child: IgnorePointer(
            key: ValueKey('safe-zone-${platform.name}-${tile.id}'),
            child: CustomPaint(painter: _SafeZonePainter(safe)),
          ),
        ),
      ],
    );
  }
}

class _PathClipper extends CustomClipper<ui.Path> {
  _PathClipper(this.path);

  final ui.Path path;

  @override
  ui.Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper old) => old.path != path;
}

class _SafeZonePainter extends CustomPainter {
  _SafeZonePainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xCCFF4081);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * fraction / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SafeZonePainter old) => old.fraction != fraction;
}

import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';

/// How a preview tile is masked on screen (the painter does not mask
/// iOS squares or Android adaptive layers).
sealed class PreviewFrame {
  const PreviewFrame();
}

class NoFrame extends PreviewFrame {
  const NoFrame();
}

/// iOS rounded rectangle.
class IosFrame extends PreviewFrame {
  const IosFrame();
}

/// Android launcher [mask]; [dark] draws on a dark tile (monochrome).
class AndroidFrame extends PreviewFrame {
  const AndroidFrame(this.mask, {this.dark = false});

  final AndroidMask mask;
  final bool dark;
}

/// One preview: what to render and how to show it.
class PreviewTile {
  const PreviewTile({
    required this.id,
    required this.label,
    required this.size,
    required this.request,
    this.variant = IconVariant.light,
    this.frame = const NoFrame(),
    this.safeZoneFraction,
    this.resolveSize = canvasSize,
  });

  final String id;
  final String label;

  /// Edge length in logical pixels (actual pixels for the small sizes).
  final int size;
  final RenderRequest request;
  final IconVariant variant;
  final PreviewFrame frame;

  /// Diameter of the safe-zone circle overlay, as a fraction of [size].
  final double? safeZoneFraction;

  /// Size [resolveIcon] runs at (the output's own size for platforms with
  /// per-size overrides).
  final int resolveSize;
}

RenderRequest _resized(RenderRequest r, int size) => RenderRequest(
  size,
  r.composition,
  r.shape,
  macTemplate: r.macTemplate,
  contentScale: r.contentScale,
  flattenAlpha: r.flattenAlpha,
);

ImageOutput _image(List<OutputFile> files, bool Function(ImageOutput) test) =>
    files.whereType<ImageOutput>().firstWhere(test);

const _large = 256;

/// Preview rows of [platform], built from the requests [outputsFor] yields
/// for [doc].
List<List<PreviewTile>> previewsFor(IconPlatform platform, IconDocument doc) {
  final files = outputsFor(platform, doc);
  switch (platform) {
    case IconPlatform.ios:
      const labels = {
        IconVariant.light: 'Açık',
        IconVariant.dark: 'Koyu',
        IconVariant.tinted: 'Tinted',
      };
      return [
        [
          for (final v in IconVariant.values)
            PreviewTile(
              id: v.name,
              label: labels[v]!,
              size: _large,
              variant: v,
              frame: const IosFrame(),
              request: _resized(
                _image(files, (o) => o.variant == v).request,
                _large,
              ),
            ),
        ],
      ];
    case IconPlatform.android:
      final full = _image(
        files,
        (o) => o.path.endsWith('mdpi/ic_launcher.png'),
      );
      final mono = _image(
        files,
        (o) => o.path.endsWith('mdpi/ic_launcher_monochrome.png'),
      );
      // The design canvas fills the visible 72 dp window, so the content is
      // not scaled; the mask is applied by the preview.
      RenderRequest visible(Composition c) =>
          RenderRequest(_large, c, IconShape.square);
      const names = {
        AndroidMask.circle: 'Daire',
        AndroidMask.squircle: 'Squircle',
        AndroidMask.roundedSquare: 'Yuvarlatılmış kare',
      };
      return [
        [
          for (final m in AndroidMask.values)
            PreviewTile(
              id: m.name,
              label: names[m]!,
              size: _large,
              frame: AndroidFrame(m),
              safeZoneFraction: 66 / 72,
              request: visible(full.request.composition),
            ),
        ],
        [
          PreviewTile(
            id: 'mono',
            label: 'Monokrom',
            size: _large,
            frame: const AndroidFrame(AndroidMask.circle, dark: true),
            request: visible(mono.request.composition),
          ),
        ],
      ];
    case IconPlatform.macos:
      final first = _image(files, (_) => true);
      return [
        [
          PreviewTile(
            id: 'main',
            label: 'macOS',
            size: _large,
            request: _resized(first.request, _large),
          ),
        ],
      ];
    case IconPlatform.windows:
      final ico = files.whereType<ContainerOutput>().single;
      return [
        [
          for (final r in ico.images)
            if (const {16, 24, 32, 48, 256}.contains(r.sizePx))
              PreviewTile(
                id: '${r.sizePx}',
                label: '${r.sizePx}',
                size: r.sizePx,
                request: r,
                resolveSize: r.sizePx,
              ),
        ],
      ];
    case IconPlatform.web:
      final any = _image(files, (o) => o.path.endsWith('Icon-192.png'));
      final maskable = _image(
        files,
        (o) => o.path.endsWith('Icon-maskable-192.png'),
      );
      return [
        [
          PreviewTile(
            id: 'any',
            label: 'any',
            size: any.request.sizePx,
            request: any.request,
            resolveSize: any.request.sizePx,
          ),
          PreviewTile(
            id: 'maskable',
            label: 'maskable',
            size: maskable.request.sizePx,
            request: maskable.request,
            safeZoneFraction: 0.8,
            resolveSize: maskable.request.sizePx,
          ),
        ],
      ];
    case IconPlatform.linux:
      return [
        [
          for (final o in files.whereType<ImageOutput>())
            if (o.request.sizePx <= _large)
              PreviewTile(
                id: '${o.request.sizePx}',
                label: '${o.request.sizePx}',
                size: o.request.sizePx,
                request: o.request,
                resolveSize: o.request.sizePx,
              ),
        ],
      ];
  }
}

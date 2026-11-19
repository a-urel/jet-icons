import '../encoders/adaptive_icon_xml.dart';
import '../model/document.dart';
import '../model/override.dart';
import 'output.dart';

const _p = IconPlatform.android;

/// density -> (adaptive layer px at 108dp, legacy launcher px at 48dp).
const _densities = {
  'mdpi': (108, 48),
  'hdpi': (162, 72),
  'xhdpi': (216, 96),
  'xxhdpi': (324, 144),
  'xxxhdpi': (432, 192),
};

List<OutputFile> androidOutputs(IconDocument doc) {
  const layers = {
    'foreground': Composition.foreground,
    'background': Composition.background,
    'monochrome': Composition.monochrome,
  };
  final xml = adaptiveIconXml(includeMonochrome: true);
  return [
    for (final MapEntry(key: density, value: (layerPx, legacyPx))
        in _densities.entries) ...[
      for (final MapEntry(key: name, value: composition) in layers.entries)
        ImageOutput(
          'android/res/mipmap-$density/ic_launcher_$name.png',
          _p,
          IconVariant.light,
          RenderRequest(
            layerPx,
            composition,
            IconShape.square,
            contentScale: 72 / 108,
          ),
        ),
      ImageOutput(
        'android/res/mipmap-$density/ic_launcher.png',
        _p,
        IconVariant.light,
        RenderRequest(legacyPx, Composition.full, IconShape.roundedSquare),
      ),
      ImageOutput(
        'android/res/mipmap-$density/ic_launcher_round.png',
        _p,
        IconVariant.light,
        RenderRequest(legacyPx, Composition.full, IconShape.circle),
      ),
    ],
    TextOutput('android/res/mipmap-anydpi-v26/ic_launcher.xml', _p, xml),
    TextOutput('android/res/mipmap-anydpi-v26/ic_launcher_round.xml', _p, xml),
    const ImageOutput(
      'android/play_store_512.png',
      _p,
      IconVariant.light,
      RenderRequest(
        512,
        Composition.full,
        IconShape.square,
        flattenAlpha: true,
      ),
    ),
  ];
}

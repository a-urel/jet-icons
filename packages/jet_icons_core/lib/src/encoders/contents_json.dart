import 'dart:convert';

const _info = {'author': 'jet-icons', 'version': 1};

String _pretty(Object value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// `Contents.json` for an iOS single-size app icon set (light, dark, tinted).
String iosContentsJson() {
  Map<String, Object> image(String filename, [String? appearance]) => {
    if (appearance != null)
      'appearances': [
        {'appearance': 'luminosity', 'value': appearance},
      ],
    'filename': filename,
    'idiom': 'universal',
    'platform': 'ios',
    'size': '1024x1024',
  };
  return _pretty({
    'images': [
      image('AppIcon-1024.png'),
      image('AppIcon-1024-dark.png', 'dark'),
      image('AppIcon-1024-tinted.png', 'tinted'),
    ],
    'info': _info,
  });
}

/// `Contents.json` for a macOS app icon set (10 entries).
String macosContentsJson() {
  final images = <Map<String, Object>>[];
  for (final points in const [16, 32, 128, 256, 512]) {
    for (final scale in const [1, 2]) {
      images.add({
        'filename': 'app_icon_${points * scale}.png',
        'idiom': 'mac',
        'scale': '${scale}x',
        'size': '${points}x$points',
      });
    }
  }
  return _pretty({'images': images, 'info': _info});
}

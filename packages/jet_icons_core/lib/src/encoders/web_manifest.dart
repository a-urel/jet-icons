import 'dart:convert';

/// The `{"icons": [...]}` fragment for a web app manifest.
String webManifestIcons() {
  Map<String, String> icon(int size, String purpose) => {
    'src': 'icons/Icon-${purpose == 'maskable' ? 'maskable-' : ''}$size.png',
    'sizes': '${size}x$size',
    'type': 'image/png',
    'purpose': purpose,
  };
  return const JsonEncoder.withIndent('  ').convert({
    'icons': [
      icon(192, 'any'),
      icon(512, 'any'),
      icon(192, 'maskable'),
      icon(512, 'maskable'),
    ],
  });
}

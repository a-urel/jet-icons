import '../encoders/web_manifest.dart';
import '../model/document.dart';
import '../model/override.dart';
import 'output.dart';

List<OutputFile> webOutputs(IconDocument doc) {
  const p = IconPlatform.web;
  final shape = doc.shapeFor(p);
  RenderRequest opaque(int s) =>
      RenderRequest(s, Composition.full, IconShape.square, flattenAlpha: true);
  ImageOutput image(String path, RenderRequest r) =>
      ImageOutput(path, p, IconVariant.light, r);
  return [
    ContainerOutput('web/favicon.ico', p, ContainerKind.ico, [
      for (final s in const [16, 32, 48]) shapedRequest(s, shape),
    ]),
    image('web/icons/Icon-192.png', shapedRequest(192, shape)),
    image('web/icons/Icon-512.png', shapedRequest(512, shape)),
    image('web/icons/Icon-maskable-192.png', opaque(192)),
    image('web/icons/Icon-maskable-512.png', opaque(512)),
    image('web/apple-touch-icon.png', opaque(180)),
    TextOutput('web/manifest-icons.json', p, webManifestIcons()),
  ];
}

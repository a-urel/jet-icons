import '../encoders/contents_json.dart';
import '../model/document.dart';
import '../model/override.dart';
import 'output.dart';

const _sizes = [16, 32, 64, 128, 256, 512, 1024];

RenderRequest _req(int size) =>
    RenderRequest(size, Composition.full, IconShape.square, macTemplate: true);

List<OutputFile> macosOutputs(IconDocument doc) {
  const p = IconPlatform.macos;
  return [
    for (final s in _sizes)
      ImageOutput(
        'macos/AppIcon.appiconset/app_icon_$s.png',
        p,
        IconVariant.light,
        _req(s),
      ),
    TextOutput(
      'macos/AppIcon.appiconset/Contents.json',
      p,
      macosContentsJson(),
    ),
    ContainerOutput('macos/AppIcon.icns', p, ContainerKind.icns, [
      for (final s in _sizes) _req(s),
    ]),
  ];
}

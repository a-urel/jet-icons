import '../encoders/contents_json.dart';
import '../model/document.dart';
import '../model/override.dart';
import 'output.dart';

List<OutputFile> iosOutputs(IconDocument doc) {
  const p = IconPlatform.ios;
  const dir = 'ios/AppIcon.appiconset';
  return [
    const ImageOutput(
      '$dir/AppIcon-1024.png',
      p,
      IconVariant.light,
      RenderRequest(
        1024,
        Composition.full,
        IconShape.square,
        flattenAlpha: true,
      ),
    ),
    const ImageOutput(
      '$dir/AppIcon-1024-dark.png',
      p,
      IconVariant.dark,
      RenderRequest(1024, Composition.full, IconShape.square),
    ),
    const ImageOutput(
      '$dir/AppIcon-1024-tinted.png',
      p,
      IconVariant.tinted,
      RenderRequest(
        1024,
        Composition.tinted,
        IconShape.square,
        flattenAlpha: true,
      ),
    ),
    TextOutput('$dir/Contents.json', p, iosContentsJson()),
  ];
}

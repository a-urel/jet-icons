import '../model/document.dart';
import '../model/override.dart';
import 'output.dart';

List<OutputFile> linuxOutputs(IconDocument doc) {
  final shape = doc.shapeFor(IconPlatform.linux);
  return [
    for (final s in const [16, 22, 24, 32, 48, 64, 128, 256, 512])
      ImageOutput(
        'linux/hicolor/${s}x$s/apps/app_icon.png',
        IconPlatform.linux,
        IconVariant.light,
        shapedRequest(s, shape),
      ),
  ];
}

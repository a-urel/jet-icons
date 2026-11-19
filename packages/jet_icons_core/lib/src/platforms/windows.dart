import '../model/document.dart';
import '../model/override.dart';
import 'output.dart';

List<OutputFile> windowsOutputs(IconDocument doc) {
  final shape = doc.shapeFor(IconPlatform.windows);
  return [
    ContainerOutput(
      'windows/app_icon.ico',
      IconPlatform.windows,
      ContainerKind.ico,
      [
        for (final s in const [16, 24, 32, 48, 64, 128, 256])
          shapedRequest(s, shape),
      ],
    ),
  ];
}

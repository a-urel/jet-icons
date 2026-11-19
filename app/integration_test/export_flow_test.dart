import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:jet_icons/src/document_controller.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';

const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="8" fill="#3366FF"/>
  <path d="M8 8 L16 8 L12 17 Z" fill="#FFFFFF"/>
</svg>''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import svg then export zip contains all six platforms', (
    t,
  ) async {
    final controller = DocumentController();
    controller.importBytes('logo.svg', utf8.encode(_svg), LayerKind.foreground);
    final platforms = IconPlatform.values.toSet();

    final bundle = await t.runAsync(
      () => runExport(controller.doc, platforms, const FlutterIconRasterizer()),
    );

    expect(
      bundle!.files.keys.toSet(),
      plannedPaths(controller.doc, platforms).toSet(),
    );

    final fg =
        bundle.files['android/res/mipmap-xxxhdpi/ic_launcher_foreground.png']!;
    expect(img.decodePng(fg)!.width, 432);

    final iosLight = bundle.files['ios/AppIcon.appiconset/AppIcon-1024.png']!;
    expect(img.decodePng(iosLight)!.numChannels, 3);

    expect(bundle.files['windows/app_icon.ico']!.sublist(0, 4), [
      0x00,
      0x00,
      0x01,
      0x00,
    ]);
    expect(encodeZip(bundle), isNotEmpty);
  });
}

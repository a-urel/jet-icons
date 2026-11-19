import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jet_icons/src/document_controller.dart';
import 'package:jet_icons/src/shared/doc_assets.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.controller);
  final DocumentController controller;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with DocAssetsMixin<_Probe> {
  @override
  DocumentController get docController => widget.controller;

  @override
  void initState() {
    super.initState();
    initDocAssets();
  }

  @override
  void dispose() {
    disposeDocAssets();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

IconDocument _docWithPng(int sizePx) {
  final png = Uint8List.fromList(
    img.encodePng(img.Image(width: sizePx, height: sizePx)),
  );
  return IconDocument.empty().copyWith(
    foreground: Layer(null, [
      RasterElement(
        id: 'e1',
        name: 'r',
        png: png,
        width: sizePx,
        height: sizePx,
      ),
    ]),
  );
}

void main() {
  testWidgets('replacing the document with another image under the same id '
      'reloads the assets', (t) async {
    final c = DocumentController(_docWithPng(8));
    await t.pumpWidget(MaterialApp(home: _Probe(c)));
    final state = t.state<_ProbeState>(find.byType(_Probe));

    Future<void> settle() => t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );

    await settle();
    await t.pump();
    expect(state.assets.raster('e1')?.width, 8);

    c.apply(_docWithPng(16));
    await settle();
    await t.pump();
    expect(state.assets.raster('e1')?.width, 16);
  });
}

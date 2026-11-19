import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons/src/design/doc_edit.dart';
import 'package:jet_icons_core/jet_icons_core.dart';

PathElement _p(String id) => PathElement(id: id, name: id, d: 'M0 0 L1 1');

void main() {
  group('removeElement', () {
    test('removes only the given top-level element of the given layer', () {
      final doc = IconDocument.empty().copyWith(
        foreground: Layer(null, [_p('a'), _p('b')]),
        background: Layer(null, [_p('a')]),
      );
      final next = removeElement(doc, LayerKind.foreground, 'a');
      expect(next.foreground.elements.map((e) => e.id), ['b']);
      expect(next.background.elements.map((e) => e.id), ['a']);
    });

    test('unknown id leaves the layer equal; monochrome null stays usable', () {
      final doc = IconDocument.empty();
      expect(removeElement(doc, LayerKind.foreground, 'x'), doc);
      final m = removeElement(doc, LayerKind.monochrome, 'x');
      expect(m.monochrome, const Layer(null, []));
    });
  });
}

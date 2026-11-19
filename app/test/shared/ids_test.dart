import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons/src/shared/ids.dart';
import 'package:jet_icons_core/jet_icons_core.dart';

PathElement _p(String id) =>
    PathElement(id: id, name: id, d: 'M0 0 L10 0 L10 10 Z');

void main() {
  test('nextFreeId picks the smallest free eN', () {
    expect(nextFreeId({}), 'e1');
    expect(nextFreeId({'e1', 'e3'}), 'e2');
    expect(nextFreeId({'a', 'e1', 'e2'}), 'e3');
  });

  test('allElementIds covers groups and detached layers', () {
    final doc = IconDocument.empty().copyWith(
      foreground: Layer(null, [
        GroupElement(id: 'g', name: 'g', children: [_p('c')]),
      ]),
      overrides: [
        PlatformOverride(
          IconPlatform.macos,
          detached: {
            LayerKind.background: Layer(null, [_p('d')]),
          },
        ),
      ],
    );
    expect(allElementIds(doc), {'g', 'c', 'd'});
  });

  test('withFreshIds renames deeply with unique free ids', () {
    final used = {'e1', 'e2'};
    final layer = Layer(null, [
      GroupElement(id: 'g', name: 'g', children: [_p('c')]),
      _p('x'),
    ]);
    final out = withFreshIds(layer, used);
    final g = out.elements[0] as GroupElement;
    expect(
      [g.id, g.children.single.id, out.elements[1].id],
      ['e3', 'e4', 'e5'],
    );
    expect(used, {'e1', 'e2', 'e3', 'e4', 'e5'});
    expect(g.name, 'g');
  });
}

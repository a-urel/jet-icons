import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons/src/platforms/override_edit.dart';
import 'package:jet_icons_core/jet_icons_core.dart';

const _ios = IconPlatform.ios;
const _win = IconPlatform.windows;
const _range = SizeRange(16, 32);
const _red = SolidFill(JColor(0xFFFF0000));

PathElement _p(String id) =>
    PathElement(id: id, name: id, d: 'M0 0 L10 0 L10 10 Z');

IconDocument _doc() => IconDocument.empty().copyWith(
  foreground: Layer(null, [
    _p('e1'),
    GroupElement(id: 'e2', name: 'g', children: [_p('e3')]),
  ], scale: 0.9),
);

void main() {
  group('updateOverride / findOverride', () {
    test('creates a missing override with the full key', () {
      final d = updateOverride(
        _doc(),
        _win,
        null,
        _range,
        (o) => o.copyWith(
          layerPatches: [const LayerPatch(LayerKind.foreground, scale: 0.5)],
        ),
      );
      final o = d.overrides.single;
      expect(o.platform, _win);
      expect(o.variant, isNull);
      expect(o.sizeRange, _range);
      expect(findOverride(d, _win, null, _range), o);
      expect(findOverride(d, _win, null, null), isNull);
      expect(findOverride(d, _win, IconVariant.dark, _range), isNull);
      expect(findOverride(d, IconPlatform.linux, null, _range), isNull);
    });

    test('empty result removes the override, or never creates one', () {
      expect(
        updateOverride(_doc(), _ios, null, null, (o) => o).overrides,
        isEmpty,
      );
      final d = setLayerPatch(
        _doc(),
        _ios,
        null,
        null,
        LayerKind.foreground,
        scale: 0.5,
      );
      expect(d.overrides, hasLength(1));
      final back = updateOverride(
        d,
        _ios,
        null,
        null,
        (o) => o.copyWith(layerPatches: []),
      );
      expect(back.overrides, isEmpty);
    });

    test('keeps other overrides untouched', () {
      var d = setLayerPatch(
        _doc(),
        _ios,
        IconVariant.dark,
        null,
        LayerKind.background,
        hidden: true,
      );
      d = setLayerPatch(d, _ios, null, null, LayerKind.foreground, scale: 0.5);
      expect(d.overrides, hasLength(2));
      d = updateOverride(
        d,
        _ios,
        null,
        null,
        (o) => o.copyWith(layerPatches: []),
      );
      expect(d.overrides.single.variant, IconVariant.dark);
    });
  });

  group('layer patches', () {
    test('setLayerPatch merges fields into one patch', () {
      var d = setLayerPatch(
        _doc(),
        _ios,
        null,
        null,
        LayerKind.background,
        hidden: true,
      );
      d = setLayerPatch(d, _ios, null, null, LayerKind.background, fill: _red);
      final patches = d.overrides.single.layerPatches;
      expect(
        patches.single,
        const LayerPatch(LayerKind.background, hidden: true, fill: _red),
      );
    });

    test(
      'clearLayerPatchField clears one field then the patch then the override',
      () {
        var d = setLayerPatch(
          _doc(),
          _ios,
          null,
          null,
          LayerKind.background,
          hidden: true,
          fill: _red,
        );
        d = clearLayerPatchField(
          d,
          _ios,
          null,
          null,
          LayerKind.background,
          LayerPatchField.hidden,
        );
        expect(
          d.overrides.single.layerPatches.single,
          const LayerPatch(LayerKind.background, fill: _red),
        );
        d = clearLayerPatchField(
          d,
          _ios,
          null,
          null,
          LayerKind.background,
          LayerPatchField.fill,
        );
        expect(d.overrides, isEmpty);
      },
    );

    test('clearing a missing patch is a no-op', () {
      final d = clearLayerPatchField(
        _doc(),
        _ios,
        null,
        null,
        LayerKind.foreground,
        LayerPatchField.scale,
      );
      expect(d, _doc());
    });

    test('patch is visible through resolveIcon for the platform only', () {
      final d = setLayerPatch(
        _doc(),
        IconPlatform.macos,
        null,
        null,
        LayerKind.foreground,
        scale: 0.5,
      );
      expect(
        resolveIcon(
          d,
          platform: IconPlatform.macos,
          sizePx: 1024,
        ).foreground.scale,
        0.5,
      );
      expect(
        resolveIcon(d, platform: _ios, sizePx: 1024).foreground.scale,
        0.9,
      );
    });
  });

  group('element patches', () {
    test('set and clear, removing empty patch and override', () {
      var d = setElementPatch(_doc(), _ios, null, null, 'e1', opacity: 0.4);
      d = setElementPatch(d, _ios, null, null, 'e1', hidden: true);
      expect(
        d.overrides.single.elementPatches.single,
        const ElementPatch('e1', opacity: 0.4, hidden: true),
      );
      d = clearElementPatchField(
        d,
        _ios,
        null,
        null,
        'e1',
        ElementPatchField.opacity,
      );
      expect(
        d.overrides.single.elementPatches.single,
        const ElementPatch('e1', hidden: true),
      );
      d = clearElementPatchField(
        d,
        _ios,
        null,
        null,
        'e1',
        ElementPatchField.hidden,
      );
      expect(d.overrides, isEmpty);
    });

    test('patches for different elements coexist', () {
      var d = setElementPatch(_doc(), _ios, null, null, 'e1', hidden: true);
      d = setElementPatch(d, _ios, null, null, 'e3', opacity: 0.5);
      expect(d.overrides.single.elementPatches.map((p) => p.elementId), [
        'e1',
        'e3',
      ]);
    });
  });

  group('detach / reattach', () {
    test('detach copies the resolved layer with fresh unique ids', () {
      final d = detachLayer(_doc(), _ios, null, null, LayerKind.foreground);
      final copy = d.overrides.single.detached[LayerKind.foreground]!;
      final ids = <String>[
        for (final e in copy.elements) ...[
          e.id,
          if (e is GroupElement) ...e.children.map((c) => c.id),
        ],
      ];
      expect(ids, ['e4', 'e5', 'e6']);
      expect(copy.scale, 0.9);
      final all = [
        ...elementIdsOf(d.foreground).map((e) => e.$1),
        ...elementIdsOf(copy).map((e) => e.$1),
      ];
      expect(all.toSet(), hasLength(all.length));
      final resolved = resolveIcon(d, platform: _ios, sizePx: 1024).foreground;
      expect(resolved, copy);
    });

    test(
      'detach uses the common design plus other overrides, not own patches',
      () {
        var d = setLayerPatch(
          _doc(),
          _ios,
          null,
          null,
          LayerKind.foreground,
          hidden: true,
        );
        d = detachLayer(d, _ios, null, null, LayerKind.foreground);
        expect(
          d.overrides.single.detached[LayerKind.foreground]!.elements,
          isNotEmpty,
        );
      },
    );

    test('detach resolves at the range min', () {
      var d = _doc();
      d = setLayerPatch(
        d,
        _win,
        null,
        const SizeRange(16, 16),
        LayerKind.foreground,
        scale: 0.3,
      );
      d = detachLayer(
        d,
        _win,
        null,
        const SizeRange(16, 16),
        LayerKind.foreground,
      );
      expect(d.overrides.single.detached[LayerKind.foreground]!.scale, 0.9);
      // a different override matching the range min is baked in
      var e = setLayerPatch(
        _doc(),
        _win,
        null,
        const SizeRange(16, 32),
        LayerKind.foreground,
        scale: 0.3,
      );
      e = detachLayer(
        e,
        _win,
        null,
        const SizeRange(16, 48),
        LayerKind.foreground,
      );
      expect(
        findOverride(
          e,
          _win,
          null,
          const SizeRange(16, 48),
        )!.detached[LayerKind.foreground]!.scale,
        0.3,
      );
    });

    test('reattach removes the entry and the empty override', () {
      var d = detachLayer(_doc(), _ios, null, null, LayerKind.background);
      d = reattachLayer(d, _ios, null, null, LayerKind.background);
      expect(d.overrides, isEmpty);
    });

    test('reattach keeps the override when patches remain', () {
      var d = setLayerPatch(
        _doc(),
        _ios,
        null,
        null,
        LayerKind.foreground,
        scale: 0.5,
      );
      d = detachLayer(d, _ios, null, null, LayerKind.background);
      d = reattachLayer(d, _ios, null, null, LayerKind.background);
      expect(d.overrides.single.detached, isEmpty);
      expect(d.overrides.single.layerPatches, hasLength(1));
    });
  });

  test('elementIds walks groups depth first', () {
    expect(elementIdsOf(_doc().foreground).map((e) => e.$1), [
      'e1',
      'e2',
      'e3',
    ]);
    expect(elementIdsOf(_doc().foreground).map((e) => e.$2), [0, 0, 1]);
  });
}

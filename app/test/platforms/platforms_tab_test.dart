import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons/src/document_controller.dart';
import 'package:jet_icons/src/platforms/platforms_tab.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';
import 'package:material_ui/material_ui.dart';

PathElement _p(String id) => PathElement(
  id: id,
  name: 'sekil $id',
  d: 'M100 100 L300 100 L300 300 L100 300 Z',
  fill: const SolidFill(JColor(0xFF000000)),
);

DocumentController _controller() => DocumentController(
  IconDocument.empty().copyWith(foreground: Layer(null, [_p('e1'), _p('e2')])),
);

Future<void> _pump(WidgetTester t, DocumentController c) async {
  t.view.physicalSize = const Size(1600, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PlatformsTab(controller: c)),
    ),
  );
}

Future<void> _select(WidgetTester t, IconPlatform p) async {
  await t.tap(find.byKey(Key('platform-${p.name}')));
  await t.pump();
}

Future<void> _variant(WidgetTester t, String label) async {
  await t.tap(
    find.descendant(
      of: find.byKey(const Key('variant-picker')),
      matching: find.text(label),
    ),
  );
  await t.pump();
}

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pump();
}

IconPainter _painter(WidgetTester t, String key) {
  final paint = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(CustomPaint),
  );
  return t.widget<CustomPaint>(paint.first).painter! as IconPainter;
}

Future<void> _pickRange(WidgetTester t, int? min, int? max) async {
  for (final (key, value) in [('range-min', min), ('range-max', max)]) {
    await _tap(t, key);
    await t.tap(find.text(value == null ? 'Tüm boyutlar' : '$value').last);
    await t.pumpAndSettle();
  }
}

void main() {
  group('shape picker', () {
    testWidgets('only on windows/linux/web and updates doc.shapes', (t) async {
      final c = _controller();
      await _pump(t, c);
      for (final p in [
        IconPlatform.ios,
        IconPlatform.android,
        IconPlatform.macos,
      ]) {
        await _select(t, p);
        expect(
          find.byKey(const Key('shape-picker')),
          findsNothing,
          reason: p.name,
        );
      }
      for (final p in [
        IconPlatform.windows,
        IconPlatform.linux,
        IconPlatform.web,
      ]) {
        await _select(t, p);
        expect(find.byKey(const Key('shape-picker')), findsOneWidget);
      }
      await _select(t, IconPlatform.linux);
      await t.tap(find.text('Daire'));
      await t.pump();
      expect(c.doc.shapes[IconPlatform.linux], IconShape.circle);
      expect(c.doc.shapeFor(IconPlatform.windows), IconShape.roundedSquare);
      await t.tap(find.text('Arka plansız'));
      await t.pump();
      expect(c.doc.shapes[IconPlatform.linux], IconShape.none);
      await t.tap(find.text('Kare'));
      await t.pump();
      expect(c.doc.shapes[IconPlatform.linux], IconShape.square);
      expect(find.text('Yuvarlatılmış kare'), findsOneWidget);
    });
  });

  group('previews', () {
    testWidgets('each platform shows its tiles', (t) async {
      final c = _controller();
      await _pump(t, c);
      final expected = {
        IconPlatform.ios: ['light', 'dark', 'tinted'],
        IconPlatform.android: ['circle', 'squircle', 'roundedSquare', 'mono'],
        IconPlatform.macos: ['main'],
        IconPlatform.windows: ['16', '24', '32', '48', '256'],
        IconPlatform.web: ['any', 'maskable'],
        IconPlatform.linux: ['16', '22', '24', '32', '48', '64', '128', '256'],
      };
      for (final MapEntry(key: p, value: tiles) in expected.entries) {
        await _select(t, p);
        for (final id in tiles) {
          expect(
            find.byKey(Key('preview-${p.name}-$id')),
            findsOneWidget,
            reason: '${p.name} $id',
          );
        }
      }
      await _select(t, IconPlatform.windows);
      expect(
        t.getSize(find.byKey(const Key('preview-windows-16'))),
        const Size(16, 16),
      );
      expect(
        t.getSize(find.byKey(const Key('preview-windows-256'))),
        const Size(256, 256),
      );
    });

    testWidgets('android draws safe zone overlays; web maskable 80%', (
      t,
    ) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.android);
      expect(find.byKey(const Key('safe-zone-android-circle')), findsOneWidget);
      expect(find.byKey(const Key('safe-zone-android-mono')), findsNothing);
      await _select(t, IconPlatform.web);
      expect(find.byKey(const Key('safe-zone-web-maskable')), findsOneWidget);
    });

    testWidgets('shape of windows tiles follows doc.shapes', (t) async {
      final c = _controller();
      c.apply(c.doc.copyWith(shapes: {IconPlatform.windows: IconShape.none}));
      await _pump(t, c);
      await _select(t, IconPlatform.windows);
      final r = _painter(t, 'preview-windows-48').request;
      expect(r.shape, IconShape.none);
      expect(r.composition, Composition.foreground);
      expect(r.sizePx, 48);
    });

    testWidgets('macOS uses the template; ios tinted uses tinted', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.macos);
      expect(_painter(t, 'preview-macos-main').request.macTemplate, isTrue);
      await _select(t, IconPlatform.ios);
      expect(
        _painter(t, 'preview-ios-tinted').request.composition,
        Composition.tinted,
      );
    });
  });

  group('overrides', () {
    testWidgets('foreground scale patch on macOS does not affect iOS', (
      t,
    ) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.macos);
      await t.drag(
        find.byKey(const Key('scale-foreground')),
        const Offset(-60, 0),
      );
      await t.pump();
      final o = c.doc.overrides.single;
      expect(o.platform, IconPlatform.macos);
      final scale = o.layerPatches.single.scale!;
      expect(scale, lessThan(1));
      expect(
        resolveIcon(
          c.doc,
          platform: IconPlatform.macos,
          sizePx: 1024,
        ).foreground.scale,
        scale,
      );
      expect(
        resolveIcon(
          c.doc,
          platform: IconPlatform.ios,
          sizePx: 1024,
        ).foreground.scale,
        1,
      );
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.canUndo, isFalse);
      expect(c.doc.overrides, isEmpty);
    });

    testWidgets('removing the last patch removes the override', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.macos);
      await t.drag(
        find.byKey(const Key('scale-foreground')),
        const Offset(-60, 0),
      );
      await t.pump();
      expect(c.doc.overrides, hasLength(1));
      await _tap(t, 'reset-foreground-scale');
      expect(c.doc.overrides, isEmpty);
      expect(find.byKey(const Key('reset-foreground-scale')), findsNothing);
    });

    testWidgets('hide layer patch then reset', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.web);
      await _tap(t, 'hide-background');
      expect(
        c.doc.overrides.single.layerPatches.single,
        const LayerPatch(LayerKind.background, hidden: true),
      );
      expect(
        resolveIcon(
          c.doc,
          platform: IconPlatform.web,
          sizePx: 256,
        ).background.fill,
        isNull,
      );
      await _tap(t, 'reset-background-hidden');
      expect(c.doc.overrides, isEmpty);
    });

    testWidgets('background fill patch via the fill editor', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.linux);
      await _tap(t, 'swatch-FFE53935');
      final patch = c.doc.overrides.single.layerPatches.single;
      expect(patch.layer, LayerKind.background);
      expect(patch.fill, const SolidFill(JColor(0xFFE53935)));
      expect(c.doc.background.fill, const SolidFill(JColor(0xFFFFFFFF)));
    });

    testWidgets('detach then reattach background restores common', (t) async {
      final c = _controller();
      final before = c.doc;
      await _pump(t, c);
      await _select(t, IconPlatform.android);
      expect(find.byKey(const Key('reattach-background')), findsNothing);
      await _tap(t, 'detach-background');
      expect(c.doc.overrides.single.detached.keys, [LayerKind.background]);
      expect(find.text('Ayrılmış'), findsOneWidget);
      expect(find.text('Katmanı ayır'), findsWidgets);
      await _tap(t, 'reattach-background');
      expect(c.doc.overrides, isEmpty);
      expect(c.doc, before);
      expect(find.text('Ayrılmış'), findsNothing);
    });

    testWidgets('detached foreground gets fresh ids', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.macos);
      await _tap(t, 'detach-foreground');
      final copy = c.doc.overrides.single.detached[LayerKind.foreground]!;
      expect(copy.elements.map((e) => e.id), ['e3', 'e4']);
      expect(c.doc.foreground.elements.map((e) => e.id), ['e1', 'e2']);
    });

    testWidgets('size range override created for windows 16-32', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.windows);
      await _pickRange(t, 16, 32);
      await _tap(t, 'hide-foreground');
      final o = c.doc.overrides.single;
      expect(o.platform, IconPlatform.windows);
      expect(o.sizeRange, const SizeRange(16, 32));
      expect(o.variant, isNull);
    });

    testWidgets('min above max is swapped', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.windows);
      await _pickRange(t, 48, 24);
      await _tap(t, 'hide-foreground');
      expect(c.doc.overrides.single.sizeRange, const SizeRange(24, 48));
    });

    testWidgets('range only on windows/linux/web; options per platform', (
      t,
    ) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.macos);
      expect(find.byKey(const Key('range-min')), findsNothing);
      await _select(t, IconPlatform.web);
      await _tap(t, 'range-max');
      expect(find.text('180').hitTestable(), findsOneWidget);
      expect(find.text('22'), findsNothing);
    });

    testWidgets('previews of a range override render at the range min', (
      t,
    ) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.windows);
      await _pickRange(t, 16, 32);
      await t.drag(
        find.byKey(const Key('scale-foreground')),
        const Offset(-60, 0),
      );
      await t.pump();
      final scale = c.doc.overrides.single.layerPatches.single.scale!;
      expect(_painter(t, 'preview-windows-256').icon.foreground.scale, scale);
      expect(_painter(t, 'preview-windows-16').icon.foreground.scale, scale);
    });

    testWidgets('ios variant tabs target the override variant', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.ios);
      await _variant(t, 'Koyu');
      await t.pump();
      await _tap(t, 'hide-foreground');
      expect(c.doc.overrides.single.variant, IconVariant.dark);
      await _variant(t, 'Tinted');
      await t.pump();
      expect(find.byKey(const Key('reset-foreground-hidden')), findsNothing);
      await _tap(t, 'hide-foreground');
      expect(c.doc.overrides.map((o) => o.variant), [
        IconVariant.dark,
        IconVariant.tinted,
      ]);
      await _variant(t, 'Açık');
      await t.pump();
      await _tap(t, 'hide-foreground');
      expect(c.doc.overrides.last.variant, IconVariant.light);
    });

    testWidgets('element hide and opacity patches', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.macos);
      await _tap(t, 'el-hide-e2');
      expect(
        c.doc.overrides.single.elementPatches.single,
        const ElementPatch('e2', hidden: true),
      );
      await t.drag(
        find.byKey(const Key('el-opacity-e1')),
        const Offset(-40, 0),
      );
      await t.pump();
      final patches = c.doc.overrides.single.elementPatches;
      expect(patches.map((p) => p.elementId), ['e2', 'e1']);
      expect(patches.last.opacity, lessThan(1));
      final r = resolveIcon(c.doc, platform: IconPlatform.macos, sizePx: 1024);
      expect(findElement(r.foreground, 'e2')!.hidden, isTrue);
      await _tap(t, 'reset-el-e2-hidden');
      await _tap(t, 'reset-el-e1-opacity');
      expect(c.doc.overrides, isEmpty);
    });

    testWidgets('toggling back to the common value clears the patch', (
      t,
    ) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.macos);
      await _tap(t, 'el-hide-e1');
      expect(c.doc.overrides, hasLength(1));
      await _tap(t, 'el-hide-e1');
      expect(c.doc.overrides, isEmpty);
    });

    testWidgets('opacity back to common value clears the patch', (t) async {
      final c = _controller();
      await _pump(t, c);
      await _select(t, IconPlatform.macos);
      final f = find.byKey(const Key('el-opacity-e1'));
      await t.drag(f, const Offset(-40, 0));
      await t.pump();
      expect(c.doc.overrides, hasLength(1));
      await t.drag(f, const Offset(400, 0));
      await t.pump();
      expect(c.doc.overrides, isEmpty);
    });
  });
}

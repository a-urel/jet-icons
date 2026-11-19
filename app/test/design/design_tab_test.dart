import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_icons/src/design/design_tab.dart';
import 'package:jet_icons/src/design/element_bounds.dart';
import 'package:jet_icons/src/design/fill_editor.dart';
import 'package:jet_icons/src/document_controller.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

PathElement _square({String id = 'p1', Transform2D? t}) => PathElement(
  id: id,
  name: 'square $id',
  d: 'M100 100 L300 100 L300 300 L100 300 Z',
  fill: const SolidFill(JColor(0xFF000000)),
  transform: t ?? Transform2D.identity,
);

DocumentController _controller({
  List<IconElement>? elements,
  double layerScale = 1,
}) {
  final c = DocumentController(
    IconDocument.empty().copyWith(
      foreground: Layer(null, elements ?? [_square()], scale: layerScale),
    ),
  );
  c.select(LayerKind.foreground, (elements ?? [_square()]).first.id);
  return c;
}

Future<void> _pump(
  WidgetTester t,
  DocumentController c, {
  PickImportFile? pick,
}) async {
  t.view.physicalSize = const Size(1400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DesignTab(controller: c, pickImportFile: pick),
      ),
    ),
  );
}

PathElement _el(DocumentController c, [String id = 'p1']) =>
    findElement(c.doc.foreground, id)! as PathElement;

void main() {
  group('elementBounds', () {
    test('path is bounded then transformed', () {
      final e = _square(t: Transform2D.translate(10, 20));
      expect(elementBounds(e), const Rect.fromLTRB(110, 120, 310, 320));
    });

    test('raster and raw svg use their size', () {
      final r = RasterElement(
        id: 'r',
        name: 'r',
        png: Uint8List(0),
        width: 40,
        height: 20,
        transform: Transform2D.scale(2),
      );
      expect(elementBounds(r), const Rect.fromLTRB(0, 0, 80, 40));
      const s = RawSvgElement(
        id: 's',
        name: 's',
        svg: '',
        vbX: 0,
        vbY: 0,
        vbWidth: 24,
        vbHeight: 12,
      );
      expect(elementBounds(s), const Rect.fromLTRB(0, 0, 24, 12));
    });

    test('group is the union of children, then transformed', () {
      final g = GroupElement(
        id: 'g',
        name: 'g',
        transform: Transform2D.translate(5, 5),
        children: [
          _square(),
          _square(id: 'p2', t: Transform2D.translate(400, 0)),
        ],
      );
      expect(elementBounds(g), const Rect.fromLTRB(105, 105, 705, 305));
    });

    test('rotation yields the axis-aligned box', () {
      final e = _square(t: Transform2D.rotate(1.5707963267948966));
      final b = elementBounds(e);
      expect(b.left, closeTo(-300, 1e-6));
      expect(b.right, closeTo(-100, 1e-6));
      expect(b.top, closeTo(100, 1e-6));
    });
  });

  group('canvas', () {
    testWidgets('dragging selected element updates transform in one undo', (
      t,
    ) async {
      final c = _controller();
      await _pump(t, c);
      final size = t.getSize(find.byKey(const Key('design-canvas')));
      await t.drag(
        find.byKey(const Key('design-canvas')),
        const Offset(100, 0),
      );
      await t.pump();
      final k = 1024 / size.width;
      expect(_el(c).transform.e, closeTo(100 * k, 1e-6));
      expect(_el(c).transform.f, closeTo(0, 1e-6));
      expect(c.canUndo, isTrue);
      c.undo();
      expect(_el(c).transform, Transform2D.identity);
      expect(c.canUndo, isFalse);
    });

    testWidgets('drag inside a scaled layer divides by layer scale', (t) async {
      final c = _controller(layerScale: 0.5);
      await _pump(t, c);
      final size = t.getSize(find.byKey(const Key('design-canvas')));
      await t.drag(find.byKey(const Key('design-canvas')), const Offset(0, 60));
      await t.pump();
      expect(_el(c).transform.f, closeTo(60 * 1024 / size.width / 0.5, 1e-6));
    });

    testWidgets('translation happens in parent space of a scaled element', (
      t,
    ) async {
      final c = _controller(elements: [_square(t: Transform2D.scale(2))]);
      await _pump(t, c);
      final size = t.getSize(find.byKey(const Key('design-canvas')));
      await t.drag(find.byKey(const Key('design-canvas')), const Offset(50, 0));
      await t.pump();
      final tr = _el(c).transform;
      expect(tr.a, 2);
      expect(tr.e, closeTo(50 * 1024 / size.width, 1e-6));
    });

    testWidgets('scale handle scales uniformly about the bounds center', (
      t,
    ) async {
      final c = _controller();
      await _pump(t, c);
      final before = elementBounds(_el(c));
      await t.drag(find.byKey(const Key('scale-handle')), const Offset(60, 60));
      await t.pump();
      final after = elementBounds(_el(c));
      expect(after.width, greaterThan(before.width));
      expect(after.width, closeTo(after.height, 1e-6));
      expect(after.center.dx, closeTo(before.center.dx, 1e-6));
      expect(after.center.dy, closeTo(before.center.dy, 1e-6));
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.canUndo, isFalse);
    });

    testWidgets('tapping empty canvas clears element selection', (t) async {
      final c = _controller();
      await _pump(t, c);
      final r = t.getRect(find.byKey(const Key('design-canvas')));
      await t.tapAt(r.bottomRight - const Offset(10, 10));
      await t.pump();
      expect(c.selectedElementId, isNull);
    });

    testWidgets('tapping an element selects it', (t) async {
      final c = _controller();
      c.select(LayerKind.foreground);
      await _pump(t, c);
      final r = t.getRect(find.byKey(const Key('design-canvas')));
      final k = r.width / 1024;
      await t.tapAt(r.topLeft + Offset(200 * k, 200 * k));
      await t.pump();
      expect(c.selectedElementId, 'p1');
    });
  });

  group('panels', () {
    testWidgets('hide toggle sets element hidden', (t) async {
      final c = _controller();
      await _pump(t, c);
      await t.tap(find.byKey(const Key('hide-p1')));
      await t.pump();
      expect(_el(c).hidden, isTrue);
      expect(c.canUndo, isTrue);
    });

    testWidgets('delete removes the element', (t) async {
      final c = _controller();
      await _pump(t, c);
      await t.tap(find.byKey(const Key('delete-p1')));
      await t.pump();
      expect(c.doc.foreground.elements, isEmpty);
      expect(c.selectedElementId, isNull);
    });

    testWidgets('background hex input changes fill', (t) async {
      final c = _controller();
      c.select(LayerKind.background);
      await _pump(t, c);
      await t.enterText(find.byKey(const Key('fill-hex-0')), 'FF0000');
      await t.pump();
      expect(c.doc.background.fill, const SolidFill(JColor(0xFFFFFFFF)));
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(c.doc.background.fill, const SolidFill(JColor(0xFFFF0000)));
    });

    testWidgets('8-digit hex commits once, without a 6-digit prefix', (
      t,
    ) async {
      final c = _controller();
      c.select(LayerKind.background);
      await _pump(t, c);
      await t.enterText(find.byKey(const Key('fill-hex-0')), '80FF0000');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(c.doc.background.fill, const SolidFill(JColor(0x80FF0000)));
      c.undo();
      expect(c.canUndo, isFalse);
    });

    testWidgets('retyping a color after undo is not swallowed', (t) async {
      final c = _controller();
      c.select(LayerKind.background);
      await _pump(t, c);
      final f = find.byKey(const Key('fill-hex-0'));
      await t.enterText(f, 'FF0000');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      c.undo();
      await t.pump();
      expect(c.doc.background.fill, const SolidFill(JColor(0xFFFFFFFF)));
      await t.enterText(f, 'FF0000');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(c.doc.background.fill, const SolidFill(JColor(0xFFFF0000)));
    });

    testWidgets('focus and blur after an external change adds no undo', (
      t,
    ) async {
      final c = _controller();
      c.select(LayerKind.background);
      await _pump(t, c);
      final f = find.byKey(const Key('fill-hex-0'));
      await t.enterText(f, 'FF0000');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      await t.tap(find.byKey(const Key('swatch-FF1E88E5')));
      await t.pump();
      c.undo();
      c.redo();
      await t.pump();
      // Undo stack: [initial, red] with blue current; blur must add nothing.
      await t.tap(f);
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      c.undo();
      c.undo();
      expect(c.canUndo, isFalse);
    });

    testWidgets('hex commits on focus loss', (t) async {
      final c = _controller();
      c.select(LayerKind.background);
      await _pump(t, c);
      await t.tap(find.byKey(const Key('fill-hex-0')));
      await t.enterText(find.byKey(const Key('fill-hex-0')), '00FF00');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      expect(c.doc.background.fill, const SolidFill(JColor(0xFF00FF00)));
    });

    testWidgets('invalid hex leaves doc unchanged and shows error', (t) async {
      final c = _controller();
      c.select(LayerKind.background);
      await _pump(t, c);
      final before = c.doc;
      await t.enterText(find.byKey(const Key('fill-hex-0')), 'XYZ');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(c.doc, before);
      expect(find.text('Geçersiz renk'), findsOneWidget);
    });

    testWidgets('switching to linear gradient uses canvas defaults', (t) async {
      final c = _controller();
      c.select(LayerKind.background);
      await _pump(t, c);
      await t.tap(find.byKey(const Key('fill-type')));
      await t.pumpAndSettle();
      await t.tap(find.text('Doğrusal gradyan').last);
      await t.pumpAndSettle();
      final f = c.doc.background.fill! as LinearGradientFill;
      expect([f.x1, f.y1, f.x2, f.y2], [0, 0, 1024, 1024]);
      expect(f.stops, hasLength(2));
      expect(find.byKey(const Key('fill-hex-1')), findsOneWidget);
    });

    testWidgets('radial gradient default is centered with r 724', (t) async {
      final c = _controller();
      c.select(LayerKind.background);
      await _pump(t, c);
      await t.tap(find.byKey(const Key('fill-type')));
      await t.pumpAndSettle();
      await t.tap(find.text('Radyal gradyan').last);
      await t.pumpAndSettle();
      final f = c.doc.background.fill! as RadialGradientFill;
      expect([f.cx, f.cy, f.r], [512, 512, 724]);
    });

    testWidgets('scale field applies relative scale on submit', (t) async {
      final c = _controller();
      await _pump(t, c);
      await t.enterText(find.byKey(const Key('scale-field')), '200');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      final b = elementBounds(_el(c));
      expect(b.width, closeTo(400, 1e-6));
      expect(b.center.dx, closeTo(200, 1e-6));
    });

    testWidgets('scale field rejects non-finite and clamps the range', (
      t,
    ) async {
      Future<void> submit(DocumentController c, String text) async {
        await t.enterText(find.byKey(const Key('scale-field')), text);
        await t.testTextInput.receiveAction(TextInputAction.done);
        await t.pump();
      }

      final c = _controller();
      await _pump(t, c);
      await submit(c, '9' * 400);
      expect(elementBounds(_el(c)).width, closeTo(200, 1e-6));
      await submit(c, '99999999');
      expect(elementBounds(_el(c)).width, closeTo(200 * 100, 1e-6));
      c.undo();
      await submit(c, '0.0001');
      expect(elementBounds(_el(c)).width, closeTo(2, 1e-6));
    });

    testWidgets('opacity slider is one undo step', (t) async {
      final c = _controller();
      await _pump(t, c);
      await t.drag(
        find.byKey(const Key('opacity-slider')),
        const Offset(-80, 0),
      );
      await t.pump();
      expect(_el(c).opacity, lessThan(1));
      c.undo();
      expect(_el(c).opacity, 1);
      expect(c.canUndo, isFalse);
    });

    testWidgets('derive monochrome switch toggles doc.monochrome', (t) async {
      final c = _controller();
      await _pump(t, c);
      expect(c.doc.monochrome, isNull);
      await t.tap(find.byKey(const Key('derive-mono-switch')));
      await t.pump();
      expect(c.doc.monochrome, const Layer(null, []));
      await t.tap(find.byKey(const Key('derive-mono-switch')));
      await t.pump();
      expect(c.doc.monochrome, isNull);
    });

    testWidgets('layer scale slider updates layer scale', (t) async {
      final c = _controller();
      await _pump(t, c);
      await t.drag(find.byKey(const Key('layer-scale')), const Offset(-60, 0));
      await t.pump();
      expect(c.doc.foreground.scale, lessThan(1));
    });
  });

  group('previews', () {
    testWidgets('preview strip shows six platforms with labels', (t) async {
      await _pump(t, _controller());
      for (final p in IconPlatform.values) {
        final f = find.byKey(ValueKey('preview-${p.name}'));
        expect(f, findsOneWidget);
        expect(t.getSize(f), const Size(48, 48));
      }
      for (final l in ['iOS', 'Android', 'macOS', 'Windows', 'Web', 'Linux']) {
        expect(find.text(l), findsOneWidget);
      }
      expect(find.byType(ClipRRect), findsWidgets);
    });
  });

  group('import', () {
    testWidgets('svg import adds element', (t) async {
      final c = DocumentController();
      await _pump(
        t,
        c,
        pick: () async => (
          'logo.svg',
          Uint8List.fromList(
            utf8.encode(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<path d="M0 0h24v24H0z" fill="#f00"/></svg>',
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const Key('import-button')));
      await t.pump();
      await t.pump();
      expect(c.doc.foreground.elements, hasLength(1));
    });

    testWidgets('unsupported svg shows warning snackbar', (t) async {
      final c = DocumentController();
      await _pump(
        t,
        c,
        pick: () async => (
          'logo.svg',
          Uint8List.fromList(
            utf8.encode(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<text x="0" y="10">hi</text></svg>',
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const Key('import-button')));
      await t.pump();
      await t.pump();
      expect(
        find.textContaining("Bu SVG'de düzenlenemeyen öğeler var"),
        findsOneWidget,
      );
    });

    test('hex parsing', () {
      expect(parseHexInput('#ff0000'), const JColor(0xFFFF0000));
      expect(parseHexInput('80FF0000'), const JColor(0x80FF0000));
      expect(parseHexInput('FFF'), isNull);
    });
  });
}

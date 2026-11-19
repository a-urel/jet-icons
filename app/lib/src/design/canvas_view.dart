import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:jet_icons_render/jet_icons_render.dart';
import 'package:material_ui/material_ui.dart';

import '../document_controller.dart';
import 'doc_edit.dart';
import 'element_bounds.dart';

const _handleSize = 14.0;

/// Square editing canvas: draws the design, lets the user select, move and
/// uniformly scale elements. One whole drag is one undo step.
class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.controller,
    required this.assets,
    this.showSafeZone = false,
    this.showMacBody = false,
  });

  final DocumentController controller;
  final PreparedAssets assets;
  final bool showSafeZone;
  final bool showMacBody;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  /// Accumulated handle drag in screen pixels, and the state at drag start.
  Offset _handleDelta = Offset.zero;

  /// Pointer position (global) at the previous drag event. Deltas come from
  /// positions, not `details.delta`, so the touch slop is not lost.
  Offset _lastPointer = Offset.zero;
  IconElement? _scaleStart;
  Rect? _scaleBounds;

  DocumentController get c => widget.controller;

  /// Edge of the square canvas in pixels, from the latest layout.
  double _side = canvasSize.toDouble();

  double _unitsPerPx(BuildContext context) => canvasSize / _side;

  Offset _toCanvas(BuildContext context, Offset local) =>
      local * _unitsPerPx(context);

  void _onTapUp(BuildContext context, Offset local) {
    final hit = _hit(_toCanvas(context, local));
    if (hit == null) {
      c.select(c.selectedLayer);
    } else {
      c.select(hit.$1, hit.$2.id);
    }
  }

  /// Selected layer first, then foreground.
  (LayerKind, IconElement)? _hit(Offset p) {
    final order = {c.selectedLayer, LayerKind.foreground};
    for (final kind in order) {
      final e = hitTest(layerOf(c.doc, kind), p);
      if (e != null) return (kind, e);
    }
    return null;
  }

  void _onPanStart(BuildContext context, Offset local, Offset global) {
    _lastPointer = global;
    final hit = _hit(_toCanvas(context, local));
    if (hit != null && hit.$2.id != c.selectedElementId) {
      c.select(hit.$1, hit.$2.id);
    }
    if (c.selectedElementId == null) return;
    c.beginGesture();
  }

  Offset _step(Offset global) {
    final d = global - _lastPointer;
    _lastPointer = global;
    return d;
  }

  void _onPanUpdate(BuildContext context, Offset deltaPx) {
    final id = c.selectedElementId;
    if (id == null) return;
    final layer = layerOf(c.doc, c.selectedLayer);
    final k = _unitsPerPx(context) / layer.scale;
    c.preview(
      updateElement(
        c.doc,
        c.selectedLayer,
        id,
        (e) => translated(e, deltaPx.dx * k, deltaPx.dy * k),
      ),
    );
  }

  void _onScaleStart(IconElement e, Offset global) {
    _lastPointer = global;
    _scaleStart = e;
    _scaleBounds = elementBounds(e);
    _handleDelta = Offset.zero;
    c.beginGesture();
  }

  void _onScaleUpdate(BuildContext context, Offset deltaPx, double widgetPx) {
    final start = _scaleStart;
    final b = _scaleBounds;
    if (start == null || b == null) return;
    _handleDelta += deltaPx;
    final layer = layerOf(c.doc, c.selectedLayer);
    final perPx = widgetPx / canvasSize; // px per canvas unit
    final scale = layer.scale;
    final center = toCanvasSpace(b, scale).center * perPx;
    final corner = toCanvasSpace(b, scale).bottomRight * perPx;
    final d0 = (corner - center).distance;
    if (d0 == 0) return;
    final k = math.max(0.02, (corner + _handleDelta - center).distance / d0);
    c.preview(
      updateElement(
        c.doc,
        c.selectedLayer,
        start.id,
        (_) => scaledAbout(start, k, b.center),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        _side = side;
        final doc = c.doc;
        final icon = ResolvedIcon(
          doc.background,
          doc.foreground,
          doc.monochrome ?? doc.foreground,
        );
        final request = RenderRequest(
          canvasSize,
          c.selectedLayer == LayerKind.monochrome
              ? Composition.monochrome
              : Composition.full,
          IconShape.square,
        );
        final selected = _selected();
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('design-canvas'),
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onTapUp: (d) => _onTapUp(context, d.localPosition),
                    onPanStart: (d) =>
                        _onPanStart(context, d.localPosition, d.globalPosition),
                    onPanUpdate: (d) =>
                        _onPanUpdate(context, _step(d.globalPosition)),
                    onPanEnd: (_) => c.endGesture(),
                    onPanCancel: c.endGesture,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CustomPaint(painter: _CheckerPainter()),
                        CustomPaint(
                          painter: IconPainter(icon, request, widget.assets),
                        ),
                        CustomPaint(
                          painter: _GuidePainter(
                            safeZone: widget.showSafeZone,
                            macBody: widget.showMacBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (selected != null) ..._selection(side, selected),
              ],
            ),
          ),
        );
      },
    );
  }

  (IconElement, double)? _selected() {
    final id = c.selectedElementId;
    if (id == null) return null;
    final layer = layerOf(c.doc, c.selectedLayer);
    final e = findElement(layer, id);
    return e == null ? null : (e, layer.scale);
  }

  List<Widget> _selection(double side, (IconElement, double) sel) {
    final (e, scale) = sel;
    final px = side / canvasSize;
    final r = toCanvasSpace(elementBounds(e), scale);
    final box = Rect.fromLTRB(
      r.left * px,
      r.top * px,
      r.right * px,
      r.bottom * px,
    );
    return [
      Positioned.fromRect(
        rect: box,
        child: IgnorePointer(
          child: DecoratedBox(
            key: const Key('selection-box'),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 1.5),
            ),
          ),
        ),
      ),
      Positioned(
        left: box.right - _handleSize / 2,
        top: box.bottom - _handleSize / 2,
        width: _handleSize,
        height: _handleSize,
        child: GestureDetector(
          key: const Key('scale-handle'),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) => _onScaleStart(e, d.globalPosition),
          onPanUpdate: (d) =>
              _onScaleUpdate(context, _step(d.globalPosition), side),
          onPanEnd: (_) => c.endGesture(),
          onPanCancel: c.endGesture,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.blue, width: 1.5),
            ),
          ),
        ),
      ),
    ];
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 16.0;
    final light = Paint()..color = const Color(0xFFFFFFFF);
    final dark = Paint()..color = const Color(0xFFD8D8D8);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = 0; x * cell < size.width; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          (x + y).isEven ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => false;
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter({required this.safeZone, required this.macBody});

  final bool safeZone;
  final bool macBody;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xCCFF4081);
    if (safeZone) {
      // Android adaptive icon safe zone: 66dp of the 72dp visible area.
      final d = size.width * 66 / 72;
      canvas.drawCircle(size.center(Offset.zero), d / 2, paint);
    }
    if (macBody) canvas.drawPath(macBodyPath(size.width), paint);
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.safeZone != safeZone || old.macBody != macBody;
}

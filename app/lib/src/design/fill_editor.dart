import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:material_ui/material_ui.dart';

const _presets = <int>[
  0xFFFFFFFF,
  0xFF000000,
  0xFFE53935,
  0xFFFB8C00,
  0xFFFDD835,
  0xFF43A047,
  0xFF1E88E5,
  0xFF8E24AA,
];

/// Parses `RRGGBB` or `AARRGGBB`, with or without a leading `#`; `null`
/// when invalid.
JColor? parseHexInput(String input) {
  var s = input.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (!RegExp(r'^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(s)) return null;
  final v = int.parse(s, radix: 16);
  return JColor(s.length == 6 ? 0xFF000000 | v : v);
}

/// A hex text field. Commits on submit and on focus loss: calls [onColor]
/// for a valid entry, shows "Geçersiz renk" for an invalid one.
class HexField extends StatefulWidget {
  const HexField({
    super.key,
    required this.color,
    required this.onColor,
    this.label,
  });

  final JColor color;
  final ValueChanged<JColor> onColor;
  final String? label;

  @override
  State<HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<HexField> {
  late final TextEditingController _text = TextEditingController(
    text: _format(widget.color),
  );
  bool _invalid = false;

  /// Last color reported or received; submit and the following focus loss
  /// must not both commit before the parent has rebuilt.
  late JColor _committed = widget.color;

  static String _format(JColor c) => c.toHex().substring(1);

  @override
  void didUpdateWidget(HexField old) {
    super.didUpdateWidget(old);
    if (old.color != widget.color) _committed = widget.color;
    if (old.color != widget.color &&
        parseHexInput(_text.text) != widget.color) {
      _text.text = _format(widget.color);
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Validates and commits [value]; called on submit and focus loss.
  void _commit(String value) {
    final c = parseHexInput(value);
    setState(() => _invalid = c == null);
    if (c != null && c != _committed) {
      _committed = c;
      widget.onColor(c);
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (focused) {
      if (!focused) _commit(_text.text);
    },
    child: TextField(
      controller: _text,
      onChanged: (_) {
        if (_invalid) setState(() => _invalid = false);
      },
      onSubmitted: _commit,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F#]')),
      ],
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.label,
        prefixText: '#',
        errorText: _invalid ? 'Geçersiz renk' : null,
      ),
    ),
  );
}

enum FillKind { solid, linear, radial }

String _kindLabel(FillKind k) => switch (k) {
  FillKind.solid => 'Düz renk',
  FillKind.linear => 'Doğrusal gradyan',
  FillKind.radial => 'Radyal gradyan',
};

FillKind kindOf(Fill? f) => switch (f) {
  LinearGradientFill() => FillKind.linear,
  RadialGradientFill() => FillKind.radial,
  _ => FillKind.solid,
};

/// Default fill of [kind] over [area] whose first color is [c0] and second
/// [c1]. Linear spans the diagonal; radial is centred with the half
/// diagonal as radius, or [radius] when given.
Fill defaultFill(
  FillKind kind,
  ui.Rect area,
  JColor c0,
  JColor c1, {
  double? radius,
}) => switch (kind) {
  FillKind.solid => SolidFill(c0),
  FillKind.linear => LinearGradientFill(
    [GradientStop(0, c0), GradientStop(1, c1)],
    area.left,
    area.top,
    area.right,
    area.bottom,
  ),
  FillKind.radial => RadialGradientFill(
    [GradientStop(0, c0), GradientStop(1, c1)],
    area.center.dx,
    area.center.dy,
    radius ??
        math.sqrt(area.width * area.width + area.height * area.height) / 2,
  ),
};

/// Edits a [Fill]: type dropdown, hex fields and preset swatches.
///
/// [area] is where default gradient coordinates are placed when the type
/// changes; [radialRadius] overrides the default radial radius.
class FillEditor extends StatelessWidget {
  const FillEditor({
    super.key,
    required this.fill,
    required this.area,
    required this.onChanged,
    this.radialRadius,
  });

  final Fill? fill;
  final ui.Rect area;
  final double? radialRadius;
  final ValueChanged<Fill> onChanged;

  static const _black = JColor(0xFF000000);
  static const _white = JColor(0xFFFFFFFF);

  List<JColor> get _colors => switch (fill) {
    SolidFill(:final color) => [color],
    LinearGradientFill(:final stops) => [for (final s in stops) s.color],
    RadialGradientFill(:final stops) => [for (final s in stops) s.color],
    null => [_black],
  };

  void _changeKind(FillKind kind) {
    final first = _colors.first;
    final second = _colors.length > 1
        ? _colors[1]
        : (first == _white ? _black : _white);
    onChanged(defaultFill(kind, area, first, second, radius: radialRadius));
  }

  void _setColor(int index, JColor c) {
    final f = fill;
    switch (f) {
      case LinearGradientFill():
        onChanged(f.copyWith(stops: _withStop(f.stops, index, c)));
      case RadialGradientFill():
        onChanged(f.copyWith(stops: _withStop(f.stops, index, c)));
      default:
        onChanged(SolidFill(c));
    }
  }

  List<GradientStop> _withStop(List<GradientStop> s, int i, JColor c) => [
    for (var k = 0; k < s.length; k++)
      if (k == i) s[k].copyWith(color: c) else s[k],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final kind = kindOf(fill);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<FillKind>(
          key: const Key('fill-type'),
          isExpanded: true,
          value: kind,
          items: [
            for (final k in FillKind.values)
              DropdownMenuItem(value: k, child: Text(_kindLabel(k))),
          ],
          onChanged: (k) {
            if (k != null && k != kind) _changeKind(k);
          },
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < colors.length; i++) ...[
          HexField(
            key: Key('fill-hex-$i'),
            label: kind == FillKind.solid ? 'Renk' : 'Renk ${i + 1}',
            color: colors[i],
            onColor: (c) => _setColor(i, c),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final p in _presets)
              InkWell(
                key: Key('swatch-${p.toRadixString(16).toUpperCase()}'),
                onTap: () => _setColor(0, JColor(p)),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(p),
                    border: Border.all(color: const Color(0x33000000)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

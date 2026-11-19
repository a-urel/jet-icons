import 'package:jet_icons_core/jet_icons_core.dart';

/// Every element id in [doc], including group children and detached
/// override layers.
Set<String> allElementIds(IconDocument doc) {
  final ids = <String>{};
  void elements(List<IconElement> list) {
    for (final e in list) {
      ids.add(e.id);
      if (e is GroupElement) elements(e.children);
    }
  }

  for (final l in [doc.background, doc.foreground, doc.monochrome]) {
    if (l != null) elements(l.elements);
  }
  for (final o in doc.overrides) {
    for (final l in o.detached.values) {
      elements(l.elements);
    }
  }
  return ids;
}

/// Smallest `eN` (N >= 1) not in [used].
String nextFreeId(Set<String> used) {
  var n = 1;
  while (used.contains('e$n')) {
    n++;
  }
  return 'e$n';
}

/// Copy of [layer] whose elements (deeply) all get new ids that are free in
/// [used]; [used] is extended with the ids handed out.
Layer withFreshIds(Layer layer, Set<String> used) =>
    layer.copyWith(elements: _fresh(layer.elements, used));

List<IconElement> _fresh(List<IconElement> list, Set<String> used) => [
  for (final e in list) _freshElement(e, used),
];

IconElement _freshElement(IconElement e, Set<String> used) {
  final id = nextFreeId(used);
  used.add(id);
  return switch (e) {
    PathElement() => e.copyWith(id: id),
    GroupElement() => e.copyWith(id: id, children: _fresh(e.children, used)),
    RasterElement() => e.copyWith(id: id),
    RawSvgElement() => e.copyWith(id: id),
  };
}

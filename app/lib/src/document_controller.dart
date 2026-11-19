import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jet_icons_core/jet_icons_core.dart';

import 'shared/ids.dart';

const _maxHistory = 100;

/// Holds the open icon document, its undo/redo history, the current selection
/// and the backing `.jeticon` file path.
class DocumentController extends ChangeNotifier {
  DocumentController([IconDocument? initial])
    : _doc = initial ?? IconDocument.empty();

  IconDocument _doc;
  String? _filePath;
  bool _dirty = false;
  String? _selectedElementId;
  LayerKind _selectedLayer = LayerKind.foreground;
  final List<IconDocument> _undo = [];
  final List<IconDocument> _redo = [];

  IconDocument get doc => _doc;
  String? get filePath => _filePath;
  bool get dirty => _dirty;
  String? get selectedElementId => _selectedElementId;
  LayerKind get selectedLayer => _selectedLayer;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Replaces the document with [next], recording the old one for undo.
  void apply(IconDocument next) {
    _push(next);
    notifyListeners();
  }

  IconDocument? _gestureStart;

  /// Starts a continuous edit (drag, slider): [preview] updates are not
  /// recorded; [endGesture] records the whole gesture as one undo step.
  void beginGesture() => _gestureStart = _doc;

  /// Replaces the document without touching history or [dirty] while a
  /// gesture is active. Outside a gesture (e.g. keyboard slider steps) it
  /// behaves like [apply] so the change stays undoable.
  void preview(IconDocument next) {
    if (_gestureStart == null) return apply(next);
    _doc = next;
    notifyListeners();
  }

  /// Pushes the [beginGesture] snapshot as one undo step if the document
  /// changed since; otherwise does nothing.
  void endGesture() {
    final start = _gestureStart;
    _gestureStart = null;
    if (start == null || start == _doc) return;
    _undo.add(start);
    if (_undo.length > _maxHistory) _undo.removeAt(0);
    _redo.clear();
    _dirty = true;
    notifyListeners();
  }

  void _push(IconDocument next) {
    _undo.add(_doc);
    if (_undo.length > _maxHistory) _undo.removeAt(0);
    _redo.clear();
    _doc = next;
    _dirty = true;
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_doc);
    _doc = _undo.removeLast();
    _afterHistoryMove();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_doc);
    _doc = _redo.removeLast();
    _afterHistoryMove();
  }

  void _afterHistoryMove() {
    _dirty = true;
    final id = _selectedElementId;
    if (id != null && !allElementIds(_doc).contains(id)) {
      _selectedElementId = null;
    }
    notifyListeners();
  }

  void select(LayerKind layer, [String? elementId]) {
    _selectedLayer = layer;
    _selectedElementId = elementId;
    notifyListeners();
  }

  /// Loads [path]. Throws [JeticonFormatException] for an invalid file, in
  /// which case the current document is left untouched.
  Future<void> open(String path) async {
    final loaded = decodeJeticon(await File(path).readAsString());
    _doc = loaded;
    _filePath = path;
    _undo.clear();
    _redo.clear();
    _dirty = false;
    _selectedElementId = null;
    notifyListeners();
  }

  /// Writes the document to [path], or to [filePath] when omitted. Throws
  /// [StateError] when neither is known (callers should route to Save As).
  Future<void> save([String? path]) async {
    final target = path ?? _filePath;
    if (target == null) {
      throw StateError('No file path: use Save As');
    }
    await File(target).writeAsString(encodeJeticon(_doc));
    _filePath = target;
    _dirty = false;
    notifyListeners();
  }

  /// Imports an SVG or PNG file as a new element at the end of [layer] and
  /// selects it. One undo step removes the whole import. Throws
  /// [ArgumentError] for any other extension.
  List<ImportWarning> importBytes(
    String fileName,
    Uint8List bytes,
    LayerKind layer,
  ) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    final id = nextFreeId(allElementIds(_doc));
    final name = fileName.split(RegExp(r'[/\\]')).last;
    final result = switch (ext) {
      'svg' => importSvg(utf8.decode(bytes), id: id, name: name),
      'png' => importPng(bytes, id: id, name: name),
      _ => throw ArgumentError.value(
        fileName,
        'fileName',
        'Unsupported file type; expected .svg or .png',
      ),
    };

    final current = switch (layer) {
      LayerKind.background => _doc.background,
      LayerKind.foreground => _doc.foreground,
      LayerKind.monochrome => _doc.monochrome ?? const Layer(null, []),
    };
    final updated = current.copyWith(
      elements: [...current.elements, result.element],
    );
    _push(switch (layer) {
      LayerKind.background => _doc.copyWith(background: updated),
      LayerKind.foreground => _doc.copyWith(foreground: updated),
      LayerKind.monochrome => _doc.copyWith(monochrome: updated),
    });
    _selectedLayer = layer;
    _selectedElementId = result.element.id;
    notifyListeners();
    return result.warnings;
  }
}

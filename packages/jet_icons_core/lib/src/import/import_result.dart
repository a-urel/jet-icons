import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../model/element.dart';

/// Outcome of importing a logo file: the element plus any import warnings.
@immutable
class ImportResult {
  const ImportResult(this.element, this.warnings);

  final IconElement element;
  final List<ImportWarning> warnings;
}

@immutable
sealed class ImportWarning {
  const ImportWarning();
}

/// The SVG used features the importer cannot map to editable paths, so the
/// whole file was kept as a raw SVG. [tags] are deduplicated, first-seen order.
class UnsupportedSvgFeatures extends ImportWarning {
  const UnsupportedSvgFeatures(this.tags);

  final List<String> tags;

  @override
  bool operator ==(Object other) =>
      other is UnsupportedSvgFeatures &&
      const ListEquality<String>().equals(other.tags, tags);

  @override
  int get hashCode => const ListEquality<String>().hash(tags);

  @override
  String toString() => 'UnsupportedSvgFeatures($tags)';
}

/// The raster is smaller than [recommended] pixels on its longest edge.
class LowResolution extends ImportWarning {
  const LowResolution(this.width, this.height, this.recommended);

  final int width;
  final int height;
  final int recommended;

  @override
  bool operator ==(Object other) =>
      other is LowResolution &&
      other.width == width &&
      other.height == height &&
      other.recommended == recommended;

  @override
  int get hashCode => Object.hash(width, height, recommended);

  @override
  String toString() =>
      'LowResolution($width x $height, recommended $recommended)';
}

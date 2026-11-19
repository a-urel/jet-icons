import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../model/override.dart';

/// Which layers an output renders and how they are composed.
///
/// [monochrome]: monochrome layer as white + alpha. [tinted]: monochrome layer
/// in white over an opaque black background.
enum Composition { full, foreground, background, monochrome, tinted }

enum ContainerKind { ico, icns }

/// One raster render: what to draw, at what size and in which mask.
@immutable
class RenderRequest {
  const RenderRequest(
    this.sizePx,
    this.composition,
    this.shape, {
    this.macTemplate = false,
    this.contentScale = 1.0,
    this.flattenAlpha = false,
  });

  final int sizePx;
  final Composition composition;
  final IconShape shape;

  /// Apply the macOS icon template (inset + shadow).
  final bool macTemplate;

  /// Design canvas edge / output edge (Android 108dp canvas: 72/108). The
  /// background fill always covers the whole output.
  final double contentScale;

  /// Output must have no alpha channel.
  final bool flattenAlpha;

  @override
  bool operator ==(Object other) =>
      other is RenderRequest &&
      other.sizePx == sizePx &&
      other.composition == composition &&
      other.shape == shape &&
      other.macTemplate == macTemplate &&
      other.contentScale == contentScale &&
      other.flattenAlpha == flattenAlpha;

  @override
  int get hashCode => Object.hash(
    sizePx,
    composition,
    shape,
    macTemplate,
    contentScale,
    flattenAlpha,
  );

  @override
  String toString() =>
      'RenderRequest($sizePx, $composition, $shape, macTemplate: $macTemplate, '
      'contentScale: $contentScale, flattenAlpha: $flattenAlpha)';
}

/// A file a platform needs, addressed by its path inside the platform folder.
@immutable
sealed class OutputFile {
  const OutputFile(this.path, this.platform);

  final String path;
  final IconPlatform platform;
}

class ImageOutput extends OutputFile {
  const ImageOutput(super.path, super.platform, this.variant, this.request);

  final IconVariant variant;
  final RenderRequest request;

  @override
  bool operator ==(Object other) =>
      other is ImageOutput &&
      other.path == path &&
      other.platform == platform &&
      other.variant == variant &&
      other.request == request;

  @override
  int get hashCode => Object.hash(path, platform, variant, request);

  @override
  String toString() => 'ImageOutput($path, $variant, $request)';
}

/// A multi-image container (.ico / .icns); images are resolved as `light`.
class ContainerOutput extends OutputFile {
  const ContainerOutput(super.path, super.platform, this.kind, this.images);

  final ContainerKind kind;
  final List<RenderRequest> images;

  @override
  bool operator ==(Object other) =>
      other is ContainerOutput &&
      other.path == path &&
      other.platform == platform &&
      other.kind == kind &&
      const ListEquality<RenderRequest>().equals(other.images, images);

  @override
  int get hashCode =>
      Object.hash(path, platform, kind, const ListEquality().hash(images));

  @override
  String toString() => 'ContainerOutput($path, $kind, $images)';
}

class TextOutput extends OutputFile {
  const TextOutput(super.path, super.platform, this.content);

  final String content;

  @override
  bool operator ==(Object other) =>
      other is TextOutput &&
      other.path == path &&
      other.platform == platform &&
      other.content == content;

  @override
  int get hashCode => Object.hash(path, platform, content);

  @override
  String toString() => 'TextOutput($path)';
}

/// Request for a document-chosen [shape]: `none` renders foreground only.
RenderRequest shapedRequest(int sizePx, IconShape shape) => RenderRequest(
  sizePx,
  shape == IconShape.none ? Composition.foreground : Composition.full,
  shape,
);

/// Pure-Dart core of jet-icons: icon model and `.jeticon` codec.
library;

export 'src/codec/jeticon_codec.dart';
export 'src/encoders/adaptive_icon_xml.dart';
export 'src/encoders/contents_json.dart';
export 'src/encoders/icns.dart';
export 'src/encoders/ico.dart';
export 'src/encoders/png_alpha.dart';
export 'src/encoders/web_manifest.dart';
export 'src/model/color.dart';
export 'src/model/document.dart';
export 'src/model/element.dart';
export 'src/model/fill.dart';
export 'src/model/layer.dart';
export 'src/model/override.dart';
export 'src/model/transform.dart';
export 'src/resolve/resolver.dart'
    show ResolvedIcon, findElement, resolveIcon, shapeFor;
export 'src/platforms/output.dart'
    show
        Composition,
        ContainerKind,
        ContainerOutput,
        ImageOutput,
        OutputFile,
        RenderRequest,
        TextOutput;
export 'src/platforms/outputs.dart' show outputsFor;

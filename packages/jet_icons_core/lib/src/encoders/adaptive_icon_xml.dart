/// Android `mipmap-anydpi-v26/ic_launcher.xml` adaptive icon definition.
String adaptiveIconXml({required bool includeMonochrome}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln(
      '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">',
    )
    ..writeln(
      '    <background android:drawable="@mipmap/ic_launcher_background"/>',
    )
    ..writeln(
      '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>',
    );
  if (includeMonochrome) {
    b.writeln(
      '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>',
    );
  }
  b.writeln('</adaptive-icon>');
  return b.toString();
}

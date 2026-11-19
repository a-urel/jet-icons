import 'dart:io';

import 'export_runner.dart';

/// Thrown when the export target is a non-empty folder and overwrite is off.
class ExportTargetExistsException implements Exception {
  ExportTargetExistsException(this.targetPath);

  final String targetPath;

  @override
  String toString() =>
      'ExportTargetExistsException: target folder is not empty: $targetPath';
}

/// Writes [bundle] into `parent/folderName`. Only bundle paths are written;
/// other files in the target are never touched.
Future<Directory> writeToFolder(
  ExportBundle bundle,
  Directory parent, {
  String folderName = 'jet-icons-export',
  bool overwrite = false,
}) async {
  final target = Directory('${parent.path}/$folderName');
  if (await target.exists()) {
    if (!overwrite && !await target.list().isEmpty) {
      throw ExportTargetExistsException(target.path);
    }
  } else {
    await target.create(recursive: true);
  }
  for (final e in bundle.files.entries) {
    final file = File('${target.path}/${e.key}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(e.value);
  }
  return target;
}

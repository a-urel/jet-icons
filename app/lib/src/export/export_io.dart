import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:jet_icons_core/jet_icons_core.dart';

/// Injectable file-system and dialog access for the export tab.
class ExportIo {
  const ExportIo({
    this.pickZipPath = _pickZipPath,
    this.pickDirectory = _pickDirectory,
    this.writeFolder = _writeFolder,
    this.writeFile = _writeFile,
    this.exists = _exists,
    this.revealFolder = _revealFolder,
  });

  /// Asks where to save the zip; `null` when cancelled.
  final Future<String?> Function() pickZipPath;

  /// Asks for the parent folder; `null` when cancelled.
  final Future<String?> Function() pickDirectory;

  final Future<Directory> Function(
    ExportBundle bundle,
    Directory parent, {
    bool overwrite,
  })
  writeFolder;

  final Future<void> Function(String path, Uint8List bytes) writeFile;

  final Future<void> Function(String path) revealFolder;

  /// Whether a file already exists at the path.
  final Future<bool> Function(String path) exists;
}

Future<String?> _pickZipPath() async => (await getSaveLocation(
  acceptedTypeGroups: const [
    XTypeGroup(label: 'zip', extensions: ['zip']),
  ],
  suggestedName: 'jet-icons.zip',
))?.path;

Future<String?> _pickDirectory() => getDirectoryPath();

Future<Directory> _writeFolder(
  ExportBundle bundle,
  Directory parent, {
  bool overwrite = false,
}) => writeToFolder(bundle, parent, overwrite: overwrite);

Future<void> _writeFile(String path, Uint8List bytes) =>
    File(path).writeAsBytes(bytes);

Future<bool> _exists(String path) => File(path).exists();

Future<void> _revealFolder(String path) async {
  final command = Platform.isMacOS
      ? 'open'
      : Platform.isWindows
      ? 'explorer'
      : 'xdg-open';
  await Process.run(command, [path]);
}

import 'dart:io';
import 'dart:typed_data';

import 'package:jet_icons_core/jet_icons_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory parent;
  final bundle = ExportBundle({
    'ios/a.png': Uint8List.fromList([1, 2, 3]),
    'web/icons/b.png': Uint8List.fromList([4]),
  });

  setUp(() => parent = Directory.systemTemp.createTempSync('jet_icons_w'));
  tearDown(() => parent.deleteSync(recursive: true));

  test('creates missing target and writes files', () async {
    final dir = await writeToFolder(bundle, parent);
    expect(dir.path, '${parent.path}/jet-icons-export');
    expect(File('${dir.path}/ios/a.png').readAsBytesSync(), [1, 2, 3]);
    expect(File('${dir.path}/web/icons/b.png').readAsBytesSync(), [4]);
  });

  test('writes into existing empty target', () async {
    Directory('${parent.path}/jet-icons-export').createSync();
    await writeToFolder(bundle, parent);
    expect(
      File('${parent.path}/jet-icons-export/ios/a.png').existsSync(),
      true,
    );
  });

  test('refuses non-empty target without overwrite', () async {
    File('${parent.path}/jet-icons-export/keep.txt')
        .createSync(recursive: true);
    final target = '${parent.path}/jet-icons-export';
    await expectLater(
      writeToFolder(bundle, parent),
      throwsA(
        isA<ExportTargetExistsException>().having(
          (e) => e.toString(),
          'toString',
          contains(target),
        ),
      ),
    );
    expect(File('$target/ios/a.png').existsSync(), false);
  });

  test('overwrite keeps unrelated files and replaces bundle paths', () async {
    final target = '${parent.path}/jet-icons-export';
    File('$target/keep.txt').createSync(recursive: true);
    File('$target/ios/a.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync([9, 9]);
    await writeToFolder(bundle, parent, overwrite: true);
    expect(File('$target/keep.txt').existsSync(), true);
    expect(File('$target/ios/a.png').readAsBytesSync(), [1, 2, 3]);
  });

  test('custom folderName', () async {
    final dir = await writeToFolder(bundle, parent, folderName: 'out');
    expect(dir.path, '${parent.path}/out');
  });
}

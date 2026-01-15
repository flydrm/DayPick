import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupFileStore {
  const BackupFileStore();

  Future<String> saveToAppDocuments({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await _ensureDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _ensureDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'daypick_backups'));
    if (await dir.exists()) return dir;

    final backupDirs = await root
        .list()
        .where((e) => e is Directory)
        .map((e) => e as Directory)
        .where((d) => p.basename(d.path).endsWith('_backups'))
        .toList();
    if (backupDirs.length == 1) {
      try {
        await backupDirs.single.rename(dir.path);
        return dir;
      } catch (_) {
        return backupDirs.single;
      }
    }

    await dir.create(recursive: true);
    return dir;
  }
}

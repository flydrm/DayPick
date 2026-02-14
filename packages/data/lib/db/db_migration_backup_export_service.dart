import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DbMigrationBackupExportService {
  DbMigrationBackupExportService({
    this.nowUtcMs = _defaultNowUtcMs,
    Future<Directory> Function()? getDocumentsDirectory,
  }) : _getDocumentsDirectory =
           getDocumentsDirectory ?? getApplicationDocumentsDirectory;

  final int Function() nowUtcMs;
  final Future<Directory> Function() _getDocumentsDirectory;

  Future<bool> hasMigrationBackupFiles() async {
    final dir = await _getDocumentsDirectory();
    final mainLocked = File(p.join(dir.path, _lockedDbFileName));
    final mainLockedAlt = File(p.join(dir.path, _lockedDbFileNameAlt));
    return (await mainLocked.exists()) || (await mainLockedAlt.exists());
  }

  /// Creates a content-free zip of plaintext pre-migration backup files if present.
  ///
  /// Returns null if no backup files exist.
  Future<Uint8List?> createMigrationBackupZipBytes() async {
    final dir = await _getDocumentsDirectory();

    File? pickFile(List<String> candidates) {
      for (final name in candidates) {
        final f = File(p.join(dir.path, name));
        if (f.existsSync()) return f;
      }
      return null;
    }

    final db = pickFile([_lockedDbFileName, _lockedDbFileNameAlt]);
    if (db == null) return null;

    final wal = pickFile([_lockedWalFileName, _lockedWalFileNameAlt]);
    final shm = pickFile([_lockedShmFileName, _lockedShmFileNameAlt]);

    final files = <String, List<int>>{
      'manifest.json': utf8.encode(
        jsonEncode({
          'format': 'daypick-migration-backup',
          'exported_at_utc_ms': nowUtcMs(),
          'files': {
            'db': db.path.split(Platform.pathSeparator).last,
            'wal': wal?.path.split(Platform.pathSeparator).last,
            'shm': shm?.path.split(Platform.pathSeparator).last,
          },
        }),
      ),
      _canonicalDbFileName: await db.readAsBytes(),
    };
    if (wal != null) files[_canonicalWalFileName] = await wal.readAsBytes();
    if (shm != null) files[_canonicalShmFileName] = await shm.readAsBytes();

    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}

int _defaultNowUtcMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

const _canonicalDbFileName = 'daypick.sqlite';
const _canonicalWalFileName = 'daypick.sqlite-wal';
const _canonicalShmFileName = 'daypick.sqlite-shm';

// Preferred naming (keeps WAL/SHM paired to the locked DB file name).
const _lockedDbFileName = 'daypick.sqlite.locked';
const _lockedWalFileName = 'daypick.sqlite.locked-wal';
const _lockedShmFileName = 'daypick.sqlite.locked-shm';

// Legacy naming (suffix at the end) used by DatabaseResetService today.
const _lockedDbFileNameAlt = 'daypick.sqlite.locked';
const _lockedWalFileNameAlt = 'daypick.sqlite-wal.locked';
const _lockedShmFileNameAlt = 'daypick.sqlite-shm.locked';


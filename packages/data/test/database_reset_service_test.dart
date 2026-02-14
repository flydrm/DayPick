import 'dart:io';
import 'dart:typed_data';

import 'package:data/db/database_reset_service.dart';
import 'package:data/db/db_key_store.dart';
import 'package:data/db/db_migration_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeDbKeyStorage implements DbKeyStorage {
  Uint8List? value;
  var deleteCount = 0;

  @override
  Future<String?> read(String key) async {
    final currentValue = value;
    if (currentValue == null) return null;
    return String.fromCharCodes(currentValue);
  }

  @override
  Future<void> write(String key, String value) async {
    this.value = Uint8List.fromList(value.codeUnits);
  }

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    value = null;
  }
}

void main() {
  test('resetAll deletes sqlite files, migration marker and db key', () async {
    final dir = await Directory.systemTemp.createTemp('daypick_reset_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final storage = _FakeDbKeyStorage()..value = Uint8List.fromList([1]);
    final keyStore = DbKeyStore(
      storage: storage,
      generateRandomBytes: (len) => Uint8List(len),
    );
    final service = DatabaseResetService(
      keyStore: keyStore,
      getDocumentsDirectory: () async => dir,
    );

    final db = File(p.join(dir.path, 'daypick.sqlite'));
    final wal = File(p.join(dir.path, 'daypick.sqlite-wal'));
    final note = File(p.join(dir.path, 'note.txt'));
    final migrationMarker = File(
      p.join(dir.path, DbMigrationStateStore.defaultFileName),
    );
    await db.writeAsString('db');
    await wal.writeAsString('wal');
    await note.writeAsString('keep');
    await migrationMarker.writeAsString('{"stage":"in_progress"}');

    final ok = await service.resetAll();
    expect(ok, isTrue);

    expect(await db.exists(), isFalse);
    expect(await wal.exists(), isFalse);
    expect(await note.exists(), isTrue);
    expect(await migrationMarker.exists(), isFalse);
    expect(storage.deleteCount, 1);
  });

  test('backupExistingDatabaseFiles renames and can restore', () async {
    final dir = await Directory.systemTemp.createTemp('daypick_backup_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final service = DatabaseResetService(
      getDocumentsDirectory: () async => dir,
    );

    final db = File(p.join(dir.path, 'daypick.sqlite'));
    final wal = File(p.join(dir.path, 'daypick.sqlite-wal'));
    final shm = File(p.join(dir.path, 'daypick.sqlite-shm'));
    await db.writeAsString('old');
    await wal.writeAsString('wal_old');
    await shm.writeAsString('shm_old');

    final backup = await service.backupExistingDatabaseFiles();
    expect(backup, isNotNull);
    expect(await db.exists(), isFalse);
    expect(await wal.exists(), isFalse);
    expect(await shm.exists(), isFalse);

    final backupDb = File(
      '${db.path}${DatabaseResetService.defaultBackupFileSuffix}',
    );
    final backupWal = File(
      '${wal.path}${DatabaseResetService.defaultBackupFileSuffix}',
    );
    final backupShm = File(
      '${shm.path}${DatabaseResetService.defaultBackupFileSuffix}',
    );
    expect(await backupDb.exists(), isTrue);
    expect(await backupWal.exists(), isTrue);
    expect(await backupShm.exists(), isTrue);

    await db.writeAsString('new');
    await wal.writeAsString('wal_new');
    await shm.writeAsString('shm_new');

    await service.restoreDatabaseFilesFromBackup(backup);
    expect(await db.exists(), isTrue);
    expect(await wal.exists(), isTrue);
    expect(await shm.exists(), isTrue);
    expect(await db.readAsString(), 'old');
    expect(await wal.readAsString(), 'wal_old');
    expect(await shm.readAsString(), 'shm_old');
    expect(await backupDb.exists(), isFalse);
    expect(await backupWal.exists(), isFalse);
    expect(await backupShm.exists(), isFalse);
  });

  test(
    'backupExistingDatabaseFiles replaces stale restore backup files',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'daypick_backup_stale_',
      );
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final service = DatabaseResetService(
        getDocumentsDirectory: () async => dir,
      );

      final db = File(p.join(dir.path, 'daypick.sqlite'));
      final backupDb = File(
        '${db.path}${DatabaseResetService.defaultBackupFileSuffix}',
      );

      await db.writeAsString('fresh_db');
      await backupDb.writeAsString('stale_db');

      final backup = await service.backupExistingDatabaseFiles();
      expect(backup, isNotNull);
      expect(await db.exists(), isFalse);
      expect(await backupDb.exists(), isTrue);
      expect(await backupDb.readAsString(), 'fresh_db');

      await service.restoreDatabaseFilesFromBackup(backup);
      expect(await db.exists(), isTrue);
      expect(await db.readAsString(), 'fresh_db');
    },
  );
}

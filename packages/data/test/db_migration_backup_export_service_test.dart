import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:data/db/db_migration_backup_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('createMigrationBackupZipBytes returns null when no locked db exists', () async {
    final dir = await Directory.systemTemp.createTemp('daypick_migration_backup_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final service = DbMigrationBackupExportService(
      getDocumentsDirectory: () async => dir,
    );

    expect(await service.createMigrationBackupZipBytes(), isNull);
  });

  test('zip uses canonical entry names (legacy wal/shm naming)', () async {
    final dir = await Directory.systemTemp.createTemp('daypick_migration_backup_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final dbLocked = File(p.join(dir.path, 'daypick.sqlite.locked'));
    final walLocked = File(p.join(dir.path, 'daypick.sqlite-wal.locked'));
    final shmLocked = File(p.join(dir.path, 'daypick.sqlite-shm.locked'));

    await dbLocked.writeAsBytes([1, 2, 3], flush: true);
    await walLocked.writeAsBytes([4, 5], flush: true);
    await shmLocked.writeAsBytes([6], flush: true);

    final service = DbMigrationBackupExportService(
      nowUtcMs: () => 123,
      getDocumentsDirectory: () async => dir,
    );

    final bytes = await service.createMigrationBackupZipBytes();
    expect(bytes, isNotNull);

    final archive = ZipDecoder().decodeBytes(bytes!);
    final entries = <String, Uint8List>{
      for (final f in archive.files)
        f.name: Uint8List.fromList(f.content as List<int>),
    };

    expect(entries.containsKey('manifest.json'), isTrue);
    expect(entries['daypick.sqlite'], Uint8List.fromList([1, 2, 3]));
    expect(entries['daypick.sqlite-wal'], Uint8List.fromList([4, 5]));
    expect(entries['daypick.sqlite-shm'], Uint8List.fromList([6]));
  });

  test('zip supports preferred wal/shm naming (*.locked-wal/*.locked-shm)', () async {
    final dir = await Directory.systemTemp.createTemp('daypick_migration_backup_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final dbLocked = File(p.join(dir.path, 'daypick.sqlite.locked'));
    final walLocked = File(p.join(dir.path, 'daypick.sqlite.locked-wal'));
    final shmLocked = File(p.join(dir.path, 'daypick.sqlite.locked-shm'));

    await dbLocked.writeAsBytes([7], flush: true);
    await walLocked.writeAsBytes([8], flush: true);
    await shmLocked.writeAsBytes([9], flush: true);

    final service = DbMigrationBackupExportService(
      getDocumentsDirectory: () async => dir,
    );

    final bytes = await service.createMigrationBackupZipBytes();
    expect(bytes, isNotNull);

    final archive = ZipDecoder().decodeBytes(bytes!);
    final names = archive.files.map((f) => f.name).toList();

    expect(names, containsAll(<String>[
      'manifest.json',
      'daypick.sqlite',
      'daypick.sqlite-wal',
      'daypick.sqlite-shm',
    ]));
  });
}


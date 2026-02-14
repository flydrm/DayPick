import 'dart:io';

import 'package:data/db/db_migration_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('DbMigrationStateStore write/read roundtrip updates updatedAtUtcMs', () async {
    final dir = await Directory.systemTemp.createTemp('daypick_migration_state_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    var now = 2000;
    final store = DbMigrationStateStore(
      nowUtcMs: () => now,
      getDocumentsDirectory: () async => dir,
    );

    final state = DbMigrationState(
      stage: 'started',
      startedAtUtcMs: 1000,
      updatedAtUtcMs: 1000,
      targetPath: p.join(dir.path, 'daypick.sqlite'),
      tempPath: p.join(dir.path, 'daypick.sqlite.migrating'),
      backupPaths: const ['/tmp/a.locked'],
      schemaVersion: 7,
      counts: const {'tasks': 1},
    );

    await store.write(state);

    final loaded = await store.read();
    expect(loaded, isNotNull);
    expect(loaded!.stage, 'started');
    expect(loaded.startedAtUtcMs, 1000);
    expect(loaded.updatedAtUtcMs, 2000);
    expect(loaded.targetPath, state.targetPath);
    expect(loaded.tempPath, state.tempPath);
    expect(loaded.backupPaths, state.backupPaths);
    expect(loaded.schemaVersion, 7);
    expect(loaded.counts, const {'tasks': 1});

    now = 3000;
    await store.write(loaded.copyWith(stage: 'validated'));

    final loaded2 = await store.read();
    expect(loaded2, isNotNull);
    expect(loaded2!.stage, 'validated');
    expect(loaded2.updatedAtUtcMs, 3000);
  });

  test('DbMigrationStateStore read returns null for corrupt json', () async {
    final dir = await Directory.systemTemp.createTemp('daypick_migration_state_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final store = DbMigrationStateStore(getDocumentsDirectory: () async => dir);

    final file = File(p.join(dir.path, DbMigrationStateStore.defaultFileName));
    await file.writeAsString('{', flush: true);

    expect(await store.read(), isNull);
  });

  test('DbMigrationStateStore clear deletes marker file', () async {
    final dir = await Directory.systemTemp.createTemp('daypick_migration_state_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final store = DbMigrationStateStore(getDocumentsDirectory: () async => dir);

    await store.write(
      DbMigrationState(
        stage: 'started',
        startedAtUtcMs: 1,
        updatedAtUtcMs: 1,
        targetPath: 't',
        tempPath: 'tmp',
        backupPaths: const [],
      ),
    );

    expect(await store.exists(), isTrue);
    await store.clear();
    expect(await store.exists(), isFalse);
  });
}


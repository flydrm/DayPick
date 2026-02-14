import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import 'db_key_store.dart';
import 'db_connection_policy.dart';
import 'db_migration_exceptions.dart';
import 'db_migration_state_store.dart';
import 'tables/task_check_items.dart';
import 'tables/tasks.dart';
import 'tables/active_pomodoros.dart';
import 'tables/pomodoro_sessions.dart';
import 'tables/notes.dart';
import 'tables/pomodoro_configs.dart';
import 'tables/appearance_configs.dart';
import 'tables/today_plan_items.dart';
import 'tables/weave_links.dart';
import 'tables/feature_flags.dart';
import 'tables/local_events.dart';
import 'tables/kpi_daily_rollups.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Tasks,
    TaskCheckItems,
    ActivePomodoros,
    PomodoroSessions,
    Notes,
    PomodoroConfigs,
    AppearanceConfigs,
    TodayPlanItems,
    WeaveLinks,
    FeatureFlags,
    LocalEvents,
    KpiDailyRollups,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  static AppDatabase inMemoryForTesting() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase.forTesting(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _ensureDefaultSingletons();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(activePomodoros);
        await migrator.createTable(pomodoroSessions);
      }
      if (from < 3) {
        await migrator.createTable(notes);
      }
      if (from < 4) {
        await migrator.createTable(pomodoroConfigs);
        await migrator.createTable(appearanceConfigs);
      }
      if (from < 5) {
        if (from >= 4) {
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.shortBreakMinutes,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.longBreakMinutes,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.longBreakEvery,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.autoStartBreak,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.autoStartFocus,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.notificationSound,
          );
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.notificationVibration,
          );
        }
        if (from >= 2) {
          await migrator.addColumn(activePomodoros, activePomodoros.phase);
        }
      }
      if (from < 6) {
        await migrator.createTable(todayPlanItems);
      }
      if (from < 7) {
        if (from >= 4) {
          await migrator.addColumn(appearanceConfigs, appearanceConfigs.accent);
        }
      }
      if (from < 8) {
        await migrator.addColumn(tasks, tasks.triageStatus);
        await migrator.addColumn(notes, notes.kind);
        await migrator.addColumn(notes, notes.triageStatus);
        await migrator.createTable(weaveLinks);
      }
      if (from < 9) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.defaultTab,
          );
        }
      }
      if (from < 10) {
        if (from >= 4) {
          await migrator.addColumn(
            pomodoroConfigs,
            pomodoroConfigs.dailyBudgetPomodoros,
          );
        }
      }
      if (from < 11) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.statsEnabled,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.todayModulesJson,
          );
        }
      }
      if (from < 12) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.inboxTypeFilter,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.inboxTodayOnly,
          );
        }
      }
      if (from < 13) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.timeboxingStartMinutes,
          );
        }
      }
      if (from < 14) {
        if (from >= 2) {
          await migrator.addColumn(activePomodoros, activePomodoros.focusNote);
        }
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.timeboxingLayout,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.timeboxingWorkdayStartMinutes,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.timeboxingWorkdayEndMinutes,
          );
        }
        if (from >= 6) {
          await migrator.addColumn(todayPlanItems, todayPlanItems.segment);
        }
      }
      if (from < 15) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.onboardingDone,
          );
        }
      }
      if (from < 16) {
        await migrator.createTable(featureFlags);
      }
      if (from < 17) {
        await migrator.createTable(localEvents);
      }
      if (from < 18) {
        await migrator.createTable(kpiDailyRollups);
      }
      if (from < 19) {
        if (from >= 4) {
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.calendarConstraintsDismissed,
          );
          await migrator.addColumn(
            appearanceConfigs,
            appearanceConfigs.calendarShowEventTitles,
          );
        }
      }
      await _ensureDefaultSingletons();
    },
  );

  Future<void> _ensureDefaultSingletons() async {
    const singletonId = 1;
    await into(pomodoroConfigs).insert(
      PomodoroConfigsCompanion.insert(
        id: const Value(singletonId),
        workDurationMinutes: const Value(25),
        shortBreakMinutes: const Value(5),
        longBreakMinutes: const Value(15),
        longBreakEvery: const Value(4),
        dailyBudgetPomodoros: const Value(8),
        autoStartBreak: const Value(false),
        autoStartFocus: const Value(false),
        notificationSound: const Value(false),
        notificationVibration: const Value(false),
        updatedAtUtcMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await into(appearanceConfigs).insert(
      AppearanceConfigsCompanion.insert(
        id: const Value(singletonId),
        themeMode: const Value(0),
        density: const Value(0),
        accent: const Value(0),
        defaultTab: const Value(2),
        onboardingDone: const Value(false),
        statsEnabled: const Value(false),
        todayModulesJson: const Value(
          '["nextStep","todayPlan","capture","weave","budget","focus","shortcuts","yesterdayReview"]',
        ),
        calendarConstraintsDismissed: const Value(false),
        calendarShowEventTitles: const Value(false),
        inboxTypeFilter: const Value(0),
        inboxTodayOnly: const Value(false),
        updatedAtUtcMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}

class SqlCipherUnavailableException implements Exception {
  const SqlCipherUnavailableException();

  @override
  String toString() => 'SqlCipherUnavailableException';
}

class DbEncryptedButKeyMissingException implements Exception {
  const DbEncryptedButKeyMissingException();

  @override
  String toString() => 'DbEncryptedButKeyMissingException';
}

class DbEncryptedButKeyRejectedException implements Exception {
  const DbEncryptedButKeyRejectedException({this.cause});

  final Object? cause;

  @override
  String toString() => 'DbEncryptedButKeyRejectedException';
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    _ensureSqlCipherAndroidInitialization();

    final dbFolder = await getApplicationDocumentsDirectory();
    final target = File(p.join(dbFolder.path, 'daypick.sqlite'));
    final temp = File(p.join(dbFolder.path, 'daypick.sqlite.migrating'));

    // Crash-safe guardrail: If migration artifacts exist, never create/open a new empty DB.
    final migrationStateStore = DbMigrationStateStore(
      getDocumentsDirectory: () async => dbFolder,
    );
    final hasMigrationArtifacts = await _hasMigrationArtifacts(
      dbFolder: dbFolder,
      target: target,
      temp: temp,
      stateStore: migrationStateStore,
    );
    if (hasMigrationArtifacts) {
      // Do not touch any DB files (rename/create) while migration artifacts exist.
      throw const DbMigrationFailedException(stage: 'in_progress');
    }

    final targetExists = await target.exists();
    final sqliteFiles = targetExists
        ? const <File>[]
        : await _listSqliteFiles(dbFolder);

    final openTarget = await _resolveTargetFileToOpen(
      target: target,
      targetExists: targetExists,
      sqliteFiles: sqliteFiles,
    );

    final isNewInstall = isNewInstallForSqlCipher(
      targetExists: targetExists,
      sqliteFileCount: sqliteFiles.length,
    );
    final openTargetExists = await openTarget.exists();
    final isPlaintextSqlite = openTargetExists
        ? await _looksLikePlaintextSqliteDatabase(openTarget)
        : false;

    final keyStore = DbKeyStore();

    // Key existence for plan decision (content-free, no logging).
    final keyExists = await (() async {
      try {
        return (await keyStore.readKeyHexIfExists()) != null;
      } catch (_) {
        return false;
      }
    })();

    final plan = decideDbOpenPlan(
      isNewInstall: isNewInstall,
      dbFileExists: openTargetExists,
      sqliteFileCount: sqliteFiles.length,
      hasPlaintextHeader: isPlaintextSqlite,
      keyExists: keyExists,
      hasMigrationArtifacts: hasMigrationArtifacts,
    );

    String? encryptionKeyHex;
    File finalTarget = openTarget;

    try {
      switch (plan) {
        case DbOpenPlan.migrationInProgress:
          throw const DbMigrationFailedException(stage: 'in_progress');

        case DbOpenPlan.encryptedMissingKey:
          throw const DbEncryptedButKeyMissingException();

        case DbOpenPlan.migratePlaintext:
          encryptionKeyHex = await keyStore.getOrCreateKeyHex();
          final plaintextTarget = finalTarget;
          await _migratePlaintextDbToEncrypted(
            dbFolder: dbFolder,
            target: plaintextTarget,
            temp: temp,
            encryptionKeyHex: encryptionKeyHex,
            stateStore: migrationStateStore,
          );
          finalTarget = plaintextTarget;
          break;

        case DbOpenPlan.encrypted:
          if (isNewInstall) {
            encryptionKeyHex = await keyStore.getOrCreateKeyHex();
          } else {
            encryptionKeyHex = await keyStore.readKeyHexIfExists();
            if (encryptionKeyHex == null) {
              throw const DbEncryptedButKeyMissingException();
            }
          }
          break;
      }
    } on DbKeyStoreException catch (e) {
      if (plan == DbOpenPlan.migratePlaintext) {
        throw DbMigrationFailedException(stage: 'key_store_failed', cause: e);
      }
      throw const DbEncryptedButKeyMissingException();
    }

    return NativeDatabase(
      finalTarget,
      setup: (db) {
        final keyHex = encryptionKeyHex;
        if (keyHex == null) return;

        String? cipherVersion;
        try {
          final cipherVersionRows = db.select('PRAGMA cipher_version;');
          cipherVersion = cipherVersionRows.isEmpty
              ? null
              : (cipherVersionRows.first.values.first?.toString())?.trim();
        } catch (_) {
          throw const SqlCipherUnavailableException();
        }
        if (cipherVersion == null || cipherVersion.isEmpty) {
          throw const SqlCipherUnavailableException();
        }

        db.execute("PRAGMA key = \"x'$keyHex'\";");

        try {
          db.select('PRAGMA schema_version;');
        } catch (e) {
          throw DbEncryptedButKeyRejectedException(cause: e);
        }
      },
    );
  });
}

Future<bool> _hasMigrationArtifacts({
  required Directory dbFolder,
  required File target,
  required File temp,
  required DbMigrationStateStore stateStore,
}) async {
  final state = await stateStore.read();
  if (state != null) {
    if (state.stage != 'completed') return true;
    // Best-effort cleanup: if migration completed, do not trap user in safe mode due to leftovers.
    try {
      await stateStore.clear();
    } catch (_) {}
    await _deleteIfExists(temp);

    // Backup files for migration (preferred + legacy naming).
    final lockedDb = File('${target.path}.locked');
    final lockedWal = File('${target.path}.locked-wal');
    final lockedShm = File('${target.path}.locked-shm');
    await _deleteIfExists(lockedDb);
    await _deleteIfExists(lockedWal);
    await _deleteIfExists(lockedShm);

    final legacyLockedWal = File('${target.path}-wal.locked');
    final legacyLockedShm = File('${target.path}-shm.locked');
    await _deleteIfExists(legacyLockedWal);
    await _deleteIfExists(legacyLockedShm);

    final plaintextBackup = File('${target.path}.plaintext.locked');
    final plaintextWalBackup = File('${plaintextBackup.path}-wal');
    final plaintextShmBackup = File('${plaintextBackup.path}-shm');
    await _deleteIfExists(plaintextBackup);
    await _deleteIfExists(plaintextWalBackup);
    await _deleteIfExists(plaintextShmBackup);

    return false;
  } else {
    // Corrupt marker file is treated as "in progress" to avoid silent data loss.
    if (await stateStore.exists()) return true;
  }
  if (await temp.exists()) return true;

  // Backup files for migration (preferred + legacy naming).
  final lockedDb = File('${target.path}.locked');
  final lockedWal = File('${target.path}.locked-wal');
  final lockedShm = File('${target.path}.locked-shm');
  if (await lockedDb.exists()) return true;
  if (await lockedWal.exists()) return true;
  if (await lockedShm.exists()) return true;

  final legacyLockedWal = File('${target.path}-wal.locked');
  final legacyLockedShm = File('${target.path}-shm.locked');
  if (await legacyLockedWal.exists()) return true;
  if (await legacyLockedShm.exists()) return true;

  // Extra guard: if any "*.locked" exists for this DB, treat as in-progress.
  final lockedPrefix = '${target.path}.';
  await for (final entity in dbFolder.list(followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.path;
    if (!path.startsWith(lockedPrefix)) continue;
    if (path.endsWith('.locked')) return true;
  }

  return false;
}

Future<void> _migratePlaintextDbToEncrypted({
  required Directory dbFolder,
  required File target,
  required File temp,
  required String? encryptionKeyHex,
  required DbMigrationStateStore stateStore,
}) async {
  final keyHex = encryptionKeyHex;
  if (keyHex == null || keyHex.isEmpty) {
    throw const DbMigrationFailedException(stage: 'key_missing');
  }

  final now = stateStore.nowUtcMs();

  var current = DbMigrationState(
    stage: 'started',
    startedAtUtcMs: now,
    updatedAtUtcMs: now,
    targetPath: target.path,
    tempPath: temp.path,
    backupPaths: const [],
  );
  await stateStore.write(current);

  if (!await target.exists()) {
    current = current.copyWith(stage: 'missing_plaintext_db');
    await stateStore.write(current);
    throw const DbMigrationFailedException(stage: 'missing_plaintext_db');
  }

  // Prepare crash-safe backups (file-level, content-free).
  final backupDb = File('${target.path}.locked');
  final backupWal = File('${target.path}.locked-wal');
  final backupShm = File('${target.path}.locked-shm');

  if (await backupDb.exists() ||
      await backupWal.exists() ||
      await backupShm.exists() ||
      await temp.exists()) {
    current = current.copyWith(stage: 'in_progress');
    await stateStore.write(current);
    throw const DbMigrationFailedException(stage: 'in_progress');
  }

  final backupPaths = <String>[];
  Future<void> copyIfExists(File from, File to) async {
    if (!await from.exists()) return;
    await from.copy(to.path);
    backupPaths.add(to.path);
  }

  try {
    await copyIfExists(target, backupDb);
    await copyIfExists(File('${target.path}-wal'), backupWal);
    await copyIfExists(File('${target.path}-shm'), backupShm);
    current = current.copyWith(stage: 'backup_completed', backupPaths: backupPaths);
    await stateStore.write(current);
  } catch (e) {
    current = current.copyWith(stage: 'backup_failed');
    await stateStore.write(current);
    throw DbMigrationFailedException(stage: 'backup_failed', cause: e);
  }

  // Export plaintext -> encrypted (write to temp first).
  try {
    final oldCounts = _countKeyTablesPlaintext(dbPath: target.path);

    final db = sqlite3.open(target.path);
    try {
      String? cipherVersion;
      try {
        final cipherVersionRows = db.select('PRAGMA cipher_version;');
        cipherVersion = cipherVersionRows.isEmpty
            ? null
            : (cipherVersionRows.first.values.first?.toString())?.trim();
      } catch (_) {
        throw const SqlCipherUnavailableException();
      }
      if (cipherVersion == null || cipherVersion.isEmpty) {
        throw const SqlCipherUnavailableException();
      }

      final quotedTempPath = temp.path.replaceAll("'", "''");
      db.execute(
        "ATTACH DATABASE '$quotedTempPath' AS encrypted KEY \"x'$keyHex'\";",
      );
      db.execute("SELECT sqlcipher_export('encrypted');");
      db.execute('DETACH DATABASE encrypted;');
    } finally {
      db.dispose();
    }

    current = current.copyWith(stage: 'export_completed');
    await stateStore.write(current);

    final validation = _validateEncryptedDb(
      dbPath: temp.path,
      keyHex: keyHex,
      expectedCounts: oldCounts,
    );
    current = current.copyWith(stage: 'validated', counts: validation.counts, schemaVersion: validation.userVersion);
    await stateStore.write(current);
  } catch (e) {
    current = current.copyWith(stage: 'export_failed');
    await stateStore.write(current);
    throw DbMigrationFailedException(stage: 'export_failed', cause: e);
  }

  // Atomic-ish swap: replace plaintext target with encrypted temp.
  final plaintextBackup = File('${target.path}.plaintext.locked');
  final plaintextWalBackup = File('${plaintextBackup.path}-wal');
  final plaintextShmBackup = File('${plaintextBackup.path}-shm');
  try {
    current = current.copyWith(stage: 'swap_started');
    await stateStore.write(current);

    // Move WAL/SHM out of the way before swapping to avoid applying plaintext WAL
    // to the new encrypted database.
    final plaintextWal = File('${target.path}-wal');
    final plaintextShm = File('${target.path}-shm');
    if (await plaintextWal.exists()) {
      await plaintextWal.rename(plaintextWalBackup.path);
    }
    if (await plaintextShm.exists()) {
      await plaintextShm.rename(plaintextShmBackup.path);
    }

    if (await plaintextBackup.exists()) {
      await plaintextBackup.delete();
    }
    await target.rename(plaintextBackup.path);

    await temp.rename(target.path);

    current = current.copyWith(stage: 'completed');
    await stateStore.write(current);
  } catch (e) {
    // Best-effort rollback.
    try {
      if (await plaintextBackup.exists() && !await target.exists()) {
        await plaintextBackup.rename(target.path);
      }
      if (await plaintextWalBackup.exists()) {
        await plaintextWalBackup.rename('${target.path}-wal');
      }
      if (await plaintextShmBackup.exists()) {
        await plaintextShmBackup.rename('${target.path}-shm');
      }
    } catch (_) {}
    throw DbMigrationFailedException(stage: 'swap_failed', cause: e);
  } finally {
    // Cleanup best-effort: keep backups if anything failed.
    try {
      final completed = await stateStore.read();
      final isCompleted = completed?.stage == 'completed';
      if (isCompleted) {
        await _deleteIfExists(plaintextBackup);
        await _deleteIfExists(plaintextWalBackup);
        await _deleteIfExists(plaintextShmBackup);
        await _deleteIfExists(backupDb);
        await _deleteIfExists(backupWal);
        await _deleteIfExists(backupShm);
        await stateStore.clear();
      }
    } catch (_) {}
  }
}

Future<void> _deleteIfExists(File file) async {
  if (!await file.exists()) return;
  try {
    await file.delete();
  } catch (_) {}
}

Map<String, int?> _countKeyTablesPlaintext({required String dbPath}) {
  final db = sqlite3.open(dbPath);
  try {
    return {
      'tasks': _countIfTableExists(db, 'tasks'),
      'notes': _countIfTableExists(db, 'notes'),
      'today_plan_items': _countIfTableExists(db, 'today_plan_items'),
      'weave_links': _countIfTableExists(db, 'weave_links'),
      'pomodoro_sessions': _countIfTableExists(db, 'pomodoro_sessions'),
      'task_check_items': _countIfTableExists(db, 'task_check_items'),
    };
  } finally {
    db.dispose();
  }
}

int? _countIfTableExists(Database db, String table) {
  try {
    final exists = db
        .select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';",
        )
        .isNotEmpty;
    if (!exists) return null;
    final rows = db.select('SELECT COUNT(*) FROM $table;');
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    if (v is int) return v;
    return int.tryParse(v.toString());
  } catch (_) {
    return null;
  }
}

class _EncryptedDbValidationResult {
  const _EncryptedDbValidationResult({
    required this.userVersion,
    required this.counts,
  });

  final int userVersion;
  final Map<String, int> counts;
}

_EncryptedDbValidationResult _validateEncryptedDb({
  required String dbPath,
  required String keyHex,
  required Map<String, int?> expectedCounts,
}) {
  final db = sqlite3.open(dbPath);
  try {
    String? cipherVersion;
    try {
      final cipherVersionRows = db.select('PRAGMA cipher_version;');
      cipherVersion = cipherVersionRows.isEmpty
          ? null
          : (cipherVersionRows.first.values.first?.toString())?.trim();
    } catch (_) {
      throw const SqlCipherUnavailableException();
    }
    if (cipherVersion == null || cipherVersion.isEmpty) {
      throw const SqlCipherUnavailableException();
    }

    db.execute("PRAGMA key = \"x'$keyHex'\";");

    // Fail-fast on wrong key.
    db.select('PRAGMA schema_version;');

    final userVersionRows = db.select('PRAGMA user_version;');
    final userVersionValue = userVersionRows.isEmpty
        ? null
        : userVersionRows.first.values.first;
    final userVersion = userVersionValue is int
        ? userVersionValue
        : int.tryParse(userVersionValue.toString());
    if (userVersion == null) {
      throw const DbMigrationFailedException(stage: 'validate_user_version');
    }

    final integrityRows = db.select('PRAGMA integrity_check;');
    final integrity = integrityRows.isEmpty
        ? null
        : (integrityRows.first.values.first?.toString())?.trim().toLowerCase();
    if (integrity != 'ok') {
      throw const DbMigrationFailedException(stage: 'integrity_check_failed');
    }

    final counts = <String, int>{};
    for (final entry in expectedCounts.entries) {
      final table = entry.key;
      final expected = entry.value;
      if (expected == null) continue;
      final actual = _countIfTableExists(db, table);
      if (actual == null) {
        throw DbMigrationFailedException(stage: 'missing_table_$table');
      }
      counts[table] = actual;
      if (expected > 0 && actual != expected) {
        throw DbMigrationFailedException(stage: 'count_mismatch_$table');
      }
    }

    return _EncryptedDbValidationResult(userVersion: userVersion, counts: counts);
  } finally {
    db.dispose();
  }
}

Future<List<File>> _listSqliteFiles(Directory dbFolder) async {
  return dbFolder
      .list()
      .where((e) => e is File && e.path.endsWith('.sqlite'))
      .map((e) => e as File)
      .toList();
}

Future<File> _resolveTargetFileToOpen({
  required File target,
  required bool targetExists,
  required List<File> sqliteFiles,
}) async {
  if (targetExists) return target;

  if (sqliteFiles.length == 1) {
    final existing = sqliteFiles.single;
    try {
      await existing.rename(target.path);
      return target;
    } catch (_) {
      return existing;
    }
  }

  return target;
}

Future<bool> _looksLikePlaintextSqliteDatabase(File file) async {
  try {
    final raf = await file.open();
    try {
      final headerBytes = await raf.read(16);
      return hasPlaintextSqliteHeader(headerBytes);
    } finally {
      await raf.close();
    }
  } catch (_) {
    return false;
  }
}

var _sqlCipherAndroidInitialized = false;

void _ensureSqlCipherAndroidInitialization() {
  if (!Platform.isAndroid) return;
  if (_sqlCipherAndroidInitialized) return;
  _sqlCipherAndroidInitialized = true;

  applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
}

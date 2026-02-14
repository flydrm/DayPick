import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'db_key_store.dart';
import 'db_migration_state_store.dart';

class DatabaseFileBackup {
  const DatabaseFileBackup(this.entries);

  final List<DatabaseFileBackupEntry> entries;
}

class DatabaseFileBackupEntry {
  const DatabaseFileBackupEntry({
    required this.originalPath,
    required this.backupPath,
  });

  final String originalPath;
  final String backupPath;
}

class DatabaseResetService {
  DatabaseResetService({
    DbKeyStore? keyStore,
    Future<Directory> Function()? getDocumentsDirectory,
    this.backupFileSuffix = defaultBackupFileSuffix,
    this.migrationStateFileName = DbMigrationStateStore.defaultFileName,
  }) : _keyStore = keyStore ?? DbKeyStore(),
       _getDocumentsDirectory =
           getDocumentsDirectory ?? getApplicationDocumentsDirectory;

  static const String defaultBackupFileSuffix = '.restore_backup';

  final DbKeyStore _keyStore;
  final Future<Directory> Function() _getDocumentsDirectory;
  final String backupFileSuffix;
  final String migrationStateFileName;

  Future<bool> resetAll() async {
    await _deleteAllSqliteFiles();
    await _clearMigrationStateMarker();
    await _deleteDbKey();
    return true;
  }

  Future<void> clearMigrationStateMarker() async {
    await _clearMigrationStateMarker();
  }

  Future<DatabaseFileBackup?> backupExistingDatabaseFiles() async {
    final files = await _listAllSqliteFiles(excludeRestoreBackups: true);
    if (files.isEmpty) return null;

    final entries = <DatabaseFileBackupEntry>[];
    for (final file in files) {
      final originalPath = file.path;
      final backupPath = '$originalPath$backupFileSuffix';
      final staleBackup = File(backupPath);
      if (await staleBackup.exists()) {
        try {
          await staleBackup.delete();
        } catch (_) {
          // Best-effort: if stale backup cannot be removed, skip this file.
          continue;
        }
      }

      try {
        final renamed = await file.rename(backupPath);
        entries.add(
          DatabaseFileBackupEntry(
            originalPath: originalPath,
            backupPath: renamed.path,
          ),
        );
      } catch (_) {
        // Best-effort: if we can't rename, keep it as-is and don't include it.
      }
    }

    return entries.isEmpty ? null : DatabaseFileBackup(entries);
  }

  Future<void> restoreDatabaseFilesFromBackup(
    DatabaseFileBackup? backup,
  ) async {
    if (backup == null) return;

    // Remove any newly created files at original paths before restoring.
    for (final entry in backup.entries) {
      final existing = File(entry.originalPath);
      if (await existing.exists()) {
        try {
          await existing.delete();
        } catch (_) {}
      }
    }

    for (final entry in backup.entries) {
      final backupFile = File(entry.backupPath);
      if (!await backupFile.exists()) continue;

      try {
        await backupFile.rename(entry.originalPath);
      } catch (_) {
        // Best-effort: try copy+delete.
        try {
          await backupFile.copy(entry.originalPath);
          await backupFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> deleteDatabaseFileBackup(DatabaseFileBackup? backup) async {
    if (backup == null) return;

    for (final entry in backup.entries) {
      final file = File(entry.backupPath);
      if (!await file.exists()) continue;
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _deleteDbKey() async {
    try {
      await _keyStore.deleteKey();
    } catch (_) {}
  }

  Future<void> _clearMigrationStateMarker() async {
    final dir = await _getDocumentsDirectory();
    final markerPath =
        '${dir.path}${Platform.pathSeparator}$migrationStateFileName';
    final marker = File(markerPath);
    if (!await marker.exists()) return;
    try {
      await marker.delete();
    } catch (_) {}
  }

  Future<void> _deleteAllSqliteFiles() async {
    final files = await _listAllSqliteFiles();
    for (final file in files) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<List<File>> _listAllSqliteFiles({
    bool excludeRestoreBackups = false,
  }) async {
    final dir = await _getDocumentsDirectory();
    final results = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!_isSqliteRelatedPath(path)) continue;
      if (excludeRestoreBackups && path.endsWith(backupFileSuffix)) continue;
      results.add(entity);
    }
    return results;
  }
}

bool _isSqliteRelatedPath(String path) {
  return path.endsWith('.sqlite') ||
      path.contains('.sqlite-') ||
      path.contains('.sqlite.');
}

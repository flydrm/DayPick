import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DbMigrationState {
  const DbMigrationState({
    required this.stage,
    required this.startedAtUtcMs,
    required this.updatedAtUtcMs,
    required this.targetPath,
    required this.tempPath,
    required this.backupPaths,
    this.schemaVersion,
    this.counts,
  });

  final String stage;
  final int startedAtUtcMs;
  final int updatedAtUtcMs;
  final String targetPath;
  final String tempPath;
  final List<String> backupPaths;
  final int? schemaVersion;
  final Map<String, int>? counts;

  DbMigrationState copyWith({
    String? stage,
    int? updatedAtUtcMs,
    String? targetPath,
    String? tempPath,
    List<String>? backupPaths,
    int? schemaVersion,
    Map<String, int>? counts,
  }) {
    return DbMigrationState(
      stage: stage ?? this.stage,
      startedAtUtcMs: startedAtUtcMs,
      updatedAtUtcMs: updatedAtUtcMs ?? this.updatedAtUtcMs,
      targetPath: targetPath ?? this.targetPath,
      tempPath: tempPath ?? this.tempPath,
      backupPaths: backupPaths ?? this.backupPaths,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      counts: counts ?? this.counts,
    );
  }

  Map<String, Object?> toJson() => {
    'stage': stage,
    'started_at_utc_ms': startedAtUtcMs,
    'updated_at_utc_ms': updatedAtUtcMs,
    'target_path': targetPath,
    'temp_path': tempPath,
    'backup_paths': backupPaths,
    if (schemaVersion != null) 'schema_version': schemaVersion,
    if (counts != null) 'counts': counts,
  };

  static DbMigrationState? fromJson(Object? decoded) {
    if (decoded is! Map) return null;

    final stage = decoded['stage'];
    final startedAt = decoded['started_at_utc_ms'];
    final updatedAt = decoded['updated_at_utc_ms'];
    final targetPath = decoded['target_path'];
    final tempPath = decoded['temp_path'];
    final backupPaths = decoded['backup_paths'];

    if (stage is! String) return null;
    if (startedAt is! int) return null;
    if (updatedAt is! int) return null;
    if (targetPath is! String) return null;
    if (tempPath is! String) return null;
    if (backupPaths is! List) return null;

    final safeBackupPaths = backupPaths.whereType<String>().toList();

    final schemaVersion = decoded['schema_version'];
    final counts = decoded['counts'];

    Map<String, int>? safeCounts;
    if (counts is Map) {
      final map = <String, int>{};
      for (final entry in counts.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is int) map[k] = v;
      }
      safeCounts = map.isEmpty ? null : map;
    }

    return DbMigrationState(
      stage: stage,
      startedAtUtcMs: startedAt,
      updatedAtUtcMs: updatedAt,
      targetPath: targetPath,
      tempPath: tempPath,
      backupPaths: safeBackupPaths,
      schemaVersion: schemaVersion is int ? schemaVersion : null,
      counts: safeCounts,
    );
  }
}

class DbMigrationStateStore {
  DbMigrationStateStore({
    this.fileName = defaultFileName,
    this.nowUtcMs = _defaultNowUtcMs,
    Future<Directory> Function()? getDocumentsDirectory,
  }) : _getDocumentsDirectory =
           getDocumentsDirectory ?? getApplicationDocumentsDirectory;

  static const String defaultFileName = 'daypick_db_migration_state.json';

  final String fileName;
  final int Function() nowUtcMs;
  final Future<Directory> Function() _getDocumentsDirectory;

  Future<bool> exists() async {
    final file = await _file();
    return file.exists();
  }

  Future<DbMigrationState?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      return DbMigrationState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(DbMigrationState state) async {
    final file = await _file();
    final updated = state.copyWith(updatedAtUtcMs: nowUtcMs());
    await file.writeAsString(jsonEncode(updated.toJson()), flush: true);
  }

  Future<void> clear() async {
    final file = await _file();
    if (!await file.exists()) return;
    await file.delete();
  }

  Future<File> _file() async {
    final dir = await _getDocumentsDirectory();
    return File(p.join(dir.path, fileName));
  }
}

int _defaultNowUtcMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

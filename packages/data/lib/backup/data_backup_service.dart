import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../export/data_export_service.dart';
import 'backup_exceptions.dart';
import 'backup_models.dart';

class DataBackupService {
  DataBackupService({
    required AppDatabase db,
    DataExportService? exportService,
    Cipher? cipher,
  })  : _db = db,
        _export = exportService ?? DataExportService(db),
        _cipher = cipher ?? AesGcm.with256bits();

  static const int backupFormatVersion = 1;
  static const String fileExtension = 'ppbk';
  static const Set<int> supportedExportSchemaVersions = {1, 2, 3};

  final AppDatabase _db;
  final DataExportService _export;
  final Cipher _cipher;
  final Random _random = Random.secure();

  Future<Uint8List> createEncryptedBackup({required String pin}) async {
    _validatePin(pin);

    final dataJson = await _export.exportJsonBytes();
    final exportMd = await _export.exportMarkdownBytes();
    final exportedAtUtcMillis = DateTime.now().toUtc().millisecondsSinceEpoch;

    final zipBytes = _zip(
      files: {
        'manifest.json': utf8.encode(
          jsonEncode({
            'format': 'daypick-backup',
            'backupFormatVersion': backupFormatVersion,
            'schemaVersion': DataExportService.exportSchemaVersion,
            'exportedAt': exportedAtUtcMillis,
          }),
        ),
        'data/data.json': dataJson,
        'exports/export.md': exportMd,
      },
    );

    return await _encryptZip(zipBytes: zipBytes, pin: pin);
  }

  Future<BackupPreview> readBackupPreview({
    required Uint8List encryptedBytes,
    required String pin,
  }) async {
    _validatePin(pin);
    final zipBytes = await _decryptZip(encryptedBytes: encryptedBytes, pin: pin);
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final dataFile = archive.findFile('data/data.json');
    if (dataFile == null) throw const BackupException('备份文件缺少 data/data.json');

    final dataText = utf8.decode(dataFile.content as List<int>);
    final root = jsonDecode(dataText);
    if (root is! Map) throw const BackupException('data.json 格式不正确');

    final schemaVersion = root['schemaVersion'];
    final exportedAt = root['exportedAt'];
    if (schemaVersion is! int || exportedAt is! int) {
      throw const BackupException('data.json 缺少 schemaVersion/exportedAt');
    }
    if (!supportedExportSchemaVersions.contains(schemaVersion)) {
      throw BackupException('不支持的 schemaVersion：$schemaVersion');
    }

    final items = root['items'];
    if (items is! Map) throw const BackupException('data.json 缺少 items');

    int countOf(String key) {
      final v = items[key];
      if (v is List) return v.length;
      return 0;
    }

    return BackupPreview(
      schemaVersion: schemaVersion,
      exportedAtUtcMillis: exportedAt,
      taskCount: countOf('tasks'),
      noteCount: countOf('notes'),
      sessionCount: countOf('pomodoro_sessions'),
      checklistCount: countOf('task_check_items'),
    );
  }

  Future<RestoreResult> restoreFromEncryptedBackup({
    required Uint8List encryptedBytes,
    required String pin,
  }) async {
    _validatePin(pin);
    final zipBytes = await _decryptZip(encryptedBytes: encryptedBytes, pin: pin);
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final dataFile = archive.findFile('data/data.json');
    if (dataFile == null) throw const BackupException('备份文件缺少 data/data.json');

    final dataText = utf8.decode(dataFile.content as List<int>);
    final root = jsonDecode(dataText);
    if (root is! Map) throw const BackupException('data.json 格式不正确');

    final schemaVersion = root['schemaVersion'];
    if (schemaVersion is! int) throw const BackupException('data.json 缺少 schemaVersion');
    if (!supportedExportSchemaVersions.contains(schemaVersion)) {
      throw BackupException('不支持的 schemaVersion：$schemaVersion');
    }

    final items = root['items'];
    if (items is! Map) throw const BackupException('data.json 缺少 items');

    List<Map<String, Object?>> listOf(String key) {
      final v = items[key];
      if (v is! List) return const [];
      return v.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))).toList();
    }

    final tasks = listOf('tasks');
    final todayPlanItems = listOf('today_plan_items');
    final taskCheckItems = listOf('task_check_items');
    final notes = listOf('notes');
    final sessions = listOf('pomodoro_sessions');

    Map<String, Object?>? mapOf(String key) {
      final v = items[key];
      if (v is! Map) return null;
      return v.map((k, v) => MapEntry(k.toString(), v));
    }

    final pomodoroConfig = mapOf('pomodoro_config');
    final appearanceConfig = mapOf('appearance_config');

    final workDurationMinutes = pomodoroConfig == null
        ? 25
        : (_optInt(pomodoroConfig, 'work_duration_minutes') ?? 25);
    final shortBreakMinutes = pomodoroConfig == null
        ? 5
        : (_optInt(pomodoroConfig, 'short_break_minutes') ?? 5);
    final longBreakMinutes = pomodoroConfig == null
        ? 15
        : (_optInt(pomodoroConfig, 'long_break_minutes') ?? 15);
    final longBreakEvery =
        pomodoroConfig == null ? 4 : (_optInt(pomodoroConfig, 'long_break_every') ?? 4);
    final autoStartBreak = pomodoroConfig == null
        ? false
        : (_optBool(pomodoroConfig, 'auto_start_break') ?? false);
    final autoStartFocus = pomodoroConfig == null
        ? false
        : (_optBool(pomodoroConfig, 'auto_start_focus') ?? false);
    final notificationSound = pomodoroConfig == null
        ? false
        : (_optBool(pomodoroConfig, 'notification_sound') ?? false);
    final notificationVibration = pomodoroConfig == null
        ? false
        : (_optBool(pomodoroConfig, 'notification_vibration') ?? false);

    final themeMode =
        appearanceConfig == null ? 0 : (_optInt(appearanceConfig, 'theme_mode') ?? 0);
    final density =
        appearanceConfig == null ? 0 : (_optInt(appearanceConfig, 'density') ?? 0);
    final accent =
        appearanceConfig == null ? 0 : (_optInt(appearanceConfig, 'accent') ?? 0);

    int clampInt(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    final safeWorkDurationMinutes = clampInt(workDurationMinutes, 10, 60);
    final safeShortBreakMinutes = clampInt(shortBreakMinutes, 3, 30);
    final safeLongBreakMinutes = clampInt(longBreakMinutes, 5, 60);
    final safeLongBreakEvery = clampInt(longBreakEvery, 2, 10);
    final safeThemeMode = clampInt(themeMode, 0, 2);
    final safeDensity = clampInt(density, 0, 1);
    final safeAccent = clampInt(accent, 0, 2);

    await _db.transaction(() async {
      await (_db.delete(_db.taskCheckItems)).go();
      await (_db.delete(_db.pomodoroSessions)).go();
      await (_db.delete(_db.notes)).go();
      await (_db.delete(_db.todayPlanItems)).go();
      await (_db.delete(_db.tasks)).go();
      await (_db.delete(_db.activePomodoros)).go();
      await (_db.delete(_db.pomodoroConfigs)).go();
      await (_db.delete(_db.appearanceConfigs)).go();

      await _db.batch((batch) {
        batch.insertAll(
          _db.tasks,
          [
            for (final t in tasks)
              TasksCompanion.insert(
                id: _reqString(t, 'id'),
                title: _reqString(t, 'title'),
                description: Value(_optString(t, 'description')),
                status: _reqInt(t, 'status'),
                priority: _reqInt(t, 'priority'),
                dueAtUtcMillis: Value(_optInt(t, 'due_at_utc_ms')),
                tagsJson: Value(jsonEncode(_optStringList(t, 'tags'))),
                estimatedPomodoros: Value(_optInt(t, 'estimated_pomodoros')),
                createdAtUtcMillis: _reqInt(t, 'created_at_utc_ms'),
                updatedAtUtcMillis: _reqInt(t, 'updated_at_utc_ms'),
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );

        batch.insertAll(
          _db.taskCheckItems,
          [
            for (final c in taskCheckItems)
              TaskCheckItemsCompanion.insert(
                id: _reqString(c, 'id'),
                taskId: _reqString(c, 'task_id'),
                title: _reqString(c, 'title'),
                isDone: Value(_optBool(c, 'is_done') ?? false),
                orderIndex: _reqInt(c, 'order_index'),
                createdAtUtcMillis: _reqInt(c, 'created_at_utc_ms'),
                updatedAtUtcMillis: _reqInt(c, 'updated_at_utc_ms'),
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );

        batch.insertAll(
          _db.todayPlanItems,
          [
            for (final row in todayPlanItems)
              TodayPlanItemsCompanion.insert(
                dayKey: _reqString(row, 'day_key'),
                taskId: _reqString(row, 'task_id'),
                orderIndex: _reqInt(row, 'order_index'),
                createdAtUtcMillis: _reqInt(row, 'created_at_utc_ms'),
                updatedAtUtcMillis: _reqInt(row, 'updated_at_utc_ms'),
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );

        batch.insertAll(
          _db.notes,
          [
            for (final n in notes)
              NotesCompanion.insert(
                id: _reqString(n, 'id'),
                title: _reqString(n, 'title'),
                body: Value(_optString(n, 'body') ?? ''),
                tagsJson: Value(jsonEncode(_optStringList(n, 'tags'))),
                taskId: Value(_optString(n, 'task_id')),
                createdAtUtcMillis: _reqInt(n, 'created_at_utc_ms'),
                updatedAtUtcMillis: _reqInt(n, 'updated_at_utc_ms'),
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );

        batch.insertAll(
          _db.pomodoroSessions,
          [
            for (final s in sessions)
              PomodoroSessionsCompanion.insert(
                id: _reqString(s, 'id'),
                taskId: _reqString(s, 'task_id'),
                startAtUtcMillis: _reqInt(s, 'start_at_utc_ms'),
                endAtUtcMillis: _reqInt(s, 'end_at_utc_ms'),
                isDraft: Value(_optBool(s, 'is_draft') ?? false),
                progressNote: Value(_optString(s, 'progress_note')),
                createdAtUtcMillis: _reqInt(s, 'created_at_utc_ms'),
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );

        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        batch.insertAll(
          _db.pomodoroConfigs,
          [
            PomodoroConfigsCompanion.insert(
              id: const Value(1),
              workDurationMinutes: Value(safeWorkDurationMinutes),
              shortBreakMinutes: Value(safeShortBreakMinutes),
              longBreakMinutes: Value(safeLongBreakMinutes),
              longBreakEvery: Value(safeLongBreakEvery),
              autoStartBreak: Value(autoStartBreak),
              autoStartFocus: Value(autoStartFocus),
              notificationSound: Value(notificationSound),
              notificationVibration: Value(notificationVibration),
              updatedAtUtcMillis: now,
            ),
          ],
          mode: InsertMode.insertOrReplace,
        );
        batch.insertAll(
          _db.appearanceConfigs,
          [
            AppearanceConfigsCompanion.insert(
              id: const Value(1),
              themeMode: Value(safeThemeMode),
              density: Value(safeDensity),
              accent: Value(safeAccent),
              updatedAtUtcMillis: now,
            ),
          ],
          mode: InsertMode.insertOrReplace,
        );
      });
    });

    return RestoreResult(
      taskCount: tasks.length,
      checklistCount: taskCheckItems.length,
      noteCount: notes.length,
      sessionCount: sessions.length,
    );
  }

  Uint8List _zip({required Map<String, List<int>> files}) {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<Uint8List> _encryptZip({
    required Uint8List zipBytes,
    required String pin,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);

    final secretKey = await _deriveKey(pin: pin, salt: salt);
    final secretBox = await _cipher.encrypt(
      zipBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final header = {
      'format': 'daypick-backup',
      'version': backupFormatVersion,
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': 100000,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'macLength': secretBox.mac.bytes.length,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    final headerBytes = utf8.encode(jsonEncode(header));

    final out = BytesBuilder(copy: false);
    out.add(utf8.encode('PPBK'));
    out.add(_u32(headerBytes.length));
    out.add(headerBytes);
    out.add(secretBox.cipherText);
    out.add(secretBox.mac.bytes);
    return out.toBytes();
  }

  List<int> _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  Future<Uint8List> _decryptZip({
    required Uint8List encryptedBytes,
    required String pin,
  }) async {
    if (encryptedBytes.length < 8) throw const BackupException('备份文件过短或已损坏');
    final magic = utf8.decode(encryptedBytes.sublist(0, 4));
    if (magic != 'PPBK') throw const BackupException('不是 DayPick 备份文件');

    final headerLen = ByteData.sublistView(encryptedBytes, 4, 8).getUint32(0, Endian.big);
    final headerStart = 8;
    final headerEnd = headerStart + headerLen;
    if (headerEnd > encryptedBytes.length) throw const BackupException('备份文件头损坏');

    final headerText = utf8.decode(encryptedBytes.sublist(headerStart, headerEnd));
    final header = jsonDecode(headerText);
    if (header is! Map) throw const BackupException('备份文件头格式不正确');

    final saltB64 = header['salt'];
    final nonceB64 = header['nonce'];
    final iterations = header['iterations'];
    final macLength = header['macLength'];
    if (saltB64 is! String ||
        nonceB64 is! String ||
        iterations is! int ||
        macLength is! int) {
      throw const BackupException('备份文件头缺少必要字段');
    }
    if (iterations != 100000) {
      throw BackupException('不支持的 KDF 参数：iterations=$iterations');
    }

    final salt = base64Decode(saltB64);
    final nonce = base64Decode(nonceB64);

    final payload = encryptedBytes.sublist(headerEnd);
    if (payload.length <= macLength) throw const BackupException('备份文件内容损坏');

    final cipherText = payload.sublist(0, payload.length - macLength);
    final macBytes = payload.sublist(payload.length - macLength);

    final key = await _deriveKey(pin: pin, salt: salt);
    try {
      final plain = await _cipher.decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
        secretKey: key,
      );
      return Uint8List.fromList(plain);
    } catch (_) {
      throw const BackupException('PIN 不正确或备份文件已损坏');
    }
  }

  Future<SecretKey> _deriveKey({required String pin, required List<int> salt}) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  void _validatePin(String pin) {
    final trimmed = pin.trim();
    final ok = trimmed.length == 6 && RegExp(r'^[0-9]{6}$').hasMatch(trimmed);
    if (!ok) throw const BackupException('PIN 必须是恰好 6 位数字');
  }

  List<int> _u32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.big);
    return b.buffer.asUint8List();
  }

  String _reqString(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v is String && v.isNotEmpty) return v;
    throw BackupException('缺少字段：$key');
  }

  int _reqInt(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    throw BackupException('缺少字段：$key');
  }

  int? _optInt(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    return null;
  }

  bool? _optBool(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v is bool) return v;
    return null;
  }

  String? _optString(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  List<String> _optStringList(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v is List) return v.whereType<String>().toList();
    return const [];
  }
}

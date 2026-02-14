import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:drift/drift.dart';
import 'package:domain/domain.dart' as domain;

import '../ai/secure_ai_config_repository.dart';
import '../db/app_database.dart';
import '../export/data_export_service.dart';
import 'backup_exceptions.dart';
import 'backup_models.dart';

class DataBackupService {
  DataBackupService({
    required AppDatabase db,
    DataExportService? exportService,
    Cipher? cipher,
    domain.AiConfigRepository? aiConfigRepository,
  }) : _db = db,
       _export = exportService ?? DataExportService(db),
       _cipher = cipher ?? AesGcm.with256bits(),
       _aiConfigRepository = aiConfigRepository;

  static const int backupFormatVersion = 1;
  static const String fileExtension = 'ppbk';
  static const int kdfVersionPbkdf2 = 1;
  static const int kdfVersionArgon2id = 2;
  static const Set<int> supportedExportSchemaVersions = {
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
  };

  final AppDatabase _db;
  final DataExportService _export;
  final Cipher _cipher;
  domain.AiConfigRepository? _aiConfigRepository;
  final Random _random = Random.secure();

  static const int _argon2Parallelism = 4;
  static const int _argon2MemoryKib = 16 * 1024;
  static const int _argon2Iterations = 3;
  static const int _argon2HashLength = 32;
  static const String _aiConfigEntryPath = 'secrets/ai_config.json';

  Future<Uint8List> createEncryptedBackup({
    required String passphrase,
    bool includesSecrets = false,
  }) async {
    final normalizedPassphrase = passphrase.trim();
    _validatePassphrase(
      normalizedPassphrase,
      requiresStrongPassphrase: includesSecrets,
    );

    final dataJson = await _export.exportJsonBytes();

    final (schemaVersion, exportedAtUtcMillis) =
        _readExportMetadataFromDataJson(dataJson);
    if (!supportedExportSchemaVersions.contains(schemaVersion)) {
      throw BackupUnsupportedException('不支持的 schema_version：$schemaVersion');
    }

    final aiConfigBytes = includesSecrets
        ? await _buildAiConfigBytesOrThrow()
        : null;

    final manifest = includesSecrets
        ? {
            'format': 'daypick-backup',
            'backup_format_version': backupFormatVersion,
            'export_schema_version': schemaVersion,
            'exported_at_utc_ms': exportedAtUtcMillis,
            'includes_secrets': true,
            'kdf_version': kdfVersionArgon2id,
            'kdf': {
              'algorithm': 'argon2id',
              'parallelism': _argon2Parallelism,
              'memory_kib': _argon2MemoryKib,
              'iterations': _argon2Iterations,
              'hash_length': _argon2HashLength,
              'salt_length': 16,
            },
          }
        : {
            'format': 'daypick-backup',
            'backup_format_version': backupFormatVersion,
            'schema_version': schemaVersion,
            'exported_at_utc_ms': exportedAtUtcMillis,
            'includes_secrets': false,
          };
    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));

    if (includesSecrets) {
      _assertNoSensitiveTokensInJsonBytes(
        manifestBytes,
        sensitiveTokensLower: _nonSecretSensitiveTokensLower,
      );
      _assertNoSensitiveTokensInJsonBytes(
        dataJson,
        sensitiveTokensLower: _nonSecretSensitiveTokensLower,
      );
      _assertNoSensitiveTokensInJsonBytes(
        aiConfigBytes!,
        sensitiveTokensLower: _nonSecretSensitiveTokensLower,
      );
    } else {
      _assertNoSensitiveTokensInJsonBytes(
        manifestBytes,
        sensitiveTokensLower: _allSensitiveTokensLower,
      );
      _assertNoSensitiveTokensInJsonBytes(
        dataJson,
        sensitiveTokensLower: _allSensitiveTokensLower,
      );
    }

    final zipBytes = _zip(
      files: {
        'manifest.json': manifestBytes,
        'data/data.json': dataJson,
        if (aiConfigBytes != null) _aiConfigEntryPath: aiConfigBytes,
      },
    );

    return await _encryptZip(
      zipBytes: zipBytes,
      passphrase: normalizedPassphrase,
      kdfVersion: includesSecrets ? kdfVersionArgon2id : kdfVersionPbkdf2,
      includesSecrets: includesSecrets,
    );
  }

  Future<BackupPreview> readBackupPreview({
    required Uint8List encryptedBytes,
    required String passphrase,
  }) async {
    final normalizedPassphrase = passphrase.trim();
    _validatePassphrase(normalizedPassphrase);
    final zipBytes = await _decryptZip(
      encryptedBytes: encryptedBytes,
      passphrase: normalizedPassphrase,
    );
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final manifest = _readBackupManifest(archive);
    final exportSchemaVersion = manifest.exportSchemaVersion;
    if (!supportedExportSchemaVersions.contains(exportSchemaVersion)) {
      throw BackupUnsupportedException(
        '不支持的 schema_version：$exportSchemaVersion',
      );
    }

    final dataFile = archive.findFile('data/data.json');
    if (dataFile == null) throw const BackupException('备份文件缺少 data/data.json');

    final dataText = utf8.decode(dataFile.content as List<int>);
    final root = jsonDecode(dataText);
    if (root is! Map) throw const BackupException('data.json 格式不正确');

    final items = root['items'];
    if (items is! Map) throw const BackupException('data.json 缺少 items');

    int countOf(String key) {
      final v = items[key];
      if (v is List) return v.length;
      return 0;
    }

    return BackupPreview(
      backupFormatVersion: manifest.backupFormatVersion,
      schemaVersion: exportSchemaVersion,
      exportedAtUtcMillis: manifest.exportedAtUtcMillis,
      includesSecrets: manifest.includesSecrets,
      taskCount: countOf('tasks'),
      noteCount: countOf('notes'),
      weaveLinkCount: countOf('weave_links'),
      sessionCount: countOf('pomodoro_sessions'),
      checklistCount: countOf('task_check_items'),
    );
  }

  Future<RestoreResult> restoreFromEncryptedBackup({
    required Uint8List encryptedBytes,
    required String passphrase,
    BackupCancellationToken? cancelToken,
  }) async {
    final normalizedPassphrase = passphrase.trim();
    _validatePassphrase(normalizedPassphrase);
    final zipBytes = await _decryptZip(
      encryptedBytes: encryptedBytes,
      passphrase: normalizedPassphrase,
    );
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final manifest = _readBackupManifest(archive);
    final exportSchemaVersion = manifest.exportSchemaVersion;
    if (!supportedExportSchemaVersions.contains(exportSchemaVersion)) {
      throw BackupUnsupportedException(
        '不支持的 schema_version：$exportSchemaVersion',
      );
    }

    final dataFile = archive.findFile('data/data.json');
    if (dataFile == null) throw const BackupException('备份文件缺少 data/data.json');

    final dataText = utf8.decode(dataFile.content as List<int>);
    final root = jsonDecode(dataText);
    if (root is! Map) throw const BackupException('data.json 格式不正确');

    final items = root['items'];
    if (items is! Map) throw const BackupException('data.json 缺少 items');

    List<Map<String, Object?>> listOf(String key) {
      final v = items[key];
      if (v is! List) return const [];
      return v
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }

    final tasks = listOf('tasks');
    final todayPlanItems = listOf('today_plan_items');
    final taskCheckItems = listOf('task_check_items');
    final notes = listOf('notes');
    final weaveLinks = listOf('weave_links');
    final sessions = listOf('pomodoro_sessions');
    final kpiDailyRollups = listOf('kpi_daily_rollups');

    Map<String, Object?>? mapOf(String key) {
      final v = items[key];
      if (v is! Map) return null;
      return v.map((k, v) => MapEntry(k.toString(), v));
    }

    final pomodoroConfig = mapOf('pomodoro_config');
    final appearanceConfig = mapOf('appearance_config');

    final aiConfig = manifest.includesSecrets
        ? _readAiConfigFromArchive(archive)
        : null;
    final aiConfigBeforeRestore = aiConfig == null
        ? null
        : await _aiConfigRepositoryOrThrow().getConfig();

    final workDurationMinutes = pomodoroConfig == null
        ? 25
        : (_optInt(pomodoroConfig, 'work_duration_minutes') ?? 25);
    final shortBreakMinutes = pomodoroConfig == null
        ? 5
        : (_optInt(pomodoroConfig, 'short_break_minutes') ?? 5);
    final longBreakMinutes = pomodoroConfig == null
        ? 15
        : (_optInt(pomodoroConfig, 'long_break_minutes') ?? 15);
    final longBreakEvery = pomodoroConfig == null
        ? 4
        : (_optInt(pomodoroConfig, 'long_break_every') ?? 4);
    final dailyBudgetPomodoros = pomodoroConfig == null
        ? 8
        : (_optInt(pomodoroConfig, 'daily_budget_pomodoros') ?? 8);
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

    final themeMode = appearanceConfig == null
        ? 0
        : (_optInt(appearanceConfig, 'theme_mode') ?? 0);
    final density = appearanceConfig == null
        ? 0
        : (_optInt(appearanceConfig, 'density') ?? 0);
    final accent = appearanceConfig == null
        ? 0
        : (_optInt(appearanceConfig, 'accent') ?? 0);
    final defaultTab = appearanceConfig == null
        ? 2
        : (_optInt(appearanceConfig, 'default_tab') ?? 2);
    final onboardingDone = appearanceConfig == null
        ? false
        : (_optBool(appearanceConfig, 'onboarding_done') ?? false);
    final statsEnabled = appearanceConfig == null
        ? false
        : (_optBool(appearanceConfig, 'stats_enabled') ?? false);
    final timeboxingStartMinutes = appearanceConfig == null
        ? null
        : _optInt(appearanceConfig, 'timeboxing_start_minutes');
    final timeboxingLayout = appearanceConfig == null
        ? 0
        : (_optInt(appearanceConfig, 'timeboxing_layout') ?? 0);
    final timeboxingWorkdayStartMinutes = appearanceConfig == null
        ? 7 * 60
        : (_optInt(appearanceConfig, 'timeboxing_workday_start_minutes') ??
              7 * 60);
    final timeboxingWorkdayEndMinutes = appearanceConfig == null
        ? 21 * 60
        : (_optInt(appearanceConfig, 'timeboxing_workday_end_minutes') ??
              21 * 60);
    final inboxTypeFilter = appearanceConfig == null
        ? 0
        : (_optInt(appearanceConfig, 'inbox_type_filter') ?? 0);
    final inboxTodayOnly = appearanceConfig == null
        ? false
        : (_optBool(appearanceConfig, 'inbox_today_only') ?? false);
    final todayModulesJson = appearanceConfig == null
        ? '["nextStep","todayPlan","weave","budget","focus","shortcuts","yesterdayReview"]'
        : jsonEncode(
            (appearanceConfig.containsKey('today_modules')
                    ? _optStringList(appearanceConfig, 'today_modules')
                    : const [
                        'nextStep',
                        'todayPlan',
                        'weave',
                        'budget',
                        'focus',
                        'shortcuts',
                        'yesterdayReview',
                      ])
                .where((m) => m != 'quickAdd')
                .toList(growable: false),
          );

    int clampInt(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    final safeWorkDurationMinutes = clampInt(workDurationMinutes, 10, 60);
    final safeShortBreakMinutes = clampInt(shortBreakMinutes, 3, 30);
    final safeLongBreakMinutes = clampInt(longBreakMinutes, 5, 60);
    final safeLongBreakEvery = clampInt(longBreakEvery, 2, 10);
    final safeDailyBudgetPomodoros = clampInt(dailyBudgetPomodoros, 0, 24);
    final safeThemeMode = clampInt(themeMode, 0, 2);
    final safeDensity = clampInt(density, 0, 1);
    final safeAccent = clampInt(accent, 0, 2);
    final safeDefaultTab = clampInt(defaultTab, 0, 4);
    final safeInboxTypeFilter = clampInt(inboxTypeFilter, 0, 3);
    final safeTimeboxingStartMinutes = timeboxingStartMinutes == null
        ? null
        : clampInt(timeboxingStartMinutes, 0, 24 * 60 - 1);
    final safeTimeboxingLayout = clampInt(timeboxingLayout, 0, 1);
    final safeTimeboxingWorkdayStartMinutes = clampInt(
      timeboxingWorkdayStartMinutes,
      0,
      24 * 60 - 1,
    );
    var safeTimeboxingWorkdayEndMinutes = clampInt(
      timeboxingWorkdayEndMinutes,
      0,
      24 * 60 - 1,
    );
    if (safeTimeboxingWorkdayEndMinutes <= safeTimeboxingWorkdayStartMinutes) {
      safeTimeboxingWorkdayEndMinutes = clampInt(
        safeTimeboxingWorkdayStartMinutes + 8 * 60,
        0,
        24 * 60 - 1,
      );
      if (safeTimeboxingWorkdayEndMinutes <=
          safeTimeboxingWorkdayStartMinutes) {
        safeTimeboxingWorkdayEndMinutes =
            (safeTimeboxingWorkdayStartMinutes + 60).clamp(0, 24 * 60 - 1);
      }
    }

    cancelToken?.throwIfCancelled();
    try {
      await _db.transaction(() async {
        cancelToken?.throwIfCancelled();
        await (_db.delete(_db.taskCheckItems)).go();
        cancelToken?.throwIfCancelled();
        await (_db.delete(_db.pomodoroSessions)).go();
        cancelToken?.throwIfCancelled();
        await (_db.delete(_db.weaveLinks)).go();
        cancelToken?.throwIfCancelled();
        await (_db.delete(_db.notes)).go();
        cancelToken?.throwIfCancelled();
        await (_db.delete(_db.todayPlanItems)).go();
        cancelToken?.throwIfCancelled();
        await (_db.delete(_db.kpiDailyRollups)).go();
        cancelToken?.throwIfCancelled();
        await (_db.delete(_db.tasks)).go();
        await (_db.delete(_db.activePomodoros)).go();
        await (_db.delete(_db.pomodoroConfigs)).go();
        await (_db.delete(_db.appearanceConfigs)).go();

        cancelToken?.throwIfCancelled();
        await _db.batch((batch) {
          batch.insertAll(_db.tasks, [
            for (final t in tasks)
              TasksCompanion.insert(
                id: _reqString(t, 'id'),
                title: _reqString(t, 'title'),
                description: Value(_optString(t, 'description')),
                status: _reqInt(t, 'status'),
                priority: _reqInt(t, 'priority'),
                dueAtUtcMillis: Value(_optInt(t, 'due_at_utc_ms')),
                tagsJson: Value(jsonEncode(_optStringList(t, 'tags'))),
                triageStatus: Value(_optInt(t, 'triage_status') ?? 2),
                estimatedPomodoros: Value(_optInt(t, 'estimated_pomodoros')),
                createdAtUtcMillis: _reqInt(t, 'created_at_utc_ms'),
                updatedAtUtcMillis: _reqInt(t, 'updated_at_utc_ms'),
              ),
          ], mode: InsertMode.insertOrReplace);

          batch.insertAll(_db.taskCheckItems, [
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
          ], mode: InsertMode.insertOrReplace);

          batch.insertAll(_db.todayPlanItems, [
            for (final row in todayPlanItems)
              TodayPlanItemsCompanion.insert(
                dayKey: _reqString(row, 'day_key'),
                taskId: _reqString(row, 'task_id'),
                segment: Value(clampInt(_optInt(row, 'segment') ?? 0, 0, 1)),
                orderIndex: _reqInt(row, 'order_index'),
                createdAtUtcMillis: _reqInt(row, 'created_at_utc_ms'),
                updatedAtUtcMillis: _reqInt(row, 'updated_at_utc_ms'),
              ),
          ], mode: InsertMode.insertOrReplace);

          batch.insertAll(_db.notes, [
            for (final n in notes)
              NotesCompanion.insert(
                id: _reqString(n, 'id'),
                title: _reqString(n, 'title'),
                body: Value(_optString(n, 'body') ?? ''),
                tagsJson: Value(jsonEncode(_optStringList(n, 'tags'))),
                taskId: Value(_optString(n, 'task_id')),
                kind: Value(_optInt(n, 'kind') ?? 0),
                triageStatus: Value(_optInt(n, 'triage_status') ?? 2),
                createdAtUtcMillis: _reqInt(n, 'created_at_utc_ms'),
                updatedAtUtcMillis: _reqInt(n, 'updated_at_utc_ms'),
              ),
          ], mode: InsertMode.insertOrReplace);

          batch.insertAll(_db.weaveLinks, [
            for (final w in weaveLinks)
              WeaveLinksCompanion.insert(
                id: _reqString(w, 'id'),
                sourceType: _reqInt(w, 'source_type'),
                sourceId: _reqString(w, 'source_id'),
                targetNoteId: _reqString(w, 'target_note_id'),
                mode: Value(_optInt(w, 'mode') ?? 0),
                createdAtUtcMillis: _reqInt(w, 'created_at_utc_ms'),
                updatedAtUtcMillis: _reqInt(w, 'updated_at_utc_ms'),
              ),
          ], mode: InsertMode.insertOrReplace);

          batch.insertAll(_db.pomodoroSessions, [
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
          ], mode: InsertMode.insertOrReplace);

          batch.insertAll(_db.kpiDailyRollups, [
            for (final r in kpiDailyRollups)
              KpiDailyRollupsCompanion.insert(
                dayKey: _reqString(r, 'day_key'),
                segment: _reqString(r, 'segment'),
                segmentStrategy: _reqString(r, 'segment_strategy'),
                sampleThreshold: _reqInt(r, 'sample_threshold'),
                computedAtUtcMs: _reqInt(r, 'computed_at_utc_ms'),
                clarityOkCount: _reqInt(r, 'clarity_ok_count'),
                clarityTotalCount: _reqInt(r, 'clarity_total_count'),
                clarityInsufficient: _optBool(r, 'clarity_insufficient') ?? true,
                clarityInsufficientReason: Value(
                  _optString(r, 'clarity_insufficient_reason'),
                ),
                clarityFailureBucketCountsJson: Value(
                  _optString(r, 'clarity_failure_bucket_counts_json'),
                ),
                ttfaSampleCount: _reqInt(r, 'ttfa_sample_count'),
                ttfaP50Ms: Value(_optInt(r, 'ttfa_p50_ms')),
                ttfaP90Ms: Value(_optInt(r, 'ttfa_p90_ms')),
                ttfaInsufficient: _optBool(r, 'ttfa_insufficient') ?? true,
                ttfaInsufficientReason: Value(
                  _optString(r, 'ttfa_insufficient_reason'),
                ),
                mainlineCompletedCount: _reqInt(r, 'mainline_completed_count'),
                mainlineInsufficient: _optBool(r, 'mainline_insufficient') ?? true,
                mainlineInsufficientReason: Value(
                  _optString(r, 'mainline_insufficient_reason'),
                ),
                journalOpenedCount: _reqInt(r, 'journal_opened_count'),
                journalCompletedCount: _reqInt(r, 'journal_completed_count'),
                journalInsufficient: _optBool(r, 'journal_insufficient') ?? true,
                journalInsufficientReason: Value(
                  _optString(r, 'journal_insufficient_reason'),
                ),
                activeDayCount: _reqInt(r, 'active_day_count'),
                r7Retained: Value(_optBool(r, 'r7_retained')),
                r7Insufficient: _optBool(r, 'r7_insufficient') ?? true,
                r7InsufficientReason: Value(
                  _optString(r, 'r7_insufficient_reason'),
                ),
                inboxPendingCount: _reqInt(r, 'inbox_pending_count'),
                inboxCreatedCount: _reqInt(r, 'inbox_created_count'),
                inboxProcessedCount: _reqInt(r, 'inbox_processed_count'),
              ),
          ], mode: InsertMode.insertOrReplace);

          final now = DateTime.now().toUtc().millisecondsSinceEpoch;
          batch.insertAll(_db.pomodoroConfigs, [
            PomodoroConfigsCompanion.insert(
              id: const Value(1),
              workDurationMinutes: Value(safeWorkDurationMinutes),
              shortBreakMinutes: Value(safeShortBreakMinutes),
              longBreakMinutes: Value(safeLongBreakMinutes),
              longBreakEvery: Value(safeLongBreakEvery),
              dailyBudgetPomodoros: Value(safeDailyBudgetPomodoros),
              autoStartBreak: Value(autoStartBreak),
              autoStartFocus: Value(autoStartFocus),
              notificationSound: Value(notificationSound),
              notificationVibration: Value(notificationVibration),
              updatedAtUtcMillis: now,
            ),
          ], mode: InsertMode.insertOrReplace);
          batch.insertAll(_db.appearanceConfigs, [
            AppearanceConfigsCompanion.insert(
              id: const Value(1),
              themeMode: Value(safeThemeMode),
              density: Value(safeDensity),
              accent: Value(safeAccent),
              defaultTab: Value(safeDefaultTab),
              onboardingDone: Value(onboardingDone),
              statsEnabled: Value(statsEnabled),
              todayModulesJson: Value(todayModulesJson),
              timeboxingStartMinutes: Value(safeTimeboxingStartMinutes),
              timeboxingLayout: Value(safeTimeboxingLayout),
              timeboxingWorkdayStartMinutes: Value(
                safeTimeboxingWorkdayStartMinutes,
              ),
              timeboxingWorkdayEndMinutes: Value(safeTimeboxingWorkdayEndMinutes),
              inboxTypeFilter: Value(safeInboxTypeFilter),
              inboxTodayOnly: Value(inboxTodayOnly),
              updatedAtUtcMillis: now,
            ),
          ], mode: InsertMode.insertOrReplace);
        });

        if (aiConfig != null) {
          cancelToken?.throwIfCancelled();
          await _aiConfigRepositoryOrThrow().saveConfig(aiConfig);
          cancelToken?.throwIfCancelled();
        }
      });
    } catch (_) {
      if (aiConfig != null) {
        await _restoreAiConfig(aiConfigBeforeRestore);
      }
      rethrow;
    }

    return RestoreResult(
      taskCount: tasks.length,
      checklistCount: taskCheckItems.length,
      noteCount: notes.length,
      weaveLinkCount: weaveLinks.length,
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
    required String passphrase,
    required int kdfVersion,
    required bool includesSecrets,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);

    final secretKey = await _deriveKey(
      passphrase: passphrase,
      salt: salt,
      kdfVersion: kdfVersion,
      kdf: kdfVersion == kdfVersionArgon2id
          ? {
              'algorithm': 'argon2id',
              'parallelism': _argon2Parallelism,
              'memory_kib': _argon2MemoryKib,
              'iterations': _argon2Iterations,
              'hash_length': _argon2HashLength,
            }
          : {
              'algorithm': 'pbkdf2-hmac-sha256',
              'iterations': 100000,
              'hash_length': 32,
            },
    );
    final secretBox = await _cipher.encrypt(
      zipBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final header =
        kdfVersion == kdfVersionArgon2id
            ? {
                'format': 'daypick-backup',
                'version': backupFormatVersion,
                'cipher': 'AES-256-GCM',
                'includes_secrets': includesSecrets,
                'kdf_version': kdfVersion,
                'kdf': {
                  'algorithm': 'argon2id',
                  'parallelism': _argon2Parallelism,
                  'memory_kib': _argon2MemoryKib,
                  'iterations': _argon2Iterations,
                  'hash_length': _argon2HashLength,
                  'salt_length': salt.length,
                },
                'salt': base64Encode(salt),
                'nonce': base64Encode(secretBox.nonce),
                'mac_length': secretBox.mac.bytes.length,
                'created_at': DateTime.now().toUtc().toIso8601String(),
              }
            : {
                'format': 'daypick-backup',
                'version': backupFormatVersion,
                'cipher': 'AES-256-GCM',
                'includes_secrets': includesSecrets,
                'kdf_version': kdfVersion,
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
    required String passphrase,
  }) async {
    final normalizedPassphrase = passphrase.trim();
    _validatePassphrase(normalizedPassphrase);
    if (encryptedBytes.length < 8) throw const BackupException('备份文件过短或已损坏');
    final magic = utf8.decode(encryptedBytes.sublist(0, 4));
    if (magic != 'PPBK') throw const BackupException('不是 DayPick 备份文件');

    final headerLen = ByteData.sublistView(
      encryptedBytes,
      4,
      8,
    ).getUint32(0, Endian.big);
    final headerStart = 8;
    final headerEnd = headerStart + headerLen;
    if (headerEnd > encryptedBytes.length)
      throw const BackupException('备份文件头损坏');

    final headerText = utf8.decode(
      encryptedBytes.sublist(headerStart, headerEnd),
    );
    final header = jsonDecode(headerText);
    if (header is! Map) throw const BackupException('备份文件头格式不正确');

    int? optInt(String key) {
      final v = header[key];
      if (v is int) return v;
      if (v is double) return v.toInt();
      return null;
    }

    bool? optBool(String key) {
      final v = header[key];
      if (v is bool) return v;
      return null;
    }

    Map<String, Object?>? optMap(String key) {
      final v = header[key];
      if (v is! Map) return null;
      return v.map((k, v) => MapEntry(k.toString(), v));
    }

    final includesSecretsHeader =
        optBool('includes_secrets') ?? optBool('includesSecrets') ?? false;
    final kdfVersionHeader = optInt('kdf_version') ?? optInt('kdfVersion');
    final kdfHeader = optMap('kdf');
    final kdfVersion =
        kdfVersionHeader ??
        (kdfHeader?['algorithm'] == 'argon2id'
            ? kdfVersionArgon2id
            : kdfVersionPbkdf2);

    _validatePassphrase(
      normalizedPassphrase,
      requiresStrongPassphrase:
          includesSecretsHeader || kdfVersion == kdfVersionArgon2id,
    );

    final saltB64 = header['salt'];
    final nonceB64 = header['nonce'];
    final iterations = optInt('iterations');
    final macLength = optInt('mac_length') ?? optInt('macLength');
    if (saltB64 is! String || nonceB64 is! String || macLength == null) {
      throw const BackupException('备份文件头缺少必要字段');
    }

    final salt = base64Decode(saltB64);
    final nonce = base64Decode(nonceB64);

    final payload = encryptedBytes.sublist(headerEnd);
    if (payload.length <= macLength) throw const BackupException('备份文件内容损坏');

    final cipherText = payload.sublist(0, payload.length - macLength);
    final macBytes = payload.sublist(payload.length - macLength);

    final key = await _deriveKey(
      passphrase: normalizedPassphrase,
      salt: salt,
      kdfVersion: kdfVersion,
      kdf:
          kdfHeader ??
          (kdfVersion == kdfVersionArgon2id
              ? null
              : {
                  'algorithm': 'pbkdf2-hmac-sha256',
                  'iterations': iterations ?? 100000,
                  'hash_length': 32,
                }),
    );
    try {
      final plain = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );
      return Uint8List.fromList(plain);
    } catch (_) {
      throw const BackupWrongPassphraseOrCorruptedException();
    }
  }

  Future<SecretKey> _deriveKey({
    required String passphrase,
    required List<int> salt,
    required int kdfVersion,
    required Map<String, Object?>? kdf,
  }) async {
    if (kdfVersion == kdfVersionPbkdf2) {
      final iterationsRaw = kdf?['iterations'];
      final iterations = iterationsRaw is int
          ? iterationsRaw
          : (iterationsRaw is double ? iterationsRaw.toInt() : null);
      if (iterations != null && iterations != 100000) {
        throw BackupUnsupportedException('不支持的 KDF 参数：iterations=$iterations');
      }
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 100000,
        bits: 256,
      );
      return pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: salt,
      );
    }

    if (kdfVersion == kdfVersionArgon2id) {
      if (kdf == null) {
        throw const BackupUnsupportedException('备份文件头缺少 KDF 参数');
      }

      final algorithm = kdf['algorithm'];
      if (algorithm != null && algorithm != 'argon2id') {
        throw const BackupUnsupportedException('不支持的 KDF 算法');
      }
      int? readInt(String key) {
        final v = kdf[key];
        if (v is int) return v;
        if (v is double) return v.toInt();
        return null;
      }

      final parallelism = readInt('parallelism');
      final memoryKib = readInt('memory_kib');
      final iterations = readInt('iterations');
      final hashLength = readInt('hash_length');

      if (parallelism == null ||
          memoryKib == null ||
          iterations == null ||
          hashLength == null) {
        throw const BackupUnsupportedException('备份文件头缺少 KDF 参数');
      }

      if (parallelism < 1 || parallelism > 8) {
        throw BackupUnsupportedException('不支持的 KDF 参数：parallelism=$parallelism');
      }
      if (memoryKib < 8 * 1024 || memoryKib > 64 * 1024) {
        throw BackupUnsupportedException('不支持的 KDF 参数：memory_kib=$memoryKib');
      }
      if (iterations < 1 || iterations > 10) {
        throw BackupUnsupportedException('不支持的 KDF 参数：iterations=$iterations');
      }
      if (hashLength < 16 || hashLength > 64) {
        throw BackupUnsupportedException('不支持的 KDF 参数：hash_length=$hashLength');
      }

      final argon2 = DartArgon2id(
        parallelism: parallelism,
        memory: memoryKib,
        iterations: iterations,
        hashLength: hashLength,
      );
      return argon2.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: salt,
      );
    }

    throw BackupUnsupportedException('不支持的 kdf_version：$kdfVersion');
  }

  Future<Uint8List> _buildAiConfigBytesOrThrow() async {
    final config = await _aiConfigRepositoryOrThrow().getConfig();
    final apiKey = config?.apiKey?.trim();
    if (config == null || apiKey == null || apiKey.isEmpty) {
      throw const BackupMissingAiApiKeyException();
    }

    final baseUrl = config.baseUrl.trim();
    final model = config.model.trim();
    if (baseUrl.isEmpty || model.isEmpty) {
      throw const BackupMissingAiConfigException();
    }

    final payload = {
      'base_url': baseUrl,
      'model': model,
      'api_key': apiKey,
      'updated_at_utc_ms': config.updatedAt.toUtc().millisecondsSinceEpoch,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  domain.AiProviderConfig _readAiConfigFromArchive(Archive archive) {
    final entry = archive.findFile(_aiConfigEntryPath);
    if (entry == null) {
      throw BackupUnsupportedException('备份文件缺少 $_aiConfigEntryPath');
    }
    final text = utf8.decode(entry.content as List<int>);
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const BackupUnsupportedException('ai_config.json 格式不正确');

    String? optString(String key) {
      final v = decoded[key];
      if (v == null) return null;
      if (v is String) return v;
      return v.toString();
    }

    int? optInt(String key) {
      final v = decoded[key];
      if (v is int) return v;
      if (v is double) return v.toInt();
      return null;
    }

    final baseUrl = (optString('base_url') ?? optString('baseUrl'))?.trim();
    final model = (optString('model'))?.trim();
    final apiKey = (optString('api_key') ?? optString('apiKey'))?.trim();
    final updatedAtUtcMs =
        optInt('updated_at_utc_ms') ?? optInt('updatedAtUtcMillis');

    if (baseUrl == null || baseUrl.isEmpty) {
      throw const BackupUnsupportedException('ai_config.json 缺少 base_url');
    }
    if (model == null || model.isEmpty) {
      throw const BackupUnsupportedException('ai_config.json 缺少 model');
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw const BackupUnsupportedException('ai_config.json 缺少 api_key');
    }

    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      updatedAtUtcMs ?? DateTime.now().toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );
    return domain.AiProviderConfig(
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      updatedAt: updatedAt,
    );
  }

  domain.AiConfigRepository _aiConfigRepositoryOrThrow() {
    final existing = _aiConfigRepository;
    if (existing != null) return existing;
    final repo = SecureAiConfigRepository();
    _aiConfigRepository = repo;
    return repo;
  }

  Future<void> _restoreAiConfig(domain.AiProviderConfig? previous) async {
    try {
      final repo = _aiConfigRepositoryOrThrow();
      if (previous == null) {
        await repo.clear();
      } else {
        await repo.saveConfig(previous);
      }
    } catch (_) {}
  }

  void _validatePassphrase(
    String passphrase, {
    bool requiresStrongPassphrase = false,
  }) {
    final trimmed = passphrase.trim();
    if (trimmed.length < 6) throw const BackupException('密码至少 6 位');
    if (!requiresStrongPassphrase) return;

    final isPin6 = RegExp(r'^\d{6}$').hasMatch(trimmed);
    if (isPin6) throw const BackupWeakPassphraseException();
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(trimmed);
    final hasDigit = RegExp(r'\d').hasMatch(trimmed);
    if (trimmed.length < 12 || !hasLetter || !hasDigit) {
      throw const BackupWeakPassphraseException();
    }
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

class _BackupManifest {
  const _BackupManifest({
    required this.backupFormatVersion,
    required this.exportSchemaVersion,
    required this.exportedAtUtcMillis,
    required this.includesSecrets,
    required this.kdfVersion,
    required this.kdf,
  });

  final int backupFormatVersion;
  final int exportSchemaVersion;
  final int exportedAtUtcMillis;
  final bool includesSecrets;
  final int? kdfVersion;
  final Map<String, Object?>? kdf;
}

_BackupManifest _readBackupManifest(Archive archive) {
  final manifestFile = archive.findFile('manifest.json');
  if (manifestFile == null) {
    throw const BackupUnsupportedException('备份文件缺少 manifest.json');
  }

  final manifestText = utf8.decode(manifestFile.content as List<int>);
  final decoded = jsonDecode(manifestText);
  if (decoded is! Map) {
    throw const BackupUnsupportedException('manifest.json 格式不正确');
  }

  final format = decoded['format'];
  if (format is! String || format != 'daypick-backup') {
    throw const BackupUnsupportedException('不是 DayPick 备份文件');
  }

  int? optInt(String key) {
    final v = decoded[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    return null;
  }

  bool? optBool(String key) {
    final v = decoded[key];
    if (v is bool) return v;
    return null;
  }

  final backupFormatVersion =
      optInt('backup_format_version') ?? optInt('backupFormatVersion');
  final hasExplicitExportSchemaVersion =
      decoded.containsKey('export_schema_version') ||
      decoded.containsKey('exportSchemaVersion');
  final exportSchemaVersion =
      optInt('export_schema_version') ??
      optInt('exportSchemaVersion') ??
      optInt('schema_version') ??
      optInt('schemaVersion');
  final exportedAtUtcMillis =
      optInt('exported_at_utc_ms') ?? optInt('exportedAt');
  final includesSecrets =
      optBool('includes_secrets') ?? optBool('includesSecrets') ?? false;
  final kdfVersion = optInt('kdf_version') ?? optInt('kdfVersion');

  Map<String, Object?>? optMap(String key) {
    final v = decoded[key];
    if (v is! Map) return null;
    return v.map((k, v) => MapEntry(k.toString(), v));
  }

  final kdf = optMap('kdf');

  if (backupFormatVersion == null ||
      exportSchemaVersion == null ||
      exportedAtUtcMillis == null) {
    throw const BackupUnsupportedException('manifest.json 缺少必要字段');
  }
  if (includesSecrets) {
    if (!hasExplicitExportSchemaVersion) {
      throw const BackupUnsupportedException(
        'manifest.json 缺少 export_schema_version',
      );
    }
    if (kdfVersion == null || kdf == null) {
      throw const BackupUnsupportedException('manifest.json 缺少 kdf_version/kdf');
    }
    if (kdfVersion != DataBackupService.kdfVersionArgon2id) {
      throw BackupUnsupportedException('不支持的 kdf_version：$kdfVersion');
    }
    final algorithm = kdf['algorithm'];
    if (algorithm is! String || algorithm != 'argon2id') {
      throw const BackupUnsupportedException('不支持的 kdf.algorithm');
    }
    bool hasInt(String key) {
      final v = kdf[key];
      return v is int || v is double;
    }

    if (!hasInt('parallelism') ||
        !hasInt('memory_kib') ||
        !hasInt('iterations') ||
        !hasInt('hash_length') ||
        !hasInt('salt_length')) {
      throw const BackupUnsupportedException('manifest.json kdf 参数缺失或类型不正确');
    }
  }

  return _BackupManifest(
    backupFormatVersion: backupFormatVersion,
    exportSchemaVersion: exportSchemaVersion,
    exportedAtUtcMillis: exportedAtUtcMillis,
    includesSecrets: includesSecrets,
    kdfVersion: kdfVersion,
    kdf: kdf,
  );
}

(int schemaVersion, int exportedAtUtcMillis) _readExportMetadataFromDataJson(
  Uint8List dataJson,
) {
  final dataText = utf8.decode(dataJson);
  final decoded = jsonDecode(dataText);
  if (decoded is! Map) {
    throw const BackupException('data.json 格式不正确');
  }

  final schemaVersion = decoded['schemaVersion'];
  final exportedAt = decoded['exportedAt'];
  if (schemaVersion is! int || exportedAt is! int) {
    throw const BackupException('data.json 缺少 schemaVersion/exportedAt');
  }
  return (schemaVersion, exportedAt);
}

void _assertNoSensitiveTokensInJsonBytes(
  Uint8List jsonBytes, {
  required List<String> sensitiveTokensLower,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(jsonBytes));
  } catch (_) {
    return;
  }

  void walk(Object? node, {String? parentKey}) {
    if (node == null) return;

    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString();
        final keyLower = key.toLowerCase();
        for (final token in sensitiveTokensLower) {
          if (keyLower.contains(token)) {
            throw const BackupSensitiveContentDetectedException();
          }
        }
        walk(entry.value, parentKey: key);
      }
      return;
    }

    if (node is List) {
      for (final e in node) {
        walk(e, parentKey: parentKey);
      }
      return;
    }

    if (node is String) {
      final keyLower = parentKey?.toLowerCase();
      if (keyLower != null && _contentValueKeysToSkipLower.contains(keyLower)) {
        return;
      }

      final valueLower = node.toLowerCase();
      for (final token in sensitiveTokensLower) {
        if (valueLower.contains(token)) {
          throw const BackupSensitiveContentDetectedException();
        }
      }
    }
  }

  walk(decoded);
}

const _allSensitiveTokensLower = <String>[
  'ai.apikey',
  'apikey',
  'api_key',
  'db key',
  'db_key',
  'flutter_secure_storage',
  'db.key.v1',
];

const _nonSecretSensitiveTokensLower = <String>[
  'db key',
  'db_key',
  'flutter_secure_storage',
  'db.key.v1',
];

const _contentValueKeysToSkipLower = <String>{
  'title',
  'body',
  'description',
  'content',
  'prompt',
  'response',
  'progress_note',
  'tags',
};

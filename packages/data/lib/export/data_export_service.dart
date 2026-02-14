import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'data_export_models.dart';

class DataExportService {
  DataExportService(this._db);

  static const int exportSchemaVersion = 8;

  final AppDatabase _db;

  Future<ExportSnapshot> snapshot() async {
    final exportedAtUtcMillis = DateTime.now().toUtc().millisecondsSinceEpoch;

    final tasks = await _db.select(_db.tasks).get();
    final todayPlanItems = await _db.select(_db.todayPlanItems).get();
    final checkItems = await _db.select(_db.taskCheckItems).get();
    final notes = await _db.select(_db.notes).get();
    final weaveLinks = await _db.select(_db.weaveLinks).get();
    final sessions = await _db.select(_db.pomodoroSessions).get();
    final kpiDailyRollups =
        await (_db.select(_db.kpiDailyRollups)..orderBy([
              (t) => OrderingTerm(expression: t.dayKey, mode: OrderingMode.asc),
              (t) =>
                  OrderingTerm(expression: t.segment, mode: OrderingMode.asc),
            ]))
            .get();
    final pomodoroConfigRow = await (_db.select(
      _db.pomodoroConfigs,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    final appearanceRow = await (_db.select(
      _db.appearanceConfigs,
    )..where((t) => t.id.equals(1))).getSingleOrNull();

    return ExportSnapshot(
      exportedAtUtcMillis: exportedAtUtcMillis,
      pomodoroConfig: {
        'work_duration_minutes': pomodoroConfigRow?.workDurationMinutes ?? 25,
        'short_break_minutes': pomodoroConfigRow?.shortBreakMinutes ?? 5,
        'long_break_minutes': pomodoroConfigRow?.longBreakMinutes ?? 15,
        'long_break_every': pomodoroConfigRow?.longBreakEvery ?? 4,
        'daily_budget_pomodoros': pomodoroConfigRow?.dailyBudgetPomodoros ?? 8,
        'auto_start_break': pomodoroConfigRow?.autoStartBreak ?? false,
        'auto_start_focus': pomodoroConfigRow?.autoStartFocus ?? false,
        'notification_sound': pomodoroConfigRow?.notificationSound ?? false,
        'notification_vibration':
            pomodoroConfigRow?.notificationVibration ?? false,
        'updated_at_utc_ms': pomodoroConfigRow?.updatedAtUtcMillis,
      },
      appearanceConfig: {
        'theme_mode': appearanceRow?.themeMode ?? 0,
        'density': appearanceRow?.density ?? 0,
        'accent': appearanceRow?.accent ?? 0,
        'default_tab': appearanceRow?.defaultTab ?? 2,
        'onboarding_done': appearanceRow?.onboardingDone ?? false,
        'stats_enabled': appearanceRow?.statsEnabled ?? false,
        'today_modules': _decodeStringList(
          appearanceRow?.todayModulesJson ??
              '["nextStep","todayPlan","weave","budget","focus","shortcuts","yesterdayReview"]',
        ).where((m) => m != 'quickAdd').toList(growable: false),
        'timeboxing_start_minutes': appearanceRow?.timeboxingStartMinutes,
        'timeboxing_layout': appearanceRow?.timeboxingLayout ?? 0,
        'timeboxing_workday_start_minutes':
            appearanceRow?.timeboxingWorkdayStartMinutes ?? 7 * 60,
        'timeboxing_workday_end_minutes':
            appearanceRow?.timeboxingWorkdayEndMinutes ?? 21 * 60,
        'inbox_type_filter': appearanceRow?.inboxTypeFilter ?? 0,
        'inbox_today_only': appearanceRow?.inboxTodayOnly ?? false,
        'updated_at_utc_ms': appearanceRow?.updatedAtUtcMillis,
      },
      tasks: [
        for (final t in tasks)
          {
            'id': t.id,
            'title': t.title,
            'description': t.description,
            'status': t.status,
            'priority': t.priority,
            'due_at_utc_ms': t.dueAtUtcMillis,
            'tags': _decodeStringList(t.tagsJson),
            'triage_status': t.triageStatus,
            'estimated_pomodoros': t.estimatedPomodoros,
            'created_at_utc_ms': t.createdAtUtcMillis,
            'updated_at_utc_ms': t.updatedAtUtcMillis,
          },
      ],
      todayPlanItems: [
        for (final row in todayPlanItems)
          {
            'day_key': row.dayKey,
            'task_id': row.taskId,
            'segment': row.segment,
            'order_index': row.orderIndex,
            'created_at_utc_ms': row.createdAtUtcMillis,
            'updated_at_utc_ms': row.updatedAtUtcMillis,
          },
      ],
      taskCheckItems: [
        for (final c in checkItems)
          {
            'id': c.id,
            'task_id': c.taskId,
            'title': c.title,
            'is_done': c.isDone,
            'order_index': c.orderIndex,
            'created_at_utc_ms': c.createdAtUtcMillis,
            'updated_at_utc_ms': c.updatedAtUtcMillis,
          },
      ],
      notes: [
        for (final n in notes)
          {
            'id': n.id,
            'title': n.title,
            'body': n.body,
            'tags': _decodeStringList(n.tagsJson),
            'task_id': n.taskId,
            'kind': n.kind,
            'triage_status': n.triageStatus,
            'created_at_utc_ms': n.createdAtUtcMillis,
            'updated_at_utc_ms': n.updatedAtUtcMillis,
          },
      ],
      weaveLinks: [
        for (final w in weaveLinks)
          {
            'id': w.id,
            'source_type': w.sourceType,
            'source_id': w.sourceId,
            'target_note_id': w.targetNoteId,
            'mode': w.mode,
            'created_at_utc_ms': w.createdAtUtcMillis,
            'updated_at_utc_ms': w.updatedAtUtcMillis,
          },
      ],
      pomodoroSessions: [
        for (final s in sessions)
          {
            'id': s.id,
            'task_id': s.taskId,
            'start_at_utc_ms': s.startAtUtcMillis,
            'end_at_utc_ms': s.endAtUtcMillis,
            'is_draft': s.isDraft,
            'progress_note': s.progressNote,
            'created_at_utc_ms': s.createdAtUtcMillis,
          },
      ],
      kpiDailyRollups: [
        for (final r in kpiDailyRollups)
          {
            'day_key': r.dayKey,
            'segment': r.segment,
            'segment_strategy': r.segmentStrategy,
            'sample_threshold': r.sampleThreshold,
            'computed_at_utc_ms': r.computedAtUtcMs,
            'clarity_ok_count': r.clarityOkCount,
            'clarity_total_count': r.clarityTotalCount,
            'clarity_insufficient': r.clarityInsufficient,
            'clarity_insufficient_reason': r.clarityInsufficientReason,
            'clarity_failure_bucket_counts_json':
                r.clarityFailureBucketCountsJson,
            'ttfa_sample_count': r.ttfaSampleCount,
            'ttfa_p50_ms': r.ttfaP50Ms,
            'ttfa_p90_ms': r.ttfaP90Ms,
            'ttfa_insufficient': r.ttfaInsufficient,
            'ttfa_insufficient_reason': r.ttfaInsufficientReason,
            'mainline_completed_count': r.mainlineCompletedCount,
            'mainline_insufficient': r.mainlineInsufficient,
            'mainline_insufficient_reason': r.mainlineInsufficientReason,
            'journal_opened_count': r.journalOpenedCount,
            'journal_completed_count': r.journalCompletedCount,
            'journal_insufficient': r.journalInsufficient,
            'journal_insufficient_reason': r.journalInsufficientReason,
            'active_day_count': r.activeDayCount,
            'r7_retained': r.r7Retained,
            'r7_insufficient': r.r7Insufficient,
            'r7_insufficient_reason': r.r7InsufficientReason,
            'inbox_pending_count': r.inboxPendingCount,
            'inbox_created_count': r.inboxCreatedCount,
            'inbox_processed_count': r.inboxProcessedCount,
          },
      ],
    );
  }

  Future<Uint8List> exportJsonBytes() async {
    final snap = await snapshot();
    final obj = {
      'schemaVersion': exportSchemaVersion,
      'exportedAt': snap.exportedAtUtcMillis,
      'items': {
        'tasks': snap.tasks,
        'today_plan_items': snap.todayPlanItems,
        'task_check_items': snap.taskCheckItems,
        'notes': snap.notes,
        'weave_links': snap.weaveLinks,
        'pomodoro_sessions': snap.pomodoroSessions,
        'kpi_daily_rollups': snap.kpiDailyRollups,
        'pomodoro_config': snap.pomodoroConfig,
        'appearance_config': snap.appearanceConfig,
      },
    };
    final jsonText = const JsonEncoder.withIndent('  ').convert(obj);
    return Uint8List.fromList(utf8.encode(jsonText));
  }

  Future<Uint8List> exportMarkdownBytes() async {
    final snap = await snapshot();
    final buffer = StringBuffer();

    buffer.writeln('---');
    buffer.writeln('schemaVersion: ${exportSchemaVersion}');
    buffer.writeln('exportedAtUtcMs: ${snap.exportedAtUtcMillis}');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('# DayPick 导出');
    buffer.writeln();
    buffer.writeln('- 任务：${snap.taskCount}');
    buffer.writeln('- 笔记：${snap.noteCount}');
    buffer.writeln('- 编织链接：${snap.weaveLinkCount}');
    buffer.writeln('- 番茄：${snap.sessionCount}');
    buffer.writeln('- Checklist：${snap.checklistCount}');
    buffer.writeln('- 今天计划项：${snap.todayPlanItemCount}');
    buffer.writeln();

    buffer.writeln('## 设置');
    buffer.writeln();
    buffer.writeln(
      '- 专注时长（分钟）：${snap.pomodoroConfig['work_duration_minutes']}',
    );
    buffer.writeln('- 短休（分钟）：${snap.pomodoroConfig['short_break_minutes']}');
    buffer.writeln('- 长休（分钟）：${snap.pomodoroConfig['long_break_minutes']}');
    buffer.writeln(
      '- 长休间隔（每 N 个专注）：${snap.pomodoroConfig['long_break_every']}',
    );
    buffer.writeln(
      '- 每日预算（番茄）：${snap.pomodoroConfig['daily_budget_pomodoros']}',
    );
    final themeMode = (snap.appearanceConfig['theme_mode'] as int?) ?? 0;
    final density = (snap.appearanceConfig['density'] as int?) ?? 0;
    final accent = (snap.appearanceConfig['accent'] as int?) ?? 0;
    final defaultTab = (snap.appearanceConfig['default_tab'] as int?) ?? 2;
    final themeLabel = switch (themeMode) {
      1 => '浅色',
      2 => '深色',
      _ => '系统',
    };
    final densityLabel = switch (density) {
      1 => '紧凑',
      _ => '舒适',
    };
    final accentLabel = switch (accent) {
      1 => 'B',
      2 => 'C',
      _ => 'A',
    };
    final defaultTabLabel = switch (defaultTab) {
      0 => 'AI',
      1 => '笔记',
      3 => '任务',
      4 => '专注',
      _ => '今天',
    };
    final statsEnabled =
        (snap.appearanceConfig['stats_enabled'] as bool?) ?? false;
    final timeboxingStartMinutes =
        snap.appearanceConfig['timeboxing_start_minutes'] as int?;
    final timeboxingLayout =
        (snap.appearanceConfig['timeboxing_layout'] as int?) ?? 0;
    final timeboxingWorkdayStartMinutes =
        (snap.appearanceConfig['timeboxing_workday_start_minutes'] as int?) ??
        7 * 60;
    final timeboxingWorkdayEndMinutes =
        (snap.appearanceConfig['timeboxing_workday_end_minutes'] as int?) ??
        21 * 60;
    final todayModules =
        (snap.appearanceConfig['today_modules'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    final statsLabel = statsEnabled ? '开启' : '关闭';
    String formatTime(int minutes) {
      final clamped = minutes.clamp(0, 24 * 60 - 1);
      final hh = (clamped ~/ 60).toString().padLeft(2, '0');
      final mm = (clamped % 60).toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final timeboxingLayoutLabel = switch (timeboxingLayout) {
      1 => 'Minimal',
      _ => 'Full',
    };
    buffer.writeln('- 主题：$themeLabel');
    buffer.writeln('- 密度：$densityLabel');
    buffer.writeln('- Accent：$accentLabel');
    buffer.writeln('- 默认入口：$defaultTabLabel');
    buffer.writeln('- 统计/热力图：$statsLabel');
    if (timeboxingStartMinutes != null) {
      buffer.writeln('- Timeboxing 开始时间：${formatTime(timeboxingStartMinutes)}');
    }
    buffer.writeln('- Timeboxing 布局：$timeboxingLayoutLabel');
    buffer.writeln(
      '- Timeboxing 工作时段：${formatTime(timeboxingWorkdayStartMinutes)}–${formatTime(timeboxingWorkdayEndMinutes)}',
    );
    if (todayModules.isNotEmpty) {
      buffer.writeln('- Today 模块：${todayModules.join(', ')}');
    }
    buffer.writeln();

    buffer.writeln('## 任务');
    buffer.writeln();
    if (snap.tasks.isEmpty) {
      buffer.writeln('（无）');
      buffer.writeln();
    } else {
      for (final t in snap.tasks) {
        final title = (t['title'] as String?) ?? '';
        final status = t['status'];
        final priority = t['priority'];
        final triage = t['triage_status'];
        final due = t['due_at_utc_ms'];
        final tags =
            (t['tags'] as List?)?.whereType<String>().toList() ?? const [];
        final desc = (t['description'] as String?)?.trim();

        buffer.writeln('### ${_escapeMd(title)}');
        buffer.writeln();
        buffer.writeln('- id: `${t['id']}`');
        buffer.writeln('- status: $status');
        buffer.writeln('- priority: $priority');
        if (triage != null) buffer.writeln('- triage_status: $triage');
        if (due != null) buffer.writeln('- due_at_utc_ms: $due');
        if (tags.isNotEmpty)
          buffer.writeln('- tags: ${tags.map(_escapeMd).join(', ')}');
        buffer.writeln();
        if (desc != null && desc.isNotEmpty) {
          buffer.writeln(desc);
          buffer.writeln();
        }
      }
    }

    buffer.writeln('## 笔记');
    buffer.writeln();
    if (snap.notes.isEmpty) {
      buffer.writeln('（无）');
      buffer.writeln();
    } else {
      for (final n in snap.notes) {
        final title = (n['title'] as String?) ?? '';
        final kind = n['kind'];
        final triage = n['triage_status'];
        final tags =
            (n['tags'] as List?)?.whereType<String>().toList() ?? const [];
        final taskId = n['task_id'];
        final updatedAt = n['updated_at_utc_ms'];
        final body = _stripInternalRouteTokens((n['body'] as String?) ?? '');

        buffer.writeln('### ${_escapeMd(title)}');
        buffer.writeln();
        buffer.writeln('- id: `${n['id']}`');
        if (kind != null) buffer.writeln('- kind: $kind');
        if (triage != null) buffer.writeln('- triage_status: $triage');
        if (updatedAt != null)
          buffer.writeln('- updated_at_utc_ms: $updatedAt');
        if (taskId != null) buffer.writeln('- task_id: `$taskId`');
        if (tags.isNotEmpty)
          buffer.writeln('- tags: ${tags.map(_escapeMd).join(', ')}');
        buffer.writeln();
        buffer.writeln(body.trim().isEmpty ? '（空）' : body.trimRight());
        buffer.writeln();
      }
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<Uint8List> exportTasksMarkdownBytes() async {
    final snap = await snapshot();
    final buffer = StringBuffer();

    buffer.writeln('---');
    buffer.writeln('schemaVersion: ${exportSchemaVersion}');
    buffer.writeln('exportedAtUtcMs: ${snap.exportedAtUtcMillis}');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('# DayPick 任务清单');
    buffer.writeln();
    buffer.writeln('- 任务：${snap.taskCount}');
    buffer.writeln();

    if (snap.tasks.isEmpty) {
      buffer.writeln('（无）');
      buffer.writeln();
      return Uint8List.fromList(utf8.encode(buffer.toString()));
    }

    for (final t in snap.tasks) {
      final title = (t['title'] as String?) ?? '';
      final status = t['status'];
      final priority = t['priority'];
      final triage = t['triage_status'];
      final due = t['due_at_utc_ms'];
      final tags =
          (t['tags'] as List?)?.whereType<String>().toList() ?? const [];
      final desc = (t['description'] as String?)?.trim();

      buffer.writeln('## ${_escapeMd(title)}');
      buffer.writeln();
      buffer.writeln('- id: `${t['id']}`');
      buffer.writeln('- status: $status');
      buffer.writeln('- priority: $priority');
      if (triage != null) buffer.writeln('- triage_status: $triage');
      if (due != null) buffer.writeln('- due_at_utc_ms: $due');
      if (tags.isNotEmpty)
        buffer.writeln('- tags: ${tags.map(_escapeMd).join(', ')}');
      buffer.writeln();
      if (desc != null && desc.isNotEmpty) {
        buffer.writeln(desc);
        buffer.writeln();
      }
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<Uint8List> exportNotesMarkdownBytes() async {
    final snap = await snapshot();
    final buffer = StringBuffer();

    buffer.writeln('---');
    buffer.writeln('schemaVersion: ${exportSchemaVersion}');
    buffer.writeln('exportedAtUtcMs: ${snap.exportedAtUtcMillis}');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('# DayPick 笔记导出');
    buffer.writeln();
    buffer.writeln('- 笔记：${snap.noteCount}');
    buffer.writeln();

    if (snap.notes.isEmpty) {
      buffer.writeln('（无）');
      buffer.writeln();
      return Uint8List.fromList(utf8.encode(buffer.toString()));
    }

    for (final n in snap.notes) {
      final title = (n['title'] as String?) ?? '';
      final kind = n['kind'];
      final triage = n['triage_status'];
      final tags =
          (n['tags'] as List?)?.whereType<String>().toList() ?? const [];
      final taskId = n['task_id'];
      final updatedAt = n['updated_at_utc_ms'];
      final body = _stripInternalRouteTokens((n['body'] as String?) ?? '');

      buffer.writeln('## ${_escapeMd(title)}');
      buffer.writeln();
      buffer.writeln('- id: `${n['id']}`');
      if (kind != null) buffer.writeln('- kind: $kind');
      if (triage != null) buffer.writeln('- triage_status: $triage');
      if (updatedAt != null) buffer.writeln('- updated_at_utc_ms: $updatedAt');
      if (taskId != null) buffer.writeln('- task_id: `$taskId`');
      if (tags.isNotEmpty)
        buffer.writeln('- tags: ${tags.map(_escapeMd).join(', ')}');
      buffer.writeln();
      buffer.writeln(body.trim().isEmpty ? '（空）' : body.trimRight());
      buffer.writeln();
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<Uint8List> exportReviewsMarkdownBytes() async {
    final snap = await snapshot();
    final buffer = StringBuffer();

    bool isReviewNote(Map<String, Object?> note) {
      final tags =
          (note['tags'] as List?)?.whereType<String>().toList() ?? const [];
      return tags.contains('daily-review') || tags.contains('weekly-review');
    }

    final reviews = snap.notes.where(isReviewNote).toList(growable: false);

    buffer.writeln('---');
    buffer.writeln('schemaVersion: ${exportSchemaVersion}');
    buffer.writeln('exportedAtUtcMs: ${snap.exportedAtUtcMillis}');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('# DayPick 复盘导出');
    buffer.writeln();
    buffer.writeln('- 复盘（按笔记计）：${reviews.length}');
    buffer.writeln();

    if (reviews.isEmpty) {
      buffer.writeln('（无）');
      buffer.writeln();
      return Uint8List.fromList(utf8.encode(buffer.toString()));
    }

    for (final n in reviews) {
      final title = (n['title'] as String?) ?? '';
      final tags =
          (n['tags'] as List?)?.whereType<String>().toList() ?? const [];
      final updatedAt = n['updated_at_utc_ms'];
      final body = _stripInternalRouteTokens((n['body'] as String?) ?? '');

      buffer.writeln('## ${_escapeMd(title)}');
      buffer.writeln();
      buffer.writeln('- id: `${n['id']}`');
      if (updatedAt != null) buffer.writeln('- updated_at_utc_ms: $updatedAt');
      if (tags.isNotEmpty)
        buffer.writeln('- tags: ${tags.map(_escapeMd).join(', ')}');
      buffer.writeln();
      buffer.writeln(body.trim().isEmpty ? '（空）' : body.trimRight());
      buffer.writeln();
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  List<String> _decodeStringList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

  String _escapeMd(String input) {
    return input
        .replaceAll('*', r'\*')
        .replaceAll('_', r'\_')
        .replaceAll('#', r'\#');
  }

  String _stripInternalRouteTokens(String input) {
    return input.replaceAll(RegExp(r'\s*\[\[route:[^\]]+\]\]'), '');
  }
}

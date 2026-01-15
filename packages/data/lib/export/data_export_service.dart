import 'dart:convert';
import 'dart:typed_data';

import '../db/app_database.dart';
import 'data_export_models.dart';

class DataExportService {
  DataExportService(this._db);

  static const int exportSchemaVersion = 3;

  final AppDatabase _db;

  Future<ExportSnapshot> snapshot() async {
    final exportedAtUtcMillis = DateTime.now().toUtc().millisecondsSinceEpoch;

    final tasks = await _db.select(_db.tasks).get();
    final todayPlanItems = await _db.select(_db.todayPlanItems).get();
    final checkItems = await _db.select(_db.taskCheckItems).get();
    final notes = await _db.select(_db.notes).get();
    final sessions = await _db.select(_db.pomodoroSessions).get();
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
            'created_at_utc_ms': n.createdAtUtcMillis,
            'updated_at_utc_ms': n.updatedAtUtcMillis,
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
        'pomodoro_sessions': snap.pomodoroSessions,
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
    final themeMode = (snap.appearanceConfig['theme_mode'] as int?) ?? 0;
    final density = (snap.appearanceConfig['density'] as int?) ?? 0;
    final accent = (snap.appearanceConfig['accent'] as int?) ?? 0;
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
    buffer.writeln('- 主题：$themeLabel');
    buffer.writeln('- 密度：$densityLabel');
    buffer.writeln('- Accent：$accentLabel');
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
        final due = t['due_at_utc_ms'];
        final tags =
            (t['tags'] as List?)?.whereType<String>().toList() ?? const [];
        final desc = (t['description'] as String?)?.trim();

        buffer.writeln('### ${_escapeMd(title)}');
        buffer.writeln();
        buffer.writeln('- id: `${t['id']}`');
        buffer.writeln('- status: $status');
        buffer.writeln('- priority: $priority');
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
        final tags =
            (n['tags'] as List?)?.whereType<String>().toList() ?? const [];
        final taskId = n['task_id'];
        final updatedAt = n['updated_at_utc_ms'];
        final body = (n['body'] as String?) ?? '';

        buffer.writeln('### ${_escapeMd(title)}');
        buffer.writeln();
        buffer.writeln('- id: `${n['id']}`');
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
      final due = t['due_at_utc_ms'];
      final tags =
          (t['tags'] as List?)?.whereType<String>().toList() ?? const [];
      final desc = (t['description'] as String?)?.trim();

      buffer.writeln('## ${_escapeMd(title)}');
      buffer.writeln();
      buffer.writeln('- id: `${t['id']}`');
      buffer.writeln('- status: $status');
      buffer.writeln('- priority: $priority');
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
      final tags =
          (n['tags'] as List?)?.whereType<String>().toList() ?? const [];
      final taskId = n['task_id'];
      final updatedAt = n['updated_at_utc_ms'];
      final body = (n['body'] as String?) ?? '';

      buffer.writeln('## ${_escapeMd(title)}');
      buffer.writeln();
      buffer.writeln('- id: `${n['id']}`');
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
      final body = (n['body'] as String?) ?? '';

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
}

import 'dart:convert';

import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftTaskRepository implements domain.TaskRepository {
  DriftTaskRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<domain.Task>> watchAllTasks() {
    final query = _db.select(_db.tasks)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.updatedAtUtcMillis,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<domain.Task?> getTaskById(String taskId) async {
    final query = _db.select(_db.tasks)..where((t) => t.id.equals(taskId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> upsertTask(domain.Task task) async {
    await _db.into(_db.tasks).insertOnConflictUpdate(_toCompanion(task));
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((n) => n.taskId.equals(taskId)))
          .write(const NotesCompanion(taskId: Value(null)));

      await (_db.delete(
        _db.taskCheckItems,
      )..where((t) => t.taskId.equals(taskId))).go();
      await (_db.delete(
        _db.pomodoroSessions,
      )..where((s) => s.taskId.equals(taskId))).go();
      await (_db.delete(
        _db.todayPlanItems,
      )..where((t) => t.taskId.equals(taskId))).go();
      await (_db.delete(
        _db.activePomodoros,
      )..where((a) => a.taskId.equals(taskId))).go();

      await (_db.delete(_db.tasks)..where((t) => t.id.equals(taskId))).go();
    });
  }

  TasksCompanion _toCompanion(domain.Task task) {
    return TasksCompanion.insert(
      id: task.id,
      title: task.title.value,
      description: Value(task.description),
      status: task.status.index,
      priority: task.priority.index,
      dueAtUtcMillis: Value(
        task.dueAt == null ? null : task.dueAt!.toUtc().millisecondsSinceEpoch,
      ),
      tagsJson: Value(jsonEncode(task.tags)),
      triageStatus: Value(task.triageStatus.index),
      estimatedPomodoros: Value(task.estimatedPomodoros),
      createdAtUtcMillis: task.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAtUtcMillis: task.updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  domain.Task _toDomain(TaskRow row) {
    return domain.Task(
      id: row.id,
      title: domain.TaskTitle(row.title),
      description: row.description,
      status: domain.TaskStatus.values[row.status],
      priority: domain.TaskPriority.values[row.priority],
      dueAt: row.dueAtUtcMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              row.dueAtUtcMillis!,
              isUtc: true,
            ).toLocal(),
      tags: _decodeTags(row.tagsJson),
      triageStatus: _decodeTriageStatus(row.triageStatus),
      estimatedPomodoros: row.estimatedPomodoros,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtUtcMillis,
        isUtc: true,
      ).toLocal(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtUtcMillis,
        isUtc: true,
      ).toLocal(),
    );
  }

  domain.TriageStatus _decodeTriageStatus(int value) {
    if (value < 0 || value >= domain.TriageStatus.values.length) {
      return domain.TriageStatus.scheduledLater;
    }
    return domain.TriageStatus.values[value];
  }

  List<String> _decodeTags(String tagsJson) {
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return const [];
  }
}

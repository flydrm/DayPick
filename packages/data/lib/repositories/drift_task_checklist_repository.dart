import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftTaskChecklistRepository implements domain.TaskChecklistRepository {
  DriftTaskChecklistRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<domain.TaskChecklistItem>> watchByTaskId(String taskId) {
    final query =
        (_db.select(_db.taskCheckItems)..where((t) => t.taskId.equals(taskId)))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc),
          ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<void> upsertItem(domain.TaskChecklistItem item) async {
    await _db
        .into(_db.taskCheckItems)
        .insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await (_db.delete(
      _db.taskCheckItems,
    )..where((t) => t.id.equals(itemId))).go();
  }

  TaskCheckItemsCompanion _toCompanion(domain.TaskChecklistItem item) {
    return TaskCheckItemsCompanion.insert(
      id: item.id,
      taskId: item.taskId,
      title: item.title.value,
      isDone: Value(item.isDone),
      orderIndex: item.orderIndex,
      createdAtUtcMillis: item.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAtUtcMillis: item.updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  domain.TaskChecklistItem _toDomain(TaskCheckItemRow row) {
    return domain.TaskChecklistItem(
      id: row.id,
      taskId: row.taskId,
      title: domain.ChecklistItemTitle(row.title),
      isDone: row.isDone,
      orderIndex: row.orderIndex,
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
}

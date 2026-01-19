import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import '../db/app_database.dart';

class DriftTodayPlanRepository implements domain.TodayPlanRepository {
  DriftTodayPlanRepository(this._db);

  final AppDatabase _db;
  static const _plannedToday = 1;
  static const _scheduledLater = 2;
  static const _segmentToday = 0;
  static const _segmentEvening = 1;

  @override
  Stream<List<String>> watchTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) {
    final dayKey = _dayKey(day);
    final segment = _segmentFor(section);
    final query =
        (_db.select(_db.todayPlanItems)
            ..where((t) => t.dayKey.equals(dayKey))
            ..where((t) => t.segment.equals(segment)))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc),
          ]);
    return query.watch().map((rows) => [for (final r in rows) r.taskId]);
  }

  @override
  Future<List<String>> getTaskIdsForDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final dayKey = _dayKey(day);
    final segment = _segmentFor(section);
    final query =
        (_db.select(_db.todayPlanItems)
            ..where((t) => t.dayKey.equals(dayKey))
            ..where((t) => t.segment.equals(segment)))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.orderIndex, mode: OrderingMode.asc),
          ]);
    final rows = await query.get();
    return [for (final r in rows) r.taskId];
  }

  @override
  Future<void> addTask({
    required DateTime day,
    required String taskId,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final dayKey = _dayKey(day);
    final segment = _segmentFor(section);
    final existing =
        await (_db.select(_db.todayPlanItems)
              ..where((t) => t.dayKey.equals(dayKey) & t.taskId.equals(taskId)))
            .getSingleOrNull();
    if (existing != null) {
      if (existing.segment != segment) {
        await moveTaskToSection(day: day, taskId: taskId, section: section);
      }
      return;
    }

    final maxIndex =
        await (_db.selectOnly(_db.todayPlanItems)
              ..addColumns([_db.todayPlanItems.orderIndex.max()])
              ..where(
                _db.todayPlanItems.dayKey.equals(dayKey) &
                    _db.todayPlanItems.segment.equals(segment),
              ))
            .map((row) => row.read(_db.todayPlanItems.orderIndex.max()))
            .getSingleOrNull();
    final nextIndex = (maxIndex ?? -1) + 1;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db
        .into(_db.todayPlanItems)
        .insert(
          TodayPlanItemsCompanion.insert(
            dayKey: dayKey,
            taskId: taskId,
            segment: Value(segment),
            orderIndex: nextIndex,
            createdAtUtcMillis: now,
            updatedAtUtcMillis: now,
          ),
          mode: InsertMode.insert,
        );
    await _markTasksPlannedToday([taskId], nowUtcMillis: now);
  }

  @override
  Future<void> removeTask({
    required DateTime day,
    required String taskId,
  }) async {
    final dayKey = _dayKey(day);
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todayPlanItems)..where(
                (t) => t.dayKey.equals(dayKey) & t.taskId.equals(taskId),
              ))
              .getSingleOrNull();
      if (existing == null) return;

      await (_db.delete(
        _db.todayPlanItems,
      )..where((t) => t.dayKey.equals(dayKey) & t.taskId.equals(taskId))).go();
      await _compactOrder(dayKey, existing.segment);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _unmarkTasksPlannedTodayIfNoLongerPlanned([
        taskId,
      ], nowUtcMillis: now);
    });
  }

  @override
  Future<void> replaceTasks({
    required DateTime day,
    required List<String> taskIds,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final dayKey = _dayKey(day);
    final segment = _segmentFor(section);
    final unique = <String>[];
    for (final id in taskIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      if (!unique.contains(trimmed)) unique.add(trimmed);
    }

    await _db.transaction(() async {
      final existingRows =
          await (_db.select(_db.todayPlanItems)
                ..where((t) => t.dayKey.equals(dayKey))
                ..where((t) => t.segment.equals(segment)))
              .get();
      final existingIds = [for (final r in existingRows) r.taskId];
      final removedIds = [
        for (final id in existingIds)
          if (!unique.contains(id)) id,
      ];

      await (_db.delete(_db.todayPlanItems)
            ..where((t) => t.dayKey.equals(dayKey))
            ..where((t) => t.segment.equals(segment)))
          .go();

      if (unique.isNotEmpty) {
        await (_db.delete(
          _db.todayPlanItems,
        )..where((t) => t.dayKey.equals(dayKey) & t.taskId.isIn(unique))).go();
        await _compactOrder(dayKey, _segmentToday);
        await _compactOrder(dayKey, _segmentEvening);
      }

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      if (unique.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.todayPlanItems, [
            for (var i = 0; i < unique.length; i++)
              TodayPlanItemsCompanion.insert(
                dayKey: dayKey,
                taskId: unique[i],
                segment: Value(segment),
                orderIndex: i,
                createdAtUtcMillis: now,
                updatedAtUtcMillis: now,
              ),
          ], mode: InsertMode.insert);
        });
        await _markTasksPlannedToday(unique, nowUtcMillis: now);
      }

      await _unmarkTasksPlannedTodayIfNoLongerPlanned(
        removedIds,
        nowUtcMillis: now,
      );
    });
  }

  @override
  Future<void> clearDay({
    required DateTime day,
    domain.TodayPlanSection section = domain.TodayPlanSection.today,
  }) async {
    final dayKey = _dayKey(day);
    final segment = _segmentFor(section);
    await _db.transaction(() async {
      final existingRows =
          await (_db.select(_db.todayPlanItems)
                ..where((t) => t.dayKey.equals(dayKey))
                ..where((t) => t.segment.equals(segment)))
              .get();
      final existingIds = [for (final r in existingRows) r.taskId];

      await (_db.delete(_db.todayPlanItems)
            ..where((t) => t.dayKey.equals(dayKey))
            ..where((t) => t.segment.equals(segment)))
          .go();
      await _compactOrder(dayKey, segment);

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _unmarkTasksPlannedTodayIfNoLongerPlanned(
        existingIds,
        nowUtcMillis: now,
      );
    });
  }

  @override
  Future<void> clearAll({required DateTime day}) async {
    final dayKey = _dayKey(day);
    await _db.transaction(() async {
      final existingRows = await (_db.select(
        _db.todayPlanItems,
      )..where((t) => t.dayKey.equals(dayKey))).get();
      final existingIds = [for (final r in existingRows) r.taskId];

      await (_db.delete(
        _db.todayPlanItems,
      )..where((t) => t.dayKey.equals(dayKey))).go();

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _unmarkTasksPlannedTodayIfNoLongerPlanned(
        existingIds,
        nowUtcMillis: now,
      );
    });
  }

  @override
  Future<void> moveTaskToSection({
    required DateTime day,
    required String taskId,
    required domain.TodayPlanSection section,
    int? toIndex,
  }) async {
    final dayKey = _dayKey(day);
    final toSegment = _segmentFor(section);
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.todayPlanItems)..where(
                (t) => t.dayKey.equals(dayKey) & t.taskId.equals(taskId),
              ))
              .getSingleOrNull();
      if (existing == null) return;

      final fromSegment = existing.segment;

      if (fromSegment == toSegment) {
        if (toIndex == null) return;
        final rows =
            await (_db.select(_db.todayPlanItems)
                  ..where((t) => t.dayKey.equals(dayKey))
                  ..where((t) => t.segment.equals(fromSegment))
                  ..orderBy([
                    (t) => OrderingTerm(
                      expression: t.orderIndex,
                      mode: OrderingMode.asc,
                    ),
                  ]))
                .get();
        final ids = [for (final r in rows) r.taskId];
        if (!ids.contains(taskId)) return;

        final safeIndex = toIndex.clamp(0, ids.length - 1);
        ids.remove(taskId);
        ids.insert(safeIndex, taskId);

        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await _db.batch((batch) {
          for (var i = 0; i < ids.length; i++) {
            batch.update(
              _db.todayPlanItems,
              TodayPlanItemsCompanion(
                orderIndex: Value(i),
                updatedAtUtcMillis: Value(now),
              ),
              where: (t) => t.dayKey.equals(dayKey) & t.taskId.equals(ids[i]),
            );
          }
        });
        return;
      }

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      final fromRows =
          await (_db.select(_db.todayPlanItems)
                ..where((t) => t.dayKey.equals(dayKey))
                ..where((t) => t.segment.equals(fromSegment))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.orderIndex,
                    mode: OrderingMode.asc,
                  ),
                ]))
              .get();
      final toRows =
          await (_db.select(_db.todayPlanItems)
                ..where((t) => t.dayKey.equals(dayKey))
                ..where((t) => t.segment.equals(toSegment))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.orderIndex,
                    mode: OrderingMode.asc,
                  ),
                ]))
              .get();

      final fromIds = [for (final r in fromRows) r.taskId]..remove(taskId);
      final toIds = [for (final r in toRows) r.taskId]..remove(taskId);
      final insertIndex = toIndex == null
          ? toIds.length
          : toIndex.clamp(0, toIds.length);
      toIds.insert(insertIndex, taskId);

      await _db.batch((batch) {
        for (var i = 0; i < fromIds.length; i++) {
          batch.update(
            _db.todayPlanItems,
            TodayPlanItemsCompanion(
              segment: Value(fromSegment),
              orderIndex: Value(i),
              updatedAtUtcMillis: Value(now),
            ),
            where: (t) => t.dayKey.equals(dayKey) & t.taskId.equals(fromIds[i]),
          );
        }
        for (var i = 0; i < toIds.length; i++) {
          batch.update(
            _db.todayPlanItems,
            TodayPlanItemsCompanion(
              segment: Value(toSegment),
              orderIndex: Value(i),
              updatedAtUtcMillis: Value(now),
            ),
            where: (t) => t.dayKey.equals(dayKey) & t.taskId.equals(toIds[i]),
          );
        }
      });
    });
  }

  int _segmentFor(domain.TodayPlanSection section) {
    return switch (section) {
      domain.TodayPlanSection.today => _segmentToday,
      domain.TodayPlanSection.evening => _segmentEvening,
    };
  }

  Future<void> _compactOrder(String dayKey, int segment) async {
    final rows =
        await (_db.select(_db.todayPlanItems)
              ..where((t) => t.dayKey.equals(dayKey))
              ..where((t) => t.segment.equals(segment)))
            .get();
    if (rows.isEmpty) return;

    rows.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _db.batch((batch) {
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        batch.update(
          _db.todayPlanItems,
          TodayPlanItemsCompanion(
            orderIndex: Value(i),
            updatedAtUtcMillis: Value(now),
          ),
          where: (t) => t.dayKey.equals(dayKey) & t.taskId.equals(row.taskId),
        );
      }
    });
  }

  Future<void> _markTasksPlannedToday(
    List<String> taskIds, {
    required int nowUtcMillis,
  }) async {
    if (taskIds.isEmpty) return;
    await (_db.update(_db.tasks)..where((t) => t.id.isIn(taskIds))).write(
      TasksCompanion(
        triageStatus: const Value(_plannedToday),
        updatedAtUtcMillis: Value(nowUtcMillis),
      ),
    );
  }

  Future<void> _unmarkTasksPlannedTodayIfNoLongerPlanned(
    List<String> taskIds, {
    required int nowUtcMillis,
  }) async {
    if (taskIds.isEmpty) return;

    final rows =
        await (_db.selectOnly(_db.todayPlanItems)
              ..addColumns([_db.todayPlanItems.taskId])
              ..where(_db.todayPlanItems.taskId.isIn(taskIds)))
            .get();
    final stillPlanned = {
      for (final row in rows) row.read(_db.todayPlanItems.taskId),
    };
    final toUnmark = [
      for (final id in taskIds)
        if (!stillPlanned.contains(id)) id,
    ];
    if (toUnmark.isEmpty) return;

    await (_db.update(_db.tasks)..where(
          (t) => t.id.isIn(toUnmark) & t.triageStatus.equals(_plannedToday),
        ))
        .write(
          TasksCompanion(
            triageStatus: const Value(_scheduledLater),
            updatedAtUtcMillis: Value(nowUtcMillis),
          ),
        );
  }

  String _dayKey(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

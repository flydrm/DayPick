import 'dart:ffi';

import 'package:data/data.dart' as data;
import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

domain.Task _task({required String id, required DateTime now}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(id),
    status: domain.TaskStatus.todo,
    priority: domain.TaskPriority.medium,
    tags: const [],
    estimatedPomodoros: 1,
    triageStatus: domain.TriageStatus.inbox,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );

  test(
    'today plan removal unmarks triageStatus when no longer planned',
    () async {
      final db = data.AppDatabase.inMemoryForTesting();
      addTearDown(() async => db.close());

      final tasksRepo = data.DriftTaskRepository(db);
      final planRepo = data.DriftTodayPlanRepository(db);

      final now = DateTime(2026, 1, 10, 12);
      final task = _task(id: 't-1', now: now);
      await tasksRepo.upsertTask(task);

      final day = DateTime(2026, 1, 10);
      await planRepo.addTask(day: day, taskId: task.id);
      expect(
        (await tasksRepo.getTaskById(task.id))!.triageStatus,
        domain.TriageStatus.plannedToday,
      );

      await planRepo.removeTask(day: day, taskId: task.id);
      expect(
        (await tasksRepo.getTaskById(task.id))!.triageStatus,
        domain.TriageStatus.scheduledLater,
      );
    },
  );

  test(
    'today plan keeps plannedToday if task still planned on other day',
    () async {
      final db = data.AppDatabase.inMemoryForTesting();
      addTearDown(() async => db.close());

      final tasksRepo = data.DriftTaskRepository(db);
      final planRepo = data.DriftTodayPlanRepository(db);

      final now = DateTime(2026, 1, 10, 12);
      final task = _task(id: 't-1', now: now);
      await tasksRepo.upsertTask(task);

      final day1 = DateTime(2026, 1, 10);
      final day2 = DateTime(2026, 1, 11);
      await planRepo.addTask(day: day1, taskId: task.id);
      await planRepo.addTask(day: day2, taskId: task.id);

      await planRepo.removeTask(day: day1, taskId: task.id);
      expect(
        (await tasksRepo.getTaskById(task.id))!.triageStatus,
        domain.TriageStatus.plannedToday,
      );

      await planRepo.removeTask(day: day2, taskId: task.id);
      expect(
        (await tasksRepo.getTaskById(task.id))!.triageStatus,
        domain.TriageStatus.scheduledLater,
      );
    },
  );

  test('today plan replaceTasks unmarks removed tasks', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final tasksRepo = data.DriftTaskRepository(db);
    final planRepo = data.DriftTodayPlanRepository(db);

    final now = DateTime(2026, 1, 10, 12);
    final t1 = _task(id: 't-1', now: now);
    final t2 = _task(id: 't-2', now: now);
    await tasksRepo.upsertTask(t1);
    await tasksRepo.upsertTask(t2);

    final day = DateTime(2026, 1, 10);
    await planRepo.replaceTasks(day: day, taskIds: [t1.id, t2.id]);
    expect(
      (await tasksRepo.getTaskById(t1.id))!.triageStatus,
      domain.TriageStatus.plannedToday,
    );
    expect(
      (await tasksRepo.getTaskById(t2.id))!.triageStatus,
      domain.TriageStatus.plannedToday,
    );

    await planRepo.replaceTasks(day: day, taskIds: [t2.id]);
    expect(
      (await tasksRepo.getTaskById(t1.id))!.triageStatus,
      domain.TriageStatus.scheduledLater,
    );
    expect(
      (await tasksRepo.getTaskById(t2.id))!.triageStatus,
      domain.TriageStatus.plannedToday,
    );
  });

  test('today plan clearDay unmarks tasks', () async {
    final db = data.AppDatabase.inMemoryForTesting();
    addTearDown(() async => db.close());

    final tasksRepo = data.DriftTaskRepository(db);
    final planRepo = data.DriftTodayPlanRepository(db);

    final now = DateTime(2026, 1, 10, 12);
    final task = _task(id: 't-1', now: now);
    await tasksRepo.upsertTask(task);

    final day = DateTime(2026, 1, 10);
    await planRepo.addTask(day: day, taskId: task.id);
    expect(
      (await tasksRepo.getTaskById(task.id))!.triageStatus,
      domain.TriageStatus.plannedToday,
    );

    await planRepo.clearDay(day: day);
    expect(
      (await tasksRepo.getTaskById(task.id))!.triageStatus,
      domain.TriageStatus.scheduledLater,
    );
  });
}

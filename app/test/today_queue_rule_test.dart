import 'package:domain/domain.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

domain.Task _task({
  required String id,
  required domain.TaskPriority priority,
  required DateTime now,
  domain.TaskStatus status = domain.TaskStatus.todo,
  DateTime? dueAt,
  domain.TriageStatus triageStatus = domain.TriageStatus.scheduledLater,
}) {
  return domain.Task(
    id: id,
    title: domain.TaskTitle(id),
    status: status,
    priority: priority,
    dueAt: dueAt,
    tags: const [],
    estimatedPomodoros: 1,
    triageStatus: triageStatus,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('TodayQueueRule prioritizes overdue/dueToday then fills by sort', () {
    final now = DateTime(2026, 1, 10, 12);
    final startOfToday = DateTime(now.year, now.month, now.day);

    final tasks = [
      _task(
        id: 'A',
        priority: domain.TaskPriority.medium,
        now: now,
        dueAt: startOfToday.add(const Duration(days: 5)),
      ),
      _task(
        id: 'B',
        priority: domain.TaskPriority.low,
        now: now,
        dueAt: startOfToday.subtract(const Duration(days: 1, hours: 1)),
      ),
      _task(
        id: 'C',
        priority: domain.TaskPriority.high,
        now: now,
        dueAt: startOfToday.add(const Duration(hours: 23, minutes: 59)),
      ),
      _task(id: 'D', priority: domain.TaskPriority.high, now: now),
    ];

    final result = const domain.TodayQueueRule(maxItems: 5)(tasks, now);
    expect(result.nextStep?.id, 'B');
    expect(result.todayQueue.map((t) => t.id).toList(), ['B', 'C', 'D', 'A']);
  });

  test('TodayQueueRule excludes done tasks and respects maxItems', () {
    final now = DateTime(2026, 1, 10, 12);
    final startOfToday = DateTime(now.year, now.month, now.day);

    final tasks = [
      _task(
        id: 'done',
        priority: domain.TaskPriority.high,
        now: now,
        status: domain.TaskStatus.done,
        dueAt: startOfToday,
      ),
      _task(
        id: 'overdue',
        priority: domain.TaskPriority.low,
        now: now,
        dueAt: startOfToday.subtract(const Duration(days: 1)),
      ),
      _task(
        id: 'today',
        priority: domain.TaskPriority.low,
        now: now,
        dueAt: startOfToday,
      ),
      _task(id: 'p1', priority: domain.TaskPriority.high, now: now),
      _task(id: 'p2', priority: domain.TaskPriority.medium, now: now),
    ];

    final result = const domain.TodayQueueRule(maxItems: 3)(tasks, now);
    expect(result.todayQueue.map((t) => t.id).toList(), [
      'overdue',
      'today',
      'p1',
    ]);
  });

  test('TodayQueueRule excludes inbox and archived tasks', () {
    final now = DateTime(2026, 1, 10, 12);
    final startOfToday = DateTime(now.year, now.month, now.day);

    final tasks = [
      _task(
        id: 'inboxOverdue',
        priority: domain.TaskPriority.high,
        now: now,
        triageStatus: domain.TriageStatus.inbox,
        dueAt: startOfToday.subtract(const Duration(days: 1)),
      ),
      _task(
        id: 'archivedToday',
        priority: domain.TaskPriority.high,
        now: now,
        triageStatus: domain.TriageStatus.archived,
        dueAt: startOfToday,
      ),
      _task(
        id: 'overdue',
        priority: domain.TaskPriority.low,
        now: now,
        dueAt: startOfToday.subtract(const Duration(days: 1)),
      ),
      _task(id: 'high', priority: domain.TaskPriority.high, now: now),
    ];

    final result = const domain.TodayQueueRule(maxItems: 10)(tasks, now);
    expect(result.nextStep?.id, 'overdue');
    expect(result.todayQueue.map((t) => t.id).toList(), ['overdue', 'high']);
  });
}

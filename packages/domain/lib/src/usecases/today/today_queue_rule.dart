import '../../entities/task.dart';
import '../../entities/triage_status.dart';
import '../tasks/task_list_query.dart';

class TodayQueueResult {
  const TodayQueueResult({required this.nextStep, required this.todayQueue});

  final Task? nextStep;
  final List<Task> todayQueue;
}

class TodayQueueRule {
  const TodayQueueRule({this.maxItems = 5});

  final int maxItems;

  TodayQueueResult call(List<Task> tasks, DateTime now) {
    final openTasks = tasks
        .where(
          (t) =>
              t.status == TaskStatus.todo || t.status == TaskStatus.inProgress,
        )
        .where(
          (t) =>
              t.triageStatus != TriageStatus.inbox &&
              t.triageStatus != TriageStatus.archived,
        )
        .toList();
    final startOfToday = DateTime(now.year, now.month, now.day);

    bool isDueToday(Task task) {
      final dueAt = task.dueAt;
      if (dueAt == null) return false;
      final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
      return dueDate == startOfToday;
    }

    bool isOverdue(Task task) {
      final dueAt = task.dueAt;
      if (dueAt == null) return false;
      final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
      return dueDate.isBefore(startOfToday);
    }

    final prioritized = <Task>[
      ...openTasks.where(isOverdue),
      ...openTasks.where(isDueToday),
    ];

    final seen = <String>{};
    final queue = <Task>[];

    void addIfNew(Task task) {
      if (queue.length >= maxItems) return;
      if (seen.add(task.id)) {
        queue.add(task);
      }
    }

    for (final task in prioritized) {
      addIfNew(task);
    }

    if (queue.length < maxItems) {
      final remaining = openTasks.where((t) => !seen.contains(t.id)).toList();
      remaining.sort(defaultCompare);
      for (final task in remaining) {
        addIfNew(task);
      }
    }

    final nextStep = queue.isEmpty ? null : queue.first;
    return TodayQueueResult(nextStep: nextStep, todayQueue: queue);
  }
}

import '../../entities/task.dart';
import '../../entities/triage_status.dart';

enum TaskStatusFilter {
  /// 默认：仅未完成（todo + inProgress）
  open,

  /// 仅待办
  todo,

  /// 仅进行中
  inProgress,

  /// 仅已完成
  done,

  /// 全部状态
  all,
}

class TaskListQuery {
  const TaskListQuery({
    this.statusFilter = TaskStatusFilter.open,
    this.priority,
    this.tag,
    this.dueToday = false,
    this.overdue = false,
    this.includeInbox = false,
    this.includeArchived = false,
  });

  final TaskStatusFilter statusFilter;
  final TaskPriority? priority;
  final String? tag;
  final bool dueToday;
  final bool overdue;
  final bool includeInbox;
  final bool includeArchived;

  List<Task> apply(List<Task> tasks, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final normalizedTag = tag?.trim();

    bool predicate(Task task) {
      if (!_matchesStatus(task.status)) return false;
      if (!includeInbox && task.triageStatus == TriageStatus.inbox)
        return false;
      if (!includeArchived && task.triageStatus == TriageStatus.archived)
        return false;
      if (priority != null && task.priority != priority) return false;
      if (normalizedTag != null &&
          normalizedTag.isNotEmpty &&
          !task.tags.contains(normalizedTag))
        return false;

      if (dueToday && !_isDueToday(task.dueAt, startOfToday)) return false;
      if (overdue && !_isOverdue(task.dueAt, startOfToday)) return false;
      return true;
    }

    final filtered = tasks.where(predicate).toList();
    filtered.sort((a, b) => defaultCompare(a, b));
    return filtered;
  }

  bool _matchesStatus(TaskStatus status) {
    return switch (statusFilter) {
      TaskStatusFilter.open =>
        status == TaskStatus.todo || status == TaskStatus.inProgress,
      TaskStatusFilter.todo => status == TaskStatus.todo,
      TaskStatusFilter.inProgress => status == TaskStatus.inProgress,
      TaskStatusFilter.done => status == TaskStatus.done,
      TaskStatusFilter.all => true,
    };
  }

  bool _isDueToday(DateTime? dueAt, DateTime startOfToday) {
    if (dueAt == null) return false;
    final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return dueDate == startOfToday;
  }

  bool _isOverdue(DateTime? dueAt, DateTime startOfToday) {
    if (dueAt == null) return false;
    final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return dueDate.isBefore(startOfToday);
  }
}

int defaultCompare(Task a, Task b) {
  final priorityDiff = b.priority.index.compareTo(a.priority.index);
  if (priorityDiff != 0) return priorityDiff;

  final dueA = a.dueAt;
  final dueB = b.dueAt;
  if (dueA == null && dueB != null) return 1;
  if (dueA != null && dueB == null) return -1;
  if (dueA != null && dueB != null) {
    final dueDiff = dueA.compareTo(dueB);
    if (dueDiff != 0) return dueDiff;
  }

  return b.createdAt.compareTo(a.createdAt);
}

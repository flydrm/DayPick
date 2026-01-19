import '../value_objects/task_title.dart';
import 'triage_status.dart';

enum TaskStatus { todo, inProgress, done }

enum TaskPriority { low, medium, high }

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.tags,
    required this.estimatedPomodoros,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueAt,
    this.triageStatus = TriageStatus.scheduledLater,
  });

  final String id;
  final TaskTitle title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueAt;
  final List<String> tags;
  final int? estimatedPomodoros;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TriageStatus triageStatus;

  Task copyWith({
    TaskTitle? title,
    Object? description = _unset,
    TaskStatus? status,
    TaskPriority? priority,
    Object? dueAt = _unset,
    List<String>? tags,
    int? estimatedPomodoros,
    DateTime? updatedAt,
    TriageStatus? triageStatus,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as DateTime?,
      tags: tags ?? this.tags,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      triageStatus: triageStatus ?? this.triageStatus,
    );
  }
}

import '../../entities/task.dart';
import '../../entities/triage_status.dart';
import '../../repositories/task_repository.dart';
import '../../value_objects/task_title.dart';

typedef TaskIdGenerator = String Function();
typedef _Now = DateTime Function();

class CreateTaskUseCase {
  CreateTaskUseCase({
    required TaskRepository repository,
    required TaskIdGenerator generateId,
    _Now now = DateTime.now,
  }) : _repository = repository,
       _generateId = generateId,
       _now = now;

  final TaskRepository _repository;
  final TaskIdGenerator _generateId;
  final _Now _now;

  Future<Task> call({
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueAt,
    List<String> tags = const [],
    int? estimatedPomodoros,
    TriageStatus triageStatus = TriageStatus.scheduledLater,
  }) async {
    final now = _now();
    final task = Task(
      id: _generateId(),
      title: TaskTitle(title),
      description: _normalizeOptionalText(description),
      status: TaskStatus.todo,
      priority: priority,
      dueAt: dueAt,
      tags: tags,
      estimatedPomodoros: estimatedPomodoros,
      createdAt: now,
      updatedAt: now,
      triageStatus: triageStatus,
    );
    await _repository.upsertTask(task);
    return task;
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

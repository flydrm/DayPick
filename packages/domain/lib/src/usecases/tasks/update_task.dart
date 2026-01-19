import '../../entities/task.dart';
import '../../entities/triage_status.dart';
import '../../repositories/task_repository.dart';
import '../../value_objects/task_title.dart';

typedef _Now = DateTime Function();

class UpdateTaskUseCase {
  UpdateTaskUseCase({
    required TaskRepository repository,
    _Now now = DateTime.now,
  }) : _repository = repository,
       _now = now;

  final TaskRepository _repository;
  final _Now _now;

  Future<Task> call({
    required Task task,
    required String title,
    String? description,
    required TaskStatus status,
    required TaskPriority priority,
    DateTime? dueAt,
    required List<String> tags,
    int? estimatedPomodoros,
    TriageStatus? triageStatus,
  }) async {
    final updated = Task(
      id: task.id,
      title: TaskTitle(title),
      description: _normalizeOptionalText(description),
      status: status,
      priority: priority,
      dueAt: dueAt,
      tags: tags,
      estimatedPomodoros: estimatedPomodoros,
      createdAt: task.createdAt,
      updatedAt: _now(),
      triageStatus: triageStatus ?? task.triageStatus,
    );
    await _repository.upsertTask(updated);
    return updated;
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

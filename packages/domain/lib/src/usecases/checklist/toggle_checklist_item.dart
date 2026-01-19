import '../../entities/task_checklist_item.dart';
import '../../repositories/task_checklist_repository.dart';

typedef _Now = DateTime Function();

class ToggleChecklistItemUseCase {
  ToggleChecklistItemUseCase({
    required TaskChecklistRepository repository,
    _Now now = DateTime.now,
  }) : _repository = repository,
       _now = now;

  final TaskChecklistRepository _repository;
  final _Now _now;

  Future<TaskChecklistItem> call({
    required TaskChecklistItem item,
    required bool isDone,
  }) async {
    final updated = item.copyWith(isDone: isDone, updatedAt: _now());
    await _repository.upsertItem(updated);
    return updated;
  }
}

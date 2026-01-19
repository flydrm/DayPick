import '../../entities/task_checklist_item.dart';
import '../../repositories/task_checklist_repository.dart';
import '../../value_objects/checklist_item_title.dart';

typedef ChecklistItemIdGenerator = String Function();
typedef _Now = DateTime Function();

class CreateChecklistItemUseCase {
  CreateChecklistItemUseCase({
    required TaskChecklistRepository repository,
    required ChecklistItemIdGenerator generateId,
    _Now now = DateTime.now,
  }) : _repository = repository,
       _generateId = generateId,
       _now = now;

  final TaskChecklistRepository _repository;
  final ChecklistItemIdGenerator _generateId;
  final _Now _now;

  Future<TaskChecklistItem> call({
    required String taskId,
    required String title,
    required int orderIndex,
  }) async {
    final now = _now();
    final item = TaskChecklistItem(
      id: _generateId(),
      taskId: taskId,
      title: ChecklistItemTitle(title),
      isDone: false,
      orderIndex: orderIndex,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.upsertItem(item);
    return item;
  }
}

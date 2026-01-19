import 'package:domain/domain.dart' as domain;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

final tasksStreamProvider = StreamProvider<List<domain.Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchAllTasks();
});

final taskByIdProvider = StreamProvider.family<domain.Task?, String>((
  ref,
  taskId,
) {
  return ref.watch(taskRepositoryProvider).watchAllTasks().map((tasks) {
    for (final task in tasks) {
      if (task.id == taskId) return task;
    }
    return null;
  });
});

final taskChecklistItemsProvider =
    StreamProvider.family<List<domain.TaskChecklistItem>, String>((
      ref,
      taskId,
    ) {
      return ref.watch(taskChecklistRepositoryProvider).watchByTaskId(taskId);
    });

final taskListQueryProvider = StateProvider<domain.TaskListQuery>(
  (ref) => const domain.TaskListQuery(),
);

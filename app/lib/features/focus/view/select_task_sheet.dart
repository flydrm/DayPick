import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/kit/dp_spinner.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/view/task_edit_sheet.dart';
import '../../tasks/view/task_list_item.dart';

class SelectTaskSheet extends ConsumerWidget {
  const SelectTaskSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final tasksAsync = ref.watch(tasksStreamProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '选择任务',
                    style: shadTheme.textTheme.h3.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ShadButton.secondary(
                  size: ShadButtonSize.sm,
                  onPressed: () => _openCreateTask(context),
                  child: const Text('新增任务'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: tasksAsync.when(
                loading: () => const Center(child: DpSpinner()),
                error: (error, stack) => Center(child: Text('加载失败：$error')),
                data: (tasks) {
                  final openTasks = tasks
                      .where((t) => t.status != domain.TaskStatus.done)
                      .toList();
                  if (openTasks.isEmpty) {
                    return ShadCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '暂无未完成任务，请先新增一条任务',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    );
                  }
                  return ShadCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: openTasks.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 0, color: colorScheme.border),
                      itemBuilder: (context, index) {
                        final task = openTasks[index];
                        return TaskListItem(
                          task: task,
                          onTap: () => Navigator.of(context).pop(task.id),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateTask(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const TaskEditSheet(),
    );
  }
}

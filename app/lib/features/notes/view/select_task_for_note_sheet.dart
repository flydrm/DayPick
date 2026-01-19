import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../tasks/providers/task_providers.dart';
import '../../tasks/view/task_edit_sheet.dart';
import '../../tasks/view/task_list_item.dart';

class SelectTaskForNoteSheet extends ConsumerStatefulWidget {
  const SelectTaskForNoteSheet({super.key});

  @override
  ConsumerState<SelectTaskForNoteSheet> createState() =>
      _SelectTaskForNoteSheetState();
}

class _SelectTaskForNoteSheetState
    extends ConsumerState<SelectTaskForNoteSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showDone = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final tasksAsync = ref.watch(tasksStreamProvider);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择关联任务',
                      style: shadTheme.textTheme.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  ShadButton.secondary(
                    size: ShadButtonSize.sm,
                    onPressed: () => _openCreateTask(context),
                    child: const Text('新增任务'),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '关闭',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ShadCard(
                padding: const EdgeInsets.all(16),
                child: ShadInput(
                  controller: _searchController,
                  placeholder: Text(
                    '搜索任务（标题/描述）…',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: const Icon(Icons.search, size: 18),
                  trailing: _query.trim().isEmpty
                      ? null
                      : Tooltip(
                          message: '清除',
                          child: ShadIconButton.ghost(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                        ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 12),
              ShadCard(
                padding: const EdgeInsets.all(16),
                child: ShadSwitch(
                  value: _showDone,
                  onChanged: (v) => setState(() => _showDone = v),
                  label: const Text('显示已完成任务'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: tasksAsync.when(
                  loading: () =>
                      const Center(child: ShadProgress(minHeight: 8)),
                  error: (error, stack) => ShadAlert.destructive(
                    icon: const Icon(Icons.error_outline),
                    title: const Text('任务加载失败'),
                    description: Text('$error'),
                  ),
                  data: (tasks) {
                    if (tasks.isEmpty) {
                      return ShadCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '暂无任务，请先新增一条任务。',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      );
                    }

                    final keyword = _query.trim().toLowerCase();
                    final filtered = keyword.isEmpty
                        ? tasks
                        : tasks
                              .where((t) {
                                final hay = [
                                  t.title.value,
                                  t.description ?? '',
                                ].join('\n').toLowerCase();
                                return hay.contains(keyword);
                              })
                              .toList(growable: false);

                    final openTasks = filtered
                        .where((t) => t.status != domain.TaskStatus.done)
                        .toList(growable: false);
                    final doneTasks = filtered
                        .where((t) => t.status == domain.TaskStatus.done)
                        .toList(growable: false);

                    if (openTasks.isEmpty &&
                        (!_showDone || doneTasks.isEmpty)) {
                      return ShadCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '没有匹配的任务。',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      );
                    }

                    return ListView(
                      children: [
                        if (openTasks.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '未完成',
                              style: shadTheme.textTheme.small.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.foreground,
                              ),
                            ),
                          ),
                          ShadCard(
                            padding: EdgeInsets.zero,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: openTasks.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 0, color: colorScheme.border),
                              itemBuilder: (context, index) {
                                final task = openTasks[index];
                                return TaskListItem(
                                  task: task,
                                  onTap: () =>
                                      Navigator.of(context).pop(task.id),
                                );
                              },
                            ),
                          ),
                        ],
                        if (_showDone && doneTasks.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '已完成',
                              style: shadTheme.textTheme.small.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.foreground,
                              ),
                            ),
                          ),
                          ShadCard(
                            padding: EdgeInsets.zero,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: doneTasks.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 0, color: colorScheme.border),
                              itemBuilder: (context, index) {
                                final task = doneTasks[index];
                                return TaskListItem(
                                  task: task,
                                  onTap: () =>
                                      Navigator.of(context).pop(task.id),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
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

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/kit/dp_section_card.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../today/providers/today_plan_providers.dart';
import '../providers/task_providers.dart';
import 'task_filters_sheet.dart';
import 'task_list_item.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _selectionMode = false;
  final Set<String> _selectedTaskIds = <String>{};

  int get _selectedCount => _selectedTaskIds.length;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSelected(domain.Task task) => _selectedTaskIds.contains(task.id);

  void _toggleSelected(domain.Task task) {
    setState(() {
      if (_selectedTaskIds.contains(task.id)) {
        _selectedTaskIds.remove(task.id);
      } else {
        _selectedTaskIds.add(task.id);
      }
      if (_selectedCount == 0) _selectionMode = false;
    });
  }

  void _startSelection(domain.Task task) {
    setState(() {
      _selectionMode = true;
      _selectedTaskIds.add(task.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(taskListQueryProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final todayPlanIdsAsync = ref.watch(todayPlanTaskIdsProvider);
    final todayPlanIds = todayPlanIdsAsync.valueOrNull ?? const <String>[];
    final appearanceAsync = ref.watch(appearanceConfigProvider);
    final dense = appearanceAsync.maybeWhen(
      data: (c) => c.density == domain.AppDensity.compact,
      orElse: () => false,
    );
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final allTasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final taskById = {for (final t in allTasks) t.id: t};
    final keyword = _searchQuery.trim().toLowerCase();
    final filtered = query.apply(allTasks, DateTime.now());
    final visible = keyword.isEmpty
        ? filtered
        : filtered
              .where((task) {
                final hay = [
                  task.title.value,
                  task.description ?? '',
                ].join('\n').toLowerCase();
                return hay.contains(keyword);
              })
              .toList(growable: false);

    final selectedTasks = <domain.Task>[
      for (final id in _selectedTaskIds)
        if (taskById[id] != null) taskById[id]!,
    ];
    final allSelected = visible.isNotEmpty && visible.every(_isSelected);

    return AppPageScaffold(
      title: _selectionMode ? '已选 $_selectedCount' : '任务',
      showSettingsAction: !_selectionMode,
      showCreateAction: !_selectionMode,
      actions: [
        if (_selectionMode) ...[
          Tooltip(
            message: allSelected ? '取消全选' : '全选',
            child: ShadIconButton.ghost(
              icon: Icon(
                allSelected ? Icons.remove_done : Icons.done_all,
                size: 20,
              ),
              onPressed: visible.isEmpty
                  ? null
                  : () {
                      setState(() {
                        if (allSelected) {
                          _selectionMode = false;
                          _selectedTaskIds.clear();
                          return;
                        }
                        _selectionMode = true;
                        _selectedTaskIds
                          ..clear()
                          ..addAll(visible.map((t) => t.id));
                      });
                    },
            ),
          ),
          Tooltip(
            message: '退出选择',
            child: ShadIconButton.ghost(
              icon: const Icon(Icons.close, size: 20),
              onPressed: _exitSelectionMode,
            ),
          ),
        ] else ...[
          Tooltip(
            message: '筛选',
            child: ShadIconButton.ghost(
              icon: const Icon(Icons.filter_list, size: 20),
              onPressed: () => _openFilters(context, query),
            ),
          ),
        ],
      ],
      body: Stack(
        children: [
          Column(
            children: [
              if (!_selectionMode) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DpSpacing.lg,
                    DpSpacing.lg,
                    DpSpacing.lg,
                    DpSpacing.sm,
                  ),
                  child: DpSectionCard(
                    title: '搜索任务',
                    child: ShadInput(
                      controller: _searchController,
                      placeholder: Text(
                        '搜索：标题/描述…',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      leading: const Icon(Icons.search, size: 18),
                      trailing: _searchQuery.trim().isEmpty
                          ? null
                          : Tooltip(
                              message: '清除搜索',
                              child: ShadIconButton.ghost(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              ),
                            ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ),
                _ActiveFiltersBar(
                  query: query,
                  onClear: () =>
                      ref.read(taskListQueryProvider.notifier).state =
                          const domain.TaskListQuery(),
                ),
                Divider(height: 0, color: colorScheme.border),
              ],
              Expanded(
                child: tasksAsync.when(
                  loading: () => const Center(child: DpSpinner()),
                  error: (error, stack) => Padding(
                    padding: DpInsets.page,
                    child: DpInlineNotice(
                      variant: DpInlineNoticeVariant.destructive,
                      title: '加载失败',
                      description: '$error',
                      icon: const Icon(Icons.error_outline),
                    ),
                  ),
                  data: (tasks) {
                    if (visible.isEmpty) {
                      if (tasks.isEmpty) {
                        return const Padding(
                          padding: DpInsets.page,
                          child: DpEmptyState(
                            icon: Icons.checklist_outlined,
                            title: '暂无任务',
                            description: '点右上角「＋」来创建第一条。',
                          ),
                        );
                      }
                      final canClearSearch = _searchQuery.trim().isNotEmpty;
                      return Padding(
                        padding: DpInsets.page,
                        child: DpEmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: '没有匹配的任务',
                          description: canClearSearch
                              ? '试试清除搜索或调整筛选。'
                              : '试试调整筛选范围。',
                          actionLabel: canClearSearch ? '清除搜索' : '清除筛选',
                          onAction: () {
                            if (canClearSearch) {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                              return;
                            }
                            ref.read(taskListQueryProvider.notifier).state =
                                const domain.TaskListQuery();
                          },
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.only(bottom: _selectionMode ? 72 : 0),
                      itemCount: visible.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 0, color: colorScheme.border),
                      itemBuilder: (context, index) {
                        final task = visible[index];
                        final inToday = todayPlanIds.contains(task.id);

                        return Dismissible(
                          key: ValueKey('task_${task.id}'),
                          direction: _selectionMode
                              ? DismissDirection.none
                              : DismissDirection.horizontal,
                          background: _SwipeActionBackground(
                            alignment: Alignment.centerLeft,
                            background: colorScheme.primary,
                            foreground: colorScheme.primaryForeground,
                            icon: task.status == domain.TaskStatus.done
                                ? Icons.undo
                                : Icons.check,
                            label: task.status == domain.TaskStatus.done
                                ? '撤销完成'
                                : '完成',
                          ),
                          secondaryBackground: _SwipeActionBackground(
                            alignment: Alignment.centerRight,
                            background: colorScheme.secondary,
                            foreground: colorScheme.secondaryForeground,
                            icon: inToday
                                ? Icons.event_busy_outlined
                                : Icons.event_available_outlined,
                            label: inToday ? '移出今天' : '加入今天',
                          ),
                          confirmDismiss: (direction) async {
                            if (_selectionMode) return false;
                            if (direction == DismissDirection.startToEnd) {
                              await _toggleDone(context, task);
                              return false;
                            }
                            if (direction == DismissDirection.endToStart) {
                              await _toggleToday(
                                context,
                                task,
                                inToday: inToday,
                              );
                              return false;
                            }
                            return false;
                          },
                          child: TaskListItem(
                            task: task,
                            dense: dense,
                            selectionMode: _selectionMode,
                            selected: _isSelected(task),
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelected(task);
                                return;
                              }
                              context.push('/tasks/${task.id}');
                            },
                            onLongPress: () {
                              if (_selectionMode) {
                                _toggleSelected(task);
                                return;
                              }
                              _startSelection(task);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_selectionMode && _selectedCount > 0)
            _TasksBulkActionsBar(
              selectedCount: _selectedCount,
              allDone:
                  selectedTasks.isNotEmpty &&
                  selectedTasks.every(
                    (t) => t.status == domain.TaskStatus.done,
                  ),
              allInToday:
                  selectedTasks.isNotEmpty &&
                  selectedTasks.every((t) => todayPlanIds.contains(t.id)),
              onDoneToggle: () => _bulkToggleDone(context, selectedTasks),
              onTodayToggle: () =>
                  _bulkToggleToday(context, selectedTasks, todayPlanIds),
              onMoveLater: () =>
                  _bulkMoveLater(context, selectedTasks, todayPlanIds),
              onArchive: () =>
                  _bulkArchive(context, selectedTasks, todayPlanIds),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleDone(BuildContext context, domain.Task task) async {
    final before = task;
    final repo = ref.read(taskRepositoryProvider);
    final nextStatus = task.status == domain.TaskStatus.done
        ? domain.TaskStatus.todo
        : domain.TaskStatus.done;
    await repo.upsertTask(
      task.copyWith(status: nextStatus, updatedAt: DateTime.now()),
    );

    if (!context.mounted) return;
    _showUndoSnack(
      context,
      message: nextStatus == domain.TaskStatus.done ? '已完成任务' : '已撤销完成',
      undo: () async {
        await repo.upsertTask(before.copyWith(updatedAt: DateTime.now()));
      },
    );
  }

  Future<void> _toggleToday(
    BuildContext context,
    domain.Task task, {
    required bool inToday,
  }) async {
    final before = task;
    final repo = ref.read(taskRepositoryProvider);
    final todayRepo = ref.read(todayPlanRepositoryProvider);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    if (inToday) {
      await todayRepo.removeTask(day: day, taskId: task.id);
      final nextTriage = task.triageStatus == domain.TriageStatus.plannedToday
          ? domain.TriageStatus.scheduledLater
          : task.triageStatus;
      await repo.upsertTask(
        task.copyWith(triageStatus: nextTriage, updatedAt: DateTime.now()),
      );
    } else {
      await todayRepo.addTask(day: day, taskId: task.id);
      await repo.upsertTask(
        task.copyWith(
          triageStatus: domain.TriageStatus.plannedToday,
          updatedAt: DateTime.now(),
        ),
      );
    }

    if (!context.mounted) return;
    _showUndoSnack(
      context,
      message: inToday ? '已移出今天' : '已加入今天',
      undo: () async {
        if (inToday) {
          await todayRepo.addTask(day: day, taskId: before.id);
        } else {
          await todayRepo.removeTask(day: day, taskId: before.id);
        }
        await repo.upsertTask(before.copyWith(updatedAt: DateTime.now()));
      },
    );
  }

  Future<void> _bulkToggleDone(
    BuildContext context,
    List<domain.Task> tasks,
  ) async {
    if (tasks.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final beforeById = {for (final t in tasks) t.id: t};
    final allDone = tasks.every((t) => t.status == domain.TaskStatus.done);
    final nextStatus = allDone
        ? domain.TaskStatus.todo
        : domain.TaskStatus.done;

    for (final task in tasks) {
      await repo.upsertTask(
        task.copyWith(status: nextStatus, updatedAt: DateTime.now()),
      );
    }

    if (!context.mounted) return;
    _exitSelectionMode();
    _showUndoSnack(
      context,
      message: nextStatus == domain.TaskStatus.done ? '已批量完成' : '已批量撤销完成',
      undo: () async {
        for (final before in beforeById.values) {
          await repo.upsertTask(before.copyWith(updatedAt: DateTime.now()));
        }
      },
    );
  }

  Future<void> _bulkToggleToday(
    BuildContext context,
    List<domain.Task> tasks,
    List<String> todayPlanIds,
  ) async {
    if (tasks.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final todayRepo = ref.read(todayPlanRepositoryProvider);
    final beforeById = {for (final t in tasks) t.id: t};
    final beforeInToday = <String>{
      for (final t in tasks)
        if (todayPlanIds.contains(t.id)) t.id,
    };

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final allInToday = tasks.every((t) => todayPlanIds.contains(t.id));

    if (allInToday) {
      for (final task in tasks) {
        await todayRepo.removeTask(day: day, taskId: task.id);
        final nextTriage = task.triageStatus == domain.TriageStatus.plannedToday
            ? domain.TriageStatus.scheduledLater
            : task.triageStatus;
        await repo.upsertTask(
          task.copyWith(triageStatus: nextTriage, updatedAt: DateTime.now()),
        );
      }
    } else {
      for (final task in tasks) {
        if (!todayPlanIds.contains(task.id)) {
          await todayRepo.addTask(day: day, taskId: task.id);
        }
        await repo.upsertTask(
          task.copyWith(
            triageStatus: domain.TriageStatus.plannedToday,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }

    if (!context.mounted) return;
    _exitSelectionMode();
    _showUndoSnack(
      context,
      message: allInToday ? '已批量移出今天' : '已批量加入今天',
      undo: () async {
        for (final before in beforeById.values) {
          await repo.upsertTask(before.copyWith(updatedAt: DateTime.now()));
        }
        for (final task in tasks) {
          if (beforeInToday.contains(task.id)) {
            await todayRepo.addTask(day: day, taskId: task.id);
          } else {
            await todayRepo.removeTask(day: day, taskId: task.id);
          }
        }
      },
    );
  }

  Future<void> _bulkMoveLater(
    BuildContext context,
    List<domain.Task> tasks,
    List<String> todayPlanIds,
  ) async {
    if (tasks.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final todayRepo = ref.read(todayPlanRepositoryProvider);
    final beforeById = {for (final t in tasks) t.id: t};
    final beforeInToday = <String>{
      for (final t in tasks)
        if (todayPlanIds.contains(t.id)) t.id,
    };

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    for (final task in tasks) {
      if (todayPlanIds.contains(task.id)) {
        await todayRepo.removeTask(day: day, taskId: task.id);
      }
      await repo.upsertTask(
        task.copyWith(
          triageStatus: domain.TriageStatus.scheduledLater,
          updatedAt: DateTime.now(),
        ),
      );
    }

    if (!context.mounted) return;
    _exitSelectionMode();
    _showUndoSnack(
      context,
      message: '已移动到以后',
      undo: () async {
        for (final before in beforeById.values) {
          await repo.upsertTask(before.copyWith(updatedAt: DateTime.now()));
        }
        for (final task in tasks) {
          if (beforeInToday.contains(task.id)) {
            await todayRepo.addTask(day: day, taskId: task.id);
          }
        }
      },
    );
  }

  Future<void> _bulkArchive(
    BuildContext context,
    List<domain.Task> tasks,
    List<String> todayPlanIds,
  ) async {
    if (tasks.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final todayRepo = ref.read(todayPlanRepositoryProvider);
    final beforeById = {for (final t in tasks) t.id: t};
    final beforeInToday = <String>{
      for (final t in tasks)
        if (todayPlanIds.contains(t.id)) t.id,
    };

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    for (final task in tasks) {
      if (todayPlanIds.contains(task.id)) {
        await todayRepo.removeTask(day: day, taskId: task.id);
      }
      await repo.upsertTask(
        task.copyWith(
          triageStatus: domain.TriageStatus.archived,
          updatedAt: DateTime.now(),
        ),
      );
    }

    if (!context.mounted) return;
    _exitSelectionMode();
    _showUndoSnack(
      context,
      message: '已归档',
      undo: () async {
        for (final before in beforeById.values) {
          await repo.upsertTask(before.copyWith(updatedAt: DateTime.now()));
        }
        for (final task in tasks) {
          if (beforeInToday.contains(task.id)) {
            await todayRepo.addTask(day: day, taskId: task.id);
          }
        }
      },
    );
  }

  void _showUndoSnack(
    BuildContext context, {
    required String message,
    required Future<void> Function() undo,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: '撤销', onPressed: () async => undo()),
      ),
    );
  }

  Future<void> _openFilters(
    BuildContext context,
    domain.TaskListQuery current,
  ) async {
    final next = await showModalBottomSheet<domain.TaskListQuery>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (context) => TaskFiltersSheet(initial: current),
    );
    if (next == null) return;
    ref.read(taskListQueryProvider.notifier).state = next;
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TasksBulkActionsBar extends StatelessWidget {
  const _TasksBulkActionsBar({
    required this.selectedCount,
    required this.allDone,
    required this.allInToday,
    required this.onDoneToggle,
    required this.onTodayToggle,
    required this.onMoveLater,
    required this.onArchive,
  });

  final int selectedCount;
  final bool allDone;
  final bool allInToday;
  final VoidCallback onDoneToggle;
  final VoidCallback onTodayToggle;
  final VoidCallback onMoveLater;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Material(
          color: colorScheme.background,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Text(
                  '已选 $selectedCount',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: onTodayToggle,
                          child: Text(allInToday ? '移出今天' : '加入今天'),
                        ),
                        const SizedBox(width: 8),
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: onDoneToggle,
                          child: Text(allDone ? '撤销完成' : '完成'),
                        ),
                        const SizedBox(width: 8),
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: onMoveLater,
                          child: const Text('以后'),
                        ),
                        const SizedBox(width: 8),
                        ShadButton.outline(
                          size: ShadButtonSize.sm,
                          onPressed: onArchive,
                          child: const Text('归档'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({required this.query, required this.onClear});

  final domain.TaskListQuery query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip('状态：${_statusLabel(query.statusFilter)}'),
      if (query.priority != null)
        _chip('优先级：${_priorityLabel(query.priority!)}'),
      if (query.tag != null && query.tag!.isNotEmpty) _chip('标签：${query.tag}'),
      if (query.dueToday) _chip('今天到期'),
      if (query.overdue) _chip('已逾期'),
      if (query.includeInbox) _chip('含待处理'),
      if (query.includeArchived) _chip('含归档'),
    ];

    final hasAnyFilter =
        query.statusFilter != domain.TaskStatusFilter.open ||
        query.priority != null ||
        (query.tag != null && query.tag!.isNotEmpty) ||
        query.dueToday ||
        query.overdue ||
        query.includeInbox ||
        query.includeArchived;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DpSpacing.md,
        0,
        DpSpacing.md,
        DpSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          if (hasAnyFilter)
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: onClear,
              child: const Text('清除'),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Padding(
    padding: const EdgeInsets.only(right: DpSpacing.sm),
    child: ShadBadge.secondary(child: Text(text)),
  );

  String _statusLabel(domain.TaskStatusFilter filter) => switch (filter) {
    domain.TaskStatusFilter.open => '未完成',
    domain.TaskStatusFilter.all => '全部',
    domain.TaskStatusFilter.todo => '待办',
    domain.TaskStatusFilter.inProgress => '进行中',
    domain.TaskStatusFilter.done => '已完成',
  };

  String _priorityLabel(domain.TaskPriority priority) => switch (priority) {
    domain.TaskPriority.high => '高',
    domain.TaskPriority.medium => '中',
    domain.TaskPriority.low => '低',
  };
}

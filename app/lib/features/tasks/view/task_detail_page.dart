import 'dart:math' as math;

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../focus/providers/focus_providers.dart';
import '../../notes/providers/note_providers.dart';
import '../../notes/view/note_edit_sheet.dart';
import '../../notes/view/select_longform_note_sheet.dart';
import '../../today/providers/today_plan_providers.dart';
import '../../weave/view/weave_mode_sheet.dart';
import '../../weave/weave_service.dart';
import '../providers/task_providers.dart';
import 'task_edit_sheet.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final TextEditingController _newChecklistController = TextEditingController();

  @override
  void dispose() {
    _newChecklistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskByIdProvider(widget.taskId));
    return taskAsync.when(
      loading: () => const AppPageScaffold(
        title: '任务详情',
        body: Center(child: DpSpinner()),
      ),
      error: (error, stack) => AppPageScaffold(
        title: '任务详情',
        body: Padding(
          padding: DpInsets.page,
          child: ShadAlert.destructive(
            icon: const Icon(Icons.error_outline),
            title: const Text('加载失败'),
            description: Text('$error'),
          ),
        ),
      ),
      data: (task) {
        if (task == null) {
          return const AppPageScaffold(
            title: '任务详情',
            body: Padding(
              padding: DpInsets.page,
              child: DpEmptyState(
                icon: Icons.search_off_outlined,
                title: '任务不存在或已删除',
                description: '你可以返回任务列表继续浏览。',
              ),
            ),
          );
        }

        final planIdsAsync = ref.watch(todayPlanTaskIdsProvider);
        final planIds = planIdsAsync.valueOrNull ?? const <String>[];
        final inTodayPlan = planIds.contains(task.id);

        return AppPageScaffold(
          title: task.title.value,
          actions: [
            Tooltip(
              message: '编织到长文',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.link_outlined, size: 20),
                onPressed: () => _weaveToLongform(context, task),
              ),
            ),
            Tooltip(
              message: '删除',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _confirmDelete(context, task.id),
              ),
            ),
            Tooltip(
              message: '编辑',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _openEditSheet(context, task),
              ),
            ),
          ],
          body: ListView(
            padding: DpInsets.page,
            children: [
              _TaskSummaryCard(task: task),
              const SizedBox(height: DpSpacing.md),
              _buildChecklistSection(task),
              const SizedBox(height: DpSpacing.md),
              _buildPomodoroSection(task),
              const SizedBox(height: DpSpacing.md),
              _buildNotesSection(task),
              _buildWeaveTargetsSection(task),
              const SizedBox(height: DpSpacing.lg),
              ShadButton.outline(
                onPressed: planIdsAsync.isLoading
                    ? null
                    : () => _toggleTodayPlan(context, task.id, inTodayPlan),
                leading: Icon(
                  inTodayPlan
                      ? Icons.event_busy_outlined
                      : Icons.event_available_outlined,
                  size: 18,
                ),
                child: Text(inTodayPlan ? '移出今天计划' : '加入今天计划'),
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadButton(
                onPressed: () => context.go('/focus?taskId=${task.id}'),
                leading: const Icon(
                  Icons.center_focus_strong_outlined,
                  size: 18,
                ),
                child: const Text('开始专注'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _weaveToLongform(BuildContext context, domain.Task task) async {
    final mode = await showModalBottomSheet<domain.WeaveMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const WeaveModeSheet(),
    );
    if (mode == null) return;
    if (!context.mounted) return;

    final targetNoteId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectLongformNoteSheet(),
    );
    if (targetNoteId == null) return;

    final result = await weaveToLongform(
      ref: ref,
      targetNoteId: targetNoteId,
      mode: mode,
      tasks: [task],
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mode == domain.WeaveMode.copy ? '已拷贝编织到长文正文' : '已编织到长文'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async => undoWeaveToLongform(ref, result),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String taskId) async {
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('删除任务？'),
        description: const Text(
          '将删除该任务，并清理相关 Checklist / 番茄记录 / 今天计划引用；关联笔记会保留但将解除关联。\n\n此操作不可撤销。',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final active = await ref.read(activePomodoroProvider.future);
    if (active != null && active.taskId == taskId) {
      await ref.read(cancelPomodoroNotificationUseCaseProvider)();
      await ref.read(activePomodoroRepositoryProvider).clear();
    }

    await ref.read(taskRepositoryProvider).deleteTask(taskId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除任务')));
    context.pop();
  }

  Future<void> _toggleTodayPlan(
    BuildContext context,
    String taskId,
    bool inPlan,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final repo = ref.read(todayPlanRepositoryProvider);
    if (inPlan) {
      await repo.removeTask(day: day, taskId: taskId);
    } else {
      await repo.addTask(day: day, taskId: taskId);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(inPlan ? '已移出今天计划' : '已加入今天计划')));
  }

  Widget _buildNotesSection(domain.Task task) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final notesAsync = ref.watch(notesByTaskIdProvider(task.id));

    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '关联笔记',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              ShadButton.secondary(
                size: ShadButtonSize.sm,
                onPressed: () => _openCreateNoteSheet(context, task.id),
                child: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          notesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: DpSpinner()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('加载失败：$error'),
            ),
            data: (notes) {
              if (notes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '还没有关联笔记。写一条记录进展/资料吧。',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < notes.length; i++) ...[
                    _TaskDetailListRow(
                      leading: const Icon(Icons.note_outlined, size: 18),
                      title: notes[i].title.value,
                      subtitle: notes[i].body.trim().isEmpty
                          ? null
                          : notes[i].body.trim().split('\n').first,
                      onTap: () => context.push('/notes/${notes[i].id}'),
                    ),
                    if (i != notes.length - 1)
                      Divider(height: 0, color: colorScheme.border),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateNoteSheet(BuildContext context, String taskId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => NoteEditSheet(taskId: taskId),
    );
  }

  Widget _buildWeaveTargetsSection(domain.Task task) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final linksAsync = ref.watch(
      weaveLinksBySourceProvider((
        sourceType: domain.WeaveSourceType.task,
        sourceId: task.id,
      )),
    );
    final notesAsync = ref.watch(notesStreamProvider);
    final noteById = {
      for (final n in notesAsync.valueOrNull ?? const <domain.Note>[]) n.id: n,
    };

    return linksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('编织目标加载失败：$error'),
      ),
      data: (links) {
        if (links.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Text(
                    '已编织到',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                for (var i = 0; i < links.length; i++) ...[
                  _TaskDetailListRow(
                    leading: const Icon(Icons.link_outlined, size: 18),
                    title:
                        noteById[links[i].targetNoteId]?.title.value ??
                        '（长文不存在或已删除）',
                    subtitle: links[i].mode == domain.WeaveMode.copy
                        ? '拷贝'
                        : '引用',
                    trailing: Tooltip(
                      message: '移除链接',
                      child: ShadIconButton.ghost(
                        icon: const Icon(Icons.link_off_outlined, size: 18),
                        onPressed: () async {
                          await ref
                              .read(weaveLinkRepositoryProvider)
                              .deleteLink(links[i].id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已移除编织链接')),
                          );
                        },
                      ),
                    ),
                    onTap: () {
                      final target = noteById[links[i].targetNoteId];
                      if (target == null) return;
                      context.push('/notes/${target.id}');
                    },
                  ),
                  if (i != links.length - 1)
                    Divider(height: 0, color: colorScheme.border),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPomodoroSection(domain.Task task) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final sessionsAsync = ref.watch(pomodoroSessionsByTaskProvider(task.id));
    final countAsync = ref.watch(pomodoroCountByTaskProvider(task.id));

    return ShadCard(
      padding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '番茄记录',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
          countAsync.when(
            data: (count) => Text(
              '累计 $count',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      child: sessionsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: DpSpinner()),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('加载失败：$error'),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '还没有番茄记录。开始一次专注吧。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            );
          }

          final visible = sessions.take(5).toList(growable: false);
          return Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                _TaskDetailListRow(
                  dense: true,
                  leading: Icon(
                    visible[i].isDraft
                        ? Icons.edit_note
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  title: _formatSessionTime(visible[i]),
                  subtitle:
                      visible[i].progressNote == null ||
                          visible[i].progressNote!.isEmpty
                      ? (visible[i].isDraft ? '稍后补（草稿）' : '未填写进展')
                      : visible[i].progressNote!,
                ),
                if (i != visible.length - 1)
                  Divider(height: 0, color: colorScheme.border),
              ],
              if (sessions.length > visible.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '仅展示最近 5 条',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _formatSessionTime(domain.PomodoroSession session) {
    final end = session.endAt;
    final mm = end.month.toString().padLeft(2, '0');
    final dd = end.day.toString().padLeft(2, '0');
    final hh = end.hour.toString().padLeft(2, '0');
    final min = end.minute.toString().padLeft(2, '0');
    final mins = session.duration.inMinutes;
    return '$mm/$dd $hh:$min · ${mins}min';
  }

  Widget _buildChecklistSection(domain.Task task) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final itemsAsync = ref.watch(taskChecklistItemsProvider(task.id));
    return ShadCard(
      padding: const EdgeInsets.all(16),
      title: Text(
        'Checklist',
        style: shadTheme.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.foreground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          itemsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: DpSpinner()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('加载失败：$error'),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '还没有子任务，添加一条让它更可执行。',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ShadCheckbox(
                        value: item.isDone,
                        onChanged: (value) async {
                          final toggle = ref.read(
                            toggleChecklistItemUseCaseProvider,
                          );
                          await toggle(item: item, isDone: value);
                        },
                        label: Text(
                          item.title.value,
                          style: shadTheme.textTheme.small.copyWith(
                            color: colorScheme.foreground,
                            decoration: item.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Divider(height: 24, color: colorScheme.border),
          ShadInput(
            controller: _newChecklistController,
            placeholder: Text(
              '新增子任务…',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            leading: const Icon(Icons.add, size: 18),
            trailing: Tooltip(
              message: '添加',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.send, size: 18),
                onPressed: () => _addChecklistItem(task),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addChecklistItem(task),
          ),
        ],
      ),
    );
  }

  Future<void> _addChecklistItem(domain.Task task) async {
    final title = _newChecklistController.text.trim();
    if (title.isEmpty) return;

    final items = await ref.read(taskChecklistItemsProvider(task.id).future);
    final nextOrderIndex = items.isEmpty
        ? 0
        : (items.map((i) => i.orderIndex).reduce(math.max) + 1);

    try {
      final create = ref.read(createChecklistItemUseCaseProvider);
      await create(taskId: task.id, title: title, orderIndex: nextOrderIndex);
      _newChecklistController.clear();
    } on domain.ChecklistItemTitleEmptyException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('子任务标题不能为空')));
    }
  }

  void _openEditSheet(BuildContext context, domain.Task task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TaskEditSheet(task: task),
    );
  }
}

class _TaskDetailListRow extends StatelessWidget {
  const _TaskDetailListRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final vertical = dense ? 8.0 : 10.0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: vertical),
        child: Row(
          children: [
            IconTheme(
              data: IconThemeData(color: colorScheme.mutedForeground),
              child: leading,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: dense ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
      ),
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({required this.task});

  final domain.Task task;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final dueAt = task.dueAt;
    final dueText = dueAt == null
        ? '未设置'
        : '${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')}';

    final tags = task.tags;
    final estimatedText = task.estimatedPomodoros?.toString() ?? '未设置';

    return ShadCard(
      padding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '概览',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
          _statusBadge(task.status),
          const SizedBox(width: 8),
          _priorityBadge(task.priority),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '截止：$dueText',
            style: shadTheme.textTheme.small.copyWith(
              color: colorScheme.foreground,
            ),
          ),
          Text(
            '预计番茄：$estimatedText',
            style: shadTheme.textTheme.small.copyWith(
              color: colorScheme.foreground,
            ),
          ),
          if (tags.isEmpty)
            Text(
              '标签：无',
              style: shadTheme.textTheme.small.copyWith(
                color: colorScheme.foreground,
              ),
            )
          else ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags)
                  ShadBadge.outline(
                    child: Text(
                      '#$t',
                      style: shadTheme.textTheme.small.copyWith(
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if ((task.description ?? '').trim().isNotEmpty) ...[
            Divider(height: 24, color: colorScheme.border),
            Text(
              task.description!.trim(),
              style: shadTheme.textTheme.small.copyWith(
                color: colorScheme.foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(domain.TaskStatus status) {
    return switch (status) {
      domain.TaskStatus.todo => const ShadBadge.secondary(child: Text('待办')),
      domain.TaskStatus.inProgress => const ShadBadge(child: Text('进行中')),
      domain.TaskStatus.done => const ShadBadge.outline(child: Text('已完成')),
    };
  }

  Widget _priorityBadge(domain.TaskPriority priority) {
    return switch (priority) {
      domain.TaskPriority.high => const ShadBadge.destructive(child: Text('高')),
      domain.TaskPriority.medium => const ShadBadge.secondary(child: Text('中')),
      domain.TaskPriority.low => const ShadBadge.outline(child: Text('低')),
    };
  }
}

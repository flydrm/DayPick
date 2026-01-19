import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/sheets/quick_create_sheet.dart';
import '../../focus/view/select_task_sheet.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/today_plan_providers.dart';

class TodayPlanEditSheet extends ConsumerStatefulWidget {
  const TodayPlanEditSheet({super.key});

  @override
  ConsumerState<TodayPlanEditSheet> createState() => _TodayPlanEditSheetState();
}

class _TodayPlanEditSheetState extends ConsumerState<TodayPlanEditSheet> {
  bool _adding = false;
  List<String>? _overrideTodayPlanIds;
  List<String>? _overrideEveningPlanIds;
  bool _pruningMissingProviderIds = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final todayPlanIdsAsync = ref.watch(todayPlanTaskIdsProvider);
    final eveningPlanIdsAsync = ref.watch(todayEveningPlanTaskIdsProvider);

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final byId = {for (final t in tasks) t.id: t};
    final providerTodayPlanIds =
        todayPlanIdsAsync.valueOrNull ?? const <String>[];
    final providerEveningPlanIds =
        eveningPlanIdsAsync.valueOrNull ?? const <String>[];

    final todayPlanIds = _overrideTodayPlanIds ?? providerTodayPlanIds;
    final eveningPlanIds = _overrideEveningPlanIds ?? providerEveningPlanIds;

    final todayPlanTasks = <domain.Task>[
      for (final id in todayPlanIds)
        if (byId[id] != null) byId[id]!,
    ];
    final eveningPlanTasks = <domain.Task>[
      for (final id in eveningPlanIds)
        if (byId[id] != null) byId[id]!,
    ];

    final visibleTodayPlanIds = [for (final t in todayPlanTasks) t.id];
    final visibleEveningPlanIds = [for (final t in eveningPlanTasks) t.id];
    final plannedIds = {...visibleTodayPlanIds, ...visibleEveningPlanIds};

    final suggested = const domain.TodayQueueRule(maxItems: 5)(
      tasks,
      now,
    ).todayQueue;
    final suggestedAddableIds = [
      for (final t in suggested)
        if (!plannedIds.contains(t.id)) t.id,
    ];
    final plannedPomodoros = _plannedPomodoros(todayPlanTasks);

    if (!_pruningMissingProviderIds &&
        _overrideTodayPlanIds == null &&
        _overrideEveningPlanIds == null &&
        tasksAsync.hasValue &&
        todayPlanIdsAsync.hasValue &&
        eveningPlanIdsAsync.hasValue) {
      final missingTodayIds = [
        for (final id in providerTodayPlanIds)
          if (!byId.containsKey(id)) id,
      ];
      final missingEveningIds = [
        for (final id in providerEveningPlanIds)
          if (!byId.containsKey(id)) id,
      ];
      if (missingTodayIds.isNotEmpty || missingEveningIds.isNotEmpty) {
        _pruningMissingProviderIds = true;
        final cleanedToday = [
          for (final id in providerTodayPlanIds)
            if (byId.containsKey(id)) id,
        ];
        final cleanedTodaySet = cleanedToday.toSet();
        final cleanedEvening = [
          for (final id in providerEveningPlanIds)
            if (byId.containsKey(id) && !cleanedTodaySet.contains(id)) id,
        ];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(() async {
            if (!mounted) return;
            setState(() {
              _overrideTodayPlanIds = cleanedToday;
              _overrideEveningPlanIds = cleanedEvening;
            });

            final repo = ref.read(todayPlanRepositoryProvider);
            await repo.replaceTasks(
              day: day,
              taskIds: cleanedToday,
              section: domain.TodayPlanSection.today,
            );
            await repo.replaceTasks(
              day: day,
              taskIds: cleanedEvening,
              section: domain.TodayPlanSection.evening,
            );
            if (!mounted) return;
            setState(() => _pruningMissingProviderIds = false);
          }());
        });
      }
    }

    if (_overrideTodayPlanIds != null &&
        _listEquals(todayPlanIds, providerTodayPlanIds)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_overrideTodayPlanIds == null) return;
        setState(() => _overrideTodayPlanIds = null);
      });
    }
    if (_overrideEveningPlanIds != null &&
        _listEquals(eveningPlanIds, providerEveningPlanIds)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_overrideEveningPlanIds == null) return;
        setState(() => _overrideEveningPlanIds = null);
      });
    }

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            primary: false,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '编辑今天计划',
                      style: shadTheme.textTheme.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '关闭',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _adding
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '拖拽排序；你可以创建任务并加入今天，或从任务库添加、用建议填充开始。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ShadButton(
                    onPressed: _adding ? null : () => _createTaskForToday(),
                    leading: const Icon(Icons.add_task_outlined, size: 18),
                    child: const Text('创建并加入今天'),
                  ),
                  ShadButton.outline(
                    onPressed: _adding ? null : () => _addTask(day),
                    leading: const Icon(Icons.add, size: 18),
                    child: const Text('从任务库添加'),
                  ),
                  ShadButton.outline(
                    onPressed: suggested.isEmpty || _adding
                        ? null
                        : () => _fillSuggested(day, suggested),
                    leading: const Icon(Icons.auto_fix_high_outlined, size: 18),
                    child: const Text('用建议填充'),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed:
                        (todayPlanIds.isEmpty && eveningPlanIds.isEmpty) ||
                            _adding
                        ? null
                        : () => _clearPlan(day),
                    child: const Text('清空'),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: _adding
                        ? null
                        : () => context.push('/ai/today-plan'),
                    leading: const Icon(Icons.auto_awesome_outlined, size: 16),
                    child: const Text('AI 草稿'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ShadCard(
                padding: EdgeInsets.zero,
                title: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '建议候选',
                          style: shadTheme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                      if (suggested.isNotEmpty)
                        Text(
                          '最多 ${suggested.length} 条',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '来自到期/优先级的自动规则；你可以“加入”几条再手动排序。',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (suggested.isEmpty)
                        Text(
                          '暂时没有建议任务。先去任务列表加一条，或用 AI 拆任务。',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        )
                      else ...[
                        ShadCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0; i < suggested.length; i++) ...[
                                _SuggestedTaskRow(
                                  task: suggested[i],
                                  planned: plannedIds.contains(suggested[i].id),
                                  onAdd: _adding
                                      ? null
                                      : () => _appendPlanIds(
                                          day,
                                          visibleTodayPlanIds,
                                          [suggested[i].id],
                                        ),
                                ),
                                if (i != suggested.length - 1)
                                  Divider(height: 0, color: colorScheme.border),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ShadButton.secondary(
                                onPressed:
                                    suggestedAddableIds.isEmpty || _adding
                                    ? null
                                    : () => _appendPlanIds(
                                        day,
                                        visibleTodayPlanIds,
                                        suggestedAddableIds,
                                      ),
                                leading: const Icon(
                                  Icons.playlist_add_outlined,
                                  size: 16,
                                ),
                                child: Text(
                                  suggestedAddableIds.isEmpty
                                      ? '都已在计划中'
                                      : '全部加入今天',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ShadButton.outline(
                                onPressed: _adding
                                    ? null
                                    : () => _fillSuggested(day, suggested),
                                leading: const Icon(
                                  Icons.auto_fix_high_outlined,
                                  size: 16,
                                ),
                                child: const Text('替换为建议'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ShadCard(
                padding: EdgeInsets.zero,
                title: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '已计划',
                          style: shadTheme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                      Text(
                        '${todayPlanTasks.length + eveningPlanTasks.length} 条 · Today $plannedPomodoros 番茄',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    if (todayPlanIdsAsync.isLoading ||
                        eveningPlanIdsAsync.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: ShadProgress(minHeight: 8),
                      );
                    }
                    if (todayPlanIdsAsync.hasError ||
                        eveningPlanIdsAsync.hasError) {
                      final errors = <String>[
                        if (todayPlanIdsAsync.hasError)
                          'Today: ${todayPlanIdsAsync.error}',
                        if (eveningPlanIdsAsync.hasError)
                          'Evening: ${eveningPlanIdsAsync.error}',
                      ].join('\n');
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: ShadAlert.destructive(
                          icon: const Icon(Icons.error_outline),
                          title: const Text('今天计划加载失败'),
                          description: Text(errors),
                        ),
                      );
                    }
                    if (tasksAsync.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: ShadProgress(minHeight: 8),
                      );
                    }
                    if (tasksAsync.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: ShadAlert.destructive(
                          icon: const Icon(Icons.error_outline),
                          title: const Text('任务加载失败'),
                          description: Text('${tasksAsync.error}'),
                        ),
                      );
                    }
                    if (todayPlanIds.isEmpty && eveningPlanIds.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '今天还没有计划任务。先创建一条，或点「用建议填充」。',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      );
                    }

                    Widget sectionTitle({
                      required IconData icon,
                      required String title,
                      required String meta,
                      String? hint,
                    }) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 16,
                                  color: colorScheme.mutedForeground,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: shadTheme.textTheme.small.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.foreground,
                                    ),
                                  ),
                                ),
                                Text(
                                  meta,
                                  style: shadTheme.textTheme.muted.copyWith(
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                            if (hint != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                hint,
                                style: shadTheme.textTheme.muted.copyWith(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    Widget emptyHint(String text) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          text,
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        sectionTitle(
                          icon: Icons.today_outlined,
                          title: 'Today',
                          meta:
                              '${todayPlanTasks.length} 条 · $plannedPomodoros 番茄',
                        ),
                        if (todayPlanTasks.isEmpty)
                          emptyHint('把 3–5 条任务装入 Today，作为今天的执行队列。')
                        else
                          ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: todayPlanTasks.length,
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final ids = visibleTodayPlanIds.toList();
                              if (oldIndex < 0 || oldIndex >= ids.length) {
                                return;
                              }
                              final moved = ids.removeAt(oldIndex);
                              final insertIndex = newIndex.clamp(0, ids.length);
                              ids.insert(insertIndex, moved);
                              setState(() => _overrideTodayPlanIds = ids);
                              unawaited(
                                ref
                                    .read(todayPlanRepositoryProvider)
                                    .replaceTasks(
                                      day: day,
                                      taskIds: ids,
                                      section: domain.TodayPlanSection.today,
                                    ),
                              );
                            },
                            itemBuilder: (context, index) {
                              final task = todayPlanTasks[index];
                              return _PlanTaskRow(
                                key: ValueKey('today_plan_item:${task.id}'),
                                title: task.title.value,
                                subtitle: _subtitleFor(task),
                                onOpen: () => context.push('/tasks/${task.id}'),
                                secondaryAction: Tooltip(
                                  message: '移到 This Evening',
                                  child: ShadIconButton.ghost(
                                    icon: const Icon(
                                      Icons.nights_stay_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () => unawaited(
                                      _moveTaskToSection(
                                        day: day,
                                        taskId: task.id,
                                        section:
                                            domain.TodayPlanSection.evening,
                                      ),
                                    ),
                                  ),
                                ),
                                onRemove: () {
                                  final ids = visibleTodayPlanIds.toList()
                                    ..remove(task.id);
                                  setState(() => _overrideTodayPlanIds = ids);
                                  unawaited(
                                    ref
                                        .read(todayPlanRepositoryProvider)
                                        .replaceTasks(
                                          day: day,
                                          taskIds: ids,
                                          section:
                                              domain.TodayPlanSection.today,
                                        ),
                                  );
                                },
                                dragHandle: ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle),
                                ),
                              );
                            },
                          ),
                        Divider(height: 0, color: colorScheme.border),
                        sectionTitle(
                          icon: Icons.nights_stay_outlined,
                          title: 'This Evening',
                          meta: '${eveningPlanTasks.length} 条',
                          hint: '今天但不急的任务放这里，降低压力墙。',
                        ),
                        if (eveningPlanTasks.isEmpty)
                          emptyHint('在 Today 列表点 🌙 可移入。')
                        else
                          ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: eveningPlanTasks.length,
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final ids = visibleEveningPlanIds.toList();
                              if (oldIndex < 0 || oldIndex >= ids.length) {
                                return;
                              }
                              final moved = ids.removeAt(oldIndex);
                              final insertIndex = newIndex.clamp(0, ids.length);
                              ids.insert(insertIndex, moved);
                              setState(() => _overrideEveningPlanIds = ids);
                              unawaited(
                                ref
                                    .read(todayPlanRepositoryProvider)
                                    .replaceTasks(
                                      day: day,
                                      taskIds: ids,
                                      section: domain.TodayPlanSection.evening,
                                    ),
                              );
                            },
                            itemBuilder: (context, index) {
                              final task = eveningPlanTasks[index];
                              return _PlanTaskRow(
                                key: ValueKey('evening_plan_item:${task.id}'),
                                title: task.title.value,
                                subtitle: _subtitleFor(task),
                                onOpen: () => context.push('/tasks/${task.id}'),
                                secondaryAction: Tooltip(
                                  message: '移回 Today',
                                  child: ShadIconButton.ghost(
                                    icon: const Icon(
                                      Icons.wb_sunny_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () => unawaited(
                                      _moveTaskToSection(
                                        day: day,
                                        taskId: task.id,
                                        section: domain.TodayPlanSection.today,
                                      ),
                                    ),
                                  ),
                                ),
                                onRemove: () {
                                  final ids = visibleEveningPlanIds.toList()
                                    ..remove(task.id);
                                  setState(() => _overrideEveningPlanIds = ids);
                                  unawaited(
                                    ref
                                        .read(todayPlanRepositoryProvider)
                                        .replaceTasks(
                                          day: day,
                                          taskIds: ids,
                                          section:
                                              domain.TodayPlanSection.evening,
                                        ),
                                  );
                                },
                                dragHandle: ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle),
                                ),
                              );
                            },
                          ),
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

  Future<void> _createTaskForToday() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const QuickCreateSheet(
          initialType: QuickCreateType.task,
          initialTaskAddToToday: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _addTask(DateTime day) async {
    final taskId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectTaskSheet(),
    );
    if (taskId == null) return;
    await ref
        .read(todayPlanRepositoryProvider)
        .addTask(
          day: day,
          taskId: taskId,
          section: domain.TodayPlanSection.today,
        );
    if (!mounted) return;
    setState(() {
      final todayBase =
          (_overrideTodayPlanIds ??
                  ref.read(todayPlanTaskIdsProvider).valueOrNull ??
                  const <String>[])
              .toList();
      final eveningBase =
          (_overrideEveningPlanIds ??
                  ref.read(todayEveningPlanTaskIdsProvider).valueOrNull ??
                  const <String>[])
              .toList();
      todayBase.remove(taskId);
      eveningBase.remove(taskId);
      todayBase.add(taskId);
      _overrideTodayPlanIds = todayBase;
      _overrideEveningPlanIds = eveningBase;
    });
  }

  Future<void> _fillSuggested(DateTime day, List<domain.Task> suggested) async {
    final ids = suggested.map((t) => t.id).toList();
    if (ids.isEmpty) return;
    if (ref.read(todayPlanTaskIdsProvider).valueOrNull?.isNotEmpty == true) {
      final ok = await showShadDialog<bool>(
        context: context,
        builder: (dialogContext) => ShadDialog.alert(
          title: const Text('用建议覆盖当前计划？'),
          description: const Text('这会用建议列表替换你当前的 Today 列表（不会删除任务）。'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            ShadButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('替换'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    await ref
        .read(todayPlanRepositoryProvider)
        .replaceTasks(
          day: day,
          taskIds: ids,
          section: domain.TodayPlanSection.today,
        );
    if (!mounted) return;
    setState(() {
      _overrideTodayPlanIds = ids;
      final eveningBase =
          (_overrideEveningPlanIds ??
                  ref.read(todayEveningPlanTaskIdsProvider).valueOrNull ??
                  const <String>[])
              .toList();
      eveningBase.removeWhere(ids.contains);
      _overrideEveningPlanIds = eveningBase;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已填充 ${ids.length} 条计划')));
  }

  Future<void> _clearPlan(DateTime day) async {
    final ok = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('清空今天计划（含 This Evening）？'),
        description: const Text('仅清空计划列表，不会删除任何任务。'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(todayPlanRepositoryProvider).clearAll(day: day);
    if (!mounted) return;
    setState(() {
      _overrideTodayPlanIds = const [];
      _overrideEveningPlanIds = const [];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清空今天计划')));
  }

  Future<void> _moveTaskToSection({
    required DateTime day,
    required String taskId,
    required domain.TodayPlanSection section,
  }) async {
    if (!mounted) return;
    setState(() {
      final todayBase =
          (_overrideTodayPlanIds ??
                  ref.read(todayPlanTaskIdsProvider).valueOrNull ??
                  const <String>[])
              .toList();
      final eveningBase =
          (_overrideEveningPlanIds ??
                  ref.read(todayEveningPlanTaskIdsProvider).valueOrNull ??
                  const <String>[])
              .toList();
      todayBase.remove(taskId);
      eveningBase.remove(taskId);

      switch (section) {
        case domain.TodayPlanSection.today:
          todayBase.add(taskId);
          break;
        case domain.TodayPlanSection.evening:
          eveningBase.add(taskId);
          break;
      }

      _overrideTodayPlanIds = todayBase;
      _overrideEveningPlanIds = eveningBase;
    });

    await ref
        .read(todayPlanRepositoryProvider)
        .moveTaskToSection(day: day, taskId: taskId, section: section);
  }

  Future<void> _appendPlanIds(
    DateTime day,
    List<String> currentIds,
    List<String> toAdd,
  ) async {
    if (toAdd.isEmpty) return;
    final ids = currentIds.toList();
    for (final id in toAdd) {
      if (!ids.contains(id)) ids.add(id);
    }
    setState(() {
      _overrideTodayPlanIds = ids;
      if (_overrideEveningPlanIds != null) {
        _overrideEveningPlanIds = [
          for (final id in _overrideEveningPlanIds!)
            if (!ids.contains(id)) id,
        ];
      }
    });
    await ref
        .read(todayPlanRepositoryProvider)
        .replaceTasks(
          day: day,
          taskIds: ids,
          section: domain.TodayPlanSection.today,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已加入 ${toAdd.length} 条到今天计划')));
  }

  Widget? _subtitleFor(domain.Task task) {
    final dueAt = task.dueAt;
    final dueText = dueAt == null ? null : '${dueAt.month}/${dueAt.day}';

    final parts = <String>[];
    if (dueText != null) parts.add('到期 $dueText');
    if (task.tags.isNotEmpty) parts.add(task.tags.take(3).join(' · '));
    if (parts.isEmpty) return null;
    return Text(
      parts.join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  int _plannedPomodoros(List<domain.Task> planTasks) {
    var sum = 0;
    for (final task in planTasks) {
      final est = task.estimatedPomodoros;
      sum += est == null || est <= 0 ? 1 : est;
    }
    return sum;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _PlanTaskRow extends StatelessWidget {
  const _PlanTaskRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.secondaryAction,
    required this.onRemove,
    required this.dragHandle,
  });

  final String title;
  final Widget? subtitle;
  final VoidCallback onOpen;
  final Widget? secondaryAction;
  final VoidCallback onRemove;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (secondaryAction != null) ...[
              secondaryAction!,
              const SizedBox(width: 4),
            ],
            Tooltip(
              message: '移除',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: onRemove,
              ),
            ),
            const SizedBox(width: 4),
            dragHandle,
          ],
        ),
      ),
    );
  }
}

class _SuggestedTaskRow extends StatelessWidget {
  const _SuggestedTaskRow({
    required this.task,
    required this.planned,
    required this.onAdd,
  });

  final domain.Task task;
  final bool planned;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final dueAt = task.dueAt;
    final dueText = dueAt == null ? null : '${dueAt.month}/${dueAt.day}';

    final meta = <String>[];
    if (dueText != null) meta.add('到期 $dueText');
    if (task.tags.isNotEmpty) meta.add(task.tags.take(3).join(' · '));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta.join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (planned)
            const ShadBadge.secondary(child: Text('已计划'))
          else
            ShadButton.secondary(
              size: ShadButtonSize.sm,
              onPressed: onAdd,
              child: const Text('加入'),
            ),
        ],
      ),
    );
  }
}

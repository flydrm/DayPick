import 'dart:math' as math;

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/sheets/time_picker_sheet.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_radius.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/timeboxing_providers.dart';
import '../providers/today_plan_providers.dart';
import 'today_plan_edit_sheet.dart';

typedef _TimeboxBlock = ({
  domain.Task task,
  int pomodoros,
  int minutes,
  int startMinutes,
  int endMinutes,
});

class TodayTimeboxingCanvasPage extends ConsumerStatefulWidget {
  const TodayTimeboxingCanvasPage({super.key});

  @override
  ConsumerState<TodayTimeboxingCanvasPage> createState() =>
      _TodayTimeboxingCanvasPageState();
}

class _TodayTimeboxingCanvasPageState
    extends ConsumerState<TodayTimeboxingCanvasPage> {
  final ScrollController _scrollController = ScrollController();
  bool _didAutoScroll = false;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setSelectedDay(DateTime next) {
    final normalized = DateTime(next.year, next.month, next.day);
    if (normalized == _selectedDay) return;
    setState(() {
      _selectedDay = normalized;
      _didAutoScroll = false;
    });
  }

  String _dayLabel(DateTime day) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekdayIndex = (day.weekday - 1).clamp(0, 6);
    final weekday = weekdays[weekdayIndex];
    return '${day.month}月${day.day}日 · 周$weekday';
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _selectedDay == today;
    final nowMinutes = isToday ? now.hour * 60 + now.minute : -1;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final planIdsAsync = ref.watch(
      todayPlanTaskIdsForDayProvider(_selectedDay),
    );
    final configAsync = ref.watch(pomodoroConfigProvider);
    final appearanceAsync = ref.watch(appearanceConfigProvider);

    final appearance =
        appearanceAsync.valueOrNull ?? const domain.AppearanceConfig();
    final workMinutes = configAsync.maybeWhen(
      data: (c) => c.workDurationMinutes,
      orElse: () => 25,
    );
    final startMinutes = ref.watch(timeboxingStartMinutesProvider);

    int clampMinute(int v) => v.clamp(0, 24 * 60 - 1);

    var workdayStart = clampMinute(appearance.timeboxingWorkdayStartMinutes);
    var workdayEnd = clampMinute(appearance.timeboxingWorkdayEndMinutes);
    if (workdayEnd <= workdayStart) {
      workdayEnd = clampMinute(workdayStart + 8 * 60);
      if (workdayEnd <= workdayStart) {
        workdayStart = 7 * 60;
        workdayEnd = 21 * 60;
      }
    }

    final minuteHeight = switch (appearance.timeboxingLayout) {
      domain.TimeboxingLayout.minimal => 1.2,
      domain.TimeboxingLayout.full => 1.6,
    };

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final byId = {for (final t in tasks) t.id: t};
    final planIds = planIdsAsync.valueOrNull ?? const <String>[];
    final planTasks = <domain.Task>[
      for (final id in planIds)
        if (byId[id] != null) byId[id]!,
    ];

    int pomodorosFor(domain.Task task) {
      final est = task.estimatedPomodoros;
      return est == null || est <= 0 ? 1 : est;
    }

    final blocks = <_TimeboxBlock>[];
    var cursor = startMinutes;
    for (final task in planTasks) {
      final pomodoros = pomodorosFor(task);
      final minutes = pomodoros * workMinutes;
      final start = cursor;
      final end = start + minutes;
      blocks.add((
        task: task,
        pomodoros: pomodoros,
        minutes: minutes,
        startMinutes: start,
        endMinutes: end,
      ));
      cursor = end;
    }

    final totalPomodoros = blocks.fold<int>(0, (sum, b) => sum + b.pomodoros);
    final totalMinutes = blocks.fold<int>(0, (sum, b) => sum + b.minutes);
    final endMinutes = startMinutes + totalMinutes;

    final hasPlan = planTasks.isNotEmpty;
    final overloaded = hasPlan && endMinutes > workdayEnd;
    final overloadMinutes = overloaded ? endMinutes - workdayEnd : 0;

    String formatTime(int minutes) {
      final clamped = clampMinute(minutes);
      final hh = (clamped ~/ 60).toString().padLeft(2, '0');
      final mm = (clamped % 60).toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    String formatDuration(int minutes) {
      if (minutes <= 0) return '0m';
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (h <= 0) return '${m}m';
      if (m == 0) return '${h}h';
      return '${h}h${m}m';
    }

    Future<void> openPlanEditor() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const TodayPlanEditSheet(),
      );
    }

    Future<void> openBlockActions(domain.Task task, int pomodoros) async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => _TimeboxBlockActionsSheet(
          task: task,
          initialPomodoros: pomodoros,
          workMinutes: workMinutes,
        ),
      );
    }

    Future<void> openInboxDrawer() async {
      if (!isToday) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) =>
            _TimeboxingInboxSheet(day: _selectedDay, plannedTaskIds: planIds),
      );
    }

    Future<void> openReorderSheet() async {
      if (!isToday) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => _TimeboxingReorderSheet(
          day: _selectedDay,
          startMinutes: startMinutes,
          workMinutes: workMinutes,
          taskIds: planIds,
        ),
      );
    }

    Future<void> openSettings() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => _TimeboxingSettingsSheet(
          config: appearance,
          startMinutes: startMinutes,
        ),
      );
    }

    void maybeAutoScroll() {
      if (_didAutoScroll) return;
      if (!_scrollController.hasClients) return;
      _didAutoScroll = true;

      final anchorMinutes = (isToday ? nowMinutes : startMinutes).clamp(
        workdayStart,
        workdayEnd,
      );
      final offset = math.max(
        0.0,
        (anchorMinutes - workdayStart) * minuteHeight - 120,
      );
      _scrollController.jumpTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => maybeAutoScroll());

    final headerText = hasPlan
        ? '从 ${formatTime(startMinutes)} 开始 · 预计 ${formatTime(endMinutes)} 结束'
              ' · ${formatDuration(totalMinutes)}'
        : '把 3–5 条任务装入 Today 后，就能投影一个可执行时间线。';

    return AppPageScaffold(
      title: '画布',
      createRoute: '/create?addToToday=1',
      showSearchAction: false,
      showSettingsAction: false,
      actions: [
        Tooltip(
          message: '待处理（Drawer）',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.inbox_outlined, size: 20),
            onPressed: isToday ? openInboxDrawer : null,
          ),
        ),
        Tooltip(
          message: '拖拽重排',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.drag_indicator, size: 20),
            onPressed: (isToday && hasPlan) ? openReorderSheet : null,
          ),
        ),
        Tooltip(
          message: '设置',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.tune_outlined, size: 20),
            onPressed: openSettings,
          ),
        ),
        Tooltip(
          message: '编辑今天计划',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.checklist_outlined, size: 20),
            onPressed: isToday ? openPlanEditor : null,
          ),
        ),
      ],
      body: Padding(
        padding: DpInsets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadCard(
              padding: DpInsets.card,
              title: Row(
                children: [
                  Tooltip(
                    message: '前一天',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.chevron_left, size: 22),
                      onPressed: () => _setSelectedDay(
                        _selectedDay.subtract(const Duration(days: 1)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isToday
                              ? '今天 · ${_dayLabel(_selectedDay)}'
                              : _dayLabel(_selectedDay),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: shadTheme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headerText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: '后一天',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.chevron_right, size: 22),
                      onPressed: () => _setSelectedDay(
                        _selectedDay.add(const Duration(days: 1)),
                      ),
                    ),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ShadBadge.outline(child: Text('$totalPomodoros 番茄')),
                  ShadBadge.outline(child: Text('${workMinutes}m/番茄')),
                  ShadBadge.outline(
                    child: Text(
                      '${formatTime(workdayStart)}–${formatTime(workdayEnd)}',
                    ),
                  ),
                  if (overloaded)
                    ShadBadge.destructive(
                      child: Text('超出 ${formatDuration(overloadMinutes)}'),
                    ),
                  if (!isToday)
                    ShadBadge.secondary(
                      child: Text(
                        '只读预览',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DpSpacing.md),
            if (tasksAsync.isLoading || planIdsAsync.isLoading)
              const ShadProgress(minHeight: 8)
            else if (tasksAsync.hasError || planIdsAsync.hasError)
              ShadAlert.destructive(
                icon: const Icon(Icons.error_outline),
                title: const Text('加载失败'),
                description: Text(
                  'tasks: ${tasksAsync.error ?? 'ok'}\nplan: ${planIdsAsync.error ?? 'ok'}',
                ),
              )
            else if (!hasPlan)
              Expanded(
                child: Center(
                  child: ShadButton(
                    onPressed: openPlanEditor,
                    leading: const Icon(Icons.tune_outlined, size: 18),
                    child: const Text('去编辑今天计划'),
                  ),
                ),
              )
            else
              Expanded(
                child: _TimelineCanvas(
                  windowStartMinutes: workdayStart,
                  windowEndMinutes: workdayEnd,
                  nowMinutes: nowMinutes,
                  minuteHeight: minuteHeight,
                  layout: appearance.timeboxingLayout,
                  blocks: blocks,
                  scrollController: _scrollController,
                  onOpenTask: (taskId) => context.push('/tasks/$taskId'),
                  onStartFocus: (taskId) =>
                      context.push('/focus?taskId=$taskId'),
                  onLongPressBlock: (taskId) {
                    final task = byId[taskId];
                    if (task == null) return;
                    var pomodoros = 1;
                    for (final b in blocks) {
                      if (b.task.id == taskId) {
                        pomodoros = b.pomodoros;
                        break;
                      }
                    }
                    openBlockActions(task, pomodoros);
                  },
                ),
              ),
            const SizedBox(height: DpSpacing.sm),
            Text(
              '提示：基于“预计番茄”投影，不会自动安排日历事件（本地-only）。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCanvas extends StatelessWidget {
  const _TimelineCanvas({
    required this.windowStartMinutes,
    required this.windowEndMinutes,
    required this.nowMinutes,
    required this.minuteHeight,
    required this.layout,
    required this.blocks,
    required this.scrollController,
    required this.onOpenTask,
    required this.onStartFocus,
    required this.onLongPressBlock,
  });

  final int windowStartMinutes;
  final int windowEndMinutes;
  final int nowMinutes;
  final double minuteHeight;
  final domain.TimeboxingLayout layout;
  final List<_TimeboxBlock> blocks;
  final ScrollController scrollController;
  final ValueChanged<String> onOpenTask;
  final ValueChanged<String> onStartFocus;
  final ValueChanged<String> onLongPressBlock;

  String _formatTime(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final hh = (clamped ~/ 60).toString().padLeft(2, '0');
    final mm = (clamped % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final totalMinutes = (windowEndMinutes - windowStartMinutes).clamp(
      1,
      24 * 60,
    );
    final height = totalMinutes * minuteHeight;
    final gutterWidth = 62.0;

    final showNowLine =
        nowMinutes >= windowStartMinutes && nowMinutes <= windowEndMinutes;
    final nowTop = (nowMinutes - windowStartMinutes) * minuteHeight;

    final showMeta = layout == domain.TimeboxingLayout.full;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(DpRadius.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.border, width: 1),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _HourGrid(
                        windowStartMinutes: windowStartMinutes,
                        totalMinutes: totalMinutes,
                        minuteHeight: minuteHeight,
                        gutterWidth: gutterWidth,
                      ),
                    ),
                    for (final b in blocks)
                      _TimeboxBlockWidget(
                        block: b,
                        windowStartMinutes: windowStartMinutes,
                        windowEndMinutes: windowEndMinutes,
                        minuteHeight: minuteHeight,
                        gutterWidth: gutterWidth,
                        highlighted:
                            nowMinutes >= b.startMinutes &&
                            nowMinutes < b.endMinutes,
                        showMeta: showMeta,
                        formatTime: _formatTime,
                        formatDuration: _formatDuration,
                        onOpenTask: onOpenTask,
                        onStartFocus: onStartFocus,
                        onLongPress: () => onLongPressBlock(b.task.id),
                      ),
                    if (showNowLine)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: nowTop - 1,
                        child: Container(height: 2, color: colorScheme.primary),
                      ),
                    if (showNowLine)
                      Positioned(
                        left: 8,
                        top: math.max(0, nowTop - 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _formatTime(nowMinutes),
                            style: shadTheme.textTheme.small.copyWith(
                              color: colorScheme.primaryForeground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HourGrid extends StatelessWidget {
  const _HourGrid({
    required this.windowStartMinutes,
    required this.totalMinutes,
    required this.minuteHeight,
    required this.gutterWidth,
  });

  final int windowStartMinutes;
  final int totalMinutes;
  final double minuteHeight;
  final double gutterWidth;

  String _formatTime(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final hh = (clamped ~/ 60).toString().padLeft(2, '0');
    final mm = (clamped % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final fullRows = totalMinutes ~/ 60;
    final remainder = totalMinutes % 60;
    final rowCount = remainder == 0 ? fullRows : fullRows + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rowCount; i++) ...[
          SizedBox(
            height:
                (i == rowCount - 1 && remainder != 0 ? remainder : 60) *
                minuteHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: gutterWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 6),
                    child: Text(
                      _formatTime(windowStartMinutes + i * 60),
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colorScheme.border, width: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeboxBlockWidget extends StatelessWidget {
  const _TimeboxBlockWidget({
    required this.block,
    required this.windowStartMinutes,
    required this.windowEndMinutes,
    required this.minuteHeight,
    required this.gutterWidth,
    required this.highlighted,
    required this.showMeta,
    required this.formatTime,
    required this.formatDuration,
    required this.onOpenTask,
    required this.onStartFocus,
    required this.onLongPress,
  });

  final _TimeboxBlock block;
  final int windowStartMinutes;
  final int windowEndMinutes;
  final double minuteHeight;
  final double gutterWidth;
  final bool highlighted;
  final bool showMeta;
  final String Function(int minutes) formatTime;
  final String Function(int minutes) formatDuration;
  final ValueChanged<String> onOpenTask;
  final ValueChanged<String> onStartFocus;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final visibleStart = math.max(block.startMinutes, windowStartMinutes);
    final visibleEnd = math.min(block.endMinutes, windowEndMinutes);
    if (visibleEnd <= visibleStart) return const SizedBox.shrink();

    final top = (visibleStart - windowStartMinutes) * minuteHeight;
    final height = (visibleEnd - visibleStart) * minuteHeight;

    final background = highlighted
        ? colorScheme.primary.withAlpha(32)
        : colorScheme.primary.withAlpha(20);
    final borderColor = highlighted
        ? colorScheme.primary
        : colorScheme.primary.withAlpha(140);

    final canShowActions = height >= 56;

    return Positioned(
      left: gutterWidth + 8,
      right: 8,
      top: top,
      height: height,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(DpRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(DpRadius.md),
          onTap: () => onOpenTask(block.task.id),
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DpRadius.md),
              border: Border.all(
                color: borderColor,
                width: highlighted ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatTime(block.startMinutes)}–${formatTime(block.endMinutes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        block.task.title.value,
                        maxLines: showMeta ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      if (showMeta) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${block.pomodoros} 番茄 · ${formatDuration(block.minutes)}',
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
                if (canShowActions) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '开始专注',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.play_arrow, size: 18),
                      onPressed: () => onStartFocus(block.task.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeboxingInboxSheet extends ConsumerWidget {
  const _TimeboxingInboxSheet({
    required this.day,
    required this.plannedTaskIds,
  });

  final DateTime day;
  final List<String> plannedTaskIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final plannedIdsAsync = ref.watch(todayPlanTaskIdsForDayProvider(day));

    final plannedIds = plannedIdsAsync.valueOrNull ?? plannedTaskIds;
    final plannedSet = plannedIds.toSet();

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final inboxTasks =
        tasks
            .where((t) => t.triageStatus == domain.TriageStatus.inbox)
            .where((t) => t.status != domain.TaskStatus.done)
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    Future<void> addToToday(domain.Task task) async {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final todayRepo = ref.read(todayPlanRepositoryProvider);
      final update = ref.read(updateTaskUseCaseProvider);

      await todayRepo.addTask(day: normalizedDay, taskId: task.id);
      await update(
        task: task,
        title: task.title.value,
        description: task.description,
        status: task.status,
        priority: task.priority,
        dueAt: task.dueAt,
        tags: task.tags,
        estimatedPomodoros: task.estimatedPomodoros,
        triageStatus: domain.TriageStatus.plannedToday,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已加入 Today')));
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '待处理 → 安排进 Today',
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '把收件箱里的任务快速加入 Today 计划；更复杂的整理/编织请去「待处理」页。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/inbox');
                      },
                      leading: const Icon(Icons.inbox_outlined, size: 18),
                      child: const Text('打开待处理'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.md),
              Expanded(
                child: tasksAsync.when(
                  loading: () =>
                      const Center(child: ShadProgress(minHeight: 8)),
                  error: (error, stack) => DpInlineNotice(
                    variant: DpInlineNoticeVariant.destructive,
                    title: '加载失败',
                    description: '$error',
                    icon: const Icon(Icons.error_outline),
                  ),
                  data: (_) {
                    if (inboxTasks.isEmpty) {
                      return const DpEmptyState(
                        icon: Icons.inbox_outlined,
                        title: '收件箱里没有任务',
                        description: '先去「任务」或「闪念」新建，再回来安排进 Today。',
                      );
                    }

                    return ShadCard(
                      padding: EdgeInsets.zero,
                      child: ListView.separated(
                        itemCount: inboxTasks.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 0, color: colorScheme.border),
                        itemBuilder: (context, index) {
                          final task = inboxTasks[index];
                          final inToday = plannedSet.contains(task.id);
                          return ListTile(
                            title: Text(
                              task.title.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              task.tags.isEmpty
                                  ? 'Inbox'
                                  : 'Inbox · ${task.tags.take(3).join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ShadButton.secondary(
                              size: ShadButtonSize.sm,
                              onPressed: inToday
                                  ? null
                                  : () => addToToday(task),
                              child: Text(inToday ? '已在 Today' : '加入 Today'),
                            ),
                            onTap: () => context.push('/tasks/${task.id}'),
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
      ),
    );
  }
}

class _TimeboxingReorderSheet extends ConsumerStatefulWidget {
  const _TimeboxingReorderSheet({
    required this.day,
    required this.startMinutes,
    required this.workMinutes,
    required this.taskIds,
  });

  final DateTime day;
  final int startMinutes;
  final int workMinutes;
  final List<String> taskIds;

  @override
  ConsumerState<_TimeboxingReorderSheet> createState() =>
      _TimeboxingReorderSheetState();
}

class _TimeboxingReorderSheetState
    extends ConsumerState<_TimeboxingReorderSheet> {
  late List<String> _taskIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _taskIds = List<String>.from(widget.taskIds);
  }

  int _pomodorosFor(domain.Task task) {
    final est = task.estimatedPomodoros;
    return est == null || est <= 0 ? 1 : est;
  }

  String _formatTime(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final hh = (clamped ~/ 60).toString().padLeft(2, '0');
    final mm = (clamped % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h${m}m';
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(todayPlanRepositoryProvider);
      await repo.replaceTasks(
        day: widget.day,
        taskIds: List.unmodifiable(_taskIds),
        section: domain.TodayPlanSection.today,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final byId = {for (final t in tasks) t.id: t};

    _taskIds = [
      for (final id in _taskIds)
        if (byId.containsKey(id)) id,
    ];

    final blocks =
        <
          ({
            String taskId,
            String title,
            int pomodoros,
            int minutes,
            int startMinutes,
            int endMinutes,
          })
        >[];

    var cursor = widget.startMinutes;
    for (final id in _taskIds) {
      final task = byId[id];
      if (task == null) continue;
      final pomodoros = _pomodorosFor(task);
      final minutes = pomodoros * widget.workMinutes;
      final start = cursor;
      final end = start + minutes;
      blocks.add((
        taskId: id,
        title: task.title.value,
        pomodoros: pomodoros,
        minutes: minutes,
        startMinutes: start,
        endMinutes: end,
      ));
      cursor = end;
    }

    final totalMinutes = blocks.fold<int>(0, (sum, b) => sum + b.minutes);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '拖拽重排（投影顺序）',
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
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '顺序即时间轴投影顺序：从 ${_formatTime(widget.startMinutes)} 开始 · ${_formatDuration(totalMinutes)}',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              Expanded(
                child: ShadCard(
                  padding: EdgeInsets.zero,
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: blocks.length,
                    onReorder: (oldIndex, newIndex) async {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _taskIds.removeAt(oldIndex);
                        _taskIds.insert(newIndex, item);
                      });
                      await _persist();
                    },
                    itemBuilder: (context, index) {
                      final b = blocks[index];
                      return ListTile(
                        key: ValueKey('reorder_${b.taskId}'),
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(
                          '${_formatTime(b.startMinutes)}–${_formatTime(b.endMinutes)} · ${b.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${b.pomodoros} 番茄 · ${_formatDuration(b.minutes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => context.push('/tasks/${b.taskId}'),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadButton.outline(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                leading: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 18),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeboxBlockActionsSheet extends ConsumerStatefulWidget {
  const _TimeboxBlockActionsSheet({
    required this.task,
    required this.initialPomodoros,
    required this.workMinutes,
  });

  final domain.Task task;
  final int initialPomodoros;
  final int workMinutes;

  @override
  ConsumerState<_TimeboxBlockActionsSheet> createState() =>
      _TimeboxBlockActionsSheetState();
}

class _TimeboxBlockActionsSheetState
    extends ConsumerState<_TimeboxBlockActionsSheet> {
  late int _pomodoros;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pomodoros = widget.initialPomodoros <= 0 ? 1 : widget.initialPomodoros;
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h${m}m';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final update = ref.read(updateTaskUseCaseProvider);
      await update(
        task: widget.task,
        title: widget.task.title.value,
        description: widget.task.description,
        status: widget.task.status,
        priority: widget.task.priority,
        dueAt: widget.task.dueAt,
        tags: widget.task.tags,
        estimatedPomodoros: _pomodoros,
        triageStatus: widget.task.triageStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已更新预计番茄')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final minutes = _pomodoros * widget.workMinutes;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.task.title.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: shadTheme.textTheme.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                Tooltip(
                  message: '关闭',
                  child: ShadIconButton.ghost(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '快速调整预计番茄（影响时间轴投影）。长按时间块可随时打开。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: DpSpacing.md),
            ShadCard(
              padding: const EdgeInsets.all(DpSpacing.md),
              title: Text(
                '预计时长',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: '减少',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _saving || _pomodoros <= 1
                          ? null
                          : () => setState(() => _pomodoros -= 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '$_pomodoros 番茄',
                          style: shadTheme.textTheme.h4.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDuration(minutes)}（${widget.workMinutes}m/番茄）',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '增加',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _pomodoros += 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DpSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ShadButton.secondary(
                    onPressed: _saving
                        ? null
                        : () {
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.push('/tasks/${widget.task.id}');
                          },
                    leading: const Icon(Icons.open_in_new, size: 18),
                    child: const Text('打开任务'),
                  ),
                ),
                const SizedBox(width: DpSpacing.sm),
                Expanded(
                  child: ShadButton(
                    onPressed: _saving
                        ? null
                        : () {
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.push('/focus?taskId=${widget.task.id}');
                          },
                    leading: const Icon(Icons.play_arrow, size: 18),
                    child: const Text('开始专注'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.sm),
            ShadButton.outline(
              onPressed: _saving ? null : _save,
              leading: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              child: const Text('保存预计番茄'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeboxingSettingsSheet extends ConsumerWidget {
  const _TimeboxingSettingsSheet({
    required this.config,
    required this.startMinutes,
  });

  final domain.AppearanceConfig config;
  final int startMinutes;

  String _formatTime(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final hh = (clamped ~/ 60).toString().padLeft(2, '0');
    final mm = (clamped % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final repo = ref.read(appearanceConfigRepositoryProvider);

    Future<void> pickStartTime() async {
      final picked = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => TimePickerSheet(
          title: '时间轴开始时间',
          initialMinutes: startMinutes,
          stepMinutes: 5,
        ),
      );
      if (picked == null) return;
      final current = await repo.get();
      await repo.save(
        current.copyWith(timeboxingStartMinutes: picked.clamp(0, 24 * 60 - 1)),
      );
    }

    Future<void> pickWorkdayStart() async {
      final picked = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => TimePickerSheet(
          title: '工作时段开始',
          initialMinutes: config.timeboxingWorkdayStartMinutes,
          stepMinutes: 15,
        ),
      );
      if (picked == null) return;
      final current = await repo.get();
      await repo.save(
        current.copyWith(
          timeboxingWorkdayStartMinutes: picked.clamp(0, 24 * 60 - 1),
        ),
      );
    }

    Future<void> pickWorkdayEnd() async {
      final picked = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => TimePickerSheet(
          title: '工作时段结束',
          initialMinutes: config.timeboxingWorkdayEndMinutes,
          stepMinutes: 15,
        ),
      );
      if (picked == null) return;
      final current = await repo.get();
      await repo.save(
        current.copyWith(
          timeboxingWorkdayEndMinutes: picked.clamp(0, 24 * 60 - 1),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '时间轴设置',
                    style: shadTheme.textTheme.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                Tooltip(
                  message: '关闭',
                  child: ShadIconButton.ghost(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.md),
            ShadCard(
              padding: DpInsets.card,
              title: Text(
                '布局',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              child: ShadSelect<domain.TimeboxingLayout>(
                initialValue: config.timeboxingLayout,
                selectedOptionBuilder: (context, value) => Text(
                  switch (value) {
                    domain.TimeboxingLayout.full => 'Full',
                    domain.TimeboxingLayout.minimal => 'Minimal',
                  },
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: const [
                  ShadOption(
                    value: domain.TimeboxingLayout.full,
                    child: Text('Full'),
                  ),
                  ShadOption(
                    value: domain.TimeboxingLayout.minimal,
                    child: Text('Minimal'),
                  ),
                ],
                onChanged: (next) async {
                  if (next == null || next == config.timeboxingLayout) return;
                  final current = await repo.get();
                  await repo.save(current.copyWith(timeboxingLayout: next));
                },
              ),
            ),
            const SizedBox(height: DpSpacing.md),
            ShadCard(
              padding: DpInsets.card,
              title: Text(
                '时间范围',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadButton.outline(
                    onPressed: pickStartTime,
                    leading: const Icon(Icons.schedule_outlined, size: 18),
                    child: Text('开始时间：${_formatTime(startMinutes)}'),
                  ),
                  const SizedBox(height: DpSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: ShadButton.outline(
                          onPressed: pickWorkdayStart,
                          child: Text(
                            '工作开始：${_formatTime(config.timeboxingWorkdayStartMinutes)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: DpSpacing.sm),
                      Expanded(
                        child: ShadButton.outline(
                          onPressed: pickWorkdayEnd,
                          child: Text(
                            '工作结束：${_formatTime(config.timeboxingWorkdayEndMinutes)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: DpSpacing.md),
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}

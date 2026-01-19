import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/kit/dp_section_card.dart';
import '../../../ui/sheets/time_picker_sheet.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../../core/providers/app_providers.dart';
import '../providers/timeboxing_providers.dart';

class TodayTimeboxingCard extends ConsumerWidget {
  const TodayTimeboxingCard({
    super.key,
    required this.planTasks,
    required this.workMinutes,
    required this.onEditPlan,
  });

  final List<domain.Task> planTasks;
  final int workMinutes;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final startMinutes = ref.watch(timeboxingStartMinutesProvider);
    final appearance = ref.watch(appearanceConfigProvider).maybeWhen(
      data: (c) => c,
      orElse: () => const domain.AppearanceConfig(),
    );

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

    int pomodorosFor(domain.Task task) {
      final est = task.estimatedPomodoros;
      return est == null || est <= 0 ? 1 : est;
    }

    final blocks =
        <
          ({
            domain.Task task,
            int pomodoros,
            int minutes,
            int startMinutes,
            int endMinutes,
          })
        >[];

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
    final overloaded = planTasks.isNotEmpty && endMinutes > workdayEnd;
    final overloadMinutes = overloaded ? endMinutes - workdayEnd : 0;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    String formatTime(int minutes) {
      final clamped = minutes.clamp(0, 24 * 60 - 1);
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
      final repo = ref.read(appearanceConfigRepositoryProvider);
      final current = await repo.get();
      await repo.save(
        current.copyWith(timeboxingStartMinutes: picked.clamp(0, 24 * 60 - 1)),
      );
    }

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '开始时间',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.schedule_outlined, size: 18),
            onPressed: pickStartTime,
          ),
        ),
        Tooltip(
          message: '全屏画布',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.open_in_full, size: 18),
            onPressed: () => context.push('/today/timeboxing'),
          ),
        ),
        Tooltip(
          message: '编辑今天计划',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.tune_outlined, size: 18),
            onPressed: onEditPlan,
          ),
        ),
      ],
    );

    if (planTasks.isEmpty) {
      return DpSectionCard(
        title: '时间轴',
        subtitle: '把 3–5 条任务装入今天计划后，就能投影一个可执行时间线。',
        trailing: trailing,
        child: ShadButton.outline(
          onPressed: onEditPlan,
          child: const Text('去编辑今天计划'),
        ),
      );
    }

    final summaryText =
        '从 ${formatTime(startMinutes)} 开始 · 预计 ${formatTime(endMinutes)} 结束'
        ' · ${formatDuration(totalMinutes)}';

    return DpSectionCard(
      title: '时间轴',
      subtitle: summaryText,
      trailing: trailing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ShadBadge.outline(child: Text('$totalPomodoros 番茄')),
              const SizedBox(width: 8),
              ShadBadge.outline(child: Text('${workMinutes}m/番茄')),
              const SizedBox(width: 8),
              ShadBadge.outline(
                child: Text(
                  '${formatTime(workdayStart)}–${formatTime(workdayEnd)}',
                ),
              ),
              if (overloaded) ...[
                const SizedBox(width: 8),
                ShadBadge.destructive(
                  child: Text('超出 ${formatDuration(overloadMinutes)}'),
                ),
              ],
            ],
          ),
          const SizedBox(height: DpSpacing.sm),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.border, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var i = 0; i < blocks.length; i++) ...[
                  if (i != 0) Divider(height: 0, color: colorScheme.border),
                  _TimeboxRow(
                    title: blocks[i].task.title.value,
                    startLabel: formatTime(blocks[i].startMinutes),
                    endLabel: formatTime(blocks[i].endMinutes),
                    metaLabel:
                        '${blocks[i].pomodoros} 番茄 · ${formatDuration(blocks[i].minutes)}',
                    highlighted:
                        nowMinutes >= blocks[i].startMinutes &&
                        nowMinutes < blocks[i].endMinutes,
                    onOpenTask: () =>
                        context.push('/tasks/${blocks[i].task.id}'),
                    onStartFocus: () =>
                        context.push('/focus?taskId=${blocks[i].task.id}'),
                  ),
                ],
              ],
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
    );
  }
}

class _TimeboxRow extends StatelessWidget {
  const _TimeboxRow({
    required this.title,
    required this.startLabel,
    required this.endLabel,
    required this.metaLabel,
    required this.highlighted,
    required this.onOpenTask,
    required this.onStartFocus,
  });

  final String title;
  final String startLabel;
  final String endLabel;
  final String metaLabel;
  final bool highlighted;
  final VoidCallback onOpenTask;
  final VoidCallback onStartFocus;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final background = highlighted
        ? colorScheme.primary.withAlpha(28)
        : Colors.transparent;

    return Material(
      color: background,
      child: InkWell(
        onTap: onOpenTask,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DpSpacing.md,
            vertical: DpSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 74,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$startLabel–$endLabel',
                      style: shadTheme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metaLabel,
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DpSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: DpSpacing.sm),
              Tooltip(
                message: '开始专注',
                child: ShadIconButton.ghost(
                  icon: const Icon(Icons.play_arrow, size: 18),
                  onPressed: onStartFocus,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

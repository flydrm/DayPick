import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/kit/dp_section_card.dart';
import '../../../ui/sheets/quick_create_sheet.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../focus/providers/focus_providers.dart';
import '../../notes/providers/note_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/today_plan_providers.dart';
import 'today_plan_edit_sheet.dart';

class TodayPlanningRitualSheet extends ConsumerWidget {
  const TodayPlanningRitualSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final notesAsync = ref.watch(unprocessedNotesStreamProvider);
    final planIdsAsync = ref.watch(todayPlanTaskIdsProvider);
    final configAsync = ref.watch(pomodoroConfigProvider);
    final activePomodoroAsync = ref.watch(activePomodoroProvider);

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final notes = notesAsync.valueOrNull ?? const <domain.Note>[];
    final inboxTaskCount = tasks
        .where((t) => t.triageStatus == domain.TriageStatus.inbox)
        .length;
    final inboxMemoCount = notes
        .where((n) => n.kind == domain.NoteKind.memo)
        .length;
    final inboxDraftCount = notes
        .where((n) => n.kind == domain.NoteKind.draft)
        .length;

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    final planIds = planIdsAsync.valueOrNull ?? const <String>[];
    final taskById = {for (final t in tasks) t.id: t};
    final planTasks = <domain.Task>[
      for (final id in planIds)
        if (taskById[id] != null) taskById[id]!,
    ];

    final config = configAsync.valueOrNull ?? const domain.PomodoroConfig();
    final budgetPomodoros = config.dailyBudgetPomodoros < 0
        ? 0
        : config.dailyBudgetPomodoros;
    final plannedPomodoros = _plannedPomodoros(planTasks);
    final overBudget =
        budgetPomodoros > 0 && plannedPomodoros > budgetPomodoros;

    final rule = const domain.TodayQueueRule(maxItems: 5);
    final suggestion = rule(tasks, now);
    final nextTask = planTasks.isNotEmpty
        ? planTasks.first
        : suggestion.nextStep;

    final active = activePomodoroAsync.valueOrNull;
    final activeTask = active == null ? null : taskById[active.taskId];

    final showBudget = budgetPomodoros > 0 || plannedPomodoros > 0;
    final planSummary = planIdsAsync.isLoading
        ? '加载中…'
        : planIdsAsync.hasError
        ? '加载失败'
        : '已选 ${planTasks.length} 条'
              '${showBudget ? ' · $plannedPomodoros/${budgetPomodoros <= 0 ? '∞' : budgetPomodoros} 番茄' : ''}';

    final bottomPadding =
        DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: bottomPadding,
        ),
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '计划仪式',
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
                '把今天收敛到可执行：处理待处理 → 选 3–5 条 → 检查预算 → 开始专注。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DpSectionCard(
                        title: '1) 清理待处理',
                        subtitle: '先把新收内容清到可控（不强迫当下整理细节）。',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '任务 $inboxTaskCount · 闪念 $inboxMemoCount · 草稿 $inboxDraftCount',
                              style: shadTheme.textTheme.small.copyWith(
                                color: colorScheme.foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: DpSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: ShadButton(
                                    onPressed:
                                        (inboxTaskCount +
                                                inboxMemoCount +
                                                inboxDraftCount) ==
                                            0
                                        ? null
                                        : () {
                                            Navigator.of(context).pop();
                                            context.push('/inbox/process');
                                          },
                                    child: const Text('处理模式'),
                                  ),
                                ),
                                const SizedBox(width: DpSpacing.sm),
                                Expanded(
                                  child: ShadButton.outline(
                                    onPressed: () async {
                                      await showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        builder: (context) =>
                                            const QuickCreateSheet(
                                              initialType: QuickCreateType.memo,
                                            ),
                                      );
                                    },
                                    child: const Text('先收一条闪念'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DpSpacing.md),
                      DpSectionCard(
                        title: '2) 装入今天计划',
                        subtitle: planSummary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (overBudget)
                              const DpInlineNotice(
                                variant: DpInlineNoticeVariant.destructive,
                                title: '今天可能过载',
                                description: '建议先收敛到 3–5 条，或把低优先级任务移到以后。',
                                icon: Icon(Icons.warning_amber_outlined),
                              ),
                            if (overBudget)
                              const SizedBox(height: DpSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: ShadButton.secondary(
                                    onPressed: planIdsAsync.isLoading
                                        ? null
                                        : () async {
                                            await showModalBottomSheet<void>(
                                              context: context,
                                              isScrollControlled: true,
                                              useSafeArea: true,
                                              builder: (context) =>
                                                  const TodayPlanEditSheet(),
                                            );
                                          },
                                    child: const Text('编辑计划'),
                                  ),
                                ),
                                const SizedBox(width: DpSpacing.sm),
                                Expanded(
                                  child: ShadButton.outline(
                                    onPressed:
                                        planIdsAsync.isLoading ||
                                            tasksAsync.isLoading ||
                                            suggestion.todayQueue.isEmpty
                                        ? null
                                        : () => _fillPlanFromSuggested(
                                            ref,
                                            context,
                                            day: day,
                                            suggested: suggestion.todayQueue,
                                          ),
                                    child: const Text('用建议填充'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DpSpacing.md),
                      DpSectionCard(
                        title: '3) 进入专注',
                        subtitle: active == null ? '下一步' : '进行中',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (active == null && nextTask == null)
                              const Text('先去「任务」新增一条任务，或去「待处理」整理。')
                            else
                              Text(
                                active == null
                                    ? (nextTask?.title.value ?? '')
                                    : (activeTask?.title.value ?? '专注进行中'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: shadTheme.textTheme.small.copyWith(
                                  color: colorScheme.foreground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: DpSpacing.sm),
                            ShadButton(
                              onPressed: (active == null && nextTask == null)
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                      final taskId =
                                          (active?.taskId ?? nextTask?.id);
                                      if (taskId == null) {
                                        context.push('/focus');
                                        return;
                                      }
                                      context.push('/focus?taskId=$taskId');
                                    },
                              child: Text(active == null ? '去开始专注' : '回到专注'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Future<void> _fillPlanFromSuggested(
    WidgetRef ref,
    BuildContext context, {
    required DateTime day,
    required List<domain.Task> suggested,
  }) async {
    final ids = suggested.map((t) => t.id).toList(growable: false);
    await ref
        .read(todayPlanRepositoryProvider)
        .replaceTasks(day: day, taskIds: ids);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已填充 ${ids.length} 条计划')));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const TodayPlanEditSheet(),
    );
  }
}

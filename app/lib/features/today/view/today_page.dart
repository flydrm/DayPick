import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../core/providers/app_providers.dart';
import '../../focus/providers/focus_providers.dart';
import '../../notes/providers/note_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/view/task_list_item.dart';
import '../providers/today_plan_providers.dart';
import 'today_plan_edit_sheet.dart';
import 'today_daily_log_sheet.dart';
import 'today_planning_ritual_sheet.dart';
import 'today_onboarding_card.dart';
import 'today_timeboxing_card.dart';
import 'today_weave_card.dart';
import 'today_workbench_edit_sheet.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  bool _dismissedOnboarding = false;
  bool _autoMarkOnboardingRequested = false;
  bool _savingOnboardingDone = false;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final tasksAsync = ref.watch(tasksStreamProvider);
    final unprocessedNotesAsync = ref.watch(unprocessedNotesStreamProvider);
    final sessionsAsync = ref.watch(todayPomodoroSessionsProvider);
    final yesterdaySessionsAsync = ref.watch(yesterdayPomodoroSessionsProvider);
    final anySessionCountAsync = ref.watch(anyPomodoroSessionCountProvider);
    final planIdsAsync = ref.watch(todayPlanTaskIdsProvider);
    final eveningPlanIdsAsync = ref.watch(todayEveningPlanTaskIdsProvider);
    final yesterdayPlanIdsAsync = ref.watch(
      todayPlanTaskIdsForDayProvider(yesterday),
    );
    final yesterdayEveningPlanIdsAsync = ref.watch(
      todayEveningPlanTaskIdsForDayProvider(yesterday),
    );
    final activePomodoroAsync = ref.watch(activePomodoroProvider);
    final configAsync = ref.watch(pomodoroConfigProvider);
    final appearanceAsync = ref.watch(appearanceConfigProvider);
    final config = configAsync.maybeWhen(
      data: (c) => c,
      orElse: () => const domain.PomodoroConfig(),
    );
    final appearance = appearanceAsync.maybeWhen(
      data: (c) => c,
      orElse: () => const domain.AppearanceConfig(),
    );
    final workMinutes = configAsync.maybeWhen(
      data: (c) => c.workDurationMinutes,
      orElse: () => 25,
    );
    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final inboxNotes =
        unprocessedNotesAsync.valueOrNull ?? const <domain.Note>[];
    final inboxTaskCount = tasks
        .where((t) => t.triageStatus == domain.TriageStatus.inbox)
        .length;
    final inboxCount = inboxTaskCount + inboxNotes.length;
    final anySessionCount = anySessionCountAsync.valueOrNull ?? 0;
    final byId = {for (final t in tasks) t.id: t};
    final planIds = planIdsAsync.valueOrNull ?? const <String>[];
    final eveningPlanIds = eveningPlanIdsAsync.valueOrNull ?? const <String>[];
    final planTasks = <domain.Task>[
      for (final id in planIds)
        if (byId[id] != null) byId[id]!,
    ];
    final eveningPlanTasks = <domain.Task>[
      for (final id in eveningPlanIds)
        if (byId[id] != null) byId[id]!,
    ];
    final carryOver = _carryOverFromYesterday(
      yesterdayPlanIds: [
        ...(yesterdayPlanIdsAsync.valueOrNull ?? const <String>[]),
        ...(yesterdayEveningPlanIdsAsync.valueOrNull ?? const <String>[]),
      ],
      todayPlanIds: [...planIds, ...eveningPlanIds],
      tasksById: byId,
    );
    final dailyBudgetPomodoros = config.dailyBudgetPomodoros < 0
        ? 0
        : config.dailyBudgetPomodoros;
    final plannedPomodoros = _plannedPomodoros(planTasks);
    final modules = appearance.todayModules;

    final rule = const domain.TodayQueueRule(maxItems: 5);
    final result = rule(tasks, now);
    final nextStep = planTasks.isNotEmpty ? planTasks.first : result.nextStep;
    final nextStepReason = _nextStepReason(
      task: nextStep,
      fromPlan: planTasks.isNotEmpty,
      now: now,
    );

    final activePomodoro = activePomodoroAsync.valueOrNull;
    final activeTask = activePomodoro == null
        ? null
        : byId[activePomodoro.taskId];

    final children = <Widget>[];

    void addModule(Widget widget) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: DpSpacing.lg));
      }
      children.add(widget);
    }

    if (tasksAsync.isLoading) {
      children.addAll(const [
        ShadProgress(minHeight: 8),
        SizedBox(height: DpSpacing.md),
      ]);
    } else if (tasksAsync.hasError) {
      children.addAll([
        DpInlineNotice(
          variant: DpInlineNoticeVariant.destructive,
          title: '任务加载失败',
          description: '${tasksAsync.error}',
          icon: const Icon(Icons.error_outline),
        ),
        const SizedBox(height: 12),
      ]);
    }

    final onboardingReady =
        tasksAsync.hasValue &&
        unprocessedNotesAsync.hasValue &&
        anySessionCountAsync.hasValue;
    final onboardingAllDone =
        inboxCount == 0 && planTasks.isNotEmpty && anySessionCount > 0;
    final onboardingDismissed =
        _dismissedOnboarding || appearance.onboardingDone;
    if (onboardingReady &&
        onboardingAllDone &&
        !onboardingDismissed &&
        !_autoMarkOnboardingRequested) {
      _autoMarkOnboardingRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _persistOnboardingDone();
      });
    }

    if (onboardingReady && !onboardingDismissed && !onboardingAllDone) {
      addModule(
        TodayOnboardingCard(
          inboxCount: inboxCount,
          planCount: planTasks.length,
          sessionCount: anySessionCount,
          onOpenInbox: () => context.push('/inbox'),
          onOpenCanvas: () => context.push('/today/timeboxing'),
          onOpenFocus: () => context.push('/focus'),
          onDismiss: _persistOnboardingDone,
        ),
      );
    }

    if (modules.isEmpty) {
      addModule(
        ShadCard(
          padding: const EdgeInsets.all(16),
          title: const Text('Today 工作台为空'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('你可以打开编辑器恢复默认布局，或重新组合模块。'),
              const SizedBox(height: 12),
              ShadButton(
                onPressed: () => _openWorkbenchEditor(context, appearance),
                child: const Text('编辑工作台'),
              ),
            ],
          ),
        ),
      );
    } else {
      for (final m in modules) {
        switch (m) {
          case domain.TodayWorkbenchModule.quickAdd:
            break;
          case domain.TodayWorkbenchModule.capture:
            addModule(
              ShadCard(
                key: const ValueKey('today_capture_module'),
                padding: const EdgeInsets.all(16),
                title: const Text('捕捉'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '快速创建会进入 Inbox；任务可直接加入今天计划。',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ShadButton.outline(
                          key: const ValueKey('today_capture_task'),
                          size: ShadButtonSize.sm,
                          leading: const Icon(
                            Icons.add_task_outlined,
                            size: 16,
                          ),
                          onPressed: () => context.push(
                            '/create?type=task&addToToday=1',
                          ),
                          child: const Text('任务'),
                        ),
                        ShadButton.outline(
                          key: const ValueKey('today_capture_memo'),
                          size: ShadButtonSize.sm,
                          leading: const Icon(Icons.bolt_outlined, size: 16),
                          onPressed: () => context.push('/create?type=memo'),
                          child: const Text('闪念'),
                        ),
                        ShadButton.outline(
                          key: const ValueKey('today_capture_draft'),
                          size: ShadButtonSize.sm,
                          leading: const Icon(
                            Icons.description_outlined,
                            size: 16,
                          ),
                          onPressed: () => context.push('/create?type=draft'),
                          child: const Text('长文草稿'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            break;
          case domain.TodayWorkbenchModule.weave:
            addModule(const TodayWeaveCard());
            break;
          case domain.TodayWorkbenchModule.shortcuts:
            addModule(
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () => context.push('/ai/breakdown'),
                      leading: const Icon(
                        Icons.auto_awesome_outlined,
                        size: 16,
                      ),
                      child: const Text('AI 拆任务'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () => context.push('/tasks'),
                      leading: const Icon(Icons.list_alt_outlined, size: 16),
                      child: const Text('任务列表'),
                    ),
                  ),
                ],
              ),
            );
            break;
          case domain.TodayWorkbenchModule.budget:
            addModule(
              _TodayBudgetCard(
                dailyBudgetPomodoros: dailyBudgetPomodoros,
                plannedPomodoros: plannedPomodoros,
                workMinutes: workMinutes,
                loading: tasksAsync.isLoading || planIdsAsync.isLoading,
                onEditPlan: () => _openPlanEditor(context),
                onOpenSettings: () => context.push('/settings/pomodoro'),
              ),
            );
            break;
          case domain.TodayWorkbenchModule.focus:
            addModule(
              _TodayFocusCard(
                tasks: tasks,
                sessionsAsync: sessionsAsync,
                workMinutes: workMinutes,
              ),
            );
            break;
          case domain.TodayWorkbenchModule.nextStep:
            addModule(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle(activePomodoro == null ? '下一步' : '进行中'),
                  const SizedBox(height: 8),
                  if (activePomodoro == null)
                    _NextStepCard(task: nextStep, reason: nextStepReason)
                  else
                    _InProgressCard(active: activePomodoro, task: activeTask),
                ],
              ),
            );
            break;
          case domain.TodayWorkbenchModule.todayPlan:
            addModule(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: _SectionTitle('今天计划')),
                      ShadButton.ghost(
                        onPressed: () => context.push('/ai/today-plan'),
                        size: ShadButtonSize.sm,
                        leading: const Icon(
                          Icons.auto_awesome_outlined,
                          size: 16,
                        ),
                        child: const Text('AI 草稿'),
                      ),
                      ShadIconButton.ghost(
                        icon: const Icon(Icons.tune_outlined, size: 18),
                        onPressed: () => _openPlanEditor(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (carryOver.isNotEmpty)
                    _CarryOverCard(
                      tasks: carryOver.take(3).toList(growable: false),
                      totalCount: carryOver.length,
                      onApply: planIdsAsync.isLoading
                          ? null
                          : () => _applyCarryOver(
                              context,
                              day: today,
                              todayPlanIds: planIds,
                              carryOverIds: [for (final t in carryOver) t.id],
                            ),
                      onOpenPlan: () => _openPlanEditor(context),
                    ),
                  if (planIdsAsync.isLoading)
                    const ShadProgress(minHeight: 8)
                  else if (planIdsAsync.hasError)
                    Text('今天计划加载失败：${planIdsAsync.error}')
                  else if (planTasks.isNotEmpty)
                    ShadCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < planTasks.length; i++) ...[
                            TaskListItem(
                              task: planTasks[i],
                              onTap: () =>
                                  context.push('/tasks/${planTasks[i].id}'),
                              trailing: Tooltip(
                                message: '移到 This Evening',
                                child: ShadIconButton.ghost(
                                  icon: const Icon(
                                    Icons.nights_stay_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(todayPlanRepositoryProvider)
                                        .moveTaskToSection(
                                          day: today,
                                          taskId: planTasks[i].id,
                                          section:
                                              domain.TodayPlanSection.evening,
                                        );
                                  },
                                ),
                              ),
                            ),
                            if (i != planTasks.length - 1)
                              Divider(
                                height: 0,
                                color: ShadTheme.of(context).colorScheme.border,
                              ),
                          ],
                        ],
                      ),
                    )
                  else if (tasksAsync.isLoading)
                    const Text('加载中…')
                  else if (result.todayQueue.isEmpty)
                    const Text('今天还没有可执行任务。去添加一条，或用 AI 拆任务更快。')
                  else
                    ShadCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('还没有“今天计划”。'),
                          const SizedBox(height: 6),
                          Text(
                            '先从自动建议队列开始：逾期/今天到期优先，其余按优先级补齐。',
                            style: shadTheme.textTheme.muted.copyWith(
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ShadCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < result.todayQueue.length;
                                  i++
                                ) ...[
                                  TaskListItem(
                                    key: ValueKey(
                                      'today_queue_suggested:${result.todayQueue[i].id}',
                                    ),
                                    task: result.todayQueue[i],
                                    dense: true,
                                    onTap: () => context.push(
                                      '/tasks/${result.todayQueue[i].id}',
                                    ),
                                  ),
                                  if (i != result.todayQueue.length - 1)
                                    Divider(
                                      height: 0,
                                      color: ShadTheme.of(
                                        context,
                                      ).colorScheme.border,
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ShadButton.secondary(
                                  onPressed: () => _fillPlanFromSuggested(
                                    context,
                                    result.todayQueue,
                                  ),
                                  child: const Text('用建议填充（可编辑）'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ShadButton.outline(
                                  onPressed: () => _openPlanEditor(context),
                                  child: const Text('编辑今天计划'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (eveningPlanIdsAsync.isLoading) ...[
                    const SizedBox(height: 12),
                    const ShadProgress(minHeight: 8),
                  ] else if (eveningPlanIdsAsync.hasError) ...[
                    const SizedBox(height: 12),
                    Text('This Evening 加载失败：${eveningPlanIdsAsync.error}'),
                  ] else if (eveningPlanTasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _SectionTitle('This Evening'),
                    const SizedBox(height: 8),
                    ShadCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < eveningPlanTasks.length; i++) ...[
                            TaskListItem(
                              task: eveningPlanTasks[i],
                              onTap: () => context.push(
                                '/tasks/${eveningPlanTasks[i].id}',
                              ),
                              trailing: Tooltip(
                                message: '移回 Today',
                                child: ShadIconButton.ghost(
                                  icon: const Icon(
                                    Icons.wb_sunny_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    await ref
                                        .read(todayPlanRepositoryProvider)
                                        .moveTaskToSection(
                                          day: today,
                                          taskId: eveningPlanTasks[i].id,
                                          section:
                                              domain.TodayPlanSection.today,
                                        );
                                  },
                                ),
                              ),
                            ),
                            if (i != eveningPlanTasks.length - 1)
                              Divider(
                                height: 0,
                                color: ShadTheme.of(context).colorScheme.border,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
            break;
          case domain.TodayWorkbenchModule.timeboxing:
            addModule(
              TodayTimeboxingCard(
                planTasks: planTasks,
                workMinutes: workMinutes,
                onEditPlan: () => _openPlanEditor(context),
              ),
            );
            break;
          case domain.TodayWorkbenchModule.yesterdayReview:
            addModule(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle('昨天回顾'),
                  const SizedBox(height: 8),
                  _YesterdayReviewCard(
                    tasks: tasks,
                    sessionsAsync: yesterdaySessionsAsync,
                  ),
                ],
              ),
            );
            break;
          case domain.TodayWorkbenchModule.stats:
            if (!appearance.statsEnabled) break;
            addModule(
              ShadCard(
                padding: const EdgeInsets.all(16),
                title: const Text('统计/热力图'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('近 12 周节奏与热力图（默认关闭，可在工作台编辑中开启）。'),
                    const SizedBox(height: 12),
                    ShadButton.outline(
                      onPressed: () => context.push('/stats'),
                      child: const Text('查看统计'),
                    ),
                  ],
                ),
              ),
            );
            break;
        }
      }
    }

    return AppPageScaffold(
      title: '今天',
      createRoute: '/create?addToToday=1',
      actions: [
        Tooltip(
          message: '计划仪式',
          child: SizedBox(
            key: const ValueKey('today_planning_ritual_action'),
            child: ShadIconButton.ghost(
              icon: const Icon(Icons.check_circle_outline, size: 20),
              onPressed: () => _openPlanningRitual(context),
            ),
          ),
        ),
        Tooltip(
          message: '今日记录',
          child: SizedBox(
            key: const ValueKey('today_daily_log_action'),
            child: ShadIconButton.ghost(
              icon: const Icon(Icons.description_outlined, size: 20),
              onPressed: () => _openDailyLog(context),
            ),
          ),
        ),
        Tooltip(
          message: '时间轴',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.view_timeline_outlined, size: 20),
            onPressed: () => context.push('/today/timeboxing'),
          ),
        ),
        Tooltip(
          message: '编辑工作台',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.dashboard_customize_outlined, size: 20),
            onPressed: () => _openWorkbenchEditor(context, appearance),
          ),
        ),
        Tooltip(
          message: '待处理',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.inbox_outlined, size: 20),
            onPressed: () => context.push('/inbox'),
          ),
        ),
      ],
      body: ListView(padding: DpInsets.page, children: children),
    );
  }

  Future<void> _persistOnboardingDone() async {
    if (_savingOnboardingDone) return;
    _savingOnboardingDone = true;

    if (mounted) setState(() => _dismissedOnboarding = true);

    try {
      final repo = ref.read(appearanceConfigRepositoryProvider);
      final current = await ref.read(appearanceConfigProvider.future);
      if (current.onboardingDone) return;
      await repo.save(current.copyWith(onboardingDone: true));
    } catch (_) {
    } finally {
      _savingOnboardingDone = false;
    }
  }

  Future<void> _openPlanningRitual(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const TodayPlanningRitualSheet(),
    );
  }

  Future<void> _openDailyLog(BuildContext context) async {
    final noteId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const TodayDailyLogSheet(),
    );
    if (noteId == null) return;
    if (!context.mounted) return;
    context.push('/notes/$noteId');
  }

  Future<void> _openWorkbenchEditor(
    BuildContext context,
    domain.AppearanceConfig config,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TodayWorkbenchEditSheet(config: config),
    );
  }

  Future<void> _openPlanEditor(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const TodayPlanEditSheet(),
    );
  }

  Future<void> _fillPlanFromSuggested(
    BuildContext context,
    List<domain.Task> suggested,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final ids = suggested.map((t) => t.id).toList();
    await ref
        .read(todayPlanRepositoryProvider)
        .replaceTasks(day: day, taskIds: ids);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已填充 ${ids.length} 条计划')));
    await _openPlanEditor(context);
  }

  int _plannedPomodoros(List<domain.Task> planTasks) {
    var sum = 0;
    for (final task in planTasks) {
      final est = task.estimatedPomodoros;
      sum += est == null || est <= 0 ? 1 : est;
    }
    return sum;
  }

  List<domain.Task> _carryOverFromYesterday({
    required List<String> yesterdayPlanIds,
    required List<String> todayPlanIds,
    required Map<String, domain.Task> tasksById,
  }) {
    if (yesterdayPlanIds.isEmpty) return const [];
    final todaySet = todayPlanIds.toSet();
    final carry = <domain.Task>[];
    for (final id in yesterdayPlanIds) {
      if (todaySet.contains(id)) continue;
      final task = tasksById[id];
      if (task == null) continue;
      if (task.status == domain.TaskStatus.done) continue;
      if (task.triageStatus == domain.TriageStatus.archived) continue;
      if (task.triageStatus == domain.TriageStatus.inbox) continue;
      carry.add(task);
    }
    return carry;
  }

  String? _nextStepReason({
    required domain.Task? task,
    required bool fromPlan,
    required DateTime now,
  }) {
    if (task == null) return null;
    if (fromPlan) return '来自今天计划置顶条目';

    final startOfToday = DateTime(now.year, now.month, now.day);
    final dueAt = task.dueAt;
    if (dueAt != null) {
      final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
      if (dueDate.isBefore(startOfToday)) return '自动规则：逾期任务置顶';
      if (dueDate == startOfToday) return '自动规则：今天到期置顶';
    }
    return '自动规则：优先级 → 到期 → 创建时间';
  }

  Future<void> _applyCarryOver(
    BuildContext context, {
    required DateTime day,
    required List<String> todayPlanIds,
    required List<String> carryOverIds,
  }) async {
    if (carryOverIds.isEmpty) return;
    final merged = [...todayPlanIds, ...carryOverIds];
    await ref
        .read(todayPlanRepositoryProvider)
        .replaceTasks(day: day, taskIds: merged);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已结转 ${carryOverIds.length} 条到今天计划')),
    );
    await _openPlanEditor(context);
  }
}

class _TodayBudgetCard extends StatelessWidget {
  const _TodayBudgetCard({
    required this.dailyBudgetPomodoros,
    required this.plannedPomodoros,
    required this.workMinutes,
    required this.loading,
    required this.onEditPlan,
    required this.onOpenSettings,
  });

  final int dailyBudgetPomodoros;
  final int plannedPomodoros;
  final int workMinutes;
  final bool loading;
  final VoidCallback onEditPlan;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final budget = dailyBudgetPomodoros;
    final planned = plannedPomodoros;
    final over = budget > 0 && planned > budget;

    final budgetLabel = budget <= 0 ? '不限制' : '$budget 番茄';
    final plannedLabel = loading ? '…' : '$planned 番茄';

    final budgetMinutes = budget <= 0 ? null : budget * workMinutes;
    final plannedMinutes = planned * workMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '今日预算',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '预算：$budgetLabel'
                      '${budgetMinutes == null ? '' : '（约 $budgetMinutes 分钟）'}',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '已计划：$plannedLabel（约 $plannedMinutes 分钟）',
                      textAlign: TextAlign.right,
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: onEditPlan,
                      size: ShadButtonSize.sm,
                      leading: const Icon(Icons.tune_outlined, size: 16),
                      child: const Text('编辑今天计划'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ShadButton.secondary(
                      onPressed: onOpenSettings,
                      size: ShadButtonSize.sm,
                      leading: const Icon(Icons.settings_outlined, size: 16),
                      child: const Text('调整预算'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '未设置预计番茄的任务，默认按 1 计算。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        if (over) ...[
          const SizedBox(height: 10),
          ShadAlert(
            icon: const Icon(Icons.warning_amber_outlined),
            title: const Text('今天可能过载'),
            description: Text('已计划 $planned 番茄，超过预算 $budget 番茄。建议移一些到以后。'),
          ),
        ],
      ],
    );
  }
}

class _TodayFocusCard extends StatelessWidget {
  const _TodayFocusCard({
    required this.tasks,
    required this.sessionsAsync,
    required this.workMinutes,
  });

  final List<domain.Task> tasks;
  final AsyncValue<List<domain.PomodoroSession>> sessionsAsync;
  final int workMinutes;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sessions) {
        if (sessions.isEmpty) {
          return ShadCard(
            padding: const EdgeInsets.all(16),
            title: Text(
              '今日专注',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '还没有专注记录。开始一个 ${workMinutes}min 番茄，今天会更“在掌控中”。',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                ShadButton(
                  onPressed: () => context.go('/focus'),
                  child: const Text('去专注'),
                ),
              ],
            ),
          );
        }

        final byId = {for (final t in tasks) t.id: t};
        final totalMinutes = sessions.fold<int>(
          0,
          (sum, s) => sum + s.duration.inMinutes,
        );
        final draftCount = sessions.where((s) => s.isDraft).length;

        final minutesByTask = <String, int>{};
        final countByTask = <String, int>{};
        for (final s in sessions) {
          minutesByTask[s.taskId] =
              (minutesByTask[s.taskId] ?? 0) + s.duration.inMinutes;
          countByTask[s.taskId] = (countByTask[s.taskId] ?? 0) + 1;
        }

        String? topTaskId;
        var topMinutes = -1;
        for (final entry in minutesByTask.entries) {
          if (entry.value > topMinutes) {
            topMinutes = entry.value;
            topTaskId = entry.key;
          }
        }

        final topTask = topTaskId == null ? null : byId[topTaskId];
        final topCount = topTaskId == null ? null : countByTask[topTaskId];

        return ShadCard(
          padding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '今日专注',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              Text(
                '番茄 ${sessions.length}',
                style: shadTheme.textTheme.small.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('总计 ${totalMinutes}min'),
              if (topTask != null && topCount != null) ...[
                const SizedBox(height: 4),
                Text(
                  '最专注：${topTask.title.value} · $topCount 个 · ${topMinutes}min',
                ),
              ],
              if (draftCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '待补草稿：$draftCount',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return Text(
      text,
      style: shadTheme.textTheme.small.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.foreground,
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.task, required this.reason});

  final domain.Task? task;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    if (task == null) {
      return ShadCard(
        padding: DpInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('还没有“下一步”。'),
            const SizedBox(height: 8),
            ShadButton(
              onPressed: () => context.go('/tasks'),
              child: const Text('去添加任务'),
            ),
          ],
        ),
      );
    }

    return ShadCard(
      padding: DpInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            task!.title.value,
            style: shadTheme.textTheme.large.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
          if (reason != null) ...[
            const SizedBox(height: 6),
            Text(
              reason!,
              style: shadTheme.textTheme.small.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  onPressed: () => context.push('/tasks/${task!.id}'),
                  child: const Text('查看详情'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton(
                  onPressed: () => context.go('/focus?taskId=${task!.id}'),
                  child: const Text('开始专注'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InProgressCard extends StatelessWidget {
  const _InProgressCard({required this.active, required this.task});

  final domain.ActivePomodoro active;
  final domain.Task? task;

  String _phaseLabel(domain.PomodoroPhase phase) {
    return switch (phase) {
      domain.PomodoroPhase.focus => '专注',
      domain.PomodoroPhase.shortBreak => '短休',
      domain.PomodoroPhase.longBreak => '长休',
    };
  }

  String _statusLabel(domain.ActivePomodoroStatus status) {
    return switch (status) {
      domain.ActivePomodoroStatus.running => '进行中',
      domain.ActivePomodoroStatus.paused => '已暂停',
      domain.ActivePomodoroStatus.finished => '已结束',
    };
  }

  String _formatRemaining(Duration remaining) {
    final totalSeconds = remaining.inSeconds.clamp(0, 99 * 60 + 59);
    final mm = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final now = DateTime.now();
    final remaining = active.remaining(now);
    final label =
        '${_phaseLabel(active.phase)} · ${_statusLabel(active.status)}';

    return ShadCard(
      padding: DpInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            task?.title.value ?? '继续专注',
            style: shadTheme.textTheme.large.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
              Text(
                _formatRemaining(remaining),
                style: shadTheme.textTheme.small.copyWith(
                  color: colorScheme.mutedForeground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (task != null) ...[
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () => context.push('/tasks/${task!.id}'),
                    child: const Text('查看任务'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ShadButton(
                  onPressed: () => context.go('/focus?taskId=${active.taskId}'),
                  child: const Text('回到专注'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarryOverCard extends StatelessWidget {
  const _CarryOverCard({
    required this.tasks,
    required this.totalCount,
    required this.onApply,
    required this.onOpenPlan,
  });

  final List<domain.Task> tasks;
  final int totalCount;
  final VoidCallback? onApply;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ShadCard(
        padding: DpInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '建议结转',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                Text(
                  '$totalCount 条',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '昨天计划里未完成的任务。确认后会加入今天计划（不会删除任务）。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            if (tasks.isNotEmpty) ...[
              for (var i = 0; i < tasks.length; i++) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.push('/tasks/${tasks[i].id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tasks[i].title.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: colorScheme.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
                if (i != tasks.length - 1)
                  ShadSeparator.horizontal(
                    margin: EdgeInsets.zero,
                    thickness: 1,
                    color: colorScheme.border,
                  ),
              ],
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: ShadButton.secondary(
                    onPressed: onApply,
                    child: Text(onApply == null ? '处理中…' : '加入今天计划'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShadButton.outline(
                    onPressed: onOpenPlan,
                    child: const Text('编辑计划'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YesterdayReviewCard extends StatelessWidget {
  const _YesterdayReviewCard({
    required this.tasks,
    required this.sessionsAsync,
  });

  final List<domain.Task> tasks;
  final AsyncValue<List<domain.PomodoroSession>> sessionsAsync;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final start = todayStart.subtract(const Duration(days: 1));
    final end = todayStart;

    final completedTasks = tasks
        .where((t) {
          if (t.status != domain.TaskStatus.done) return false;
          return !t.updatedAt.isBefore(start) && t.updatedAt.isBefore(end);
        })
        .toList(growable: false);

    return ShadCard(
      padding: const EdgeInsets.all(8),
      child: ShadAccordion<int>(
        children: [
          ShadAccordionItem<int>(
            value: 0,
            title: Text(
              '展开查看',
              style: shadTheme.textTheme.small.copyWith(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: sessionsAsync.when(
                loading: () => const ShadProgress(minHeight: 8),
                error: (e, st) => Text(
                  '专注记录加载失败：$e',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                data: (sessions) {
                  final totalMinutes = sessions.fold<int>(
                    0,
                    (sum, s) => sum + s.duration.inMinutes,
                  );
                  final draftCount = sessions.where((s) => s.isDraft).length;

                  final byTask = <String, int>{};
                  for (final s in sessions) {
                    byTask[s.taskId] =
                        (byTask[s.taskId] ?? 0) + s.duration.inMinutes;
                  }

                  String? topTaskId;
                  var topMinutes = -1;
                  for (final entry in byTask.entries) {
                    if (entry.value > topMinutes) {
                      topMinutes = entry.value;
                      topTaskId = entry.key;
                    }
                  }

                  final byId = {for (final t in tasks) t.id: t};
                  final topTask = topTaskId == null ? null : byId[topTaskId];

                  final visibleCompletedTasks = completedTasks.take(5).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('完成任务：${completedTasks.length}'),
                      const SizedBox(height: 4),
                      Text('专注番茄：${sessions.length} · 总计 ${totalMinutes}min'),
                      if (draftCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '待补草稿：$draftCount',
                          style: shadTheme.textTheme.small.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                      if (topTaskId != null && topTask != null) ...[
                        const SizedBox(height: 4),
                        Text('最专注：${topTask.title.value} · ${topMinutes}min'),
                      ],
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => context.push('/ai/daily'),
                        leading: const Icon(
                          Icons.auto_awesome_outlined,
                          size: 16,
                        ),
                        child: const Text('AI 总结昨天（可编辑后保存为笔记）'),
                      ),
                      if (visibleCompletedTasks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '昨天完成',
                          style: shadTheme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < visibleCompletedTasks.length; i++)
                          _YesterdayReviewTaskRow(
                            task: visibleCompletedTasks[i],
                            showDivider: i != visibleCompletedTasks.length - 1,
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YesterdayReviewTaskRow extends StatelessWidget {
  const _YesterdayReviewTaskRow({
    required this.task,
    required this.showDivider,
  });

  final domain.Task task;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/tasks/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    task.title.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ShadSeparator.horizontal(
              margin: EdgeInsets.zero,
              thickness: 1,
              color: colorScheme.border,
            ),
          ),
      ],
    );
  }
}

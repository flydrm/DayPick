import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/local_events/today_3s_session_controller.dart';
import '../../../core/providers/app_providers.dart';
import '../../../routing/home_tab.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../focus/providers/focus_providers.dart';
import '../../notes/providers/note_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/today_plan_providers.dart';
import 'calendar_constraints_card.dart';
import 'top3_edit_sheet.dart';
import 'top3_why_sheet.dart';
import 'today_bridge_highlight.dart';

class TodayV2Page extends ConsumerStatefulWidget {
  const TodayV2Page({super.key, this.rawHighlight});

  final String? rawHighlight;

  @override
  ConsumerState<TodayV2Page> createState() => _TodayV2PageState();
}

class _TodayV2PageState extends ConsumerState<TodayV2Page>
    with WidgetsBindingObserver {
  final Set<String> _ignoredSuggestionTaskIds = <String>{};
  String? _highlightedTaskId;
  String? _highlightFallbackMessage;

  Duration? _lastObservedSessionStart;
  bool _didRecordScrollForSession = false;
  Offset? _lastPointerPosition;
  double _pointerScrollDeltaPx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureSessionStarted(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      ref
          .read(today3sSessionControllerProvider.notifier)
          .handleAppLifecycleState(state),
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(_ensureSessionStarted());
    }
  }

  Future<void> _ensureSessionStarted() async {
    final appearance = ref.read(appearanceConfigProvider).valueOrNull;
    final segment = appearance == null
        ? null
        : (appearance.onboardingDone ? 'returning' : 'new');
    await ref
        .read(today3sSessionControllerProvider.notifier)
        .startSession(segment: segment);
  }

  Future<void> _recordPrimaryActionInvoked({required String action}) async {
    await ref
        .read(today3sSessionControllerProvider.notifier)
        .recordPrimaryActionInvoked(action: action);
  }

  Future<void> _recordTodayLeft({required String destination}) async {
    await ref
        .read(today3sSessionControllerProvider.notifier)
        .recordTodayLeft(destination: destination);
  }

  Future<void> _recordClarityFailOther() async {
    await ref
        .read(today3sSessionControllerProvider.notifier)
        .recordClarityFailOther();
  }

  Future<void> _recordTodayScrolled({required int deltaPx}) async {
    await ref
        .read(today3sSessionControllerProvider.notifier)
        .recordTodayScrolled(deltaPx: deltaPx);
  }

  Future<void> _recordEffectiveExecutionStateEntered() async {
    await ref
        .read(today3sSessionControllerProvider.notifier)
        .recordEffectiveExecutionStateEntered(
          source: 'today_primary_cta',
          kind: 'focus',
        );
  }

  void _resetScrollDedupIfNeeded() {
    final sessionStart = ref
        .read(today3sSessionControllerProvider)
        .sessionStart;
    if (sessionStart == _lastObservedSessionStart) return;
    _lastObservedSessionStart = sessionStart;
    _didRecordScrollForSession = false;
    _lastPointerPosition = null;
    _pointerScrollDeltaPx = 0;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _lastPointerPosition = event.position;
    _pointerScrollDeltaPx = 0;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final current = event.position;
    final previous = _lastPointerPosition;
    _lastPointerPosition = current;
    if (previous == null) return;

    _pointerScrollDeltaPx += (current.dy - previous.dy).abs();
    if (_didRecordScrollForSession) return;
    if (_pointerScrollDeltaPx < 24) return;

    _didRecordScrollForSession = true;
    unawaited(_recordTodayScrolled(deltaPx: _pointerScrollDeltaPx.round()));
  }

  void _handlePointerEnd(PointerEvent _) {
    _lastPointerPosition = null;
    _pointerScrollDeltaPx = 0;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeTabIndexProvider, (prev, next) {
      if (next != 2) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_ensureSessionStarted());
      });
    });
    _resetScrollDedupIfNeeded();

    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final now = DateTime.now();
    final day =
        ref.watch(todayDayProvider).valueOrNull ??
        DateTime(now.year, now.month, now.day);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final planIdsAsync = ref.watch(todayPlanTaskIdsProvider);
    final eveningPlanIdsAsync = ref.watch(todayEveningPlanTaskIdsProvider);
    final unprocessedNotesAsync = ref.watch(unprocessedNotesStreamProvider);
    final activePomodoroAsync = ref.watch(activePomodoroProvider);

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final bridgeHighlight = resolveTodayBridgeHighlight(
      rawHighlight: widget.rawHighlight,
      tasks: tasks,
    );
    if (_highlightedTaskId != bridgeHighlight.highlightedEntryId ||
        _highlightFallbackMessage != bridgeHighlight.fallbackMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _highlightedTaskId = bridgeHighlight.highlightedEntryId;
          _highlightFallbackMessage = bridgeHighlight.fallbackMessage;
        });
      });
    }

    final byId = {for (final t in tasks) t.id: t};
    final planIds = planIdsAsync.valueOrNull ?? const <String>[];
    final eveningPlanIds = eveningPlanIdsAsync.valueOrNull ?? const <String>[];
    final planTasks = <domain.Task>[
      for (final id in planIds)
        if (byId[id] != null) byId[id]!,
    ];

    final inboxNotes =
        unprocessedNotesAsync.valueOrNull ?? const <domain.Note>[];
    final inboxTaskCount = tasks
        .where((t) => t.triageStatus == domain.TriageStatus.inbox)
        .length;
    final inboxCount = inboxTaskCount + inboxNotes.length;

    final queueRule = const domain.TodayQueueRule(maxItems: 5);
    final queue = queueRule(tasks, now);
    final top3 = <domain.Task>[
      ...planTasks.take(3),
      ...queue.todayQueue
          .where(
            (t) =>
                !planIds.contains(t.id) &&
                !eveningPlanIds.contains(t.id) &&
                !_ignoredSuggestionTaskIds.contains(t.id),
          )
          .take((3 - planTasks.length).clamp(0, 3)),
    ];
    final highlightedInTop3 =
        _highlightedTaskId != null &&
        top3.any((task) => task.id == _highlightedTaskId);
    final effectiveHighlightFallbackMessage =
        _highlightFallbackMessage ??
        (_highlightedTaskId != null && !highlightedInTop3
            ? '已加入，但未定位到条目。'
            : null);
    final nextTaskId = planTasks.isNotEmpty
        ? planTasks.first.id
        : queue.nextStep?.id;
    final activeFocusTaskId = activePomodoroAsync.valueOrNull?.taskId;

    Widget buildTop3Body() {
      if (tasksAsync.isLoading ||
          planIdsAsync.isLoading ||
          eveningPlanIdsAsync.isLoading) {
        return const ShadProgress(minHeight: 8);
      }
      if (tasksAsync.hasError ||
          planIdsAsync.hasError ||
          eveningPlanIdsAsync.hasError) {
        final error =
            tasksAsync.error ?? planIdsAsync.error ?? eveningPlanIdsAsync.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DpInlineNotice(
              variant: DpInlineNoticeVariant.destructive,
              title: 'Top3 加载失败',
              description: '原因：$error',
            ),
            const SizedBox(height: DpSpacing.sm),
            ShadButton.outline(
              onPressed: () {
                unawaited(_ensureSessionStarted());
                unawaited(_recordTodayLeft(destination: 'route:tasks'));
                context.push('/tasks');
              },
              child: const Text('下一步：打开任务列表'),
            ),
          ],
        );
      }

      if (top3.isEmpty) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('还没有可执行的 Top3。'),
              const SizedBox(height: DpSpacing.sm),
              ShadButton.outline(
                onPressed: () {
                  unawaited(_ensureSessionStarted());
                  unawaited(
                    _recordPrimaryActionInvoked(action: 'open_today_plan'),
                  );
                  context.push('/today/plan');
                },
                child: const Text('进入 Today Plan'),
              ),
              const SizedBox(height: DpSpacing.sm),
              ShadButton.outline(
                onPressed: () {
                  unawaited(_ensureSessionStarted());
                  unawaited(_recordTodayLeft(destination: 'route:create'));
                  context.push('/create?type=task&addToToday=true');
                },
                child: const Text('快速创建'),
              ),
            ],
          ),
        );
      }

      final startOfToday = DateTime(now.year, now.month, now.day);

      bool isDueToday(domain.Task task) {
        final dueAt = task.dueAt;
        if (dueAt == null) return false;
        final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
        return dueDate == startOfToday;
      }

      bool isOverdue(domain.Task task) {
        final dueAt = task.dueAt;
        if (dueAt == null) return false;
        final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
        return dueDate.isBefore(startOfToday);
      }

      void openWhySheet(domain.Task task) {
        final fromPlan = planIds.contains(task.id);
        final reasonLabels = <String>[
          if (fromPlan) '今天计划' else '建议',
          if (isOverdue(task)) '已逾期' else if (isDueToday(task)) '今日到期',
          if (activeFocusTaskId == task.id) 'Focus',
        ];

        final sourceLabel = fromPlan ? '来自今天计划' : '规则建议（草稿）';
        final ruleHint = fromPlan
            ? 'Top3 = 今天计划（Today）前 3 条'
            : '规则：逾期优先 → 今日到期 → 按优先级/到期时间/创建时间补齐';

        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => Top3WhySheet(
            task: task,
            sourceLabel: sourceLabel,
            reasonLabels: reasonLabels,
            ruleHint: ruleHint,
          ),
        );
      }

      void ignoreSuggestion(domain.Task task) {
        setState(() => _ignoredSuggestionTaskIds.add(task.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('本次会话已忽略建议：${task.title.value}'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () => setState(() {
                _ignoredSuggestionTaskIds.remove(task.id);
              }),
            ),
          ),
        );
      }

      Future<void> adoptSuggestion(domain.Task task) async {
        final current =
            ref.read(todayPlanTaskIdsProvider).valueOrNull ?? const <String>[];
        final currentVisibleCount = current
            .where((id) => byId.containsKey(id))
            .length;
        if (currentVisibleCount >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Top3 已满，先在编辑里调整顺序/移除再采用建议')),
          );
          return;
        }
        final updated = [...current.where((id) => id != task.id), task.id];
        final previewVisibleIds = [
          for (final id in updated)
            if (byId.containsKey(id) || id == task.id) id,
        ];
        final previewTitles = previewVisibleIds
            .take(3)
            .map((id) => byId[id]?.title.value ?? id)
            .join(' · ');

        final ok = await showShadDialog<bool>(
          context: context,
          builder: (dialogContext) => ShadDialog.alert(
            title: const Text('采用建议？'),
            description: Text('预览（Top3）：$previewTitles'),
            actions: [
              ShadButton.outline(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              ShadButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认写入'),
              ),
            ],
          ),
        );
        if (ok != true) return;

        await ref
            .read(todayPlanRepositoryProvider)
            .replaceTasks(
              day: day,
              taskIds: updated,
              section: domain.TodayPlanSection.today,
            );
      }

      return ShadCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (effectiveHighlightFallbackMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: DpInlineNotice(
                  key: const ValueKey('today_v2_bridge_fallback_notice'),
                  title: '定位失败回退',
                  description: effectiveHighlightFallbackMessage,
                ),
              ),
            for (var i = 0; i < top3.length; i++) ...[
              _Top3Row(
                key: ValueKey('today_v2_top3:${top3[i].id}'),
                task: top3[i],
                highlighted: _highlightedTaskId == top3[i].id,
                sourceLabel: planIds.contains(top3[i].id) ? '今天计划' : '建议',
                reasonLabels: [
                  if (isOverdue(top3[i]))
                    '已逾期'
                  else if (isDueToday(top3[i]))
                    '今日到期',
                  if (activeFocusTaskId == top3[i].id) 'Focus',
                ],
                onOpen: () {
                  unawaited(_ensureSessionStarted());
                  unawaited(_recordTodayLeft(destination: 'route:tasks'));
                  context.push('/tasks/${top3[i].id}');
                },
                onOpenWhy: () => openWhySheet(top3[i]),
                onAdoptSuggestion: planIds.contains(top3[i].id)
                    ? null
                    : () => unawaited(adoptSuggestion(top3[i])),
                onIgnoreSuggestion: planIds.contains(top3[i].id)
                    ? null
                    : () => ignoreSuggestion(top3[i]),
              ),
              if (i != top3.length - 1)
                Divider(height: 0, color: colorScheme.border),
            ],
          ],
        ),
      );
    }

    Widget buildInboxBody() {
      if (tasksAsync.isLoading || unprocessedNotesAsync.isLoading) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('待处理负载加载中…')),
                ShadButton.outline(
                  onPressed: () {
                    unawaited(_ensureSessionStarted());
                    unawaited(
                      _recordPrimaryActionInvoked(action: 'open_inbox'),
                    );
                    unawaited(_recordTodayLeft(destination: 'route:inbox'));
                    context.push('/inbox');
                  },
                  child: const Text('打开收件箱'),
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.sm),
            const ShadProgress(minHeight: 8),
            const SizedBox(height: DpSpacing.xs),
            Text(
              '原因：正在读取本地数据。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        );
      }
      if (tasksAsync.hasError || unprocessedNotesAsync.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DpInlineNotice(
              variant: DpInlineNoticeVariant.destructive,
              title: '待处理负载读取失败',
              description: '原因：读取本地数据失败（不影响你开始第 1 件事）。',
            ),
            const SizedBox(height: DpSpacing.sm),
            ShadButton.outline(
              onPressed: () {
                unawaited(_ensureSessionStarted());
                unawaited(_recordPrimaryActionInvoked(action: 'open_inbox'));
                unawaited(_recordTodayLeft(destination: 'route:inbox'));
                context.push('/inbox');
              },
              child: const Text('下一步：打开收件箱'),
            ),
          ],
        );
      }

      final label = inboxCount == 0 ? '待处理已清空' : '待处理：$inboxCount';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              ShadButton.secondary(
                onPressed: () {
                  unawaited(_ensureSessionStarted());
                  unawaited(_recordPrimaryActionInvoked(action: 'open_inbox'));
                  unawaited(_recordTodayLeft(destination: 'route:inbox'));
                  context.push('/inbox');
                },
                child: const Text('打开收件箱'),
              ),
            ],
          ),
          if (inboxCount > 0) ...[
            const SizedBox(height: DpSpacing.sm),
            Text(
              '任务 + 闪念/长文',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ],
      );
    }

    Widget buildTimeConstraintsBody() {
      return const CalendarConstraintsCardBody();
    }

    Widget card({
      required Key key,
      required String title,
      Widget? trailing,
      required Widget child,
    }) {
      return ShadCard(
        key: key,
        padding: const EdgeInsets.all(DpSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: shadTheme.textTheme.h4.copyWith(
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: DpSpacing.sm),
            Expanded(child: child),
          ],
        ),
      );
    }

    const bottomCtaHeight = 56.0;
    final contentBottomPadding = bottomCtaHeight + (DpSpacing.lg * 2);

    final appBarActions = <Widget>[
      Tooltip(
        message: '创建',
        child: ShadIconButton.ghost(
          icon: const Icon(Icons.add, size: 20),
          onPressed: () {
            unawaited(_ensureSessionStarted());
            unawaited(_recordTodayLeft(destination: 'route:create'));
            context.push('/create');
          },
        ),
      ),
      Tooltip(
        message: '搜索',
        child: ShadIconButton.ghost(
          icon: const Icon(Icons.search, size: 20),
          onPressed: () {
            unawaited(_ensureSessionStarted());
            unawaited(_recordTodayLeft(destination: 'route:search'));
            context.push('/search');
          },
        ),
      ),
      Tooltip(
        message: '设置',
        child: ShadIconButton.ghost(
          icon: const Icon(Icons.settings_outlined, size: 20),
          onPressed: () {
            unawaited(_ensureSessionStarted());
            unawaited(_recordTodayLeft(destination: 'route:settings'));
            context.push('/settings');
          },
        ),
      ),
    ];

    return AppPageScaffold(
      title: 'Today',
      actions: appBarActions,
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                DpSpacing.lg,
                DpSpacing.lg,
                DpSpacing.lg,
                contentBottomPadding,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: card(
                      key: const ValueKey('today_v2_top3_card'),
                      title: 'Top3',
                      trailing: ShadButton.ghost(
                        key: const ValueKey('today_v2_top3_edit'),
                        size: ShadButtonSize.sm,
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => const Top3EditSheet(),
                        ),
                        child: const Text('编辑'),
                      ),
                      child: buildTop3Body(),
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  Expanded(
                    child: card(
                      key: const ValueKey('today_v2_time_constraints_card'),
                      title: '时间约束',
                      child: buildTimeConstraintsBody(),
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  Expanded(
                    child: card(
                      key: const ValueKey('today_v2_inbox_card'),
                      title: '待处理负载',
                      child: buildInboxBody(),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(DpSpacing.lg),
                  child: SizedBox(
                    height: bottomCtaHeight,
                    width: double.infinity,
                    child: ShadButton(
                      key: const ValueKey('today_v2_primary_cta'),
                      onPressed: () async {
                        unawaited(_ensureSessionStarted());

                        // Task 2: minimal usable execution flow with a guaranteed fallback.
                        if (activePomodoroAsync.isLoading ||
                            activePomodoroAsync.hasError) {
                          unawaited(
                            _recordPrimaryActionInvoked(action: 'start_focus'),
                          );
                          unawaited(_recordEffectiveExecutionStateEntered());
                          context.go('/focus');
                          return;
                        }

                        final active = activePomodoroAsync.valueOrNull;
                        if (active != null) {
                          unawaited(
                            _recordPrimaryActionInvoked(action: 'start_focus'),
                          );
                          unawaited(_recordEffectiveExecutionStateEntered());
                          context.go('/focus');
                          return;
                        }

                        if (nextTaskId != null) {
                          unawaited(
                            _recordPrimaryActionInvoked(action: 'start_focus'),
                          );
                          unawaited(_recordEffectiveExecutionStateEntered());
                          context.go(
                            '/focus?taskId=${Uri.encodeComponent(nextTaskId)}',
                          );
                          return;
                        }

                        unawaited(
                          _recordPrimaryActionInvoked(
                            action: 'open_today_plan',
                          ),
                        );
                        unawaited(_recordClarityFailOther());
                        await context.push('/today/plan');
                      },
                      child: const Text('开始第 1 件事'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Top3Row extends StatelessWidget {
  const _Top3Row({
    super.key,
    required this.task,
    required this.sourceLabel,
    required this.reasonLabels,
    required this.highlighted,
    required this.onOpen,
    required this.onOpenWhy,
    this.onAdoptSuggestion,
    this.onIgnoreSuggestion,
  });

  final domain.Task task;
  final String sourceLabel;
  final List<String> reasonLabels;
  final bool highlighted;
  final VoidCallback onOpen;
  final VoidCallback onOpenWhy;
  final VoidCallback? onAdoptSuggestion;
  final VoidCallback? onIgnoreSuggestion;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final highlightColor = highlighted
        ? colorScheme.primary.withAlpha(16)
        : Colors.transparent;
    final highlightBorder = highlighted
        ? Border.all(color: colorScheme.primary, width: 1)
        : null;

    return InkWell(
      onTap: onOpen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: highlightColor,
          border: highlightBorder,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: shadTheme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sourceLabel,
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (reasonLabels.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        reasonLabels.join(' · '),
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
              if (onAdoptSuggestion != null) ...[
                Tooltip(
                  message: '采用建议（写入 Today Plan）',
                  child: ShadIconButton.ghost(
                    key: ValueKey('today_v2_top3_adopt:${task.id}'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    onPressed: onAdoptSuggestion,
                  ),
                ),
                const SizedBox(width: 2),
              ],
              if (onIgnoreSuggestion != null) ...[
                Tooltip(
                  message: '忽略',
                  child: ShadIconButton.ghost(
                    key: ValueKey('today_v2_top3_ignore:${task.id}'),
                    icon: const Icon(Icons.not_interested_outlined, size: 18),
                    onPressed: onIgnoreSuggestion,
                  ),
                ),
                const SizedBox(width: 2),
              ],
              Tooltip(
                message: '为什么是这条',
                child: ShadIconButton.ghost(
                  key: ValueKey('today_v2_top3_why:${task.id}'),
                  icon: const Icon(Icons.help_outline, size: 18),
                  onPressed: onOpenWhy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

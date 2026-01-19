import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/kit/dp_timer_display.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/focus_providers.dart';
import 'focus_note_sheet.dart';
import 'focus_wrapup_sheet.dart';
import 'select_task_sheet.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key, this.taskId});

  final String? taskId;

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  String? _selectedTaskId;
  bool _wrapUpOpen = false;
  bool _finishingBreak = false;
  domain.PomodoroPhase? _pendingBreakPhase;
  int? _pendingBreakMinutes;
  String? _pendingBreakTaskId;

  @override
  void initState() {
    super.initState();
    _selectedTaskId = widget.taskId;
  }

  @override
  void didUpdateWidget(covariant FocusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.taskId != null && widget.taskId != oldWidget.taskId) {
      _selectedTaskId = widget.taskId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activePomodoroProvider);
    return AppPageScaffold(
      title: '专注',
      body: activeAsync.when(
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
        data: (active) {
          if (active == null) {
            return _FocusIdleView(
              selectedTaskId: _selectedTaskId,
              pendingBreakPhase: _pendingBreakPhase,
              pendingBreakMinutes: _pendingBreakMinutes,
              pendingBreakTaskId: _pendingBreakTaskId,
              onDismissBreak: () => setState(() {
                _pendingBreakPhase = null;
                _pendingBreakMinutes = null;
                _pendingBreakTaskId = null;
              }),
              onStartBreak: () async {
                final phase = _pendingBreakPhase;
                final minutes = _pendingBreakMinutes;
                final taskId = _pendingBreakTaskId;
                if (phase == null || minutes == null || taskId == null) return;
                final config = await ref.read(pomodoroConfigProvider.future);
                await _startBreak(
                  taskId: taskId,
                  phase: phase,
                  minutes: minutes,
                  config: config,
                );
                if (mounted) {
                  setState(() {
                    _pendingBreakPhase = null;
                    _pendingBreakMinutes = null;
                    _pendingBreakTaskId = null;
                  });
                }
              },
              onPickTask: () async {
                final picked = await _pickTask(context);
                if (picked == null) return;
                setState(() => _selectedTaskId = picked);
              },
              onStart: () async {
                final taskId = _selectedTaskId ?? await _pickTask(context);
                if (taskId == null) return;
                setState(() => _selectedTaskId = taskId);

                final start = ref.read(startPomodoroUseCaseProvider);
                final config = await ref.read(pomodoroConfigProvider.future);
                final active = await start(taskId: taskId, config: config);
                setState(() {
                  _pendingBreakPhase = null;
                  _pendingBreakMinutes = null;
                  _pendingBreakTaskId = null;
                });

                final notifications = ref.read(
                  localNotificationsServiceProvider,
                );
                final granted = await notifications
                    .requestNotificationsPermissionIfNeeded();
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('通知未开启：到点将仅在应用内提示，建议在系统设置开启。'),
                    ),
                  );
                }

                await _schedulePomodoroNotification(active, config);
              },
            );
          }

          return _FocusActiveView(
            active: active,
            onPause: () async {
              await ref.read(pausePomodoroUseCaseProvider)();
              await ref.read(cancelPomodoroNotificationUseCaseProvider)();
            },
            onResume: () async {
              final config = await ref.read(pomodoroConfigProvider.future);
              final resumed = await ref.read(resumePomodoroUseCaseProvider)();
              if (resumed == null) return;

              final notifications = ref.read(localNotificationsServiceProvider);
              final granted = await notifications
                  .requestNotificationsPermissionIfNeeded();
              if (!granted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('通知未开启：到点将仅在应用内提示，建议在系统设置开启。')),
                );
              }

              await _schedulePomodoroNotification(resumed, config);
            },
            onEndEarly: () async {
              if (active.phase != domain.PomodoroPhase.focus) return;
              await _showWrapUp(context, active, actualEndAt: DateTime.now());
            },
            onTimeUp: () async {
              if (active.phase == domain.PomodoroPhase.focus) {
                await _showWrapUp(context, active, actualEndAt: active.endAt);
                return;
              }
              await _finishBreak(active);
            },
            onWrapUp: () async {
              if (active.phase != domain.PomodoroPhase.focus) return;
              final endAt = active.endAt ?? DateTime.now();
              await _showWrapUp(context, active, actualEndAt: endAt);
            },
            onDiscard: () async {
              await ref.read(cancelPomodoroNotificationUseCaseProvider)();
              await ref.read(activePomodoroRepositoryProvider).clear();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(active.isBreak ? '已跳过休息' : '已放弃本次专注记录')),
              );
            },
            onPickNextTask: () async {
              final picked = await _pickTask(context);
              if (picked == null) return;
              if (!mounted) return;
              setState(() => _selectedTaskId = picked);
            },
            onStartNext: () async {
              final config = await ref.read(pomodoroConfigProvider.future);
              final taskId = _selectedTaskId ?? active.taskId;
              final start = ref.read(startPomodoroUseCaseProvider);
              final next = await start(taskId: taskId, config: config);

              final notifications = ref.read(localNotificationsServiceProvider);
              final granted = await notifications
                  .requestNotificationsPermissionIfNeeded();
              if (!granted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('通知未开启：到点将仅在应用内提示，建议在系统设置开启。')),
                );
              }
              await _schedulePomodoroNotification(next, config);
            },
          );
        },
      ),
    );
  }

  Future<String?> _pickTask(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectTaskSheet(),
    );
  }

  Future<void> _showWrapUp(
    BuildContext context,
    domain.ActivePomodoro active, {
    DateTime? actualEndAt,
  }) async {
    if (active.phase != domain.PomodoroPhase.focus) return;
    if (_wrapUpOpen) return;
    _wrapUpOpen = true;

    try {
      await ref.read(cancelPomodoroNotificationUseCaseProvider)();
      await _markActiveFinished(active, actualEndAt: actualEndAt);
      final taskAsync = await ref.read(taskByIdProvider(active.taskId).future);
      final taskTitle = taskAsync?.title.value ?? '专注结束';
      final focusNote = active.focusNote?.trim();
      final initialProgressNote = focusNote == null || focusNote.isEmpty
          ? null
          : '外周记事：\n$focusNote';

      if (!context.mounted) return;
      final result = await showModalBottomSheet<FocusWrapUpResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FocusWrapUpSheet(
          taskTitle: taskTitle,
          initialProgressNote: initialProgressNote,
        ),
      );

      if (result == null) return;

      final action = result.action;
      final progressNote = result.progressNote;
      final nextStepTitle = result.nextStepTitle?.trim();
      final addNextStepToToday = result.addNextStepToToday;

      if (action == FocusWrapUpAction.discard) {
        await ref.read(activePomodoroRepositoryProvider).clear();
        if (mounted) {
          setState(() {
            _pendingBreakPhase = null;
            _pendingBreakMinutes = null;
            _pendingBreakTaskId = null;
          });
        }
        return;
      }

      final complete = ref.read(completePomodoroUseCaseProvider);
      final session = await complete(
        progressNote: progressNote,
        isDraft: action == FocusWrapUpAction.later,
      );

      if (!context.mounted) return;
      if (session == null) return;

      String? nextTaskId;
      DateTime? today;
      if (nextStepTitle != null && nextStepTitle.isNotEmpty) {
        final now = DateTime.now();
        today = DateTime(now.year, now.month, now.day);
        final created = await ref.read(createTaskUseCaseProvider)(
          title: nextStepTitle,
          triageStatus: addNextStepToToday
              ? domain.TriageStatus.plannedToday
              : domain.TriageStatus.scheduledLater,
        );
        nextTaskId = created.id;
        if (addNextStepToToday) {
          await ref
              .read(todayPlanRepositoryProvider)
              .addTask(day: today, taskId: created.id);
        }
      }

      if (!context.mounted) return;
      final message = switch (action) {
        FocusWrapUpAction.later =>
          nextTaskId == null ? '已创建进展草稿，可稍后补' : '已保存草稿，并创建了下一步',
        FocusWrapUpAction.save =>
          nextTaskId == null ? '已保存进展记录' : '已保存进展，并创建了下一步',
        FocusWrapUpAction.discard => '',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              ref
                  .read(pomodoroSessionRepositoryProvider)
                  .deleteSession(session.id);
              if (nextTaskId != null) {
                if (today != null && addNextStepToToday) {
                  ref
                      .read(todayPlanRepositoryProvider)
                      .removeTask(day: today, taskId: nextTaskId);
                }
                ref.read(taskRepositoryProvider).deleteTask(nextTaskId);
              }
            },
          ),
        ),
      );

      final config = await ref.read(pomodoroConfigProvider.future);
      final suggestion = await _computeBreakSuggestion(config, session.taskId);
      if (suggestion == null) return;

      if (config.autoStartBreak) {
        await _startBreak(
          taskId: suggestion.taskId,
          phase: suggestion.phase,
          minutes: suggestion.minutes,
          config: config,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _pendingBreakPhase = suggestion.phase;
        _pendingBreakMinutes = suggestion.minutes;
        _pendingBreakTaskId = suggestion.taskId;
      });
    } finally {
      _wrapUpOpen = false;
    }
  }

  Future<_BreakSuggestion?> _computeBreakSuggestion(
    domain.PomodoroConfig config,
    String taskId,
  ) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final count = await ref
        .read(pomodoroSessionRepositoryProvider)
        .watchCountBetween(start, end)
        .first;

    final every = config.longBreakEvery.clamp(2, 10);
    final useLongBreak = count > 0 && every > 0 && count % every == 0;
    final phase = useLongBreak
        ? domain.PomodoroPhase.longBreak
        : domain.PomodoroPhase.shortBreak;
    final minutes = useLongBreak
        ? config.longBreakMinutes
        : config.shortBreakMinutes;
    final safeMinutes = minutes.clamp(1, 120);

    return _BreakSuggestion(taskId: taskId, phase: phase, minutes: safeMinutes);
  }

  Future<void> _markActiveFinished(
    domain.ActivePomodoro active, {
    DateTime? actualEndAt,
  }) async {
    final now = DateTime.now();
    final endAt = actualEndAt ?? active.endAt ?? now;
    if (active.status == domain.ActivePomodoroStatus.finished &&
        active.endAt != null &&
        active.endAt!.isAtSameMomentAs(endAt)) {
      return;
    }
    final finished = domain.ActivePomodoro(
      taskId: active.taskId,
      phase: active.phase,
      status: domain.ActivePomodoroStatus.finished,
      startAt: active.startAt,
      endAt: endAt,
      updatedAt: now,
    );
    await ref.read(activePomodoroRepositoryProvider).upsert(finished);
  }

  Future<void> _schedulePomodoroNotification(
    domain.ActivePomodoro active,
    domain.PomodoroConfig config,
  ) async {
    final endAt = active.endAt;
    if (endAt == null) return;

    final title = await _notificationTitleFor(active);

    await ref.read(schedulePomodoroNotificationUseCaseProvider)(
      taskId: active.taskId,
      taskTitle: title,
      endAt: endAt,
      playSound: config.notificationSound,
      enableVibration: config.notificationVibration,
    );
  }

  Future<String> _notificationTitleFor(domain.ActivePomodoro active) async {
    return switch (active.phase) {
      domain.PomodoroPhase.focus => () async {
        final taskAsync = await ref.read(
          taskByIdProvider(active.taskId).future,
        );
        final taskTitle = taskAsync?.title.value.trim() ?? '';
        if (taskTitle.isEmpty) return '专注结束';
        return '专注结束 · $taskTitle';
      }(),
      domain.PomodoroPhase.shortBreak => Future.value('短休结束'),
      domain.PomodoroPhase.longBreak => Future.value('长休结束'),
    };
  }

  Future<void> _startBreak({
    required String taskId,
    required domain.PomodoroPhase phase,
    required int minutes,
    required domain.PomodoroConfig config,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    final safeMinutes = minutes.clamp(1, 120);
    final now = DateTime.now();
    final endAt = now.add(Duration(minutes: safeMinutes));
    final state = domain.ActivePomodoro(
      taskId: taskId,
      phase: phase,
      status: domain.ActivePomodoroStatus.running,
      startAt: now,
      endAt: endAt,
      updatedAt: now,
    );
    await ref.read(activePomodoroRepositoryProvider).upsert(state);

    if (mounted) {
      setState(() => _selectedTaskId = taskId);
    }

    final notifications = ref.read(localNotificationsServiceProvider);
    final granted = await notifications
        .requestNotificationsPermissionIfNeeded();
    if (!granted && mounted && messenger != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('通知未开启：到点将仅在应用内提示，建议在系统设置开启。')),
      );
    }

    await _schedulePomodoroNotification(state, config);
  }

  Future<void> _finishBreak(domain.ActivePomodoro active) async {
    if (_finishingBreak) return;
    _finishingBreak = true;
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);

      await ref.read(cancelPomodoroNotificationUseCaseProvider)();
      await _markActiveFinished(active, actualEndAt: DateTime.now());

      final config = await ref.read(pomodoroConfigProvider.future);
      if (!config.autoStartFocus) {
        if (mounted && messenger != null) {
          messenger.showSnackBar(const SnackBar(content: Text('休息结束')));
        }
        return;
      }

      final taskId = _selectedTaskId ?? active.taskId;
      final start = ref.read(startPomodoroUseCaseProvider);
      final next = await start(taskId: taskId, config: config);

      final notifications = ref.read(localNotificationsServiceProvider);
      final granted = await notifications
          .requestNotificationsPermissionIfNeeded();
      if (!granted && mounted && messenger != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('通知未开启：到点将仅在应用内提示，建议在系统设置开启。')),
        );
      }
      await _schedulePomodoroNotification(next, config);

      if (mounted && messenger != null) {
        messenger.showSnackBar(const SnackBar(content: Text('休息结束，已开始下一段专注')));
      }
    } finally {
      _finishingBreak = false;
    }
  }
}

class _BreakSuggestion {
  const _BreakSuggestion({
    required this.taskId,
    required this.phase,
    required this.minutes,
  });

  final String taskId;
  final domain.PomodoroPhase phase;
  final int minutes;
}

class _FocusIdleView extends ConsumerWidget {
  const _FocusIdleView({
    required this.selectedTaskId,
    required this.pendingBreakPhase,
    required this.pendingBreakMinutes,
    required this.pendingBreakTaskId,
    required this.onStartBreak,
    required this.onDismissBreak,
    required this.onPickTask,
    required this.onStart,
  });

  final String? selectedTaskId;
  final domain.PomodoroPhase? pendingBreakPhase;
  final int? pendingBreakMinutes;
  final String? pendingBreakTaskId;
  final VoidCallback onStartBreak;
  final VoidCallback onDismissBreak;
  final VoidCallback onPickTask;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final id = selectedTaskId;
    final taskAsync = id == null ? null : ref.watch(taskByIdProvider(id));
    final durationAsync = ref.watch(pomodoroConfigProvider);
    final minutes = durationAsync.maybeWhen(
      data: (c) => c.workDurationMinutes,
      orElse: () => 25,
    );

    final breakPhase = pendingBreakPhase;
    final breakMinutes = pendingBreakMinutes;
    final breakTaskId = pendingBreakTaskId;
    final breakTaskAsync = breakTaskId == null
        ? null
        : ref.watch(taskByIdProvider(breakTaskId));

    return ListView(
      padding: DpInsets.page,
      children: [
        if (breakPhase != null &&
            breakMinutes != null &&
            breakTaskId != null) ...[
          ShadCard(
            padding: DpInsets.card,
            title: Text(
              '建议休息',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_breakLabel(breakPhase)} $breakMinutes 分钟'
                  '${breakTaskAsync == null ? '' : ' · ${_taskTitleText(breakTaskAsync)}'}',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: DpSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: onDismissBreak,
                        child: const Text('忽略'),
                      ),
                    ),
                    const SizedBox(width: DpSpacing.sm),
                    Expanded(
                      child: ShadButton(
                        onPressed: onStartBreak,
                        child: const Text('开始休息'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
        ],
        ShadCard(
          padding: DpInsets.card,
          title: Text(
            '本次专注任务',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (taskAsync == null)
                Text(
                  '未选择任务',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                )
              else
                taskAsync.when(
                  loading: () => Text(
                    '加载中…',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  error: (e, st) => Text(
                    '任务加载失败',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  data: (task) => Text(
                    task == null ? '任务不存在或已删除' : task.title.value,
                    style: shadTheme.textTheme.small.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: DpSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: onPickTask,
                      child: const Text('选择/更换任务'),
                    ),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Expanded(
                    child: ShadButton(
                      onPressed: onStart,
                      child: Text('开始专注 · $minutes 分钟'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DpSpacing.md),
        ShadAlert(
          icon: const Icon(Icons.info_outline),
          title: const Text('提示'),
          description: const Text('专注到点后会进入收尾（保存/稍后补）。'),
        ),
      ],
    );
  }

  String _breakLabel(domain.PomodoroPhase phase) => switch (phase) {
    domain.PomodoroPhase.focus => '专注',
    domain.PomodoroPhase.shortBreak => '短休',
    domain.PomodoroPhase.longBreak => '长休',
  };

  String _taskTitleText(AsyncValue<domain.Task?> taskAsync) {
    return taskAsync.when(
      loading: () => '加载中…',
      error: (_, stackTrace) => '任务加载失败',
      data: (task) => task?.title.value ?? '任务不存在或已删除',
    );
  }
}

class _FocusActiveView extends ConsumerWidget {
  const _FocusActiveView({
    required this.active,
    required this.onPause,
    required this.onResume,
    required this.onEndEarly,
    required this.onTimeUp,
    required this.onWrapUp,
    required this.onDiscard,
    required this.onPickNextTask,
    required this.onStartNext,
  });

  final domain.ActivePomodoro active;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEndEarly;
  final VoidCallback onTimeUp;
  final VoidCallback onWrapUp;
  final VoidCallback onDiscard;
  final VoidCallback onPickNextTask;
  final VoidCallback onStartNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final taskAsync = ref.watch(taskByIdProvider(active.taskId));
    final taskTitle = taskAsync.when(
      loading: () => '加载中…',
      error: (e, st) => '任务加载失败',
      data: (task) => task?.title.value ?? '任务不存在或已删除',
    );

    final isRunning = active.status == domain.ActivePomodoroStatus.running;
    final isPaused = active.status == domain.ActivePomodoroStatus.paused;
    final isFinished = active.status == domain.ActivePomodoroStatus.finished;
    final isBreak = active.isBreak;
    final phaseLabel = switch (active.phase) {
      domain.PomodoroPhase.focus => '专注',
      domain.PomodoroPhase.shortBreak => '短休',
      domain.PomodoroPhase.longBreak => '长休',
    };

    final todayCountAsync = ref.watch(todayPomodoroCountProvider);

    Future<void> openFocusNote() async {
      final text = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => FocusNoteSheet(initialText: active.focusNote),
      );
      if (text == null) return;
      final trimmed = text.trim();
      final next = domain.ActivePomodoro(
        taskId: active.taskId,
        phase: active.phase,
        status: active.status,
        startAt: active.startAt,
        endAt: active.endAt,
        remainingMs: active.remainingMs,
        focusNote: trimmed.isEmpty ? null : trimmed,
        updatedAt: DateTime.now(),
      );
      await ref.read(activePomodoroRepositoryProvider).upsert(next);
    }

    final focusNote = active.focusNote?.trim();
    final hasFocusNote = focusNote != null && focusNote.isNotEmpty;

    return ListView(
      padding: DpInsets.page,
      children: [
        ShadCard(
          padding: DpInsets.card,
          title: Text(
            '当前状态',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isBreak
                    ? '$phaseLabel · 上一任务：$taskTitle'
                    : '$phaseLabel · $taskTitle',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.lg),
              if (isRunning && active.endAt != null)
                _CountdownText(endAt: active.endAt!, onFinished: onTimeUp)
              else if (isPaused)
                _StaticRemainingText(
                  remaining: Duration(milliseconds: active.remainingMs ?? 0),
                )
              else if (isFinished)
                Text(
                  isBreak ? '休息结束' : '已结束，待收尾…',
                  textAlign: TextAlign.center,
                  style: shadTheme.textTheme.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                )
              else
                Text(
                  '等待收尾…',
                  textAlign: TextAlign.center,
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
              const SizedBox(height: DpSpacing.lg),
              if (isFinished)
                isBreak
                    ? Row(
                        children: [
                          Expanded(
                            child: ShadButton.outline(
                              onPressed: onDiscard,
                              child: const Text('结束休息'),
                            ),
                          ),
                          const SizedBox(width: DpSpacing.sm),
                          Expanded(
                            child: ShadButton(
                              onPressed: onStartNext,
                              child: const Text('开始下一段'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ShadButton.outline(
                              onPressed: onDiscard,
                              child: const Text('不记录'),
                            ),
                          ),
                          const SizedBox(width: DpSpacing.sm),
                          Expanded(
                            child: ShadButton(
                              onPressed: onWrapUp,
                              child: const Text('去收尾'),
                            ),
                          ),
                        ],
                      )
              else
                Row(
                  children: [
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: isBreak ? onDiscard : onEndEarly,
                        child: Text(isBreak ? '跳过' : '结束'),
                      ),
                    ),
                    const SizedBox(width: DpSpacing.sm),
                    Expanded(
                      child: ShadButton(
                        onPressed: isRunning
                            ? onPause
                            : isPaused
                            ? onResume
                            : null,
                        child: Text(isRunning ? '暂停' : '继续'),
                      ),
                    ),
                  ],
                ),
              if (isBreak && isFinished) ...[
                const SizedBox(height: DpSpacing.md),
                ShadButton.secondary(
                  onPressed: onPickNextTask,
                  child: const Text('换任务再开始'),
                ),
              ],
            ],
          ),
        ),
        if (!isBreak) ...[
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '外周记事',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                ),
                ShadIconButton.ghost(
                  icon: const Icon(Icons.edit_note_outlined, size: 20),
                  onPressed: openFocusNote,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasFocusNote ? focusNote : '把打断/想法写下来，不离开专注主路径。',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: DpSpacing.sm),
                ShadButton.outline(
                  onPressed: openFocusNote,
                  leading: const Icon(Icons.edit_outlined, size: 16),
                  child: Text(hasFocusNote ? '编辑' : '记录'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: DpSpacing.md),
        todayCountAsync.when(
          data: (count) => ShadCard(
            padding: DpInsets.card,
            child: Text(
              '今日已完成 $count 个番茄',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.endAt, required this.onFinished});

  final DateTime endAt;
  final VoidCallback onFinished;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endAt != widget.endAt) {
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final now = DateTime.now();
    final remaining = widget.endAt.difference(now);
    final next = remaining.isNegative ? Duration.zero : remaining;
    if (mounted) {
      setState(() => _remaining = next);
    }
    if (next == Duration.zero) {
      _timer?.cancel();
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return DpTimerDisplay('$mm:$ss');
  }
}

class _StaticRemainingText extends StatelessWidget {
  const _StaticRemainingText({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return DpTimerDisplay('$mm:$ss');
  }
}

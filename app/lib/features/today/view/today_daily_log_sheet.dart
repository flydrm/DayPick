import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/local_events/local_events_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../focus/providers/focus_providers.dart';
import '../../notes/providers/note_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/today_plan_providers.dart';

class TodayDailyLogSheet extends ConsumerStatefulWidget {
  const TodayDailyLogSheet({super.key});

  @override
  ConsumerState<TodayDailyLogSheet> createState() => _TodayDailyLogSheetState();
}

class _TodayDailyLogSheetState extends ConsumerState<TodayDailyLogSheet> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _journalOpenedRecorded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final notesAsync = ref.watch(notesStreamProvider);
    final planIdsAsync = ref.watch(todayPlanTaskIdsProvider);
    final sessionsAsync = ref.watch(todayPomodoroSessionsProvider);
    final pomodoroConfigAsync = ref.watch(pomodoroConfigProvider);

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final notes = notesAsync.valueOrNull ?? const <domain.Note>[];
    final planIds = planIdsAsync.valueOrNull ?? const <String>[];
    final sessions =
        sessionsAsync.valueOrNull ?? const <domain.PomodoroSession>[];
    final config =
        pomodoroConfigAsync.valueOrNull ?? const domain.PomodoroConfig();

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final dateLabel = _dayLabel(day);
    final noteTitle = '$dateLabel · 今日记录';

    domain.Note? findExisting() {
      for (final n in notes) {
        if (n.title.value == noteTitle && n.kind == domain.NoteKind.longform) {
          return n;
        }
      }
      return null;
    }

    final existing = findExisting();
    final generated = _generateDailyLogMarkdown(
      day: day,
      tasks: tasks,
      planIds: planIds,
      sessions: sessions,
      workMinutes: config.workDurationMinutes,
    );

    final canInit =
        !tasksAsync.isLoading &&
        !notesAsync.isLoading &&
        !planIdsAsync.isLoading &&
        !sessionsAsync.isLoading &&
        !pomodoroConfigAsync.isLoading;
    if (!_initialized && canInit) {
      _initialized = true;
      _controller.text = generated;
      unawaited(_recordJournalOpened(dayKey: dateLabel));
    }

    Future<void> regenerate() async {
      setState(() => _controller.text = generated);
    }

    Future<void> save() async {
      if (_saving) return;
      setState(() => _saving = true);
      try {
        final body = _controller.text.trimRight();
        final tags = <String>{
          ...(existing?.tags ?? const <String>[]),
          'daily-log',
        }.toList();

        if (existing == null) {
          final create = ref.read(createNoteUseCaseProvider);
          final created = await create(
            title: noteTitle,
            body: body,
            tags: tags,
            kind: domain.NoteKind.longform,
            triageStatus: domain.TriageStatus.scheduledLater,
          );
          await _recordJournalCompleted(dayKey: dateLabel, body: body);
          if (!context.mounted) return;
          Navigator.of(context).pop(created.id);
          return;
        }

        final update = ref.read(updateNoteUseCaseProvider);
        final updated = await update(
          note: existing,
          title: noteTitle,
          body: body,
          tags: tags,
          kind: domain.NoteKind.longform,
          triageStatus: domain.TriageStatus.scheduledLater,
        );
        await _recordJournalCompleted(dayKey: dateLabel, body: body);
        if (!context.mounted) return;
        Navigator.of(context).pop(updated.id);
      } on domain.NoteTitleEmptyException {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('标题不能为空')));
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
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
                      '今日记录',
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
                existing == null
                    ? '将创建笔记：$noteTitle（可编辑后保存）'
                    : '将更新已有记录：$noteTitle（可编辑后保存）',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              Expanded(
                child: ShadCard(
                  padding: DpInsets.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ShadButton.outline(
                              size: ShadButtonSize.sm,
                              onPressed: _saving ? null : regenerate,
                              leading: const Icon(Icons.refresh, size: 16),
                              child: const Text('重新生成'),
                            ),
                          ),
                          const SizedBox(width: DpSpacing.sm),
                          Expanded(
                            child: ShadButton(
                              size: ShadButtonSize.sm,
                              onPressed: _saving ? null : save,
                              leading: const Icon(
                                Icons.save_outlined,
                                size: 16,
                              ),
                              child: Text(_saving ? '保存中…' : '保存为笔记'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DpSpacing.sm),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final inputPadding =
                                shadTheme.inputTheme.padding ??
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                );
                            final minHeight = constraints.maxHeight < 120
                                ? constraints.maxHeight
                                : 120.0;
                            final editorHeight =
                                (constraints.maxHeight -
                                        inputPadding.vertical -
                                        2)
                                    .clamp(minHeight, constraints.maxHeight);

                            return ShadTextarea(
                              controller: _controller,
                              enabled: !_saving,
                              resizable: false,
                              minHeight: editorHeight,
                              maxHeight: editorHeight,
                              placeholder: const Text('生成中…'),
                              leading: const Icon(
                                Icons.description_outlined,
                                size: 18,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (tasksAsync.hasError ||
                  notesAsync.hasError ||
                  planIdsAsync.hasError ||
                  sessionsAsync.hasError ||
                  pomodoroConfigAsync.hasError) ...[
                const SizedBox(height: DpSpacing.md),
                ShadAlert.destructive(
                  icon: const Icon(Icons.error_outline),
                  title: const Text('部分数据加载失败'),
                  description: Text(
                    [
                      if (tasksAsync.hasError) '任务：${tasksAsync.error}',
                      if (notesAsync.hasError) '笔记：${notesAsync.error}',
                      if (planIdsAsync.hasError) '计划：${planIdsAsync.error}',
                      if (sessionsAsync.hasError) '专注：${sessionsAsync.error}',
                      if (pomodoroConfigAsync.hasError)
                        '配置：${pomodoroConfigAsync.error}',
                    ].join('\n'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordJournalOpened({required String dayKey}) async {
    if (_journalOpenedRecorded) return;
    _journalOpenedRecorded = true;
    await ref
        .read(localEventsServiceProvider)
        .record(
          eventName: domain.LocalEventNames.journalOpened,
          metaJson: <String, Object?>{
            'day_key': dayKey,
            'source': 'today_daily_log_sheet',
          },
        );
  }

  Future<void> _recordJournalCompleted({
    required String dayKey,
    required String body,
  }) async {
    await ref
        .read(localEventsServiceProvider)
        .record(
          eventName: domain.LocalEventNames.journalCompleted,
          metaJson: <String, Object?>{
            'day_key': dayKey,
            'answered_prompts_count': _answeredPromptsCount(body),
            'refs_count': _refsCount(body),
            'has_text': body.trim().isNotEmpty,
          },
        );
  }

  int _answeredPromptsCount(String body) {
    final lines = body.split(String.fromCharCode(10));
    var count = 0;
    for (final heading in const ['## 一句话总结', '## 留痕（进展）', '## 备注']) {
      if (_sectionHasMeaningfulText(lines: lines, heading: heading)) {
        count += 1;
      }
    }
    return count;
  }

  bool _sectionHasMeaningfulText({
    required List<String> lines,
    required String heading,
  }) {
    final startIndex = lines.indexOf(heading);
    if (startIndex < 0) return false;
    for (var i = startIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('## ')) break;
      if (line.isEmpty ||
          line == '-' ||
          line == '- ' ||
          line == '- （可选）' ||
          line == '- （空）') {
        continue;
      }
      return true;
    }
    return false;
  }

  int _refsCount(String body) {
    return RegExp(RegExp.escape('[[route:')).allMatches(body).length;
  }

  String _dayLabel(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _generateDailyLogMarkdown({
    required DateTime day,
    required List<domain.Task> tasks,
    required List<String> planIds,
    required List<domain.PomodoroSession> sessions,
    required int workMinutes,
  }) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final taskById = {for (final t in tasks) t.id: t};
    final planTasks = <domain.Task>[
      for (final id in planIds)
        if (taskById[id] != null) taskById[id]!,
    ];

    final doneToday =
        tasks
            .where((t) => t.status == domain.TaskStatus.done)
            .where(
              (t) => !t.updatedAt.isBefore(start) && t.updatedAt.isBefore(end),
            )
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final focusSessions = sessions
        .where((s) => !s.isDraft)
        .toList(growable: false);
    final totalFocusMinutes = focusSessions.fold<int>(
      0,
      (sum, s) => sum + s.duration.inMinutes,
    );

    final sessionsByTask = <String, List<domain.PomodoroSession>>{};
    for (final s in focusSessions) {
      sessionsByTask.putIfAbsent(s.taskId, () => []).add(s);
    }

    final focusSummary = sessionsByTask.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final progressNotes = <({String taskId, String title, String note})>[];
    for (final s in focusSessions) {
      final raw = s.progressNote?.trim();
      if (raw == null || raw.isEmpty) continue;
      final task = taskById[s.taskId];
      progressNotes.add((
        taskId: s.taskId,
        title: task?.title.value ?? '任务',
        note: raw,
      ));
    }

    String linkTask(String text, String taskId) =>
        '$text [[route:/tasks/$taskId]]';

    final buffer = StringBuffer();
    final dayLabel = _dayLabel(day);

    buffer.writeln('# 今日记录 · $dayLabel');
    buffer.writeln();
    buffer.writeln('## 一句话总结');
    buffer.writeln('- （可选）');
    buffer.writeln();

    buffer.writeln('## 今天计划（${planTasks.length}）');
    if (planTasks.isEmpty) {
      buffer.writeln('- （空）先把 3–5 条任务装入今天计划');
    } else {
      for (final t in planTasks) {
        final est = t.estimatedPomodoros;
        final pomodoros = est == null || est <= 0 ? 1 : est;
        buffer.writeln(
          '- ${linkTask('${t.title.value}（$pomodoros 番茄）', t.id)}',
        );
      }
    }
    buffer.writeln();

    buffer.writeln('## 完成（${doneToday.length}）');
    if (doneToday.isEmpty) {
      buffer.writeln('- （空）');
    } else {
      for (final t in doneToday.take(20)) {
        buffer.writeln('- ${linkTask(t.title.value, t.id)}');
      }
      if (doneToday.length > 20) {
        buffer.writeln('- …（仅展示 20 条）');
      }
    }
    buffer.writeln();

    buffer.writeln('## 专注（${focusSessions.length} 番茄 · ${totalFocusMinutes}m）');
    if (focusSessions.isEmpty) {
      buffer.writeln('- （空）');
    } else {
      for (final e in focusSummary.take(10)) {
        final task = taskById[e.key];
        final title = task?.title.value ?? '（任务已删除）';
        final minutes = e.value.fold<int>(
          0,
          (sum, s) => sum + s.duration.inMinutes,
        );
        buffer.writeln(
          '- ${linkTask('$title ×${e.value.length}（${minutes}m）', e.key)}',
        );
      }
      if (focusSummary.length > 10) {
        buffer.writeln('- …（仅展示 10 条）');
      }
    }
    buffer.writeln();

    buffer.writeln('## 留痕（进展）');
    if (progressNotes.isEmpty) {
      buffer.writeln('- （空）');
    } else {
      for (final p in progressNotes.take(10)) {
        buffer.writeln('- ${linkTask('${p.title}：${p.note}', p.taskId)}');
      }
      if (progressNotes.length > 10) {
        buffer.writeln('- …（仅展示 10 条）');
      }
    }
    buffer.writeln();

    buffer.writeln('## 备注');
    buffer.writeln('- ');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('生成：预计番茄 ${workMinutes}m/番茄 · 本地-only（无日历同步）');

    return buffer.toString().trimRight();
  }
}

import 'dart:async';

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../notes/providers/note_providers.dart';
import '../../notes/view/note_edit_sheet.dart';
import '../../notes/view/select_longform_note_sheet.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/view/task_edit_sheet.dart';
import '../../weave/view/weave_mode_sheet.dart';
import '../../weave/weave_service.dart';
import '../providers/inbox_undo_providers.dart';
import 'breakdown_to_tasks_sheet.dart';
import 'inbox_undo_stack_sheet.dart';

enum _InboxEntryType { task, note }

class _InboxEntry {
  _InboxEntry.task(domain.Task this.task)
    : type = _InboxEntryType.task,
      note = null,
      createdAt = task.createdAt,
      updatedAt = task.updatedAt;

  _InboxEntry.note(domain.Note this.note)
    : type = _InboxEntryType.note,
      task = null,
      createdAt = note.createdAt,
      updatedAt = note.updatedAt;

  final _InboxEntryType type;
  final domain.Task? task;
  final domain.Note? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get id => switch (type) {
    _InboxEntryType.task => task!.id,
    _InboxEntryType.note => note!.id,
  };
}

class InboxProcessPage extends ConsumerStatefulWidget {
  const InboxProcessPage({super.key});

  @override
  ConsumerState<InboxProcessPage> createState() => _InboxProcessPageState();
}

class _InboxProcessPageState extends ConsumerState<InboxProcessPage> {
  bool _processing = false;
  int _processedCount = 0;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final notesAsync = ref.watch(unprocessedNotesStreamProvider);
    final appearanceAsync = ref.watch(appearanceConfigProvider);
    final undoEntries = ref.watch(inboxUndoStackProvider);

    final appearance =
        appearanceAsync.valueOrNull ?? const domain.AppearanceConfig();
    final filter = appearance.inboxTypeFilter;
    final todayOnly = appearance.inboxTodayOnly;

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final notes = notesAsync.valueOrNull ?? const <domain.Note>[];

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    bool isToday(DateTime time) =>
        !time.isBefore(startOfToday) && time.isBefore(endOfToday);

    final inboxTasksAll = tasks
        .where((t) => t.triageStatus == domain.TriageStatus.inbox)
        .toList(growable: false);
    final inboxTasks = todayOnly
        ? inboxTasksAll
              .where((t) => isToday(t.createdAt))
              .toList(growable: false)
        : inboxTasksAll;

    final inboxNotesAll = notes.toList(growable: false);
    final inboxNotes = todayOnly
        ? inboxNotesAll
              .where((n) => isToday(n.createdAt))
              .toList(growable: false)
        : inboxNotesAll;
    final inboxMemos = inboxNotes
        .where((n) => n.kind == domain.NoteKind.memo)
        .toList(growable: false);
    final inboxDrafts = inboxNotes
        .where((n) => n.kind == domain.NoteKind.draft)
        .toList(growable: false);

    final entries = <_InboxEntry>[
      if (filter == domain.InboxTypeFilter.all ||
          filter == domain.InboxTypeFilter.tasks)
        for (final t in inboxTasks) _InboxEntry.task(t),
      if (filter == domain.InboxTypeFilter.all ||
          filter == domain.InboxTypeFilter.memos)
        for (final n in inboxMemos) _InboxEntry.note(n),
      if (filter == domain.InboxTypeFilter.all ||
          filter == domain.InboxTypeFilter.drafts)
        for (final n in inboxDrafts) _InboxEntry.note(n),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final remainingCount = entries.length;
    final current = entries.isEmpty ? null : entries.first;

    return AppPageScaffold(
      title: '处理模式',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      actions: [
        Tooltip(
          message: undoEntries.isEmpty ? '撤销栈' : '撤销栈（${undoEntries.length}）',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.undo, size: 20),
            onPressed: undoEntries.isEmpty
                ? null
                : () => _openUndoStack(context),
          ),
        ),
      ],
      body: ListView(
        padding: DpInsets.page,
        children: [
          ShadCard(
            padding: DpInsets.card,
            title: Text(
              '进度',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            child: Text(
              '剩余 $remainingCount · 本次已处理 $_processedCount',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          if (tasksAsync.isLoading || notesAsync.isLoading)
            const ShadProgress(minHeight: 8)
          else if (tasksAsync.hasError || notesAsync.hasError)
            ShadAlert.destructive(
              icon: const Icon(Icons.error_outline),
              title: const Text('加载失败'),
              description: Text(
                'tasks: ${tasksAsync.error ?? 'ok'}\nnotes: ${notesAsync.error ?? 'ok'}',
              ),
            )
          else if (current == null)
            ShadCard(
              padding: DpInsets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '已清空待处理',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '你可以回到列表继续收集，或回 Today 进入专注。',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  ShadButton.outline(
                    onPressed: () => context.pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            )
          else
            _InboxProcessCard(
              entry: current,
              processing: _processing,
              onEdit: () => _openEdit(entry: current),
              onBreakdown: () => _openBreakdown(entry: current),
              onAddToToday: () => _processWithUndo(
                actionName: '已加入今天计划',
                action: () => _addToToday(current),
              ),
              onMoveLater: () => _processWithUndo(
                actionName: '已移到以后',
                action: () => _moveLater(current),
              ),
              onWeave: () => _processWithUndo(
                actionName: '已编织到长文',
                action: () => _weave(current),
              ),
              onArchive: () => _processWithUndo(
                actionName: '已归档',
                action: () => _archive(current),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openUndoStack(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const InboxUndoStackSheet(),
    );
  }

  Future<void> _processWithUndo({
    required String actionName,
    required Future<InboxUndoEntry> Function() action,
  }) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final undoEntry = await action();
      if (!mounted) return;

      setState(() => _processedCount += 1);

      final stack = ref.read(inboxUndoStackProvider.notifier);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(undoEntry.message),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => unawaited(stack.undoById(undoEntry.id)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$actionName 失败：$e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<InboxUndoEntry> _addToToday(_InboxEntry entry) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    final stack = ref.read(inboxUndoStackProvider.notifier);
    final planRepo = ref.read(todayPlanRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);
    final noteRepo = ref.read(noteRepositoryProvider);

    return switch (entry.type) {
      _InboxEntryType.task => () async {
        final before = entry.task!;
        await planRepo.addTask(day: day, taskId: before.id);
        await taskRepo.upsertTask(
          before.copyWith(
            triageStatus: domain.TriageStatus.plannedToday,
            updatedAt: now,
          ),
        );
        return stack.push(
          message: '已加入今天计划',
          undo: () async {
            await planRepo.removeTask(day: day, taskId: before.id);
            await taskRepo.upsertTask(
              before.copyWith(updatedAt: DateTime.now()),
            );
          },
        );
      }(),
      _InboxEntryType.note => () async {
        final note = entry.note!;
        final beforeNote = note;

        domain.Task? taskBefore;
        final linkedTaskId = note.taskId?.trim();
        if (linkedTaskId != null && linkedTaskId.isNotEmpty) {
          taskBefore = await taskRepo.getTaskById(linkedTaskId);
        }

        final task =
            taskBefore ??
            await ref.read(createTaskUseCaseProvider)(
              title: note.title.value,
              description: note.body,
              tags: note.tags,
              triageStatus: domain.TriageStatus.plannedToday,
            );

        await planRepo.addTask(day: day, taskId: task.id);
        await noteRepo.upsertNote(
          note.copyWith(
            taskId: task.id,
            triageStatus: domain.TriageStatus.scheduledLater,
            updatedAt: now,
          ),
        );

        return stack.push(
          message: taskBefore == null ? '已转为任务并加入今天' : '已加入今天计划',
          undo: () async {
            await planRepo.removeTask(day: day, taskId: task.id);
            if (taskBefore == null) {
              await taskRepo.deleteTask(task.id);
            } else {
              await taskRepo.upsertTask(
                taskBefore.copyWith(updatedAt: DateTime.now()),
              );
            }
            await noteRepo.upsertNote(
              beforeNote.copyWith(updatedAt: DateTime.now()),
            );
          },
        );
      }(),
    };
  }

  Future<InboxUndoEntry> _moveLater(_InboxEntry entry) async {
    final now = DateTime.now();
    final stack = ref.read(inboxUndoStackProvider.notifier);

    return switch (entry.type) {
      _InboxEntryType.task => () async {
        final repo = ref.read(taskRepositoryProvider);
        final before = entry.task!;
        await repo.upsertTask(
          before.copyWith(
            triageStatus: domain.TriageStatus.scheduledLater,
            updatedAt: now,
          ),
        );
        return stack.push(
          message: '已移到以后',
          undo: () async =>
              repo.upsertTask(before.copyWith(updatedAt: DateTime.now())),
        );
      }(),
      _InboxEntryType.note => () async {
        final repo = ref.read(noteRepositoryProvider);
        final before = entry.note!;
        await repo.upsertNote(
          before.copyWith(
            triageStatus: domain.TriageStatus.scheduledLater,
            updatedAt: now,
          ),
        );
        return stack.push(
          message: '已标记已处理',
          undo: () async =>
              repo.upsertNote(before.copyWith(updatedAt: DateTime.now())),
        );
      }(),
    };
  }

  Future<InboxUndoEntry> _archive(_InboxEntry entry) async {
    final now = DateTime.now();
    final stack = ref.read(inboxUndoStackProvider.notifier);

    return switch (entry.type) {
      _InboxEntryType.task => () async {
        final repo = ref.read(taskRepositoryProvider);
        final before = entry.task!;
        await repo.upsertTask(
          before.copyWith(
            triageStatus: domain.TriageStatus.archived,
            updatedAt: now,
          ),
        );
        return stack.push(
          message: '已归档',
          undo: () async =>
              repo.upsertTask(before.copyWith(updatedAt: DateTime.now())),
        );
      }(),
      _InboxEntryType.note => () async {
        final repo = ref.read(noteRepositoryProvider);
        final before = entry.note!;
        await repo.upsertNote(
          before.copyWith(
            triageStatus: domain.TriageStatus.archived,
            updatedAt: now,
          ),
        );
        return stack.push(
          message: '已归档',
          undo: () async =>
              repo.upsertNote(before.copyWith(updatedAt: DateTime.now())),
        );
      }(),
    };
  }

  Future<InboxUndoEntry> _weave(_InboxEntry entry) async {
    final mode = await showModalBottomSheet<domain.WeaveMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const WeaveModeSheet(),
    );
    if (mode == null) throw StateError('cancelled');
    if (!mounted) throw StateError('cancelled');

    final targetNoteId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectLongformNoteSheet(),
    );
    if (targetNoteId == null) throw StateError('cancelled');
    if (!mounted) throw StateError('cancelled');

    final stack = ref.read(inboxUndoStackProvider.notifier);

    final result = await weaveToLongform(
      ref: ref,
      targetNoteId: targetNoteId,
      mode: mode,
      tasks: entry.type == _InboxEntryType.task ? [entry.task!] : const [],
      notes: entry.type == _InboxEntryType.note ? [entry.note!] : const [],
    );

    return stack.push(
      message: mode == domain.WeaveMode.copy ? '已拷贝编织到长文' : '已编织到长文',
      undo: () async => undoWeaveToLongform(ref, result),
    );
  }

  Future<void> _openEdit({required _InboxEntry entry}) async {
    if (_processing) return;
    switch (entry.type) {
      case _InboxEntryType.task:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => TaskEditSheet(task: entry.task!),
        );
        break;
      case _InboxEntryType.note:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => NoteEditSheet(note: entry.note!),
        );
        break;
    }
  }

  Future<void> _openBreakdown({required _InboxEntry entry}) async {
    if (_processing) return;

    final result = await showModalBottomSheet<BreakdownToTasksResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => switch (entry.type) {
        _InboxEntryType.task => BreakdownToTasksSheet(task: entry.task!),
        _InboxEntryType.note => BreakdownToTasksSheet(note: entry.note!),
      },
    );

    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已创建 ${result.createdTaskIds.length} 条任务')),
    );
  }
}

class _InboxProcessCard extends StatelessWidget {
  const _InboxProcessCard({
    required this.entry,
    required this.processing,
    required this.onEdit,
    required this.onBreakdown,
    required this.onAddToToday,
    required this.onMoveLater,
    required this.onWeave,
    required this.onArchive,
  });

  final _InboxEntry entry;
  final bool processing;
  final VoidCallback onEdit;
  final VoidCallback onBreakdown;
  final VoidCallback onAddToToday;
  final VoidCallback onMoveLater;
  final VoidCallback onWeave;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final title = switch (entry.type) {
      _InboxEntryType.task => entry.task!.title.value,
      _InboxEntryType.note => entry.note!.title.value,
    };
    final subtitle = switch (entry.type) {
      _InboxEntryType.task => entry.task!.description?.trim(),
      _InboxEntryType.note => entry.note!.body.trim(),
    };
    final typeLabel = switch (entry.type) {
      _InboxEntryType.task => '任务',
      _InboxEntryType.note =>
        entry.note!.kind == domain.NoteKind.memo ? '闪念' : '草稿',
    };

    return ShadCard(
      padding: DpInsets.card,
      title: Row(
        children: [
          ShadBadge.outline(child: Text(typeLabel)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null && subtitle.isNotEmpty) ...[
            Text(
              subtitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: DpSpacing.md),
          ] else ...[
            Text(
              '对这一条做决定：今天 / 以后 / 编织 / 归档。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: DpSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: ShadButton.secondary(
                  onPressed: processing ? null : onAddToToday,
                  leading: const Icon(Icons.today_outlined, size: 16),
                  child: const Text('今天'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.outline(
                  onPressed: processing ? null : onMoveLater,
                  leading: const Icon(Icons.schedule_outlined, size: 16),
                  child: const Text('以后'),
                ),
              ),
            ],
          ),
          const SizedBox(height: DpSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  onPressed: processing ? null : onWeave,
                  leading: const Icon(Icons.link_outlined, size: 16),
                  child: const Text('编织'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.destructive(
                  onPressed: processing ? null : onArchive,
                  leading: const Icon(Icons.archive_outlined, size: 16),
                  child: const Text('归档'),
                ),
              ),
            ],
          ),
          const SizedBox(height: DpSpacing.md),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  onPressed: processing ? null : onEdit,
                  leading: const Icon(Icons.edit_outlined, size: 16),
                  child: const Text('澄清编辑'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.outline(
                  onPressed: processing ? null : onBreakdown,
                  leading: const Icon(Icons.auto_fix_high_outlined, size: 16),
                  child: const Text('拆分'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

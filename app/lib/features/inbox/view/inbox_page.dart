import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/sheets/date_picker_sheet.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../providers/inbox_undo_providers.dart';
import '../../notes/providers/note_providers.dart';
import '../../notes/view/note_edit_sheet.dart';
import '../../notes/view/select_longform_note_sheet.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/view/task_edit_sheet.dart';
import '../../weave/view/weave_mode_sheet.dart';
import '../../weave/weave_service.dart';
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
}

class InboxPage extends ConsumerStatefulWidget {
  const InboxPage({super.key});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  bool _selectionMode = false;
  domain.InboxTypeFilter _filter = domain.InboxTypeFilter.all;
  bool _todayOnly = false;
  bool _didLoadFilterPrefs = false;
  final Set<String> _selectedTaskIds = <String>{};
  final Set<String> _selectedNoteIds = <String>{};

  int get _selectedCount => _selectedTaskIds.length + _selectedNoteIds.length;

  Future<void> _saveFilterPrefs({
    domain.InboxTypeFilter? typeFilter,
    bool? todayOnly,
  }) async {
    try {
      final repo = ref.read(appearanceConfigRepositoryProvider);
      final current = await ref.read(appearanceConfigProvider.future);
      await repo.save(
        current.copyWith(
          inboxTypeFilter: typeFilter ?? current.inboxTypeFilter,
          inboxTodayOnly: todayOnly ?? current.inboxTodayOnly,
        ),
      );
    } catch (_) {}
  }

  bool _isSelected(_InboxEntry entry) {
    return switch (entry.type) {
      _InboxEntryType.task => _selectedTaskIds.contains(entry.task!.id),
      _InboxEntryType.note => _selectedNoteIds.contains(entry.note!.id),
    };
  }

  void _toggleSelected(_InboxEntry entry) {
    setState(() {
      switch (entry.type) {
        case _InboxEntryType.task:
          final id = entry.task!.id;
          if (_selectedTaskIds.contains(id)) {
            _selectedTaskIds.remove(id);
          } else {
            _selectedTaskIds.add(id);
          }
          break;
        case _InboxEntryType.note:
          final id = entry.note!.id;
          if (_selectedNoteIds.contains(id)) {
            _selectedNoteIds.remove(id);
          } else {
            _selectedNoteIds.add(id);
          }
          break;
      }

      if (_selectedCount == 0) {
        _selectionMode = false;
      }
    });
  }

  void _startSelection(_InboxEntry entry) {
    setState(() {
      _selectionMode = true;
      switch (entry.type) {
        case _InboxEntryType.task:
          _selectedTaskIds.add(entry.task!.id);
          break;
        case _InboxEntryType.note:
          _selectedNoteIds.add(entry.note!.id);
          break;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
      _selectedNoteIds.clear();
    });
  }

  void _setFilter(domain.InboxTypeFilter next) {
    setState(() {
      _filter = next;
      _selectionMode = false;
      _selectedTaskIds.clear();
      _selectedNoteIds.clear();
    });
    () async {
      await _saveFilterPrefs(typeFilter: next);
    }();
  }

  void _setTodayOnly(bool next) {
    setState(() {
      _todayOnly = next;
      _selectionMode = false;
      _selectedTaskIds.clear();
      _selectedNoteIds.clear();
    });
    () async {
      await _saveFilterPrefs(todayOnly: next);
    }();
  }

  void _toggleSelectAll(List<_InboxEntry> entries) {
    final allSelected = entries.isNotEmpty && entries.every(_isSelected);
    setState(() {
      _selectionMode = true;
      _selectedTaskIds.clear();
      _selectedNoteIds.clear();

      if (allSelected) {
        _selectionMode = false;
        return;
      }

      for (final entry in entries) {
        switch (entry.type) {
          case _InboxEntryType.task:
            _selectedTaskIds.add(entry.task!.id);
            break;
          case _InboxEntryType.note:
            _selectedNoteIds.add(entry.note!.id);
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final notesAsync = ref.watch(unprocessedNotesStreamProvider);
    final appearanceAsync = ref.watch(appearanceConfigProvider);
    final undoEntries = ref.watch(inboxUndoStackProvider);

    final appearance = appearanceAsync.valueOrNull;
    if (!_didLoadFilterPrefs && appearance != null) {
      _filter = appearance.inboxTypeFilter;
      _todayOnly = appearance.inboxTodayOnly;
      _didLoadFilterPrefs = true;
    }

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final notes = notesAsync.valueOrNull ?? const <domain.Note>[];
    final taskById = {for (final t in tasks) t.id: t};
    final noteById = {for (final n in notes) n.id: n};

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    bool isToday(DateTime time) =>
        !time.isBefore(startOfToday) && time.isBefore(endOfToday);

    final inboxTasksAll = tasks
        .where((t) => t.triageStatus == domain.TriageStatus.inbox)
        .toList(growable: false);
    final inboxNotesAll = notes.toList(growable: false);

    final inboxTasks = _todayOnly
        ? inboxTasksAll
              .where((t) => isToday(t.createdAt))
              .toList(growable: false)
        : inboxTasksAll;
    final inboxNotes = _todayOnly
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
      if (_filter == domain.InboxTypeFilter.all ||
          _filter == domain.InboxTypeFilter.tasks)
        for (final t in inboxTasks) _InboxEntry.task(t),
      if (_filter == domain.InboxTypeFilter.all ||
          _filter == domain.InboxTypeFilter.memos)
        for (final n in inboxMemos) _InboxEntry.note(n),
      if (_filter == domain.InboxTypeFilter.all ||
          _filter == domain.InboxTypeFilter.drafts)
        for (final n in inboxDrafts) _InboxEntry.note(n),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final selectedTasks = <domain.Task>[
      for (final id in _selectedTaskIds)
        if (taskById[id] != null) taskById[id]!,
    ];
    final selectedNotes = <domain.Note>[
      for (final id in _selectedNoteIds)
        if (noteById[id] != null) noteById[id]!,
    ];

    final allSelected = entries.isNotEmpty && entries.every(_isSelected);

    return AppPageScaffold(
      title: _selectionMode ? '已选择 $_selectedCount' : '待处理',
      showSettingsAction: !_selectionMode,
      showCreateAction: !_selectionMode,
      actions: [
        if (!_selectionMode)
          Tooltip(
            message: undoEntries.isEmpty ? '撤销栈' : '撤销栈（${undoEntries.length}）',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ShadIconButton.ghost(
                  icon: const Icon(Icons.undo, size: 20),
                  onPressed: undoEntries.isEmpty
                      ? null
                      : () => _openUndoStack(context),
                ),
                if (undoEntries.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
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
                        undoEntries.length >= 9
                            ? '9+'
                            : '${undoEntries.length}',
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
        if (!_selectionMode)
          Tooltip(
            message: '处理模式',
            child: ShadIconButton.ghost(
              icon: const Icon(Icons.playlist_play_outlined, size: 20),
              onPressed: () => context.push('/inbox/process'),
            ),
          ),
        if (_selectionMode)
          Tooltip(
            message: allSelected ? '全不选' : '全选',
            child: ShadIconButton.ghost(
              icon: Icon(allSelected ? Icons.remove_done : Icons.select_all),
              onPressed: () => _toggleSelectAll(entries),
            ),
          ),
        if (_selectionMode)
          Tooltip(
            message: '取消选择',
            child: ShadIconButton.ghost(
              icon: const Icon(Icons.close, size: 20),
              onPressed: _exitSelectionMode,
            ),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: DpInsets.page,
              children: [
                ShadAlert(
                  icon: const Icon(Icons.inbox_outlined),
                  title: const Text('收件箱（待处理）'),
                  description: const Text('这里是你的收件箱：先收下，再处理进今天/以后/归档。长按可批量处理。'),
                ),
                if (!_selectionMode) ...[
                  const SizedBox(height: DpSpacing.md),
                  _InboxFilterBar(
                    value: _filter,
                    todayOnly: _todayOnly,
                    totalCount: inboxTasks.length + inboxNotes.length,
                    taskCount: inboxTasks.length,
                    memoCount: inboxMemos.length,
                    draftCount: inboxDrafts.length,
                    onChanged: _setFilter,
                    onTodayOnlyChanged: _setTodayOnly,
                  ),
                ],
                if (tasksAsync.isLoading || notesAsync.isLoading) ...[
                  const SizedBox(height: DpSpacing.md),
                  const ShadProgress(minHeight: 8),
                ],
                if (tasksAsync.hasError || notesAsync.hasError) ...[
                  const SizedBox(height: DpSpacing.md),
                  DpInlineNotice(
                    variant: DpInlineNoticeVariant.destructive,
                    title: '加载失败',
                    description:
                        'tasks: ${tasksAsync.error ?? 'ok'}\nnotes: ${notesAsync.error ?? 'ok'}',
                    icon: const Icon(Icons.error_outline),
                  ),
                ],
                const SizedBox(height: DpSpacing.lg),
                if (entries.isEmpty &&
                    !(tasksAsync.isLoading || notesAsync.isLoading))
                  const DpEmptyState(
                    icon: Icons.inbox_outlined,
                    title: '收件箱为空',
                    description: '去「任务」或「闪念」新建一条，再回来处理与编织。',
                  )
                else
                  ShadCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 0, color: colorScheme.border),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final selected = _isSelected(entry);
                        return _InboxRow(
                          entry: entry,
                          selectionMode: _selectionMode,
                          selected: selected,
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelected(entry);
                              return;
                            }
                            _openEntry(context, entry);
                          },
                          onLongPress: () {
                            if (_selectionMode) {
                              _toggleSelected(entry);
                              return;
                            }
                            _startSelection(entry);
                          },
                          onActions: () => _openActions(context, entry),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_selectionMode && _selectedCount > 0)
            _InboxBulkActionsBar(
              selectedCount: _selectedCount,
              selectedTaskCount: selectedTasks.length,
              selectedNoteCount: selectedNotes.length,
              onAddToToday: selectedTasks.isEmpty && selectedNotes.isEmpty
                  ? null
                  : () =>
                        _bulkAddToToday(context, selectedTasks, selectedNotes),
              onMoveLater: () =>
                  _bulkMoveLater(context, selectedTasks, selectedNotes),
              onWeave: () => _bulkWeave(context, selectedTasks, selectedNotes),
              onArchive: () =>
                  _bulkArchive(context, selectedTasks, selectedNotes),
            ),
        ],
      ),
    );
  }

  void _openEntry(BuildContext context, _InboxEntry entry) {
    switch (entry.type) {
      case _InboxEntryType.task:
        context.push('/tasks/${entry.task!.id}');
        return;
      case _InboxEntryType.note:
        context.push('/notes/${entry.note!.id}');
        return;
    }
  }

  Future<void> _openActions(BuildContext context, _InboxEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          _InboxActionsSheet(entry: entry, ref: ref, scaffoldContext: context),
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

  Future<void> _bulkAddToToday(
    BuildContext context,
    List<domain.Task> tasks,
    List<domain.Note> notes,
  ) async {
    if (tasks.isEmpty && notes.isEmpty) return;

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final createTask = ref.read(createTaskUseCaseProvider);
    final planRepo = ref.read(todayPlanRepositoryProvider);
    final existingPlanIdSet = (await planRepo.getTaskIdsForDay(
      day: day,
    )).toSet();
    final taskRepo = ref.read(taskRepositoryProvider);
    final noteRepo = ref.read(noteRepositoryProvider);

    final beforeTasks = List<domain.Task>.from(tasks);
    final beforeNotes = List<domain.Note>.from(notes);

    final addedPlanTaskIds = <String>{};
    final createdTaskIds = <String>{};
    final taskRestoreById = <String, domain.Task>{};

    Future<void> addToPlan(String taskId) async {
      final wasInPlan = existingPlanIdSet.contains(taskId);
      final wasAddedByThisAction = addedPlanTaskIds.contains(taskId);
      await planRepo.addTask(day: day, taskId: taskId);
      if (wasInPlan || wasAddedByThisAction) return;
      addedPlanTaskIds.add(taskId);
    }

    for (final task in beforeTasks) {
      taskRestoreById.putIfAbsent(task.id, () => task);
      await addToPlan(task.id);
      await taskRepo.upsertTask(
        task.copyWith(
          triageStatus: domain.TriageStatus.plannedToday,
          updatedAt: now,
        ),
      );
    }

    for (final note in beforeNotes) {
      final linkedId = note.taskId?.trim();
      domain.Task? linkedTask;
      if (linkedId != null && linkedId.isNotEmpty) {
        linkedTask = await taskRepo.getTaskById(linkedId);
      }

      final task =
          linkedTask ??
          await createTask(
            title: note.title.value,
            description: note.body,
            tags: note.tags,
            triageStatus: domain.TriageStatus.plannedToday,
          );
      if (linkedTask == null) createdTaskIds.add(task.id);

      if (linkedTask != null) {
        taskRestoreById.putIfAbsent(task.id, () => linkedTask!);
        await taskRepo.upsertTask(
          linkedTask.copyWith(
            triageStatus: domain.TriageStatus.plannedToday,
            updatedAt: now,
          ),
        );
      }

      await addToPlan(task.id);
      await noteRepo.upsertNote(
        note.copyWith(
          taskId: task.id,
          triageStatus: domain.TriageStatus.scheduledLater,
          updatedAt: now,
        ),
      );
    }

    if (!context.mounted) return;
    _exitSelectionMode();
    final noteCount = beforeNotes.length;
    final taskCount = beforeTasks.length;
    final total = noteCount + taskCount;
    _showUndoSnack(
      context,
      message: noteCount == 0
          ? '已加入今天计划（$taskCount）'
          : '已加入今天计划（$total；含闪念/草稿 $noteCount）',
      undo: () async {
        for (final id in addedPlanTaskIds) {
          await planRepo.removeTask(day: day, taskId: id);
        }
        for (final id in createdTaskIds) {
          await taskRepo.deleteTask(id);
        }
        for (final before in taskRestoreById.values) {
          await taskRepo.upsertTask(before.copyWith(updatedAt: DateTime.now()));
        }
        for (final before in beforeNotes) {
          await noteRepo.upsertNote(before.copyWith(updatedAt: DateTime.now()));
        }
      },
    );
  }

  Future<void> _bulkMoveLater(
    BuildContext context,
    List<domain.Task> tasks,
    List<domain.Note> notes,
  ) async {
    if (tasks.isEmpty && notes.isEmpty) return;

    final beforeTasks = List<domain.Task>.from(tasks);
    final beforeNotes = List<domain.Note>.from(notes);
    final taskRepo = ref.read(taskRepositoryProvider);
    final noteRepo = ref.read(noteRepositoryProvider);

    for (final task in beforeTasks) {
      await taskRepo.upsertTask(
        task.copyWith(
          triageStatus: domain.TriageStatus.scheduledLater,
          updatedAt: DateTime.now(),
        ),
      );
    }
    for (final note in beforeNotes) {
      await noteRepo.upsertNote(
        note.copyWith(
          triageStatus: domain.TriageStatus.scheduledLater,
          updatedAt: DateTime.now(),
        ),
      );
    }

    if (!context.mounted) return;
    _exitSelectionMode();
    _showUndoSnack(
      context,
      message: '已移到以后（${beforeTasks.length + beforeNotes.length}）',
      undo: () async {
        for (final task in beforeTasks) {
          await taskRepo.upsertTask(task.copyWith(updatedAt: DateTime.now()));
        }
        for (final note in beforeNotes) {
          await noteRepo.upsertNote(note.copyWith(updatedAt: DateTime.now()));
        }
      },
    );
  }

  Future<void> _bulkArchive(
    BuildContext context,
    List<domain.Task> tasks,
    List<domain.Note> notes,
  ) async {
    if (tasks.isEmpty && notes.isEmpty) return;

    final beforeTasks = List<domain.Task>.from(tasks);
    final beforeNotes = List<domain.Note>.from(notes);
    final taskRepo = ref.read(taskRepositoryProvider);
    final noteRepo = ref.read(noteRepositoryProvider);

    for (final task in beforeTasks) {
      await taskRepo.upsertTask(
        task.copyWith(
          triageStatus: domain.TriageStatus.archived,
          updatedAt: DateTime.now(),
        ),
      );
    }
    for (final note in beforeNotes) {
      await noteRepo.upsertNote(
        note.copyWith(
          triageStatus: domain.TriageStatus.archived,
          updatedAt: DateTime.now(),
        ),
      );
    }

    if (!context.mounted) return;
    _exitSelectionMode();
    _showUndoSnack(
      context,
      message: '已归档（${beforeTasks.length + beforeNotes.length}）',
      undo: () async {
        for (final task in beforeTasks) {
          await taskRepo.upsertTask(task.copyWith(updatedAt: DateTime.now()));
        }
        for (final note in beforeNotes) {
          await noteRepo.upsertNote(note.copyWith(updatedAt: DateTime.now()));
        }
      },
    );
  }

  Future<void> _bulkWeave(
    BuildContext context,
    List<domain.Task> tasks,
    List<domain.Note> notes,
  ) async {
    if (tasks.isEmpty && notes.isEmpty) return;

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

    final beforeTasks = List<domain.Task>.from(tasks);
    final beforeNotes = List<domain.Note>.from(notes);
    final result = await weaveToLongform(
      ref: ref,
      targetNoteId: targetNoteId,
      mode: mode,
      tasks: beforeTasks,
      notes: beforeNotes,
    );

    if (!context.mounted) return;
    _exitSelectionMode();
    _showUndoSnack(
      context,
      message: mode == domain.WeaveMode.copy
          ? '已拷贝编织 ${beforeTasks.length + beforeNotes.length} 项到长文'
          : '已编织 ${beforeTasks.length + beforeNotes.length} 项到长文',
      undo: () async => undoWeaveToLongform(ref, result),
    );
  }

  void _showUndoSnack(
    BuildContext context, {
    required String message,
    required Future<void> Function() undo,
  }) {
    final entry = ref
        .read(inboxUndoStackProvider.notifier)
        .push(message: message, undo: undo);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            () async {
              try {
                await ref
                    .read(inboxUndoStackProvider.notifier)
                    .undoById(entry.id);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('撤销失败：$e')));
              }
            }();
          },
        ),
      ),
    );
  }
}

class _InboxFilterBar extends StatelessWidget {
  const _InboxFilterBar({
    required this.value,
    required this.todayOnly,
    required this.totalCount,
    required this.taskCount,
    required this.memoCount,
    required this.draftCount,
    required this.onChanged,
    required this.onTodayOnlyChanged,
  });

  final domain.InboxTypeFilter value;
  final bool todayOnly;
  final int totalCount;
  final int taskCount;
  final int memoCount;
  final int draftCount;
  final ValueChanged<domain.InboxTypeFilter> onChanged;
  final ValueChanged<bool> onTodayOnlyChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(domain.InboxTypeFilter filter, String label) {
      final selected = value == filter;
      return selected
          ? ShadButton.secondary(
              size: ShadButtonSize.sm,
              onPressed: () => onChanged(filter),
              child: Text(label),
            )
          : ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: () => onChanged(filter),
              child: Text(label),
            );
    }

    return ShadCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              button(domain.InboxTypeFilter.all, '全部 ($totalCount)'),
              button(domain.InboxTypeFilter.tasks, '任务 ($taskCount)'),
              button(domain.InboxTypeFilter.memos, '闪念 ($memoCount)'),
              button(domain.InboxTypeFilter.drafts, '草稿 ($draftCount)'),
            ],
          ),
          const SizedBox(height: 10),
          ShadSwitch(
            value: todayOnly,
            onChanged: onTodayOnlyChanged,
            label: const Text('仅看今天收下'),
            sublabel: const Text('按创建时间筛选，不改数据'),
          ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.entry,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onActions,
  });

  final _InboxEntry entry;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final badge = switch (entry.type) {
      _InboxEntryType.task => const ShadBadge.secondary(child: Text('任务')),
      _InboxEntryType.note => ShadBadge.outline(
        child: Text(entry.note!.kind == domain.NoteKind.memo ? '闪念' : '草稿'),
      ),
    };

    final title = switch (entry.type) {
      _InboxEntryType.task => entry.task!.title.value,
      _InboxEntryType.note => entry.note!.title.value,
    };

    final subtitle = switch (entry.type) {
      _InboxEntryType.task => entry.task!.tags.take(3).join(' · '),
      _InboxEntryType.note =>
        _firstLine(entry.note!.body) ?? entry.note!.tags.take(3).join(' · '),
    };

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.mutedForeground,
              ),
              const SizedBox(width: 10),
            ],
            badge,
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
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
            if (!selectionMode)
              Tooltip(
                message: '处理',
                child: ShadIconButton.ghost(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onPressed: onActions,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _firstLine(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split('\n').first.trim();
  }
}

class _InboxBulkActionsBar extends StatelessWidget {
  const _InboxBulkActionsBar({
    required this.selectedCount,
    required this.selectedTaskCount,
    required this.selectedNoteCount,
    required this.onAddToToday,
    required this.onMoveLater,
    required this.onWeave,
    required this.onArchive,
  });

  final int selectedCount;
  final int selectedTaskCount;
  final int selectedNoteCount;
  final VoidCallback? onAddToToday;
  final VoidCallback onMoveLater;
  final VoidCallback onWeave;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.background,
          border: Border(top: BorderSide(color: colorScheme.border, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              selectedNoteCount == 0
                  ? '已选 $selectedCount 项'
                  : '已选 $selectedCount 项（任务 $selectedTaskCount，闪念/草稿 $selectedNoteCount）',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ShadButton.secondary(
                    key: const ValueKey('inbox_bulk_add_to_today'),
                    onPressed: onAddToToday,
                    size: ShadButtonSize.sm,
                    leading: const Icon(Icons.today_outlined, size: 16),
                    child: const Text('今天'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShadButton.outline(
                    onPressed: onMoveLater,
                    size: ShadButtonSize.sm,
                    leading: const Icon(Icons.schedule_outlined, size: 16),
                    child: const Text('以后'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShadButton.outline(
                    onPressed: onWeave,
                    size: ShadButtonSize.sm,
                    leading: const Icon(Icons.link, size: 16),
                    child: const Text('编织'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShadButton.destructive(
                    onPressed: onArchive,
                    size: ShadButtonSize.sm,
                    leading: const Icon(Icons.archive_outlined, size: 16),
                    child: const Text('归档'),
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

class _InboxActionsSheet extends StatelessWidget {
  const _InboxActionsSheet({
    required this.entry,
    required this.ref,
    required this.scaffoldContext,
  });

  final _InboxEntry entry;
  final WidgetRef ref;
  final BuildContext scaffoldContext;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final title = switch (entry.type) {
      _InboxEntryType.task => entry.task!.title.value,
      _InboxEntryType.note => entry.note!.title.value,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: shadTheme.textTheme.h4.copyWith(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (entry.type == _InboxEntryType.task) ..._taskActions(context),
            if (entry.type == _InboxEntryType.note) ..._noteActions(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _taskActions(BuildContext context) {
    final task = entry.task!;
    return [
      ShadButton(
        onPressed: () async {
          Navigator.of(context).pop();
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => TaskEditSheet(task: task),
          );
        },
        child: const Text('澄清编辑'),
      ),
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () async {
          Navigator.of(context).pop();
          final result = await showModalBottomSheet<BreakdownToTasksResult>(
            context: scaffoldContext,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => BreakdownToTasksSheet(task: task),
          );
          if (result == null) return;
          _showUndoSnack(
            message: '已创建 ${result.createdTaskIds.length} 条任务',
            undo: () async => _undoBreakdown(result),
          );
        },
        child: const Text('拆分子任务'),
      ),
      const SizedBox(height: 8),
      ShadButton.secondary(
        onPressed: () async {
          final now = DateTime.now();
          final day = DateTime(now.year, now.month, now.day);
          final before = task;
          await ref
              .read(todayPlanRepositoryProvider)
              .addTask(day: day, taskId: task.id);
          await _updateTask(
            before.copyWith(
              triageStatus: domain.TriageStatus.plannedToday,
              updatedAt: now,
            ),
          );
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _showUndoSnack(
            message: '已加入今天计划',
            undo: () async {
              await ref
                  .read(todayPlanRepositoryProvider)
                  .removeTask(day: day, taskId: before.id);
              await _updateTask(before.copyWith(updatedAt: DateTime.now()));
            },
          );
        },
        child: const Text('加入今天计划'),
      ),
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () async {
          final before = task;
          await _updateTask(
            before.copyWith(
              triageStatus: domain.TriageStatus.scheduledLater,
              updatedAt: DateTime.now(),
            ),
          );
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _showUndoSnack(
            message: '已移到以后',
            undo: () async =>
                _updateTask(before.copyWith(updatedAt: DateTime.now())),
          );
        },
        child: const Text('移到以后'),
      ),
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () async {
          final picked = await showModalBottomSheet<DateTime>(
            context: scaffoldContext,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => DatePickerSheet(
              title: '延期到日期',
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            ),
          );
          if (picked == null) return;
          final dueAt = DateTime(picked.year, picked.month, picked.day);
          final now = DateTime.now();
          final before = task;
          await _updateTask(
            before.copyWith(
              triageStatus: domain.TriageStatus.scheduledLater,
              dueAt: dueAt,
              updatedAt: now,
            ),
          );
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _showUndoSnack(
            message:
                '已延期到 ${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')}',
            undo: () async =>
                _updateTask(before.copyWith(updatedAt: DateTime.now())),
          );
        },
        child: const Text('延期到日期…'),
      ),
      const SizedBox(height: 8),
      ShadButton.secondary(
        onPressed: () async {
          Navigator.of(context).pop();
          await _weaveTaskToLongform(task, domain.WeaveMode.reference);
        },
        child: const Text('编织到长文（引用）'),
      ),
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () async {
          Navigator.of(context).pop();
          await _weaveTaskToLongform(task, domain.WeaveMode.copy);
        },
        child: const Text('编织到长文（拷贝）'),
      ),
      const SizedBox(height: 8),
      ShadButton.destructive(
        onPressed: () async {
          final before = task;
          await _updateTask(
            before.copyWith(
              triageStatus: domain.TriageStatus.archived,
              updatedAt: DateTime.now(),
            ),
          );
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _showUndoSnack(
            message: '已归档',
            undo: () async =>
                _updateTask(before.copyWith(updatedAt: DateTime.now())),
          );
        },
        child: const Text('归档'),
      ),
    ];
  }

  List<Widget> _noteActions(BuildContext context) {
    final note = entry.note!;
    final hasLinkedTask = note.taskId != null && note.taskId!.trim().isNotEmpty;
    return [
      ShadButton(
        onPressed: () async {
          Navigator.of(context).pop();
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => NoteEditSheet(note: note),
          );
        },
        child: const Text('澄清编辑'),
      ),
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () async {
          Navigator.of(context).pop();
          final result = await showModalBottomSheet<BreakdownToTasksResult>(
            context: scaffoldContext,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => BreakdownToTasksSheet(note: note),
          );
          if (result == null) return;
          _showUndoSnack(
            message: '已创建 ${result.createdTaskIds.length} 条任务',
            undo: () async => _undoBreakdown(result),
          );
        },
        child: const Text('拆分成任务'),
      ),
      const SizedBox(height: 8),
      ShadButton.secondary(
        onPressed: () async {
          Navigator.of(context).pop();
          await _convertNoteToTaskAndAddToday(note);
        },
        child: Text(hasLinkedTask ? '加入今天计划（关联任务）' : '转为任务并加入今天'),
      ),
      const SizedBox(height: 8),
      ShadButton.secondary(
        onPressed: () async {
          Navigator.of(context).pop();
          await _weaveNoteToLongform(note, domain.WeaveMode.reference);
        },
        child: const Text('编织到长文（引用）'),
      ),
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () async {
          Navigator.of(context).pop();
          await _weaveNoteToLongform(note, domain.WeaveMode.copy);
        },
        child: const Text('编织到长文（拷贝）'),
      ),
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () async {
          final before = note;
          await _updateNote(
            before.copyWith(
              triageStatus: domain.TriageStatus.scheduledLater,
              updatedAt: DateTime.now(),
            ),
          );
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _showUndoSnack(
            message: '已标记已处理',
            undo: () async =>
                _updateNote(before.copyWith(updatedAt: DateTime.now())),
          );
        },
        child: const Text('标记已处理'),
      ),
      const SizedBox(height: 8),
      ShadButton.destructive(
        onPressed: () async {
          final before = note;
          await _updateNote(
            before.copyWith(
              triageStatus: domain.TriageStatus.archived,
              updatedAt: DateTime.now(),
            ),
          );
          if (!context.mounted) return;
          Navigator.of(context).pop();
          _showUndoSnack(
            message: '已归档',
            undo: () async =>
                _updateNote(before.copyWith(updatedAt: DateTime.now())),
          );
        },
        child: const Text('归档'),
      ),
    ];
  }

  Future<void> _convertNoteToTaskAndAddToday(domain.Note note) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final beforeNote = note;

    final planRepo = ref.read(todayPlanRepositoryProvider);
    final noteRepo = ref.read(noteRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);

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

    _showUndoSnack(
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
  }

  Future<void> _weaveTaskToLongform(
    domain.Task task,
    domain.WeaveMode mode,
  ) async {
    final targetNoteId = await showModalBottomSheet<String>(
      context: scaffoldContext,
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

    _showUndoSnack(
      message: mode == domain.WeaveMode.copy ? '已拷贝编织到长文正文' : '已编织到长文',
      undo: () async => undoWeaveToLongform(ref, result),
    );
  }

  Future<void> _weaveNoteToLongform(
    domain.Note note,
    domain.WeaveMode mode,
  ) async {
    final targetNoteId = await showModalBottomSheet<String>(
      context: scaffoldContext,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectLongformNoteSheet(),
    );
    if (targetNoteId == null) return;

    final result = await weaveToLongform(
      ref: ref,
      targetNoteId: targetNoteId,
      mode: mode,
      notes: [note],
    );

    _showUndoSnack(
      message: mode == domain.WeaveMode.copy ? '已拷贝编织到长文正文' : '已编织到长文',
      undo: () async => undoWeaveToLongform(ref, result),
    );
  }

  Future<void> _updateTask(domain.Task task) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.upsertTask(task);
  }

  Future<void> _updateNote(domain.Note note) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.upsertNote(note);
  }

  void _showUndoSnack({
    required String message,
    required Future<void> Function() undo,
  }) {
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: '撤销', onPressed: () async => undo()),
      ),
    );
  }

  Future<void> _undoBreakdown(BreakdownToTasksResult result) async {
    if (result.addToToday) {
      for (final id in result.createdTaskIds) {
        await ref
            .read(todayPlanRepositoryProvider)
            .removeTask(day: result.day, taskId: id);
      }
    }
    for (final id in result.createdTaskIds) {
      await ref.read(taskRepositoryProvider).deleteTask(id);
    }
    final now = DateTime.now();
    if (result.sourceTaskBefore != null) {
      await _updateTask(result.sourceTaskBefore!.copyWith(updatedAt: now));
    }
    if (result.sourceNoteBefore != null) {
      await _updateNote(result.sourceNoteBefore!.copyWith(updatedAt: now));
    }
  }
}

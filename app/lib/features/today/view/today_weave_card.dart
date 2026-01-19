import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../notes/providers/note_providers.dart';
import '../../notes/view/select_longform_note_sheet.dart';
import '../../weave/weave_service.dart';

class TodayWeaveCard extends ConsumerWidget {
  const TodayWeaveCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(unprocessedNotesStreamProvider);
    final notes = notesAsync.valueOrNull ?? const <domain.Note>[];

    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final pending = notes.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final visible = pending.take(3).toList(growable: false);

    return ShadCard(
      padding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(
              '待编织',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () => context.push('/inbox'),
            child: const Text('去待处理'),
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          if (notesAsync.isLoading) {
            return const Padding(
              padding: DpInsets.card,
              child: ShadProgress(minHeight: 8),
            );
          }

          if (notesAsync.hasError) {
            return Padding(
              padding: DpInsets.card,
              child: ShadAlert.destructive(
                icon: const Icon(Icons.error_outline),
                title: const Text('闪念加载失败'),
                description: Text('${notesAsync.error}'),
              ),
            );
          }

          if (pending.isEmpty) {
            return Padding(
              padding: DpInsets.card,
              child: Text(
                '暂无待编织闪念/草稿。去「笔记」页右上角「闪念」先收下一条。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            );
          }

          return Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i != 0) Divider(height: 0, color: colorScheme.border),
                _WeaveNoteRow(note: visible[i]),
              ],
              if (pending.length > visible.length)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DpSpacing.md,
                    DpSpacing.sm,
                    DpSpacing.md,
                    DpSpacing.md,
                  ),
                  child: Text(
                    '仅展示最近 ${visible.length} 条（共 ${pending.length} 条）',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WeaveNoteRow extends ConsumerWidget {
  const _WeaveNoteRow({required this.note});

  final domain.Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final snippet = _firstLine(note.body);

    return InkWell(
      onTap: () => context.push('/notes/${note.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DpSpacing.md,
          vertical: DpSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  if (snippet != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      snippet,
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
            const SizedBox(width: DpSpacing.sm),
            Tooltip(
              message: '处理',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.more_horiz, size: 18),
                onPressed: () => _openActions(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _WeaveActionsSheet(note: note),
    );
  }

  String? _firstLine(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split('\n').first.trim();
  }
}

class _WeaveActionsSheet extends ConsumerWidget {
  const _WeaveActionsSheet({required this.note});

  final domain.Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

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
            Text(
              note.title.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: shadTheme.textTheme.h4.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '把闪念/草稿快速推进到“产出”：编织进长文、转为任务、或先安排到以后。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: DpSpacing.lg),
            ShadButton(
              onPressed: () => _weaveToLongform(context, ref),
              leading: const Icon(Icons.link_outlined, size: 18),
              child: const Text('编织进长文（引用）'),
            ),
            const SizedBox(height: DpSpacing.sm),
            ShadButton.secondary(
              onPressed: () => _weaveToLongformCopy(context, ref),
              leading: const Icon(Icons.content_copy_outlined, size: 18),
              child: const Text('编织进长文（拷贝）'),
            ),
            const SizedBox(height: DpSpacing.sm),
            ShadButton.outline(
              onPressed: () => _convertToTaskAndAddToday(context, ref),
              leading: const Icon(Icons.add_task_outlined, size: 18),
              child: const Text('转为任务并加入今天'),
            ),
            const SizedBox(height: DpSpacing.sm),
            ShadButton.outline(
              onPressed: () => _moveLater(context, ref),
              leading: const Icon(Icons.schedule_outlined, size: 18),
              child: const Text('稍后处理'),
            ),
            const SizedBox(height: DpSpacing.sm),
            ShadButton.outline(
              onPressed: () => _archive(context, ref),
              leading: const Icon(Icons.archive_outlined, size: 18),
              child: const Text('归档（仍可导出/恢复）'),
            ),
            const SizedBox(height: DpSpacing.md),
            ShadButton.ghost(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _weaveToLongform(BuildContext context, WidgetRef ref) async {
    final targetNoteId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectLongformNoteSheet(),
    );
    if (targetNoteId == null) return;

    final result = await weaveToLongform(
      ref: ref,
      targetNoteId: targetNoteId,
      mode: domain.WeaveMode.reference,
      notes: [note],
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已编织到长文收集箱'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async => undoWeaveToLongform(ref, result),
        ),
      ),
    );
  }

  Future<void> _weaveToLongformCopy(BuildContext context, WidgetRef ref) async {
    final targetNoteId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectLongformNoteSheet(),
    );
    if (targetNoteId == null) return;

    final result = await weaveToLongform(
      ref: ref,
      targetNoteId: targetNoteId,
      mode: domain.WeaveMode.copy,
      notes: [note],
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已拷贝编织到长文正文'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async => undoWeaveToLongform(ref, result),
        ),
      ),
    );
  }

  Future<void> _convertToTaskAndAddToday(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final now = DateTime.now();
    final before = note;
    final createTask = ref.read(createTaskUseCaseProvider);
    final noteRepo = ref.read(noteRepositoryProvider);
    final todayPlanRepo = ref.read(todayPlanRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);

    final task = await createTask(
      title: note.title.value,
      description: note.body,
      tags: note.tags,
      triageStatus: domain.TriageStatus.plannedToday,
    );

    final day = DateTime(now.year, now.month, now.day);
    await todayPlanRepo.addTask(day: day, taskId: task.id);
    await noteRepo.upsertNote(
      note.copyWith(
        taskId: task.id,
        triageStatus: domain.TriageStatus.scheduledLater,
        updatedAt: now,
      ),
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已转为任务并加入今天'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await todayPlanRepo.removeTask(day: day, taskId: task.id);
            await taskRepo.deleteTask(task.id);
            await noteRepo.upsertNote(
              before.copyWith(updatedAt: DateTime.now()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _moveLater(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final before = note;
    final noteRepo = ref.read(noteRepositoryProvider);

    await noteRepo.upsertNote(
      note.copyWith(
        triageStatus: domain.TriageStatus.scheduledLater,
        updatedAt: now,
      ),
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已移动到以后'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await noteRepo.upsertNote(
              before.copyWith(updatedAt: DateTime.now()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final before = note;
    final noteRepo = ref.read(noteRepositoryProvider);

    await noteRepo.upsertNote(
      note.copyWith(triageStatus: domain.TriageStatus.archived, updatedAt: now),
    );

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已归档'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await noteRepo.upsertNote(
              before.copyWith(updatedAt: DateTime.now()),
            );
          },
        ),
      ),
    );
  }
}

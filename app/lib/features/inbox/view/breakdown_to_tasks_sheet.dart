import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';

class BreakdownToTasksResult {
  const BreakdownToTasksResult({
    required this.createdTaskIds,
    required this.addToToday,
    required this.day,
    this.sourceTaskBefore,
    this.sourceNoteBefore,
  });

  final List<String> createdTaskIds;
  final bool addToToday;
  final DateTime day;
  final domain.Task? sourceTaskBefore;
  final domain.Note? sourceNoteBefore;
}

class BreakdownToTasksSheet extends ConsumerStatefulWidget {
  const BreakdownToTasksSheet({super.key, this.task, this.note})
    : assert((task == null) != (note == null));

  final domain.Task? task;
  final domain.Note? note;

  @override
  ConsumerState<BreakdownToTasksSheet> createState() =>
      _BreakdownToTasksSheetState();
}

class _BreakdownToTasksSheetState extends ConsumerState<BreakdownToTasksSheet> {
  final TextEditingController _linesController = TextEditingController();
  bool _creating = false;
  bool _addToToday = false;
  bool _archiveSource = true;

  @override
  void dispose() {
    _linesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final task = widget.task;
    final note = widget.note;
    final sourceLabel = task != null ? '任务' : '闪念/草稿';
    final sourceTitle = task?.title.value ?? note!.title.value;
    final sourceBody = task?.description ?? note?.body;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '拆分成任务',
                    style: shadTheme.textTheme.h3.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Tooltip(
                  message: '关闭',
                  child: ShadIconButton.ghost(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _creating
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              title: Text(
                '来源：$sourceLabel',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sourceTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: shadTheme.textTheme.small.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((sourceBody ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _firstLine(sourceBody!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              title: Text(
                '每行一条',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              child: ShadInput(
                controller: _linesController,
                enabled: !_creating,
                minLines: 4,
                maxLines: 10,
                placeholder: Text(
                  '例如：\n- 对齐接口参数\n- 写单测\n- 联调与回归',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadCheckbox(
                    value: _addToToday,
                    enabled: !_creating,
                    onChanged: (v) => setState(() => _addToToday = v),
                    label: const Text('生成后加入今天计划'),
                    sublabel: const Text('追加到 Today 队列，之后仍可编辑排序'),
                  ),
                  const SizedBox(height: 6),
                  ShadCheckbox(
                    value: _archiveSource,
                    enabled: !_creating,
                    onChanged: (v) => setState(() => _archiveSource = v),
                    label: const Text('同时归档源条目'),
                    sublabel: const Text('把来源从收件箱移除，避免重复处理'),
                  ),
                  const SizedBox(height: 12),
                  ShadButton(
                    onPressed: _creating ? null : () => _submit(context),
                    child: Text(_creating ? '创建中…' : '创建任务（可撤销）'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final lines = _parseLines(_linesController.text);
    if (lines.isEmpty) {
      _showSnack(context, '先写几条任务再创建');
      return;
    }

    setState(() => _creating = true);
    try {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);

      final sourceTitle =
          widget.task?.title.value ?? widget.note?.title.value ?? '';
      final sourceLabel = widget.task != null ? '任务' : '闪念/草稿';
      final sourceRef = '来源：$sourceLabel · $sourceTitle';

      final create = ref.read(createTaskUseCaseProvider);
      final planRepo = ref.read(todayPlanRepositoryProvider);
      final taskRepo = ref.read(taskRepositoryProvider);
      final noteRepo = ref.read(noteRepositoryProvider);

      final createdTaskIds = <String>[];
      for (final title in lines) {
        final task = await create(
          title: title,
          description: sourceRef,
          triageStatus: _addToToday
              ? domain.TriageStatus.plannedToday
              : domain.TriageStatus.scheduledLater,
        );
        createdTaskIds.add(task.id);
        if (_addToToday) {
          await planRepo.addTask(day: day, taskId: task.id);
        }
      }

      domain.Task? sourceTaskBefore;
      domain.Note? sourceNoteBefore;
      if (_archiveSource) {
        if (widget.task != null) {
          sourceTaskBefore = widget.task!;
          await taskRepo.upsertTask(
            widget.task!.copyWith(
              triageStatus: domain.TriageStatus.archived,
              updatedAt: now,
            ),
          );
        }
        if (widget.note != null) {
          sourceNoteBefore = widget.note!;
          await noteRepo.upsertNote(
            widget.note!.copyWith(
              triageStatus: domain.TriageStatus.archived,
              updatedAt: now,
            ),
          );
        }
      }

      if (!context.mounted) return;
      Navigator.of(context).pop(
        BreakdownToTasksResult(
          createdTaskIds: createdTaskIds,
          addToToday: _addToToday,
          day: day,
          sourceTaskBefore: sourceTaskBefore,
          sourceNoteBefore: sourceNoteBefore,
        ),
      );
    } on domain.TaskTitleEmptyException {
      _showSnack(context, '任务标题不能为空');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  List<String> _parseLines(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .map((l) => l.replaceFirst(RegExp(r'^[-*]\s+'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    final deduped = <String>[];
    final seen = <String>{};
    for (final l in lines) {
      final key = l.toLowerCase();
      if (seen.add(key)) deduped.add(l);
    }
    return deduped;
  }

  String _firstLine(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split('\n').first.trim();
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

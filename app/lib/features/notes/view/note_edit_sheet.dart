import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../weave/weave_insertion.dart';
import '../../tasks/providers/task_providers.dart';
import 'select_task_for_note_sheet.dart';

class NoteEditSheet extends ConsumerStatefulWidget {
  const NoteEditSheet({super.key, this.note, this.taskId});

  final domain.Note? note;
  final String? taskId;

  @override
  ConsumerState<NoteEditSheet> createState() => _NoteEditSheetState();
}

class _NoteEditSheetState extends ConsumerState<NoteEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _tagsController;
  String? _taskId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title.value ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _tagsController = TextEditingController(text: note?.tags.join(',') ?? '');
    _taskId = widget.taskId ?? note?.taskId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    final isLongform =
        (widget.note?.kind ?? domain.NoteKind.longform) ==
        domain.NoteKind.longform;
    final bodyMinLines = isLongform ? 12 : 6;
    final bodyMaxLines = isLongform ? 32 : 16;
    final taskId = _taskId;
    final taskAsync = taskId == null
        ? null
        : ref.watch(taskByIdProvider(taskId));
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight =
        MediaQuery.sizeOf(context).height - viewInsetsBottom;
    final maxHeight = (availableHeight * 0.92).clamp(
      320.0,
      MediaQuery.sizeOf(context).height,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.md,
          bottom: DpSpacing.lg + viewInsetsBottom,
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
                      isEdit ? '编辑笔记' : '新增笔记',
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
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.md),
              Expanded(
                child: ListView(
                  children: [
                    ShadCard(
                      padding: DpInsets.card,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShadInput(
                            controller: _titleController,
                            enabled: !_saving,
                            autofocus: !isEdit,
                            placeholder: Text(
                              '标题（必填）',
                              style: shadTheme.textTheme.muted.copyWith(
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                            leading: const Icon(Icons.title_outlined, size: 18),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _submit(context),
                          ),
                          const SizedBox(height: DpSpacing.sm),
                          ShadInput(
                            controller: _bodyController,
                            enabled: !_saving,
                            minLines: bodyMinLines,
                            maxLines: bodyMaxLines,
                            placeholder: Text(
                              isLongform
                                  ? '正文（纯文本/轻量 Markdown；建议用空行分段）'
                                  : '正文（纯文本/轻量 Markdown）',
                              style: shadTheme.textTheme.muted.copyWith(
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                            leading: const Icon(Icons.notes_outlined, size: 18),
                            textInputAction: TextInputAction.newline,
                          ),
                          if (isLongform) ...[
                            const SizedBox(height: DpSpacing.md),
                            ShadButton.outline(
                              size: ShadButtonSize.sm,
                              onPressed: _saving
                                  ? null
                                  : () => _insertAtCursor(
                                      _bodyController,
                                      '\n\n$collectAnchorToken\n\n',
                                    ),
                              leading: const Icon(
                                Icons.anchor_outlined,
                                size: 16,
                              ),
                              child: const Text('插入收集箱锚点'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: DpSpacing.md),
                    ShadCard(
                      padding: DpInsets.card,
                      title: Text(
                        '关联任务（可选）',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_outlined, size: 18),
                          const SizedBox(width: DpSpacing.sm),
                          Expanded(
                            child: taskId == null
                                ? Text(
                                    '未关联',
                                    style: shadTheme.textTheme.muted.copyWith(
                                      color: colorScheme.mutedForeground,
                                    ),
                                  )
                                : taskAsync!.when(
                                    loading: () => Text(
                                      '加载中…',
                                      style: shadTheme.textTheme.muted.copyWith(
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                    error: (_, _) => Text(
                                      '加载失败',
                                      style: shadTheme.textTheme.muted.copyWith(
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                    data: (task) => Text(
                                      task == null
                                          ? '任务不存在或已删除'
                                          : task.title.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: shadTheme.textTheme.small.copyWith(
                                        color: colorScheme.foreground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),
                          Tooltip(
                            message: '选择任务',
                            child: ShadIconButton.ghost(
                              icon: const Icon(Icons.search, size: 18),
                              onPressed: _saving
                                  ? null
                                  : () => _pickTask(context),
                            ),
                          ),
                          Tooltip(
                            message: '清除关联',
                            child: ShadIconButton.ghost(
                              icon: const Icon(
                                Icons.link_off_outlined,
                                size: 18,
                              ),
                              onPressed: (_saving || taskId == null)
                                  ? null
                                  : () => setState(() => _taskId = null),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DpSpacing.md),
                    ShadCard(
                      padding: DpInsets.card,
                      child: ShadInput(
                        controller: _tagsController,
                        enabled: !_saving,
                        placeholder: Text(
                          '标签（逗号分隔，可选）',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        leading: const Icon(Icons.tag_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ShadButton(
                  onPressed: _saving ? null : () => _submit(context),
                  child: Text(_saving ? '保存中…' : (isEdit ? '保存' : '创建')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack(context, '请输入标题');
      return;
    }

    final isEdit = widget.note != null;
    final taskId = _taskId;

    setState(() => _saving = true);
    try {
      final tags = _parseTags(_tagsController.text);
      if (isEdit) {
        final update = ref.read(updateNoteUseCaseProvider);
        await update(
          note: widget.note!,
          title: title,
          body: _bodyController.text,
          tags: tags,
          taskId: taskId,
        );
      } else {
        final create = ref.read(createNoteUseCaseProvider);
        await create(
          title: title,
          body: _bodyController.text,
          tags: tags,
          taskId: taskId,
        );
      }
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } on domain.NoteTitleEmptyException {
      if (!context.mounted) return;
      _showSnack(context, '标题不能为空');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _pickTask(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectTaskForNoteSheet(),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _taskId = picked);
  }

  void _insertAtCursor(TextEditingController controller, String text) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, text);
    final newSelection = TextSelection.collapsed(offset: start + text.length);
    controller.value = value.copyWith(text: newText, selection: newSelection);
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

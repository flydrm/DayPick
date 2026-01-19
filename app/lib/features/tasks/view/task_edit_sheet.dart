import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/sheets/date_picker_sheet.dart';

class TaskEditSheet extends ConsumerStatefulWidget {
  const TaskEditSheet({super.key, this.task});

  final domain.Task? task;

  @override
  ConsumerState<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<TaskEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _estimatedController;

  late domain.TaskPriority _priority;
  late domain.TaskStatus _status;
  DateTime? _dueAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title.value ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _tagsController = TextEditingController(text: task?.tags.join(',') ?? '');
    _estimatedController = TextEditingController(
      text: task?.estimatedPomodoros?.toString() ?? '',
    );

    _priority = task?.priority ?? domain.TaskPriority.medium;
    _status = task?.status ?? domain.TaskStatus.todo;
    _dueAt = task?.dueAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _estimatedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? '编辑任务' : '新增任务',
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
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 8),
                  ShadInput(
                    controller: _descriptionController,
                    enabled: !_saving,
                    maxLines: 5,
                    placeholder: Text(
                      '描述（可选）',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    leading: const Icon(Icons.notes_outlined, size: 18),
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              title: Text(
                '属性',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '优先级',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShadSelect<domain.TaskPriority>(
                    enabled: !_saving,
                    initialValue: _priority,
                    selectedOptionBuilder: (context, value) => Text(
                      _priorityLabel(value),
                      style: shadTheme.textTheme.small.copyWith(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    options: const [
                      ShadOption(
                        value: domain.TaskPriority.high,
                        child: Text('高'),
                      ),
                      ShadOption(
                        value: domain.TaskPriority.medium,
                        child: Text('中'),
                      ),
                      ShadOption(
                        value: domain.TaskPriority.low,
                        child: Text('低'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _priority = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '状态',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShadSelect<domain.TaskStatus>(
                    enabled: !_saving,
                    initialValue: _status,
                    selectedOptionBuilder: (context, value) => Text(
                      _statusLabel(value),
                      style: shadTheme.textTheme.small.copyWith(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    options: const [
                      ShadOption(
                        value: domain.TaskStatus.todo,
                        child: Text('待办'),
                      ),
                      ShadOption(
                        value: domain.TaskStatus.inProgress,
                        child: Text('进行中'),
                      ),
                      ShadOption(
                        value: domain.TaskStatus.done,
                        child: Text('已完成'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _DueDateRow(
                    value: _dueAt,
                    enabled: !_saving,
                    onPick: () => _pickDueDate(context),
                    onClear: _dueAt == null
                        ? null
                        : () => setState(() => _dueAt = null),
                  ),
                  const SizedBox(height: 12),
                  ShadInput(
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
                  const SizedBox(height: 8),
                  ShadInput(
                    controller: _estimatedController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    placeholder: Text(
                      '预计番茄数（可选）',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    leading: const Icon(Icons.timer_outlined, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
    );
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DatePickerSheet(
        title: '选择截止日期',
        initialDate: _dueAt ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      ),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _dueAt = picked);
  }

  Future<void> _submit(BuildContext context) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack(context, '请输入标题');
      return;
    }

    setState(() => _saving = true);
    try {
      final tags = _parseTags(_tagsController.text);
      final estimated = int.tryParse(_estimatedController.text.trim());
      final description = _descriptionController.text;

      if (widget.task != null) {
        final update = ref.read(updateTaskUseCaseProvider);
        await update(
          task: widget.task!,
          title: title,
          description: description,
          status: _status,
          priority: _priority,
          dueAt: _dueAt,
          tags: tags,
          estimatedPomodoros: estimated,
        );
      } else {
        final create = ref.read(createTaskUseCaseProvider);
        await create(
          title: title,
          description: description,
          priority: _priority,
          dueAt: _dueAt,
          tags: tags,
          estimatedPomodoros: estimated,
        );
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();
    } on domain.TaskTitleEmptyException {
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
}

String _priorityLabel(domain.TaskPriority priority) {
  return switch (priority) {
    domain.TaskPriority.high => '高',
    domain.TaskPriority.medium => '中',
    domain.TaskPriority.low => '低',
  };
}

String _statusLabel(domain.TaskStatus status) {
  return switch (status) {
    domain.TaskStatus.todo => '待办',
    domain.TaskStatus.inProgress => '进行中',
    domain.TaskStatus.done => '已完成',
  };
}

class _DueDateRow extends StatelessWidget {
  const _DueDateRow({
    required this.value,
    required this.enabled,
    required this.onPick,
    this.onClear,
  });

  final DateTime? value;
  final bool enabled;
  final Future<void> Function() onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final text = value == null
        ? '未设置'
        : '${value!.year}-${_two(value!.month)}-${_two(value!.day)}';
    return Row(
      children: [
        const Icon(Icons.calendar_month_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '截止：$text',
            style: shadTheme.textTheme.small.copyWith(
              color: colorScheme.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Tooltip(
          message: '选择日期',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            onPressed: enabled ? () async => onPick() : null,
          ),
        ),
        Tooltip(
          message: '清除',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: enabled ? onClear : null,
          ),
        ),
      ],
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class TaskFiltersSheet extends StatefulWidget {
  const TaskFiltersSheet({super.key, required this.initial});

  final domain.TaskListQuery initial;

  @override
  State<TaskFiltersSheet> createState() => _TaskFiltersSheetState();
}

class _TaskFiltersSheetState extends State<TaskFiltersSheet> {
  late domain.TaskStatusFilter _statusFilter;
  domain.TaskPriority? _priority;
  late bool _dueToday;
  late bool _overdue;
  late bool _includeInbox;
  late bool _includeArchived;
  late final TextEditingController _tagController;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initial.statusFilter;
    _priority = widget.initial.priority;
    _dueToday = widget.initial.dueToday;
    _overdue = widget.initial.overdue;
    _includeInbox = widget.initial.includeInbox;
    _includeArchived = widget.initial.includeArchived;
    _tagController = TextEditingController(text: widget.initial.tag ?? '');
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '筛选',
                    style: shadTheme.textTheme.h3.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: _clear,
                  child: const Text('清除'),
                ),
                Tooltip(
                  message: '关闭',
                  child: ShadIconButton.ghost(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              title: Text(
                '状态',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              child: ShadSelect<domain.TaskStatusFilter>(
                initialValue: _statusFilter,
                selectedOptionBuilder: (context, value) => Text(
                  _statusFilterLabel(value),
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: const [
                  ShadOption(
                    value: domain.TaskStatusFilter.open,
                    child: Text('未完成（默认）'),
                  ),
                  ShadOption(
                    value: domain.TaskStatusFilter.all,
                    child: Text('全部'),
                  ),
                  ShadOption(
                    value: domain.TaskStatusFilter.todo,
                    child: Text('待办'),
                  ),
                  ShadOption(
                    value: domain.TaskStatusFilter.inProgress,
                    child: Text('进行中'),
                  ),
                  ShadOption(
                    value: domain.TaskStatusFilter.done,
                    child: Text('已完成'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _statusFilter = value);
                },
              ),
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              title: Text(
                '优先级',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              child: ShadSelect<domain.TaskPriority?>(
                allowDeselection: true,
                initialValue: _priority,
                placeholder: Text(
                  '不限',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                selectedOptionBuilder: (context, value) => Text(
                  value == null ? '不限' : _priorityLabel(value),
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: const [
                  ShadOption<domain.TaskPriority?>(
                    value: domain.TaskPriority.high,
                    child: Text('高'),
                  ),
                  ShadOption<domain.TaskPriority?>(
                    value: domain.TaskPriority.medium,
                    child: Text('中'),
                  ),
                  ShadOption<domain.TaskPriority?>(
                    value: domain.TaskPriority.low,
                    child: Text('低'),
                  ),
                ],
                onChanged: (value) => setState(() => _priority = value),
              ),
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              child: ShadInput(
                controller: _tagController,
                placeholder: Text(
                  '标签（精确匹配，可选）',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.tag_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadSwitch(
                    value: _dueToday,
                    onChanged: (value) {
                      setState(() {
                        _dueToday = value;
                        if (value) _overdue = false;
                      });
                    },
                    label: const Text('今天到期'),
                  ),
                  const SizedBox(height: 8),
                  ShadSwitch(
                    value: _overdue,
                    onChanged: (value) {
                      setState(() {
                        _overdue = value;
                        if (value) _dueToday = false;
                      });
                    },
                    label: const Text('已逾期'),
                  ),
                  const SizedBox(height: 8),
                  ShadSwitch(
                    value: _includeInbox,
                    onChanged: (value) => setState(() => _includeInbox = value),
                    label: const Text('包含待处理（Inbox）'),
                  ),
                  const SizedBox(height: 8),
                  ShadSwitch(
                    value: _includeArchived,
                    onChanged: (value) =>
                        setState(() => _includeArchived = value),
                    label: const Text('包含归档'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ShadButton(
                onPressed: () => _apply(context),
                child: const Text('应用'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clear() {
    setState(() {
      _statusFilter = domain.TaskStatusFilter.open;
      _priority = null;
      _dueToday = false;
      _overdue = false;
      _includeInbox = false;
      _includeArchived = false;
      _tagController.text = '';
    });
  }

  void _apply(BuildContext context) {
    Navigator.of(context).pop(
      domain.TaskListQuery(
        statusFilter: _statusFilter,
        priority: _priority,
        tag: _tagController.text.trim().isEmpty
            ? null
            : _tagController.text.trim(),
        dueToday: _dueToday,
        overdue: _overdue,
        includeInbox: _includeInbox,
        includeArchived: _includeArchived,
      ),
    );
  }
}

String _statusFilterLabel(domain.TaskStatusFilter value) {
  return switch (value) {
    domain.TaskStatusFilter.open => '未完成（默认）',
    domain.TaskStatusFilter.all => '全部',
    domain.TaskStatusFilter.todo => '待办',
    domain.TaskStatusFilter.inProgress => '进行中',
    domain.TaskStatusFilter.done => '已完成',
  };
}

String _priorityLabel(domain.TaskPriority value) {
  return switch (value) {
    domain.TaskPriority.high => '高',
    domain.TaskPriority.medium => '中',
    domain.TaskPriority.low => '低',
  };
}

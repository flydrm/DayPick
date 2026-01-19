import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_radius.dart';
import '../../../ui/tokens/dp_spacing.dart';

class TaskListItem extends StatelessWidget {
  const TaskListItem({
    super.key,
    required this.task,
    required this.onTap,
    this.onLongPress,
    this.dense = false,
    this.selectionMode = false,
    this.selected = false,
    this.trailing,
  });

  final domain.Task task;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dense;
  final bool selectionMode;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final dueAt = task.dueAt;
    final dueText = dueAt == null ? null : '${dueAt.month}/${dueAt.day}';
    final subtitle = _subtitleText(dueText);
    final (priorityIcon, priorityLabel) = _priorityVisual(task.priority);
    final statusIcon = _statusIcon(task.status);
    final statusLabel = _statusLabel(task.status);

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final dueLabelColor = _dueLabelColor(task.dueAt, startOfToday, colorScheme);
    final triageBadge = _triageBadge(task, colorScheme);
    final verticalPadding = dense ? DpSpacing.sm : DpSpacing.md;

    return Semantics(
      button: true,
      label: task.title.value,
      child: InkWell(
        borderRadius: BorderRadius.circular(DpRadius.md),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: DpSpacing.md,
            vertical: verticalPadding,
          ),
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
                const SizedBox(width: DpSpacing.md),
              ],
              Tooltip(
                message: statusLabel,
                child: Icon(
                  statusIcon,
                  size: 20,
                  color: task.status == domain.TaskStatus.inProgress
                      ? colorScheme.primary
                      : colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(width: DpSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: shadTheme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    if (triageBadge != null) ...[
                      const SizedBox(height: DpSpacing.xs),
                      triageBadge,
                    ],
                    if (subtitle != null) ...[
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
              const SizedBox(width: DpSpacing.sm),
              if (dueText != null)
                Padding(
                  padding: const EdgeInsets.only(right: DpSpacing.sm),
                  child: Text(
                    dueText,
                    style: shadTheme.textTheme.muted.copyWith(
                      color: dueLabelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              trailing ??
                  Tooltip(
                    message: priorityLabel,
                    child: Icon(
                      priorityIcon,
                      size: 18,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  String? _subtitleText(String? dueText) {
    final parts = <String>[];
    if (task.tags.isNotEmpty) parts.add(task.tags.take(3).join(' · '));
    if (parts.isEmpty) return null;
    return parts.join('  ·  ');
  }

  (IconData, String) _priorityVisual(domain.TaskPriority priority) {
    return switch (priority) {
      domain.TaskPriority.high => (Icons.priority_high, '优先级：高'),
      domain.TaskPriority.medium => (Icons.drag_handle, '优先级：中'),
      domain.TaskPriority.low => (Icons.arrow_downward, '优先级：低'),
    };
  }

  IconData _statusIcon(domain.TaskStatus status) {
    return switch (status) {
      domain.TaskStatus.todo => Icons.radio_button_unchecked,
      domain.TaskStatus.inProgress => Icons.play_circle_outline,
      domain.TaskStatus.done => Icons.check_circle_outline,
    };
  }

  String _statusLabel(domain.TaskStatus status) {
    return switch (status) {
      domain.TaskStatus.todo => '待办',
      domain.TaskStatus.inProgress => '进行中',
      domain.TaskStatus.done => '已完成',
    };
  }

  Color _dueLabelColor(
    DateTime? dueAt,
    DateTime startOfToday,
    ShadColorScheme scheme,
  ) {
    if (dueAt == null) return scheme.mutedForeground;
    final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
    if (dueDate.isBefore(startOfToday)) return scheme.destructive;
    if (dueDate == startOfToday) return scheme.primary;
    return scheme.mutedForeground;
  }

  Widget? _triageBadge(domain.Task task, ShadColorScheme scheme) {
    return switch (task.triageStatus) {
      domain.TriageStatus.plannedToday => const ShadBadge.secondary(
        child: Text('今天'),
      ),
      domain.TriageStatus.inbox => ShadBadge.outline(
        child: Text('待处理', style: TextStyle(color: scheme.mutedForeground)),
      ),
      domain.TriageStatus.weaved => const ShadBadge.outline(child: Text('已编织')),
      domain.TriageStatus.archived => const ShadBadge.outline(
        child: Text('归档'),
      ),
      domain.TriageStatus.scheduledLater => null,
    };
  }
}

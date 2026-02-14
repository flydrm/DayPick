import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_spacing.dart';

class Top3WhySheet extends StatelessWidget {
  const Top3WhySheet({
    super.key,
    required this.task,
    required this.sourceLabel,
    required this.reasonLabels,
    required this.ruleHint,
  });

  final domain.Task task;
  final String sourceLabel;
  final List<String> reasonLabels;
  final String ruleHint;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final dueAt = task.dueAt;
    final dueText =
        dueAt == null
            ? '无'
            : '${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')}';

    String priorityText(domain.TaskPriority priority) {
      return switch (priority) {
        domain.TaskPriority.high => '高',
        domain.TaskPriority.medium => '中',
        domain.TaskPriority.low => '低',
      };
    }

    String statusText(domain.TaskStatus status) {
      return switch (status) {
        domain.TaskStatus.todo => '待办',
        domain.TaskStatus.inProgress => '进行中',
        domain.TaskStatus.done => '已完成',
      };
    }

    Widget fieldRow(String k, String v) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                k,
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: shadTheme.textTheme.small.copyWith(
                  color: colorScheme.foreground,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DpSpacing.lg,
            DpSpacing.md,
            DpSpacing.lg,
            DpSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '为什么是这条',
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                task.title.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: shadTheme.textTheme.large.copyWith(
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              ShadCard(
                padding: const EdgeInsets.all(DpSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fieldRow('来源', sourceLabel),
                    fieldRow('规则', ruleHint),
                    fieldRow('到期', dueText),
                    fieldRow('优先级', priorityText(task.priority)),
                    fieldRow('状态', statusText(task.status)),
                  ],
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              Text(
                '原因线索',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: DpSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in reasonLabels)
                    ShadBadge.outline(child: Text(label)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


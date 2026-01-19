import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

class TodayOnboardingCard extends StatelessWidget {
  const TodayOnboardingCard({
    super.key,
    required this.inboxCount,
    required this.planCount,
    required this.sessionCount,
    required this.onOpenInbox,
    required this.onOpenCanvas,
    required this.onOpenFocus,
    required this.onDismiss,
  });

  final int inboxCount;
  final int planCount;
  final int sessionCount;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenCanvas;
  final VoidCallback onOpenFocus;
  final VoidCallback onDismiss;

  bool get _inboxDone => inboxCount == 0;
  bool get _planDone => planCount > 0;
  bool get _focusDone => sessionCount > 0;
  bool get allDone => _inboxDone && _planDone && _focusDone;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    Widget step({
      required bool done,
      required IconData icon,
      required String title,
      required String description,
      required String actionLabel,
      required VoidCallback onAction,
    }) {
      final foreground = done ? colorScheme.primary : colorScheme.foreground;
      final badge = done
          ? ShadBadge.secondary(
              child: Text(
                '已完成',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ShadBadge.outline(child: const Text('待完成'));

      return ShadCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: shadTheme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                      badge,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: onAction,
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ShadCard(
      padding: DpInsets.card,
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Beta 起步：今天只做三件事',
              style: shadTheme.textTheme.h4.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
          Tooltip(
            message: '不再提示',
            child: ShadIconButton.ghost(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onDismiss,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '收下 → 安排 → 专注 → 留痕（任务/闪念/长文可自由组合，不强制流程）',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          step(
            done: _inboxDone,
            icon: _inboxDone ? Icons.check_circle : Icons.inbox_outlined,
            title: '清空 Inbox（待处理）',
            description: _inboxDone
                ? '已清空，开始把注意力放回今天。'
                : '还有 $inboxCount 条待处理（任务 + 闪念/长文）。',
            actionLabel: _inboxDone ? '查看' : '去处理',
            onAction: onOpenInbox,
          ),
          const SizedBox(height: 10),
          step(
            done: _planDone,
            icon: _planDone ? Icons.check_circle : Icons.today_outlined,
            title: '装入 Today（3–5 条）并打开画布',
            description: _planDone
                ? '已装入 $planCount 条任务，去画布投影节奏。'
                : '把任务加入 Today/This Evening，再用画布投影一个可执行时间线。',
            actionLabel: '打开画布',
            onAction: onOpenCanvas,
          ),
          const SizedBox(height: 10),
          step(
            done: _focusDone,
            icon: _focusDone
                ? Icons.check_circle
                : Icons.center_focus_strong_outlined,
            title: '完成 1 次专注并写下收尾',
            description: _focusDone
                ? '已产生 $sessionCount 条专注记录（可回看）。'
                : '完成一个番茄，写下进展/下一步，让今天可追溯。',
            actionLabel: '去专注',
            onAction: onOpenFocus,
          ),
          if (allDone) ...[
            const SizedBox(height: DpSpacing.md),
            ShadButton(onPressed: onDismiss, child: const Text('完成引导')),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum NoteAiAction { summary, actionItems, rewriteForSharing }

class NoteAiActionsSheet extends StatelessWidget {
  const NoteAiActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'AI 动作',
                    style: shadTheme.textTheme.h4.copyWith(
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
            const SizedBox(height: 12),
            const ShadAlert(
              icon: Icon(Icons.auto_awesome_outlined),
              title: Text('只在你点击后才会发送'),
              description: Text('结果先预览再采用，且支持撤销。'),
            ),
            const SizedBox(height: 12),
            ShadCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _AiActionTile(
                    icon: Icons.summarize_outlined,
                    title: '总结要点',
                    subtitle: '生成可编辑的总结草稿，并可写回笔记（可撤销）。',
                    action: NoteAiAction.summary,
                  ),
                  Divider(height: 0, color: colorScheme.border),
                  _AiActionTile(
                    icon: Icons.playlist_add_check_outlined,
                    title: '提取行动项',
                    subtitle: '生成可编辑的行动项清单，并可批量导入为任务（可撤销）。',
                    action: NoteAiAction.actionItems,
                  ),
                  Divider(height: 0, color: colorScheme.border),
                  _AiActionTile(
                    icon: Icons.share_outlined,
                    title: '改写同步版',
                    subtitle: '生成可编辑的对外同步文案草稿，并可写回笔记（可撤销）。',
                    action: NoteAiAction.rewriteForSharing,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiActionTile extends StatelessWidget {
  const _AiActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final NoteAiAction action;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return InkWell(
      onTap: () => Navigator.of(context).pop(action),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.mutedForeground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}

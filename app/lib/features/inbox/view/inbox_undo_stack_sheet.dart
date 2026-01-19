import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/inbox_undo_providers.dart';

class InboxUndoStackSheet extends ConsumerWidget {
  const InboxUndoStackSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final entries = ref.watch(inboxUndoStackProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '撤销栈',
                      style: shadTheme.textTheme.h4.copyWith(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w700,
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
              const SizedBox(height: 8),
              Text(
                '最近的操作会保存在这里，你可以稍后再撤销。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: entries.isEmpty
                    ? ShadCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '暂无可撤销的操作。',
                          style: shadTheme.textTheme.muted.copyWith(
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      )
                    : ShadCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 0, color: colorScheme.border),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _UndoRow(entry: entry);
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              ShadButton.outline(
                onPressed: entries.isEmpty
                    ? null
                    : () => ref.read(inboxUndoStackProvider.notifier).clear(),
                leading: const Icon(Icons.delete_sweep_outlined, size: 18),
                child: const Text('清空撤销栈'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UndoRow extends ConsumerWidget {
  const _UndoRow({required this.entry});

  final InboxUndoEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(entry.createdAt),
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShadButton.secondary(
            size: ShadButtonSize.sm,
            onPressed: () async {
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
            },
            leading: const Icon(Icons.undo, size: 16),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }
}

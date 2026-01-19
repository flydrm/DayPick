import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../providers/note_providers.dart';
import 'note_list_item.dart';

class MemosPage extends ConsumerWidget {
  const MemosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosStreamProvider);
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return AppPageScaffold(
      title: '闪念',
      createRoute: '/create?type=memo',
      actions: [
        Tooltip(
          message: '待处理',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.inbox_outlined, size: 20),
            onPressed: () => context.push('/inbox'),
          ),
        ),
      ],
      body: memosAsync.when(
        loading: () => const Center(child: ShadProgress(minHeight: 8)),
        error: (error, stack) => Padding(
          padding: DpInsets.page,
          child: DpInlineNotice(
            variant: DpInlineNoticeVariant.destructive,
            title: '加载失败',
            description: '$error',
            icon: const Icon(Icons.error_outline),
          ),
        ),
        data: (memos) {
          final visible = memos.toList(growable: false)
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          return ListView(
            padding: DpInsets.page,
            children: [
              const ShadAlert(
                icon: Icon(Icons.bolt_outlined),
                title: Text('闪念 = 随手记'),
                description: Text('点右上角「＋」先收下；在「待处理」里快速整理、编织到长文。'),
              ),
              const SizedBox(height: DpSpacing.md),
              if (visible.isEmpty)
                const DpEmptyState(
                  icon: Icons.bolt_outlined,
                  title: '还没有闪念',
                  description: '点右上角「＋」先收下一条。',
                )
              else
                ShadCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 0, color: colorScheme.border),
                    itemBuilder: (context, index) {
                      final note = visible[index];
                      return NoteListItem(
                        note: note,
                        onTap: () => context.push('/notes/${note.id}'),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

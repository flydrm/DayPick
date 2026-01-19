import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_inline_notice.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../providers/note_providers.dart';
import 'note_list_item.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(filteredNotesProvider);
    final tags = ref.watch(availableNoteTagsProvider);
    final selectedTag = ref.watch(selectedNoteTagProvider);
    void clearTagFilter() =>
        ref.read(selectedNoteTagProvider.notifier).state = null;
    void setTagFilter(String tag) =>
        ref.read(selectedNoteTagProvider.notifier).state = tag;
    return AppPageScaffold(
      title: '笔记',
      createRoute: '/create?type=draft',
      actions: [
        Tooltip(
          message: '闪念',
          child: ShadIconButton.ghost(
            icon: const Icon(Icons.bolt_outlined, size: 20),
            onPressed: () => context.push('/memos'),
          ),
        ),
      ],
      body: notesAsync.when(
        loading: () => const Center(child: DpSpinner()),
        error: (error, stack) => Padding(
          padding: DpInsets.page,
          child: DpInlineNotice(
            variant: DpInlineNoticeVariant.destructive,
            title: '加载失败',
            description: '$error',
            icon: const Icon(Icons.error_outline),
          ),
        ),
        data: (notes) {
          final canClearFilter = selectedTag != null;
          if (notes.isEmpty) {
            return Padding(
              padding: DpInsets.page,
              child: DpEmptyState(
                icon: Icons.notes_outlined,
                title: canClearFilter ? '暂无匹配笔记' : '还没有笔记',
                description: canClearFilter
                    ? '试试清除筛选，或切到「闪念」查看待处理内容。'
                    : '点右上角「＋」新建长文；或点右上角「闪念」查看待处理内容。',
                actionLabel: canClearFilter ? '清除筛选' : '写一条',
                onAction: canClearFilter
                    ? clearTagFilter
                    : () => context.push('/create?type=draft'),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DpSpacing.lg,
                    DpSpacing.lg,
                    DpSpacing.lg,
                    DpSpacing.sm,
                  ),
                  child: Wrap(
                    spacing: DpSpacing.sm,
                    runSpacing: DpSpacing.sm,
                    children: [
                      (selectedTag == null)
                          ? ShadButton.secondary(
                              size: ShadButtonSize.sm,
                              onPressed: clearTagFilter,
                              child: const Text('全部'),
                            )
                          : ShadButton.outline(
                              size: ShadButtonSize.sm,
                              onPressed: clearTagFilter,
                              child: const Text('全部'),
                            ),
                      for (final tag in tags)
                        (selectedTag == tag)
                            ? ShadButton.secondary(
                                size: ShadButtonSize.sm,
                                onPressed: clearTagFilter,
                                child: Text(tag),
                              )
                            : ShadButton.outline(
                                size: ShadButtonSize.sm,
                                onPressed: () => setTagFilter(tag),
                                child: Text(tag),
                              ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    DpSpacing.lg,
                    tags.isEmpty ? DpSpacing.lg : 0,
                    DpSpacing.lg,
                    DpSpacing.lg,
                  ),
                  itemCount: notes.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 0,
                    color: ShadTheme.of(context).colorScheme.border,
                  ),
                  itemBuilder: (context, index) {
                    final note = notes[index];
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

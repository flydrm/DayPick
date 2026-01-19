import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/note_providers.dart';

class SelectLongformNoteSheet extends ConsumerStatefulWidget {
  const SelectLongformNoteSheet({super.key});

  @override
  ConsumerState<SelectLongformNoteSheet> createState() =>
      _SelectLongformNoteSheetState();
}

class _SelectLongformNoteSheetState
    extends ConsumerState<SelectLongformNoteSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final notesAsync = ref.watch(notesStreamProvider);
    final notes = notesAsync.valueOrNull ?? const <domain.Note>[];
    final longforms = notes
        .where((n) => n.kind == domain.NoteKind.longform)
        .toList(growable: false);
    final keyword = _query.trim().toLowerCase();
    final visible = keyword.isEmpty
        ? longforms
        : longforms
              .where((n) {
                final hay = [n.title.value, n.body].join('\n').toLowerCase();
                return hay.contains(keyword);
              })
              .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '选择一篇长文',
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
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(16),
              child: ShadInput(
                controller: _searchController,
                placeholder: Text(
                  '搜索标题/正文…',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.search, size: 18),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 12),
            if (notesAsync.isLoading) const ShadProgress(minHeight: 8),
            if (notesAsync.hasError)
              ShadAlert.destructive(
                icon: const Icon(Icons.error_outline),
                title: const Text('加载失败'),
                description: Text('${notesAsync.error}'),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: visible.isEmpty
                  ? ShadCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        longforms.isEmpty ? '还没有长文笔记。' : '没有匹配的笔记。',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    )
                  : ShadCard(
                      padding: EdgeInsets.zero,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 0, color: colorScheme.border),
                        itemBuilder: (context, index) {
                          final note = visible[index];
                          final snippet = _firstLine(note.body);
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(note.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  const ShadBadge.outline(child: Text('长文')),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note.title.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: shadTheme.textTheme.small
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.foreground,
                                              ),
                                        ),
                                        if (snippet != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            snippet,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: shadTheme.textTheme.muted
                                                .copyWith(
                                                  color: colorScheme
                                                      .mutedForeground,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _firstLine(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split('\n').first.trim();
  }
}

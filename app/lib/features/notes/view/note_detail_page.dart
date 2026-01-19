import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_empty_state.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_radius.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../tasks/providers/task_providers.dart';
import '../../weave/view/weave_mode_sheet.dart';
import '../../weave/weave_insertion.dart';
import '../../weave/weave_service.dart';
import '../providers/note_providers.dart';
import '../inline_route_token.dart';
import 'note_ai_action_items_sheet.dart';
import 'note_ai_actions_sheet.dart';
import 'note_ai_rewrite_sheet.dart';
import 'note_ai_summary_sheet.dart';
import 'note_edit_sheet.dart';
import 'select_longform_note_sheet.dart';

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteByIdProvider(noteId));
    return noteAsync.when(
      loading: () => const AppPageScaffold(
        title: '笔记',
        body: Center(child: DpSpinner()),
      ),
      error: (error, stack) => AppPageScaffold(
        title: '笔记',
        body: Padding(
          padding: DpInsets.page,
          child: ShadAlert.destructive(
            icon: const Icon(Icons.error_outline),
            title: const Text('加载失败'),
            description: Text('$error'),
          ),
        ),
      ),
      data: (note) {
        if (note == null) {
          return const AppPageScaffold(
            title: '笔记',
            body: Padding(
              padding: DpInsets.page,
              child: DpEmptyState(
                icon: Icons.search_off_outlined,
                title: '笔记不存在或已删除',
                description: '你可以返回笔记列表继续浏览。',
              ),
            ),
          );
        }

        final shadTheme = ShadTheme.of(context);
        final colorScheme = shadTheme.colorScheme;
        final weaveLinksAsync = ref.watch(
          weaveLinksByTargetNoteIdProvider(note.id),
        );
        final outgoingWeaveLinksAsync = ref.watch(
          weaveLinksBySourceProvider((
            sourceType: domain.WeaveSourceType.note,
            sourceId: note.id,
          )),
        );
        final allNotesAsync = ref.watch(notesStreamProvider);
        final allTasksAsync = ref.watch(tasksStreamProvider);
        final noteById = {
          for (final n in allNotesAsync.valueOrNull ?? const <domain.Note>[])
            n.id: n,
        };
        final taskById = {
          for (final t in allTasksAsync.valueOrNull ?? const <domain.Task>[])
            t.id: t,
        };
        final taskId = note.taskId;
        final taskAsync = taskId == null
            ? null
            : ref.watch(taskByIdProvider(taskId));
        final anchor = note.kind == domain.NoteKind.longform
            ? splitCollectAnchor(note.body)
            : (hasAnchor: false, before: note.body, after: '');
        final hasCollectAnchor =
            note.kind == domain.NoteKind.longform && anchor.hasAnchor;
        final hasCollectLinks = weaveLinksAsync.valueOrNull?.isNotEmpty == true;
        final collectBoxCard = _CollectBoxCard(
          targetNote: note,
          linksAsync: weaveLinksAsync,
          noteById: noteById,
          taskById: taskById,
          showEmptyState: note.kind == domain.NoteKind.longform,
          showAnchorHint:
              note.kind == domain.NoteKind.longform && !hasCollectAnchor,
        );

        return AppPageScaffold(
          title: note.title.value,
          actions: [
            if (note.kind != domain.NoteKind.longform)
              Tooltip(
                message: '编织到长文',
                child: ShadIconButton.ghost(
                  icon: const Icon(Icons.link_outlined, size: 20),
                  onPressed: () async {
                    final mode = await showModalBottomSheet<domain.WeaveMode>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (context) => const WeaveModeSheet(),
                    );
                    if (mode == null) return;
                    if (!context.mounted) return;

                    final targetNoteId = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (context) => const SelectLongformNoteSheet(),
                    );
                    if (targetNoteId == null) return;

                    final result = await weaveToLongform(
                      ref: ref,
                      targetNoteId: targetNoteId,
                      mode: mode,
                      notes: [note],
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          mode == domain.WeaveMode.copy ? '已拷贝编织到长文' : '已编织到长文',
                        ),
                        action: SnackBarAction(
                          label: '撤销',
                          onPressed: () async =>
                              undoWeaveToLongform(ref, result),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (note.kind == domain.NoteKind.longform && !hasCollectAnchor)
              Tooltip(
                message: '插入收集箱锚点',
                child: ShadIconButton.ghost(
                  icon: const Icon(Icons.anchor_outlined, size: 20),
                  onPressed: () async {
                    final body = note.body.trimRight();
                    final nextBody = body.isEmpty
                        ? collectAnchorToken
                        : '$body\n\n$collectAnchorToken';
                    final now = DateTime.now();
                    final updated = note.copyWith(
                      body: nextBody,
                      updatedAt: now,
                    );
                    await ref.read(noteRepositoryProvider).upsertNote(updated);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('已插入收集箱锚点（可在正文中移动）'),
                        action: SnackBarAction(
                          label: '编辑',
                          onPressed: () => _openEditSheet(context, updated),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Tooltip(
              message: 'AI 动作',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                onPressed: () => _openAiActionsSheet(context, note.id),
              ),
            ),
            Tooltip(
              message: '编辑',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _openEditSheet(context, note),
              ),
            ),
          ],
          body: ListView(
            padding: DpInsets.page,
            children: [
              Text(
                note.title.value,
                style: shadTheme.textTheme.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              if (note.kind != domain.NoteKind.longform)
                _WeaveTargetsSection(
                  linksAsync: outgoingWeaveLinksAsync,
                  noteById: noteById,
                ),
              if (taskId != null) ...[
                const SizedBox(height: DpSpacing.md),
                ShadCard(
                  padding: DpInsets.card,
                  title: Text(
                    '关联任务',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  child: taskAsync!.when(
                    loading: () => Text(
                      '加载中…',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    error: (_, _) => Text(
                      '加载失败',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    data: (task) {
                      final title = task == null
                          ? '任务不存在或已删除'
                          : task.title.value;
                      return InkWell(
                        onTap: task == null
                            ? null
                            : () => context.push('/tasks/${task.id}'),
                        borderRadius: BorderRadius.circular(DpRadius.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DpSpacing.sm,
                            vertical: DpSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.checklist_outlined, size: 18),
                              const SizedBox(width: DpSpacing.sm),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (task != null)
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: colorScheme.mutedForeground,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (!hasCollectAnchor &&
                  (note.kind == domain.NoteKind.longform ||
                      hasCollectLinks)) ...[
                const SizedBox(height: DpSpacing.md),
                collectBoxCard,
              ] else if (!hasCollectAnchor &&
                  weaveLinksAsync.hasError &&
                  note.kind == domain.NoteKind.longform) ...[
                const SizedBox(height: DpSpacing.md),
                collectBoxCard,
              ],
              if (hasCollectAnchor) ...[
                const SizedBox(height: DpSpacing.md),
                _LongformBody(
                  beforeText: anchor.before,
                  afterText: anchor.after,
                  collectBox: collectBoxCard,
                ),
              ] else ...[
                const SizedBox(height: DpSpacing.md),
                note.kind == domain.NoteKind.longform
                    ? _LongformText(text: note.body)
                    : _PlainBody(text: note.body),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditSheet(BuildContext context, domain.Note note) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => NoteEditSheet(note: note),
    );
  }

  Future<void> _openAiActionsSheet(BuildContext context, String noteId) async {
    final action = await showModalBottomSheet<NoteAiAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const NoteAiActionsSheet(),
    );
    if (action == null) return;
    if (!context.mounted) return;

    switch (action) {
      case NoteAiAction.summary:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => NoteAiSummarySheet(noteId: noteId),
        );
        break;
      case NoteAiAction.actionItems:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => NoteAiActionItemsSheet(noteId: noteId),
        );
        break;
      case NoteAiAction.rewriteForSharing:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => NoteAiRewriteSheet(noteId: noteId),
        );
        break;
    }
  }
}

class _PlainBody extends StatelessWidget {
  const _PlainBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) {
      return Text(
        '（空）',
        style: shadTheme.textTheme.muted.copyWith(
          color: colorScheme.mutedForeground,
        ),
      );
    }
    return SelectionArea(
      child: Text(
        trimmed,
        style: shadTheme.textTheme.p.copyWith(
          color: colorScheme.foreground,
          height: 1.65,
        ),
      ),
    );
  }
}

class _LongformText extends StatelessWidget {
  const _LongformText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final blocks = _parseLongformBlocks(context, text);
    final visibleBlocks = blocks.where((w) => w is! _EmptyBlock).toList();

    if (visibleBlocks.isEmpty) {
      return Text(
        '（空）',
        style: shadTheme.textTheme.muted.copyWith(
          color: colorScheme.mutedForeground,
        ),
      );
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visibleBlocks.length; i++) ...[
            if (i != 0) const SizedBox(height: DpSpacing.md),
            visibleBlocks[i],
          ],
        ],
      ),
    );
  }
}

class _LongformBody extends StatelessWidget {
  const _LongformBody({
    required this.beforeText,
    required this.afterText,
    required this.collectBox,
  });

  final String beforeText;
  final String afterText;
  final Widget collectBox;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final blocks = <Widget>[
      ..._parseLongformBlocks(context, beforeText),
      collectBox,
      ..._parseLongformBlocks(context, afterText),
    ];
    final visibleBlocks = blocks.where((w) => w is! _EmptyBlock).toList();

    if (visibleBlocks.length == 1 &&
        identical(visibleBlocks.first, collectBox)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '（空）',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          collectBox,
        ],
      );
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visibleBlocks.length; i++) ...[
            if (i != 0) const SizedBox(height: DpSpacing.md),
            visibleBlocks[i],
          ],
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget _buildLongformListItemRow({
  required BuildContext context,
  required String lead,
  required String body,
  required TextStyle style,
  required ShadColorScheme colorScheme,
}) {
  final parsed = stripInlineRouteToken(body);
  final route = parsed.route;

  final row = Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 24,
        child: Text(
          lead,
          style: style.copyWith(
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(child: Text(parsed.text, style: style)),
      if (route != null) ...[
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, size: 18, color: colorScheme.mutedForeground),
      ],
    ],
  );

  if (route == null) return row;

  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => context.push(route),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: row,
    ),
  );
}

List<Widget> _parseLongformBlocks(BuildContext context, String raw) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  if (text.isEmpty) return const [];
  final paragraphs = text.split(RegExp(r'\n\s*\n'));
  final blocks = <Widget>[];
  for (final p in paragraphs) {
    final block = _renderLongformParagraph(context, p);
    if (block is _EmptyBlock) continue;
    blocks.add(block);
  }
  return blocks;
}

Widget _renderLongformParagraph(BuildContext context, String paragraph) {
  final shadTheme = ShadTheme.of(context);
  final colorScheme = shadTheme.colorScheme;
  final trimmed = paragraph.trimRight();
  if (trimmed.trim().isEmpty) return const _EmptyBlock();

  final isHr =
      trimmed.split('\n').where((l) => l.trim().isNotEmpty).length == 1 &&
      RegExp(r'^\s{0,3}([-*_])(?:\s*\1){2,}\s*$').hasMatch(trimmed.trim());
  if (isHr) {
    return Divider(height: 0, thickness: 1, color: colorScheme.border);
  }

  const lineHeight = 1.65;
  final pStyle = shadTheme.textTheme.p.copyWith(
    color: colorScheme.foreground,
    height: lineHeight,
  );
  final listStyle = shadTheme.textTheme.list.copyWith(
    color: colorScheme.foreground,
    height: lineHeight,
  );
  final quoteStyle = shadTheme.textTheme.blockquote.copyWith(
    color: colorScheme.foreground,
    height: lineHeight,
  );

  final lines = trimmed.split('\n');
  final headingMatch = RegExp(
    r'^\s{0,3}(#{1,6})\s+(.*)$',
  ).firstMatch(lines.first);
  if (headingMatch != null) {
    final level = headingMatch.group(1)!.length;
    final title = headingMatch.group(2)!.trim();
    if (title.isEmpty) return const _EmptyBlock();
    final style = switch (level) {
      1 => shadTheme.textTheme.h3.copyWith(fontWeight: FontWeight.w700),
      2 => shadTheme.textTheme.h4.copyWith(fontWeight: FontWeight.w700),
      3 => shadTheme.textTheme.large.copyWith(fontWeight: FontWeight.w700),
      4 => shadTheme.textTheme.small.copyWith(fontWeight: FontWeight.w700),
      _ => shadTheme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
    };
    return Text(title, style: style.copyWith(color: colorScheme.foreground));
  }

  final bulletPattern = RegExp(r'^\s*[-*•]\s+(.+)$');
  final numberPattern = RegExp(r'^\s*(\d+)\.\s+(.+)$');

  List<({String lead, String body})> parseListItems(Iterable<String> rawLines) {
    final out = <({String lead, String body})>[];
    for (final line in rawLines) {
      if (line.trim().isEmpty) continue;
      final bulletMatch = bulletPattern.firstMatch(line);
      if (bulletMatch != null) {
        out.add((lead: '•', body: bulletMatch.group(1)!.trimRight()));
        continue;
      }
      final numberMatch = numberPattern.firstMatch(line);
      if (numberMatch != null) {
        out.add((
          lead: '${numberMatch.group(1)}.',
          body: numberMatch.group(2)!.trimRight(),
        ));
        continue;
      }
      return const [];
    }
    return out;
  }

  bool shouldRenderAsList(List<({String lead, String body})> items) {
    if (items.length >= 2) return true;
    if (items.length == 1) {
      return stripInlineRouteToken(items.single.body).route != null;
    }
    return false;
  }

  final nonEmptyLines = lines.where((l) => l.trim().isNotEmpty).toList();
  if (nonEmptyLines.length >= 2 &&
      bulletPattern.firstMatch(nonEmptyLines.first) == null &&
      numberPattern.firstMatch(nonEmptyLines.first) == null) {
    final header = nonEmptyLines.first.trimRight();
    final items = parseListItems(nonEmptyLines.skip(1));
    if (items.isNotEmpty && shouldRenderAsList(items)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(header, style: pStyle),
          const SizedBox(height: DpSpacing.sm),
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(height: 6),
            _buildLongformListItemRow(
              context: context,
              lead: items[i].lead,
              body: items[i].body,
              style: listStyle,
              colorScheme: colorScheme,
            ),
          ],
        ],
      );
    }
  }

  final items = parseListItems(lines);
  if (items.isNotEmpty && shouldRenderAsList(items)) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i != 0) const SizedBox(height: 6),
          _buildLongformListItemRow(
            context: context,
            lead: items[i].lead,
            body: items[i].body,
            style: listStyle,
            colorScheme: colorScheme,
          ),
        ],
      ],
    );
  }

  final isQuote = lines.every(
    (l) => l.trim().isEmpty || l.trimLeft().startsWith('>'),
  );
  if (isQuote) {
    final quote = lines
        .map((l) => l.replaceFirst(RegExp(r'^\s*>\s?'), ''))
        .join('\n')
        .trimRight();
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colorScheme.border, width: 3)),
        color: colorScheme.muted,
        borderRadius: BorderRadius.circular(DpRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.md,
        vertical: DpSpacing.sm,
      ),
      child: Text(quote, style: quoteStyle),
    );
  }

  return Text(trimmed.trimRight(), style: pStyle);
}

class _CollectBoxCard extends ConsumerWidget {
  const _CollectBoxCard({
    required this.targetNote,
    required this.linksAsync,
    required this.noteById,
    required this.taskById,
    required this.showEmptyState,
    required this.showAnchorHint,
  });

  final domain.Note targetNote;
  final AsyncValue<List<domain.WeaveLink>> linksAsync;
  final Map<String, domain.Note> noteById;
  final Map<String, domain.Task> taskById;
  final bool showEmptyState;
  final bool showAnchorHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    if (!showEmptyState) {
      if (linksAsync.isLoading || linksAsync.hasError) {
        return const SizedBox.shrink();
      }
    }

    if (linksAsync.hasError) {
      return ShadAlert.destructive(
        icon: const Icon(Icons.error_outline),
        title: const Text('收集箱加载失败'),
        description: Text('${linksAsync.error}'),
      );
    }

    if (linksAsync.isLoading) {
      return ShadCard(
        padding: DpInsets.card,
        title: _collectTitle(context, count: null),
        child: const ShadProgress(minHeight: 8),
      );
    }

    final links = linksAsync.valueOrNull ?? const <domain.WeaveLink>[];
    if (links.isEmpty && !showEmptyState) return const SizedBox.shrink();

    if (links.isEmpty) {
      return ShadCard(
        padding: DpInsets.card,
        title: _collectTitle(context, count: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '还没有编织内容。你可以从 Today「待编织」或任务详情把内容编织进来。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            if (showAnchorHint) ...[
              const SizedBox(height: DpSpacing.sm),
              Text(
                '提示：在正文中插入 $collectAnchorToken 可把收集箱放到你想要的位置。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ShadCard(
      padding: EdgeInsets.zero,
      title: _collectTitle(context, count: links.length),
      child: Column(
        children: [
          for (var i = 0; i < links.length; i++) ...[
            Builder(
              builder: (context) {
                final link = links[i];
                final sourceNote =
                    link.sourceType == domain.WeaveSourceType.note
                    ? noteById[link.sourceId]
                    : null;
                final sourceTask =
                    link.sourceType == domain.WeaveSourceType.task
                    ? taskById[link.sourceId]
                    : null;
                final canCopyIntoBody =
                    targetNote.kind == domain.NoteKind.longform &&
                    link.mode == domain.WeaveMode.reference;

                return _WeaveLinkRow(
                  link: link,
                  sourceNote: sourceNote,
                  sourceTask: sourceTask,
                  onOpen: () {
                    switch (link.sourceType) {
                      case domain.WeaveSourceType.note:
                        if (sourceNote == null) return;
                        context.push('/notes/${sourceNote.id}');
                        return;
                      case domain.WeaveSourceType.task:
                        if (sourceTask == null) return;
                        context.push('/tasks/${sourceTask.id}');
                        return;
                      case domain.WeaveSourceType.pomodoroSession:
                        return;
                    }
                  },
                  onCopyIntoBody: canCopyIntoBody
                      ? () async {
                          final block = switch (link.sourceType) {
                            domain.WeaveSourceType.note =>
                              sourceNote == null
                                  ? null
                                  : formatWeaveCopyBlockFromNote(sourceNote),
                            domain.WeaveSourceType.task =>
                              sourceTask == null
                                  ? null
                                  : formatWeaveCopyBlockFromTask(sourceTask),
                            domain.WeaveSourceType.pomodoroSession => null,
                          };
                          if (block == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('来源不存在或暂不支持')),
                            );
                            return;
                          }

                          final beforeNote = targetNote;
                          final beforeLink = link;
                          final now = DateTime.now();
                          final noteRepo = ref.read(noteRepositoryProvider);
                          final weaveRepo = ref.read(
                            weaveLinkRepositoryProvider,
                          );

                          final nextBody = insertAfterCollectAnchor(
                            beforeNote.body,
                            block,
                          );
                          await noteRepo.upsertNote(
                            beforeNote.copyWith(body: nextBody, updatedAt: now),
                          );
                          await weaveRepo.upsertLink(
                            beforeLink.copyWith(
                              mode: domain.WeaveMode.copy,
                              updatedAt: now,
                            ),
                          );

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('已拷贝进正文'),
                              action: SnackBarAction(
                                label: '撤销',
                                onPressed: () async {
                                  await noteRepo.upsertNote(
                                    beforeNote.copyWith(
                                      updatedAt: DateTime.now(),
                                    ),
                                  );
                                  await weaveRepo.upsertLink(
                                    beforeLink.copyWith(
                                      updatedAt: DateTime.now(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }
                      : null,
                  onRemove: () async {
                    await ref
                        .read(weaveLinkRepositoryProvider)
                        .deleteLink(link.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已移除引用')));
                  },
                );
              },
            ),
            if (i != links.length - 1)
              Divider(height: 0, color: colorScheme.border),
          ],
        ],
      ),
    );
  }

  Widget _collectTitle(BuildContext context, {required int? count}) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            '收集箱',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
        ),
        if (count != null) ShadBadge.outline(child: Text('$count')),
      ],
    );
  }
}

class _WeaveTargetsSection extends ConsumerWidget {
  const _WeaveTargetsSection({
    required this.linksAsync,
    required this.noteById,
  });

  final AsyncValue<List<domain.WeaveLink>> linksAsync;
  final Map<String, domain.Note> noteById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return linksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: ShadProgress(minHeight: 8),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ShadAlert.destructive(
          icon: const Icon(Icons.error_outline),
          title: const Text('编织目标加载失败'),
          description: Text('$error'),
        ),
      ),
      data: (links) {
        if (links.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ShadCard(
            padding: EdgeInsets.zero,
            title: Text(
              '已编织到',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < links.length; i++) ...[
                  if (i != 0) Divider(height: 0, color: colorScheme.border),
                  ListTile(
                    title: Text(
                      noteById[links[i].targetNoteId]?.title.value ??
                          '（长文不存在或已删除）',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      links[i].mode == domain.WeaveMode.copy ? '拷贝' : '引用',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    trailing: Tooltip(
                      message: '移除链接',
                      child: ShadIconButton.ghost(
                        icon: const Icon(Icons.link_off_outlined, size: 18),
                        onPressed: () async {
                          await ref
                              .read(weaveLinkRepositoryProvider)
                              .deleteLink(links[i].id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已移除编织链接')),
                          );
                        },
                      ),
                    ),
                    onTap: () {
                      final target = noteById[links[i].targetNoteId];
                      if (target == null) return;
                      context.push('/notes/${target.id}');
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeaveLinkRow extends StatelessWidget {
  const _WeaveLinkRow({
    required this.link,
    required this.sourceNote,
    required this.sourceTask,
    required this.onOpen,
    this.onCopyIntoBody,
    required this.onRemove,
  });

  final domain.WeaveLink link;
  final domain.Note? sourceNote;
  final domain.Task? sourceTask;
  final VoidCallback onOpen;
  final VoidCallback? onCopyIntoBody;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final label = switch (link.sourceType) {
      domain.WeaveSourceType.note =>
        (sourceNote?.kind == domain.NoteKind.memo) ? '闪念' : '笔记',
      domain.WeaveSourceType.task => '任务',
      domain.WeaveSourceType.pomodoroSession => '专注',
    };

    final title = switch (link.sourceType) {
      domain.WeaveSourceType.note => sourceNote?.title.value,
      domain.WeaveSourceType.task => sourceTask?.title.value,
      domain.WeaveSourceType.pomodoroSession => '专注记录',
    };
    final snippet = switch (link.sourceType) {
      domain.WeaveSourceType.note =>
        sourceNote == null ? null : _firstLine(sourceNote!.body),
      domain.WeaveSourceType.task =>
        sourceTask?.description?.trim().isNotEmpty == true
            ? _firstLine(sourceTask!.description!)
            : sourceTask?.tags.take(3).join(' · '),
      domain.WeaveSourceType.pomodoroSession => null,
    };
    final canOpen = switch (link.sourceType) {
      domain.WeaveSourceType.note => sourceNote != null,
      domain.WeaveSourceType.task => sourceTask != null,
      domain.WeaveSourceType.pomodoroSession => false,
    };

    return InkWell(
      onTap: canOpen ? onOpen : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ShadBadge.outline(child: Text(label)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? '（来源已删除）',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  if (snippet != null && snippet.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      snippet,
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
            if (onCopyIntoBody != null &&
                link.mode == domain.WeaveMode.reference)
              Tooltip(
                message: '拷贝进正文',
                child: ShadIconButton.ghost(
                  icon: const Icon(Icons.content_copy_outlined, size: 18),
                  onPressed: onCopyIntoBody,
                ),
              ),
            Tooltip(
              message: '移除',
              child: ShadIconButton.ghost(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
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

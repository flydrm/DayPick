import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../notes/providers/note_providers.dart';
import '../../tasks/providers/task_providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

enum _SearchType { tasks, longform, drafts, memos, sessions }

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';
  bool _includeInbox = true;
  bool _includeArchived = false;
  final Set<_SearchType> _types = {
    _SearchType.tasks,
    _SearchType.longform,
    _SearchType.drafts,
    _SearchType.memos,
    _SearchType.sessions,
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final notesAsync = ref.watch(notesStreamProvider);

    final now = DateTime.now();
    final range = _SessionRange.forNow(now);
    final sessionsAsync = ref.watch(_searchSessionsProvider(range));

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final notes = notesAsync.valueOrNull ?? const <domain.Note>[];
    final sessions =
        sessionsAsync.valueOrNull ?? const <domain.PomodoroSession>[];
    final taskById = {for (final t in tasks) t.id: t};

    final keyword = _query.trim().toLowerCase();
    final results = _buildResults(
      keyword: keyword,
      tasks: tasks,
      notes: notes,
      sessions: sessions,
      taskById: taskById,
    );

    final anyLoading =
        tasksAsync.isLoading || notesAsync.isLoading || sessionsAsync.isLoading;
    final anyError =
        tasksAsync.hasError || notesAsync.hasError || sessionsAsync.hasError;

    return AppPageScaffold(
      title: '搜索',
      showCreateAction: false,
      showSearchAction: false,
      showSettingsAction: false,
      body: ListView(
        padding: DpInsets.page,
        children: [
          ShadCard(
            padding: DpInsets.card,
            child: ShadInput(
              controller: _controller,
              autofocus: true,
              placeholder: Text(
                '搜索任务/笔记/闪念/专注记录…',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              leading: const Icon(Icons.search, size: 18),
              trailing: _query.trim().isEmpty
                  ? null
                  : ShadIconButton.ghost(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '范围',
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
                    _ToggleChip(
                      label: '任务',
                      selected: _types.contains(_SearchType.tasks),
                      onTap: () => _toggleType(_SearchType.tasks),
                    ),
                    _ToggleChip(
                      label: '长文',
                      selected: _types.contains(_SearchType.longform),
                      onTap: () => _toggleType(_SearchType.longform),
                    ),
                    _ToggleChip(
                      label: '草稿',
                      selected: _types.contains(_SearchType.drafts),
                      onTap: () => _toggleType(_SearchType.drafts),
                    ),
                    _ToggleChip(
                      label: '闪念',
                      selected: _types.contains(_SearchType.memos),
                      onTap: () => _toggleType(_SearchType.memos),
                    ),
                    _ToggleChip(
                      label: '专注（近 12 周）',
                      selected: _types.contains(_SearchType.sessions),
                      onTap: () => _toggleType(_SearchType.sessions),
                    ),
                  ],
                ),
                const SizedBox(height: DpSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToggleChip(
                      label: '包含待处理（Inbox）',
                      selected: _includeInbox,
                      onTap: () =>
                          setState(() => _includeInbox = !_includeInbox),
                    ),
                    _ToggleChip(
                      label: '包含归档',
                      selected: _includeArchived,
                      onTap: () =>
                          setState(() => _includeArchived = !_includeArchived),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (anyError) ...[
            const SizedBox(height: DpSpacing.md),
            ShadAlert.destructive(
              icon: const Icon(Icons.error_outline),
              title: const Text('部分数据加载失败'),
              description: Text(
                [
                  if (tasksAsync.hasError) '任务：${tasksAsync.error}',
                  if (notesAsync.hasError) '笔记：${notesAsync.error}',
                  if (sessionsAsync.hasError) '专注：${sessionsAsync.error}',
                ].join('\n'),
              ),
            ),
          ],
          if (anyLoading) ...[
            const SizedBox(height: DpSpacing.md),
            const ShadProgress(minHeight: 8),
          ],
          const SizedBox(height: DpSpacing.md),
          if (keyword.isEmpty)
            const ShadAlert(
              icon: Icon(Icons.search),
              title: Text('全局搜索'),
              description: Text('输入关键字；空搜索会展示最近更新的内容。'),
            ),
          const SizedBox(height: DpSpacing.md),
          if (results.isEmpty)
            ShadCard(
              padding: DpInsets.card,
              child: Text(
                keyword.isEmpty ? '暂无最近内容。' : '没有匹配结果。',
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            )
          else
            ShadCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 0, color: colorScheme.border),
                itemBuilder: (context, index) {
                  final r = results[index];
                  return InkWell(
                    onTap: () => context.push(r.route),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShadBadge.outline(child: Text(r.typeLabel)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: shadTheme.textTheme.small.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                                if (r.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    r.subtitle!,
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
                          const SizedBox(width: 10),
                          if (r.timeLabel != null)
                            Text(
                              r.timeLabel!,
                              style: shadTheme.textTheme.muted.copyWith(
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _toggleType(_SearchType type) {
    setState(() {
      if (_types.contains(type)) {
        if (_types.length == 1) return;
        _types.remove(type);
      } else {
        _types.add(type);
      }
    });
  }

  bool _triageAllowed(domain.TriageStatus status) {
    if (!_includeArchived && status == domain.TriageStatus.archived) {
      return false;
    }
    if (!_includeInbox && status == domain.TriageStatus.inbox) {
      return false;
    }
    return true;
  }

  List<_SearchResult> _buildResults({
    required String keyword,
    required List<domain.Task> tasks,
    required List<domain.Note> notes,
    required List<domain.PomodoroSession> sessions,
    required Map<String, domain.Task> taskById,
  }) {
    final results = <_SearchResult>[];

    if (_types.contains(_SearchType.tasks)) {
      for (final t in tasks) {
        if (!_triageAllowed(t.triageStatus)) continue;
        final score = _matchScore(
          keyword: keyword,
          title: t.title.value,
          body: [t.description ?? '', t.tags.join(' ')].join('\n'),
        );
        if (score == null) continue;
        results.add(
          _SearchResult(
            type: _SearchType.tasks,
            id: t.id,
            title: t.title.value,
            subtitle: _firstLine(t.description) ?? _joinTags(t.tags),
            route: '/tasks/${t.id}',
            updatedAt: t.updatedAt,
            score: score,
          ),
        );
      }
    }

    for (final n in notes) {
      final type = switch (n.kind) {
        domain.NoteKind.longform => _SearchType.longform,
        domain.NoteKind.draft => _SearchType.drafts,
        domain.NoteKind.memo => _SearchType.memos,
      };
      if (!_types.contains(type)) continue;
      if (!_triageAllowed(n.triageStatus)) continue;
      final score = _matchScore(
        keyword: keyword,
        title: n.title.value,
        body: [n.body, n.tags.join(' ')].join('\n'),
      );
      if (score == null) continue;
      results.add(
        _SearchResult(
          type: type,
          id: n.id,
          title: n.title.value,
          subtitle: _firstLine(n.body) ?? _joinTags(n.tags),
          route: '/notes/${n.id}',
          updatedAt: n.updatedAt,
          score: score,
        ),
      );
    }

    if (_types.contains(_SearchType.sessions)) {
      for (final s in sessions) {
        final taskTitle = taskById[s.taskId]?.title.value;
        final title = taskTitle == null ? '专注' : '专注：$taskTitle';
        final body = [s.progressNote ?? '', taskTitle ?? ''].join('\n');
        final score = _matchScore(keyword: keyword, title: title, body: body);
        if (score == null) continue;
        results.add(
          _SearchResult(
            type: _SearchType.sessions,
            id: s.id,
            title: title,
            subtitle: _firstLine(s.progressNote) ?? _formatSessionTime(s),
            route: '/tasks/${s.taskId}',
            updatedAt: s.endAt,
            score: score,
          ),
        );
      }
    }

    results.sort((a, b) {
      final score = a.score.compareTo(b.score);
      if (score != 0) return score;
      final ta = a.updatedAt;
      final tb = b.updatedAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    if (keyword.isEmpty) {
      return results.take(20).toList(growable: false);
    }
    return results.take(80).toList(growable: false);
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = selected ? ShadButton.secondary : ShadButton.outline;
    return button(
      size: ShadButtonSize.sm,
      onPressed: onTap,
      leading: selected ? const Icon(Icons.check, size: 16) : null,
      child: Text(label),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.updatedAt,
    required this.score,
  });

  final _SearchType type;
  final String id;
  final String title;
  final String? subtitle;
  final String route;
  final DateTime? updatedAt;
  final int score;

  String get typeLabel {
    return switch (type) {
      _SearchType.tasks => '任务',
      _SearchType.longform => '长文',
      _SearchType.drafts => '草稿',
      _SearchType.memos => '闪念',
      _SearchType.sessions => '专注',
    };
  }

  String? get timeLabel {
    final t = updatedAt;
    if (t == null) return null;
    return '${t.month}/${t.day}';
  }
}

String? _firstLine(String? body) {
  if (body == null) return null;
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.split('\n').first.trim();
}

String? _joinTags(List<String> tags) {
  if (tags.isEmpty) return null;
  return tags.take(4).join(' · ');
}

int? _matchScore({
  required String keyword,
  required String title,
  required String body,
}) {
  if (keyword.isEmpty) return 0;
  final q = keyword.toLowerCase();
  final t = title.toLowerCase();
  final b = body.toLowerCase();

  if (t.startsWith(q)) return 0;
  if (t.contains(q)) return 1;
  if (b.contains(q)) return 2;
  return null;
}

String _formatSessionTime(domain.PomodoroSession s) {
  String two(int v) => v.toString().padLeft(2, '0');
  final start = '${two(s.startAt.hour)}:${two(s.startAt.minute)}';
  final end = '${two(s.endAt.hour)}:${two(s.endAt.minute)}';
  final minutes = s.duration.inMinutes;
  return '$start-$end · ${minutes}min';
}

final _searchSessionsProvider =
    StreamProvider.family<List<domain.PomodoroSession>, _SessionRange>((
      ref,
      range,
    ) {
      return ref
          .watch(pomodoroSessionRepositoryProvider)
          .watchBetween(range.startInclusive, range.endExclusive);
    });

class _SessionRange {
  const _SessionRange({
    required this.startInclusive,
    required this.endExclusive,
  });

  factory _SessionRange.forNow(DateTime now) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final currentWeekStart = todayStart.subtract(
      Duration(days: todayStart.weekday - DateTime.monday),
    );
    final start = currentWeekStart.subtract(const Duration(days: 7 * 11));
    final end = start.add(const Duration(days: 7 * 12));
    return _SessionRange(startInclusive: start, endExclusive: end);
  }

  final DateTime startInclusive;
  final DateTime endExclusive;

  @override
  bool operator ==(Object other) =>
      other is _SessionRange &&
      other.startInclusive == startInclusive &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(startInclusive, endExclusive);
}

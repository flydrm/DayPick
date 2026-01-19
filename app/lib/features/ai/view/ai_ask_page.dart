import 'dart:async';

import 'package:ai/ai.dart' as ai;
import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/providers/app_providers.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/scaffolds/app_page_scaffold.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';
import '../../notes/providers/note_providers.dart';
import '../../tasks/providers/task_providers.dart';
import '../model/ai_evidence_item.dart';
import '../model/time_range_key.dart';
import '../providers/ai_providers.dart';
import 'ai_send_field_chip.dart';
import 'ai_send_preview_sheet.dart';

class AiAskPage extends ConsumerStatefulWidget {
  const AiAskPage({super.key});

  @override
  ConsumerState<AiAskPage> createState() => _AiAskPageState();
}

class _AiAskPageState extends ConsumerState<AiAskPage> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();

  int _rangeDays = 7;
  AiEvidenceType? _typeFilter;
  String? _tagFilter;
  String _query = '';

  final Set<String> _selectedKeys = <String>{};

  bool _sendIncludeTaskDescription = true;
  bool _sendIncludeTaskDueDate = true;
  bool _sendIncludeTags = true;
  bool _sendIncludeNoteSnippet = true;
  bool _sendIncludeSessionProgressNote = true;

  ai.AiCancelToken? _cancelToken;
  bool _sending = false;
  bool _saving = false;
  ai.AiEvidenceAnswer? _answer;
  String? _lastQuestion;
  String? _savedNoteId;
  List<AiEvidenceItem> _lastSelectedEvidence = const [];
  bool _didAutoSelectTopEvidence = false;

  @override
  void dispose() {
    _cancelToken?.cancel('dispose');
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(aiConfigProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final notesAsync = ref.watch(notesStreamProvider);
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final endExclusive = todayStart.add(const Duration(days: 1));
    final startInclusive = _rangeDays >= 3650
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : endExclusive.subtract(Duration(days: _rangeDays));

    final sessionsAsync = ref.watch(
      pomodoroSessionsBetweenProvider(
        TimeRangeKey(
          startInclusive: startInclusive,
          endExclusive: endExclusive,
        ),
      ),
    );

    final config = configAsync.valueOrNull;
    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);

    final isLoading =
        tasksAsync.isLoading || notesAsync.isLoading || sessionsAsync.isLoading;

    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final notes = notesAsync.valueOrNull ?? const <domain.Note>[];
    final sessions =
        sessionsAsync.valueOrNull ?? const <domain.PomodoroSession>[];

    final evidenceAll = _buildEvidence(
      tasks: tasks,
      notes: notes,
      sessions: sessions,
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      includeTaskDescription: _sendIncludeTaskDescription,
      includeTaskDueDate: _sendIncludeTaskDueDate,
      includeTags: _sendIncludeTags,
      includeNoteSnippet: _sendIncludeNoteSnippet,
      includeSessionProgressNote: _sendIncludeSessionProgressNote,
    );

    final availableTags = _availableTags(evidenceAll);
    final evidence = _applyFilters(evidenceAll);
    _pruneSelection(evidenceAll);
    _maybeAutoSelectTopEvidence(evidenceAll: evidenceAll, isLoading: isLoading);

    return AppPageScaffold(
      title: '问答检索',
      body: ListView(
        padding: DpInsets.page,
        children: [
          _buildConfigCard(context, configAsync),
          const SizedBox(height: DpSpacing.md),
          _buildQuestionCard(context, ready),
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            title: Text(
              '证据',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _sendHintText(),
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: DpSpacing.md),
                Text(
                  '发送字段（可切换）：',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: DpSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AiSendFieldChip(
                      label: '任务描述',
                      selected: _sendIncludeTaskDescription,
                      enabled: !_sending,
                      onTap: () => setState(() {
                        _sendIncludeTaskDescription =
                            !_sendIncludeTaskDescription;
                        _resetResult();
                      }),
                    ),
                    AiSendFieldChip(
                      label: '任务到期',
                      selected: _sendIncludeTaskDueDate,
                      enabled: !_sending,
                      onTap: () => setState(() {
                        _sendIncludeTaskDueDate = !_sendIncludeTaskDueDate;
                        _resetResult();
                      }),
                    ),
                    AiSendFieldChip(
                      label: '标签',
                      selected: _sendIncludeTags,
                      enabled: !_sending,
                      onTap: () => setState(() {
                        _sendIncludeTags = !_sendIncludeTags;
                        _resetResult();
                      }),
                    ),
                    AiSendFieldChip(
                      label: '笔记摘要',
                      selected: _sendIncludeNoteSnippet,
                      enabled: !_sending,
                      onTap: () => setState(() {
                        _sendIncludeNoteSnippet = !_sendIncludeNoteSnippet;
                        _resetResult();
                      }),
                    ),
                    AiSendFieldChip(
                      label: '专注进展',
                      selected: _sendIncludeSessionProgressNote,
                      enabled: !_sending,
                      onTap: () => setState(() {
                        _sendIncludeSessionProgressNote =
                            !_sendIncludeSessionProgressNote;
                        _resetResult();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: DpSpacing.md),
                _buildFilterRow(context),
                if (availableTags.isNotEmpty) ...[
                  const SizedBox(height: DpSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      (_tagFilter == null)
                          ? ShadButton.secondary(
                              size: ShadButtonSize.sm,
                              onPressed: _sending
                                  ? null
                                  : () => setState(() => _tagFilter = null),
                              child: const Text('全部标签'),
                            )
                          : ShadButton.outline(
                              size: ShadButtonSize.sm,
                              onPressed: _sending
                                  ? null
                                  : () => setState(() => _tagFilter = null),
                              child: const Text('全部标签'),
                            ),
                      for (final tag in availableTags)
                        (_tagFilter == tag)
                            ? ShadButton.secondary(
                                size: ShadButtonSize.sm,
                                onPressed: _sending
                                    ? null
                                    : () => setState(() => _tagFilter = null),
                                child: Text(tag),
                              )
                            : ShadButton.outline(
                                size: ShadButtonSize.sm,
                                onPressed: _sending
                                    ? null
                                    : () => setState(() => _tagFilter = tag),
                                child: Text(tag),
                              ),
                    ],
                  ),
                ],
                const SizedBox(height: DpSpacing.md),
                if (isLoading)
                  const ShadProgress(minHeight: 8)
                else if (tasksAsync.hasError ||
                    notesAsync.hasError ||
                    sessionsAsync.hasError)
                  ShadAlert.destructive(
                    icon: const Icon(Icons.error_outline),
                    title: const Text('证据加载失败'),
                    description: Text(
                      '${tasksAsync.error ?? notesAsync.error ?? sessionsAsync.error}',
                    ),
                  )
                else if (evidenceAll.isEmpty)
                  Text(
                    '当前范围内没有可用证据（默认近 $_rangeDays 天）。',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  )
                else if (evidence.isEmpty)
                  Text(
                    '没有匹配的证据，请调整筛选条件。',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: _sending
                            ? null
                            : () => setState(
                                () => _selectedKeys
                                  ..clear()
                                  ..addAll(evidence.map((e) => e.key)),
                              ),
                        child: const Text('全选当前'),
                      ),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: _sending
                            ? null
                            : () => setState(() => _selectedKeys.clear()),
                        child: const Text('清空'),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: '预览本次发送',
                        child: ShadIconButton.ghost(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          onPressed: (_sending || _selectedKeys.isEmpty)
                              ? null
                              : () => _openSendPreview(
                                  context,
                                  config: config,
                                  evidenceAll: evidenceAll,
                                ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '已选 ${_selectedKeys.length}',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 0, color: colorScheme.border),
                  ShadCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < evidence.length; i++) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ShadCheckbox(
                                    value: _selectedKeys.contains(
                                      evidence[i].key,
                                    ),
                                    enabled: !_sending,
                                    onChanged: (v) => setState(() {
                                      if (v) {
                                        _selectedKeys.add(evidence[i].key);
                                      } else {
                                        _selectedKeys.remove(evidence[i].key);
                                      }
                                    }),
                                    label: Text(
                                      '${evidence[i].typeLabel} · ${evidence[i].title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    sublabel: Text(
                                      evidence[i].snippet.isEmpty
                                          ? _formatDate(evidence[i].at)
                                          : '${_formatDate(evidence[i].at)} · ${evidence[i].snippet}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: '打开',
                                  child: ShadIconButton.ghost(
                                    icon: const Icon(
                                      Icons.open_in_new_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        context.push(evidence[i].route),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i != evidence.length - 1)
                            Divider(height: 0, color: colorScheme.border),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          if (_answer != null) _buildAnswerCard(context),
        ],
      ),
    );
  }

  Widget _buildConfigCard(
    BuildContext context,
    AsyncValue<domain.AiProviderConfig?> configAsync,
  ) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return configAsync.when(
      loading: () => const ShadProgress(minHeight: 8),
      error: (error, stack) => ShadCard(
        padding: DpInsets.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.destructive),
            const SizedBox(width: DpSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'AI 配置读取失败',
                    style: shadTheme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: DpSpacing.xs),
                  Text(
                    '$error',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  ShadButton.secondary(
                    size: ShadButtonSize.sm,
                    onPressed: () => context.push('/settings/ai'),
                    child: const Text('去设置'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      data: (config) {
        final ready =
            config != null && (config.apiKey?.trim().isNotEmpty ?? false);
        if (!ready) {
          return ShadCard(
            padding: DpInsets.card,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: colorScheme.mutedForeground,
                ),
                const SizedBox(width: DpSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'AI 未配置',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: DpSpacing.xs),
                      Text(
                        '先在设置里配置 baseUrl / model / apiKey',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: DpSpacing.md),
                      ShadButton.secondary(
                        size: ShadButtonSize.sm,
                        onPressed: () => context.push('/settings/ai'),
                        child: const Text('设置'),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: colorScheme.primary),
              const SizedBox(width: DpSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'AI 已就绪',
                      style: shadTheme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: DpSpacing.xs),
                    Text(
                      '${config.model} · ${_shortBaseUrl(config.baseUrl)}',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: DpSpacing.md),
                    ShadButton.secondary(
                      size: ShadButtonSize.sm,
                      onPressed: () => context.push('/settings/ai'),
                      child: const Text('设置'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuestionCard(BuildContext context, bool ready) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return ShadCard(
      padding: DpInsets.card,
      title: Text(
        '问题',
        style: shadTheme.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.foreground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            controller: _questionController,
            enabled: !_sending,
            minLines: 2,
            maxLines: 6,
            placeholder: Text(
              '例如：我这周最重要的风险是什么？',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            leading: const Icon(Icons.question_answer_outlined, size: 18),
          ),
          const SizedBox(height: DpSpacing.md),
          ShadButton(
            onPressed: _saving ? null : (_sending ? _cancelSend : _send),
            leading: _sending
                ? const DpSpinner(size: 16, strokeWidth: 2)
                : const Icon(Icons.send_outlined, size: 18),
            child: Text(
              _sending
                  ? '发送中…（点此停止）'
                  : (ready ? '发送（需选 ≥2 条证据）' : '生成离线草稿（需选 ≥2 条证据）'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 128,
              child: ShadSelect<int>(
                enabled: !_sending,
                initialValue: _rangeDays,
                selectedOptionBuilder: (context, value) => Text(
                  value == 7
                      ? '近 7 天'
                      : value == 30
                      ? '近 30 天'
                      : '全部',
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                options: const [
                  ShadOption<int>(value: 7, child: Text('近 7 天')),
                  ShadOption<int>(value: 30, child: Text('近 30 天')),
                  ShadOption<int>(value: 3650, child: Text('全部')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _rangeDays = v;
                    _selectedKeys.clear();
                    _answer = null;
                    _lastSelectedEvidence = const [];
                    _savedNoteId = null;
                    _didAutoSelectTopEvidence = false;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShadInput(
                enabled: !_sending,
                placeholder: Text(
                  '关键词（标题/摘要）',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                leading: const Icon(Icons.search, size: 18),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ShadSelect<AiEvidenceType?>(
          enabled: !_sending,
          initialValue: _typeFilter,
          selectedOptionBuilder: (context, value) => Text(
            value == null
                ? '全部类型'
                : value == AiEvidenceType.note
                ? '笔记'
                : value == AiEvidenceType.task
                ? '任务'
                : '专注',
            style: shadTheme.textTheme.small.copyWith(
              color: colorScheme.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          options: const [
            ShadOption<AiEvidenceType?>(value: null, child: Text('全部类型')),
            ShadOption<AiEvidenceType?>(
              value: AiEvidenceType.note,
              child: Text('笔记'),
            ),
            ShadOption<AiEvidenceType?>(
              value: AiEvidenceType.task,
              child: Text('任务'),
            ),
            ShadOption<AiEvidenceType?>(
              value: AiEvidenceType.pomodoro,
              child: Text('专注'),
            ),
          ],
          onChanged: (v) => setState(() => _typeFilter = v),
        ),
      ],
    );
  }

  List<AiEvidenceItem> _buildEvidence({
    required List<domain.Task> tasks,
    required List<domain.Note> notes,
    required List<domain.PomodoroSession> sessions,
    required DateTime startInclusive,
    required DateTime endExclusive,
    required bool includeTaskDescription,
    required bool includeTaskDueDate,
    required bool includeTags,
    required bool includeNoteSnippet,
    required bool includeSessionProgressNote,
  }) {
    final byTaskId = {for (final t in tasks) t.id: t};
    final items = <AiEvidenceItem>[];

    for (final note in notes) {
      if (!_inRange(note.updatedAt, startInclusive, endExclusive)) continue;
      final noteParts = <String>[
        if (includeTags && note.tags.isNotEmpty) note.tags.take(3).join(' · '),
        if (includeNoteSnippet) _snippet(note.body),
      ];
      items.add(
        AiEvidenceItem(
          key: 'note:${note.id}',
          type: AiEvidenceType.note,
          title: note.title.value,
          snippet: noteParts.where((p) => p.trim().isNotEmpty).join('  ·  '),
          route: '/notes/${note.id}',
          at: note.updatedAt,
          tags: note.tags,
        ),
      );
    }

    for (final task in tasks) {
      if (!_inRange(task.updatedAt, startInclusive, endExclusive)) continue;
      final status = switch (task.status) {
        domain.TaskStatus.todo => '待办',
        domain.TaskStatus.inProgress => '进行中',
        domain.TaskStatus.done => '已完成',
      };
      final due = task.dueAt == null
          ? null
          : '${task.dueAt!.month}/${task.dueAt!.day}';
      final parts = <String>[
        status,
        if (includeTaskDueDate && due != null) '到期 $due',
        if (includeTags && task.tags.isNotEmpty) task.tags.take(3).join(' · '),
        if (includeTaskDescription &&
            task.description?.trim().isNotEmpty == true)
          _oneLine(task.description!),
      ];

      items.add(
        AiEvidenceItem(
          key: 'task:${task.id}',
          type: AiEvidenceType.task,
          title: task.title.value,
          snippet: parts.where((p) => p.trim().isNotEmpty).join('  ·  '),
          route: '/tasks/${task.id}',
          at: task.updatedAt,
          tags: task.tags,
        ),
      );
    }

    for (final session in sessions) {
      if (!_inRange(session.endAt, startInclusive, endExclusive)) continue;
      final task = byTaskId[session.taskId];
      final title = task?.title.value ?? '未知任务';
      final durationMinutes = session.duration.inMinutes;
      final note = session.progressNote?.trim();
      final snippetParts = <String>[
        '时长 ${durationMinutes}min',
        if (includeTags && task?.tags.isNotEmpty == true)
          task!.tags.take(3).join(' · '),
        if (includeSessionProgressNote && note != null && note.isNotEmpty) note,
      ];

      items.add(
        AiEvidenceItem(
          key: 'pomodoro:${session.id}',
          type: AiEvidenceType.pomodoro,
          title: '$title · 番茄',
          snippet: snippetParts.join('  ·  '),
          route: '/tasks/${session.taskId}',
          at: session.endAt,
          tags: task?.tags ?? const [],
        ),
      );
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  List<String> _availableTags(List<AiEvidenceItem> evidence) {
    final set = <String>{};
    for (final e in evidence) {
      set.addAll(e.tags);
    }
    final tags = set.toList();
    tags.sort((a, b) => a.compareTo(b));
    return tags;
  }

  List<AiEvidenceItem> _applyFilters(List<AiEvidenceItem> evidence) {
    final q = _query.trim();
    final type = _typeFilter;
    final tag = _tagFilter;

    return evidence
        .where((e) {
          if (type != null && e.type != type) return false;
          if (tag != null && !e.tags.contains(tag)) return false;
          if (q.isNotEmpty) {
            final hay = '${e.title}\n${e.snippet}'.toLowerCase();
            if (!hay.contains(q.toLowerCase())) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _pruneSelection(List<AiEvidenceItem> evidenceAll) {
    final availableKeys = evidenceAll.map((e) => e.key).toSet();
    _selectedKeys.removeWhere((k) => !availableKeys.contains(k));
  }

  void _resetResult() {
    _answer = null;
    _lastSelectedEvidence = const [];
    _savedNoteId = null;
    _lastQuestion = null;
    _answerController.text = '';
  }

  String _sendHintText() {
    final taskFields = <String>[
      '标题',
      if (_sendIncludeTaskDueDate) '到期',
      if (_sendIncludeTaskDescription) '描述',
      if (_sendIncludeTags) '标签',
    ];
    final noteFields = <String>[
      '标题',
      if (_sendIncludeNoteSnippet) '摘要',
      if (_sendIncludeTags) '标签',
    ];
    final focusFields = <String>[
      '标题',
      '时长',
      if (_sendIncludeSessionProgressNote) '进展',
      if (_sendIncludeTags) '标签',
    ];
    return [
      '将发送：你勾选的证据（≤12 条）。',
      '任务：${taskFields.join(' / ')}',
      '笔记：${noteFields.join(' / ')}',
      '专注：${focusFields.join(' / ')}',
      '回答必须给出可跳转引用。',
    ].join('\n');
  }

  List<String> _buildEvidenceBlocks(List<AiEvidenceItem> selected) {
    final blocks = <String>[];
    for (var i = 0; i < selected.length; i++) {
      final e = selected[i];
      final header = '[${i + 1}] ${e.type.name.toUpperCase()} ${e.title}';
      final snippet = e.snippet.trimRight();
      blocks.add(snippet.isEmpty ? header : '$header\n$snippet');
    }
    return blocks;
  }

  bool _inRange(DateTime dt, DateTime startInclusive, DateTime endExclusive) {
    return !dt.isBefore(startInclusive) && dt.isBefore(endExclusive);
  }

  void _cancelSend() {
    _cancelToken?.cancel('user');
  }

  Future<void> _openSendPreview(
    BuildContext context, {
    required domain.AiProviderConfig? config,
    required List<AiEvidenceItem> evidenceAll,
  }) async {
    final question = _questionController.text.trim();
    final selected = evidenceAll
        .where((e) => _selectedKeys.contains(e.key))
        .toList(growable: false);
    if (selected.isEmpty) {
      _showSnack('请先选择至少 1 条证据');
      return;
    }

    final questionText = question.isEmpty ? '（未填写）' : question;
    final blocks = _buildEvidenceBlocks(selected);
    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);
    final destination = ready
        ? '将发送到：${config.model} · ${_shortBaseUrl(config.baseUrl)}'
        : '离线草稿：不会联网发送';

    final previewText = [
      '# 发送预览',
      destination,
      '',
      '问题：',
      questionText,
      '',
      '证据（${blocks.length}）：',
      ...blocks,
    ].join('\n');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiSendPreviewSheet(
        destination: destination,
        previewText: previewText,
        sections: [
          AiSendPreviewSection(title: '问题', body: questionText),
          AiSendPreviewSection(title: '证据', body: blocks.join('\n\n')),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      _showSnack('请输入问题');
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final endExclusive = todayStart.add(const Duration(days: 1));
    final startInclusive = _rangeDays >= 3650
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : endExclusive.subtract(Duration(days: _rangeDays));

    final tasks = await ref.read(tasksStreamProvider.future);
    final notes = await ref.read(notesStreamProvider.future);
    final sessions = await ref.read(
      pomodoroSessionsBetweenProvider(
        TimeRangeKey(
          startInclusive: startInclusive,
          endExclusive: endExclusive,
        ),
      ).future,
    );

    final evidenceAll = _buildEvidence(
      tasks: tasks,
      notes: notes,
      sessions: sessions,
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      includeTaskDescription: _sendIncludeTaskDescription,
      includeTaskDueDate: _sendIncludeTaskDueDate,
      includeTags: _sendIncludeTags,
      includeNoteSnippet: _sendIncludeNoteSnippet,
      includeSessionProgressNote: _sendIncludeSessionProgressNote,
    );

    final selected = evidenceAll
        .where((e) => _selectedKeys.contains(e.key))
        .toList();
    if (selected.length < 2) {
      _showSnack('请至少选择 2 条证据');
      return;
    }

    if (selected.length > 12) {
      _showSnack('证据过多：请控制在 12 条以内（当前 ${selected.length}）');
      return;
    }

    final config = await ref.read(aiConfigProvider.future);
    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);

    ai.AiCancelToken? cancelToken;
    setState(() {
      _sending = true;
      _cancelToken = null;
      _answer = null;
      _answerController.text = '';
      _lastQuestion = question;
      _savedNoteId = null;
      _lastSelectedEvidence = selected;
    });

    try {
      if (!ready) {
        final draft = _offlineAskDraft(question: question, selected: selected);
        setState(() {
          _answer = ai.AiEvidenceAnswer(
            answer: draft,
            citations: const <int>[],
            insufficientEvidence: true,
          );
          _answerController.text = draft;
        });
        return;
      }

      cancelToken = ai.AiCancelToken();
      _cancelToken = cancelToken;
      final blocks = _buildEvidenceBlocks(selected);

      final result = await ref
          .read(openAiClientProvider)
          .askWithEvidence(
            config: config,
            question: question,
            evidence: blocks,
            cancelToken: cancelToken,
          );

      final validCitations =
          result.citations
              .where((c) => c >= 1 && c <= selected.length)
              .toSet()
              .toList()
            ..sort();

      final insufficient =
          result.insufficientEvidence ||
          validCitations.length < 2 ||
          validCitations.length > 5;
      final citations = insufficient ? const <int>[] : validCitations;

      setState(() {
        _answer = ai.AiEvidenceAnswer(
          answer: result.answer,
          citations: citations,
          insufficientEvidence: insufficient,
        );
        _answerController.text = result.answer;
      });
    } on ai.AiClientCancelledException {
      _showSnack('已取消');
    } catch (e) {
      _showSnack('问答失败：$e');
    } finally {
      if (cancelToken != null && identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
      if (mounted) setState(() => _sending = false);
    }
  }

  String _offlineAskDraft({
    required String question,
    required List<AiEvidenceItem> selected,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# 离线草稿（未调用模型）');
    buffer.writeln();
    buffer.writeln('## 问题');
    buffer.writeln(question);
    buffer.writeln();
    buffer.writeln('## 初步答案（待补）');
    buffer.writeln('- 结论：');
    buffer.writeln('- 依据：');
    buffer.writeln('- 不确定点：');
    buffer.writeln();
    buffer.writeln('## 证据（摘录）');
    for (final e in selected) {
      buffer.writeln('- ${e.typeLabel} · ${e.title}');
    }
    return buffer.toString().trimRight();
  }

  Widget _buildAnswerCard(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final answer = _answer!;
    final cited = answer.citations
        .where((i) => i >= 1 && i <= _lastSelectedEvidence.length)
        .map((i) => MapEntry(i, _lastSelectedEvidence[i - 1]))
        .toList(growable: false);

    return ShadCard(
      padding: DpInsets.card,
      title: Text(
        answer.insufficientEvidence ? '回答（证据不足，可编辑）' : '回答（可编辑）',
        style: shadTheme.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.foreground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            controller: _answerController,
            enabled: !_saving,
            minLines: 6,
            maxLines: 16,
            placeholder: Text(
              '可在此编辑后保存为笔记',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            leading: const Icon(Icons.edit_note_outlined, size: 18),
          ),
          const SizedBox(height: 12),
          if (!answer.insufficientEvidence) ...[
            Text(
              '引用',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            if (cited.length < 2)
              const ShadAlert(
                icon: Icon(Icons.warning_amber_outlined),
                title: Text('引用不足'),
                description: Text('应为 2–5 条。请补充更多证据后重试。'),
              )
            else
              ShadCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < cited.length; i++) ...[
                      InkWell(
                        onTap: () => context.push(cited[i].value.route),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colorScheme.muted,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: colorScheme.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${cited[i].key}',
                                  style: shadTheme.textTheme.small.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${cited[i].value.typeLabel} · ${cited[i].value.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: shadTheme.textTheme.small.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                    if (cited[i].value.snippet.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        cited[i].value.snippet,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: shadTheme.textTheme.muted
                                            .copyWith(
                                              color:
                                                  colorScheme.mutedForeground,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: colorScheme.mutedForeground,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i != cited.length - 1)
                        Divider(height: 0, color: colorScheme.border),
                    ],
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          ShadButton(
            onPressed: _saving ? null : _saveToNote,
            leading: _saving
                ? const DpSpinner(size: 16, strokeWidth: 2)
                : const Icon(Icons.save_outlined, size: 18),
            child: Text(_saving ? '保存中…' : '保存为笔记（可撤销）'),
          ),
          if (_savedNoteId != null) ...[
            const SizedBox(height: 8),
            ShadButton.outline(
              onPressed: () => context.push('/notes/${_savedNoteId!}'),
              leading: const Icon(Icons.open_in_new_outlined, size: 18),
              child: const Text('打开已保存笔记'),
            ),
          ],
        ],
      ),
    );
  }

  void _maybeAutoSelectTopEvidence({
    required List<AiEvidenceItem> evidenceAll,
    required bool isLoading,
  }) {
    if (_didAutoSelectTopEvidence) return;
    if (isLoading) return;
    if (evidenceAll.isEmpty) return;
    if (_selectedKeys.isNotEmpty) {
      _didAutoSelectTopEvidence = true;
      return;
    }
    _didAutoSelectTopEvidence = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedKeys
          ..clear()
          ..addAll(evidenceAll.take(5).map((e) => e.key));
      });
    });
  }

  Future<void> _saveToNote() async {
    final answer = _answer;
    if (answer == null) return;

    final question = _lastQuestion?.trim().isNotEmpty == true
        ? _lastQuestion!.trim()
        : _questionController.text.trim();
    final title = _buildNoteTitle(question);
    final body = _buildNoteBody(
      question: question,
      answer: _answerController.text,
    );

    setState(() => _saving = true);
    try {
      final create = ref.read(createNoteUseCaseProvider);
      final repo = ref.read(noteRepositoryProvider);
      final created = await create(
        title: title,
        body: body,
        tags: const ['ai', 'qa'],
      );

      if (!mounted) return;
      setState(() => _savedNoteId = created.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已保存为笔记'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              unawaited(repo.deleteNote(created.id));
              if (mounted && _savedNoteId == created.id) {
                setState(() => _savedNoteId = null);
              }
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _buildNoteTitle(String question) {
    final q = question.trim();
    if (q.isEmpty) return 'AI 问答';
    const max = 40;
    final normalized = q.replaceAll('\n', ' ').trim();
    final clipped = normalized.length <= max
        ? normalized
        : '${normalized.substring(0, max)}…';
    return '问答：$clipped';
  }

  String _buildNoteBody({required String question, required String answer}) {
    final selected = _lastSelectedEvidence;
    final citations =
        (_answer?.citations ?? const <int>[])
            .where((i) => i >= 1 && i <= selected.length)
            .toSet()
            .toList()
          ..sort();

    String routeToken(AiEvidenceItem item) {
      final route = item.route.trim();
      if (route.isEmpty) return '';
      return ' [[route:$route]]';
    }

    final timestamp = DateTime.now();
    final header = '## AI 问答（${_formatDateTime(timestamp)}）';
    final citationList = citations.isEmpty
        ? '引用：无（证据不足或模型未按要求返回）'
        : [
            '引用：',
            for (final c in citations)
              '- [$c] ${selected[c - 1].typeLabel} · ${selected[c - 1].title}${routeToken(selected[c - 1])}',
          ].join('\n');

    final evidenceList = <String>[
      '证据（本次发送 ${selected.length} 条）：',
      for (var i = 0; i < selected.length; i++)
        '- [${i + 1}] ${selected[i].typeLabel} · ${selected[i].title}${routeToken(selected[i])}',
    ].join('\n');

    return [
      header,
      '',
      '问题：',
      question.trim(),
      '',
      '回答：',
      answer.trimRight(),
      '',
      citationList,
      '',
      evidenceList,
    ].join('\n');
  }

  String _snippet(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    final lines = trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    return lines.take(2).join(' / ');
  }

  String _oneLine(String text) {
    final line = text.trim().split('\n').first.trim();
    return line.length <= 80 ? line : '${line.substring(0, 80)}…';
  }

  String _shortBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.length <= 32) return trimmed;
    return '${trimmed.substring(0, 32)}…';
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

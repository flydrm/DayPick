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

class AiWeeklyReviewPage extends ConsumerStatefulWidget {
  const AiWeeklyReviewPage({super.key});

  @override
  ConsumerState<AiWeeklyReviewPage> createState() => _AiWeeklyReviewPageState();
}

class _AiWeeklyReviewPageState extends ConsumerState<AiWeeklyReviewPage> {
  final TextEditingController _focusController = TextEditingController();
  final TextEditingController _draftController = TextEditingController();

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
  bool _generating = false;
  bool _saving = false;

  ai.AiEvidenceAnswer? _answer;
  List<AiEvidenceItem> _lastSelectedEvidence = const [];
  bool _didAutoSelectTopEvidence = false;

  @override
  void dispose() {
    _cancelToken?.cancel('dispose');
    _focusController.dispose();
    _draftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(aiConfigProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final notesAsync = ref.watch(notesStreamProvider);
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final range = _lastWeekRange(DateTime.now());
    final sessionsAsync = ref.watch(
      pomodoroSessionsBetweenProvider(
        TimeRangeKey(
          startInclusive: range.startInclusive,
          endExclusive: range.endExclusive,
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
      startInclusive: range.startInclusive,
      endExclusive: range.endExclusive,
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
      title: '周复盘',
      body: ListView(
        padding: DpInsets.page,
        children: [
          _buildConfigCard(context, configAsync),
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            child: Row(
              children: [
                Icon(
                  Icons.date_range_outlined,
                  color: colorScheme.mutedForeground,
                ),
                const SizedBox(width: DpSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '范围：上周自然周',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: DpSpacing.xs),
                      Text(
                        '${_formatDateYmd(range.startInclusive)} ～ ${_formatDateYmd(range.endExclusive.subtract(const Duration(days: 1)))}',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            title: Text(
              '关注点（可选）',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShadInput(
                  controller: _focusController,
                  enabled: !_generating && !_saving,
                  minLines: 1,
                  maxLines: 3,
                  placeholder: Text(
                    '例如：风险/阻塞、客户沟通、交付节奏',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: const Icon(
                    Icons.center_focus_strong_outlined,
                    size: 18,
                  ),
                ),
                const SizedBox(height: DpSpacing.md),
                ShadButton(
                  onPressed: _saving
                      ? null
                      : (_generating ? _cancelGenerate : _generate),
                  leading: _generating
                      ? const DpSpinner(size: 16, strokeWidth: 2)
                      : const Icon(Icons.auto_awesome_outlined, size: 18),
                  child: Text(
                    _generating ? '生成中…（点此停止）' : (ready ? '生成周复盘草稿' : '生成离线草稿'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            title: Text(
              '证据（上周）',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      enabled: !_generating && !_saving,
                      onTap: () => setState(() {
                        _sendIncludeTaskDescription =
                            !_sendIncludeTaskDescription;
                        _resetResult();
                      }),
                    ),
                    AiSendFieldChip(
                      label: '任务到期',
                      selected: _sendIncludeTaskDueDate,
                      enabled: !_generating && !_saving,
                      onTap: () => setState(() {
                        _sendIncludeTaskDueDate = !_sendIncludeTaskDueDate;
                        _resetResult();
                      }),
                    ),
                    AiSendFieldChip(
                      label: '标签',
                      selected: _sendIncludeTags,
                      enabled: !_generating && !_saving,
                      onTap: () => setState(() {
                        _sendIncludeTags = !_sendIncludeTags;
                        _resetResult();
                      }),
                    ),
                    AiSendFieldChip(
                      label: '笔记摘要',
                      selected: _sendIncludeNoteSnippet,
                      enabled: !_generating && !_saving,
                      onTap: () => setState(() {
                        _sendIncludeNoteSnippet = !_sendIncludeNoteSnippet;
                        _resetResult();
                      }),
                    ),
                    AiSendFieldChip(
                      label: '专注进展',
                      selected: _sendIncludeSessionProgressNote,
                      enabled: !_generating && !_saving,
                      onTap: () => setState(() {
                        _sendIncludeSessionProgressNote =
                            !_sendIncludeSessionProgressNote;
                        _resetResult();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: DpSpacing.md),
                _buildFilterRow(),
                if (availableTags.isNotEmpty) ...[
                  const SizedBox(height: DpSpacing.sm),
                  Wrap(
                    spacing: DpSpacing.sm,
                    runSpacing: DpSpacing.sm,
                    children: [
                      (_tagFilter == null)
                          ? ShadButton.secondary(
                              size: ShadButtonSize.sm,
                              onPressed: _generating || _saving
                                  ? null
                                  : () => setState(() => _tagFilter = null),
                              child: const Text('全部标签'),
                            )
                          : ShadButton.outline(
                              size: ShadButtonSize.sm,
                              onPressed: _generating || _saving
                                  ? null
                                  : () => setState(() => _tagFilter = null),
                              child: const Text('全部标签'),
                            ),
                      for (final tag in availableTags)
                        (_tagFilter == tag)
                            ? ShadButton.secondary(
                                size: ShadButtonSize.sm,
                                onPressed: _generating || _saving
                                    ? null
                                    : () => setState(() => _tagFilter = null),
                                child: Text(tag),
                              )
                            : ShadButton.outline(
                                size: ShadButtonSize.sm,
                                onPressed: _generating || _saving
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
                    title: const Text('加载失败'),
                    description: Text(
                      '${tasksAsync.error ?? notesAsync.error ?? sessionsAsync.error}',
                    ),
                  )
                else if (evidenceAll.isEmpty)
                  Text(
                    '上周没有可用证据。可以先补充笔记或完成一次专注。',
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
                        onPressed: _generating || _saving
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
                        onPressed: _generating || _saving
                            ? null
                            : () => setState(() => _selectedKeys.clear()),
                        child: const Text('清空'),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: '预览本次发送',
                        child: ShadIconButton.ghost(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          onPressed:
                              (_generating || _saving || _selectedKeys.isEmpty)
                              ? null
                              : () => _openSendPreview(
                                  context,
                                  config: config,
                                  range: range,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: DpSpacing.md,
                              vertical: DpSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ShadCheckbox(
                                    value: _selectedKeys.contains(
                                      evidence[i].key,
                                    ),
                                    enabled: !_generating && !_saving,
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
          if (_answer != null) _buildDraftCard(context),
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
                ],
              ),
            ),
            const SizedBox(width: DpSpacing.md),
            ShadButton.secondary(
              size: ShadButtonSize.sm,
              onPressed: () => context.push('/settings/ai'),
              child: const Text('去设置'),
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
                    ],
                  ),
                ),
                const SizedBox(width: DpSpacing.md),
                ShadButton.secondary(
                  size: ShadButtonSize.sm,
                  onPressed: () => context.push('/settings/ai'),
                  child: const Text('设置'),
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
                  ],
                ),
              ),
              const SizedBox(width: DpSpacing.md),
              ShadButton.secondary(
                size: ShadButtonSize.sm,
                onPressed: () => context.push('/settings/ai'),
                child: const Text('设置'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterRow() {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final disabled = _generating || _saving;

    Widget typeButton(String label, AiEvidenceType? value) {
      final selected = _typeFilter == value;
      final onPressed = disabled
          ? null
          : () => setState(() => _typeFilter = value);
      return selected
          ? ShadButton.secondary(
              size: ShadButtonSize.sm,
              onPressed: onPressed,
              child: Text(label),
            )
          : ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: onPressed,
              child: Text(label),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadInput(
          enabled: !disabled,
          placeholder: Text(
            '关键词',
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          leading: const Icon(Icons.search, size: 18),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: DpSpacing.sm),
        Wrap(
          spacing: DpSpacing.sm,
          runSpacing: DpSpacing.sm,
          children: [
            typeButton('全部', null),
            typeButton('笔记', AiEvidenceType.note),
            typeButton('任务', AiEvidenceType.task),
            typeButton('专注', AiEvidenceType.pomodoro),
          ],
        ),
      ],
    );
  }

  void _cancelGenerate() {
    _cancelToken?.cancel('user');
  }

  void _resetResult() {
    _answer = null;
    _draftController.text = '';
  }

  Future<void> _openSendPreview(
    BuildContext context, {
    required domain.AiProviderConfig? config,
    required _WeekRange range,
    required List<AiEvidenceItem> evidenceAll,
  }) async {
    final selected = evidenceAll
        .where((e) => _selectedKeys.contains(e.key))
        .toList(growable: false);
    if (selected.isEmpty) {
      _showSnack('请至少选择 1 条证据');
      return;
    }

    final focus = _focusController.text.trim();
    final rangeText =
        '${_formatDateYmd(range.startInclusive)}～${_formatDateYmd(range.endExclusive.subtract(const Duration(days: 1)))}';
    final question = _buildQuestion(rangeText: rangeText, focus: focus);
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
      question,
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
          AiSendPreviewSection(title: '问题', body: question),
          AiSendPreviewSection(title: '证据', body: blocks.join('\n\n')),
        ],
      ),
    );
  }

  String _buildQuestion({required String rangeText, required String focus}) {
    return [
      '请基于证据，生成上周周复盘草稿（$rangeText）。',
      '要求：文案克制、商务稳重；只使用证据内容，禁止编造。',
      '结构：',
      '1) 一句话总结',
      '2) 关键产出（3–5 条）',
      '3) 风险/阻塞（1–3 条）',
      '4) 下周计划（3–5 条，动词开头）',
      if (focus.isNotEmpty) '用户关注点：$focus',
    ].join('\n');
  }

  List<String> _buildEvidenceBlocks(List<AiEvidenceItem> selected) {
    return [
      for (var i = 0; i < selected.length; i++)
        '[${i + 1}] ${selected[i].type.name.toUpperCase()} ${selected[i].title}\n${selected[i].snippet}'
            .trimRight(),
    ];
  }

  Future<void> _generate() async {
    final range = _lastWeekRange(DateTime.now());
    final tasks = await ref.read(tasksStreamProvider.future);
    final notes = await ref.read(notesStreamProvider.future);
    final sessions = await ref.read(
      pomodoroSessionsBetweenProvider(
        TimeRangeKey(
          startInclusive: range.startInclusive,
          endExclusive: range.endExclusive,
        ),
      ).future,
    );

    final evidenceAll = _buildEvidence(
      tasks: tasks,
      notes: notes,
      sessions: sessions,
      startInclusive: range.startInclusive,
      endExclusive: range.endExclusive,
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
      _generating = true;
      _cancelToken = null;
      _answer = null;
      _lastSelectedEvidence = selected;
      _draftController.text = '';
    });

    try {
      final focus = _focusController.text.trim();
      final rangeText =
          '${_formatDateYmd(range.startInclusive)}～${_formatDateYmd(range.endExclusive.subtract(const Duration(days: 1)))}';

      if (!ready) {
        final draft = _offlineWeeklyReviewDraft(
          rangeText: rangeText,
          selected: selected,
          focus: focus.isEmpty ? null : focus,
        );
        setState(() {
          _answer = ai.AiEvidenceAnswer(
            answer: draft,
            citations: const <int>[],
            insufficientEvidence: true,
          );
          _draftController.text = draft;
        });
        return;
      }

      cancelToken = ai.AiCancelToken();
      _cancelToken = cancelToken;
      final question = _buildQuestion(rangeText: rangeText, focus: focus);
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
        _draftController.text = result.answer;
      });
    } on ai.AiClientCancelledException {
      _showSnack('已取消');
    } catch (e) {
      _showSnack('生成失败：$e');
    } finally {
      if (cancelToken != null && identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
      if (mounted) setState(() => _generating = false);
    }
  }

  String _offlineWeeklyReviewDraft({
    required String rangeText,
    required List<AiEvidenceItem> selected,
    required String? focus,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# 周复盘（离线草稿）');
    buffer.writeln();
    buffer.writeln('- 范围：$rangeText');
    if (focus != null) buffer.writeln('- 关注点：$focus');
    buffer.writeln();
    buffer.writeln('## 一句话总结');
    buffer.writeln('- （待补）');
    buffer.writeln();
    buffer.writeln('## 关键产出');
    buffer.writeln('- （待补，3–5 条）');
    buffer.writeln();
    buffer.writeln('## 风险/阻塞');
    buffer.writeln('- （待补，1–3 条）');
    buffer.writeln();
    buffer.writeln('## 下周计划');
    buffer.writeln('- （动词开头，3–5 条）');
    buffer.writeln();
    buffer.writeln('## 证据（摘录）');
    for (final e in selected) {
      buffer.writeln('- ${e.typeLabel} · ${e.title}');
    }
    return buffer.toString().trimRight();
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

  Widget _buildDraftCard(BuildContext context) {
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
        answer.insufficientEvidence ? '草稿（证据不足）' : '草稿（可编辑）',
        style: shadTheme.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.foreground,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            controller: _draftController,
            enabled: !_saving,
            minLines: 8,
            maxLines: 20,
            placeholder: Text(
              '可在此编辑后保存为笔记（只追加不覆盖）。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          if (!answer.insufficientEvidence) ...[
            Text(
              '引用',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: DpSpacing.sm),
            if (cited.length < 2)
              ShadAlert.destructive(
                icon: const Icon(Icons.info_outline),
                title: const Text('引用不足'),
                description: const Text('应为 2–5 条。建议补充证据后重试。'),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: DpSpacing.md,
                            vertical: DpSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              ShadBadge.secondary(
                                child: Text('${cited[i].key}'),
                              ),
                              const SizedBox(width: DpSpacing.sm),
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
                                      const SizedBox(height: DpSpacing.xs),
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
          const SizedBox(height: DpSpacing.md),
          ShadButton(
            onPressed: _saving ? null : _saveToNote,
            child: Text(_saving ? '保存中…' : '保存为笔记（只追加不覆盖）'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToNote() async {
    final draft = _draftController.text.trimRight();
    if (draft.trim().isEmpty) {
      _showSnack('草稿为空，无法保存');
      return;
    }

    final range = _lastWeekRange(DateTime.now());
    final weekKey = _formatDateYmd(range.startInclusive);
    final weekTag = 'weekly-review:$weekKey';
    final title =
        '周复盘 ${_formatDateYmd(range.startInclusive)}～${_formatDateYmd(range.endExclusive.subtract(const Duration(days: 1)))}';

    setState(() => _saving = true);
    try {
      final repo = ref.read(noteRepositoryProvider);
      final notes = await repo.watchAllNotes().first;
      final existing = notes.where((n) => n.tags.contains(weekTag)).toList();

      final timestamp = DateTime.now();
      final insufficient = _answer?.insufficientEvidence == true;
      final header = insufficient
          ? '## AI 草稿（证据不足，${_formatDateTime(timestamp)}）'
          : '## AI 草稿（${_formatDateTime(timestamp)}）';
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

      final evidenceList = <String>[
        '证据（本次发送 ${selected.length} 条）：',
        for (var i = 0; i < selected.length; i++)
          '- [${i + 1}] ${selected[i].typeLabel} · ${selected[i].title}${routeToken(selected[i])}',
      ].join('\n');

      final citationsList = citations.isEmpty
          ? '引用：无（证据不足或模型未按要求返回）'
          : [
              '引用：',
              for (final c in citations)
                '- [$c] ${selected[c - 1].typeLabel} · ${selected[c - 1].title}${routeToken(selected[c - 1])}',
            ].join('\n');

      final section = [
        header,
        '',
        draft,
        '',
        citationsList,
        '',
        evidenceList,
      ].join('\n');

      if (existing.isEmpty) {
        final created = await ref.read(createNoteUseCaseProvider)(
          title: title,
          body: section,
          tags: ['weekly-review', weekTag],
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已保存为周复盘笔记'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () => unawaited(repo.deleteNote(created.id)),
            ),
          ),
        );
        return;
      }

      final note = existing.reduce(
        (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
      );
      final before = note;
      final separator = note.body.trim().isEmpty ? '' : '\n\n---\n\n';
      final updatedBody = '${note.body}$separator$section';

      final updated = await ref.read(updateNoteUseCaseProvider)(
        note: note,
        title: note.title.value,
        body: updatedBody,
        tags: note.tags.toSet().toList(),
        taskId: note.taskId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已追加到周复盘笔记'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => unawaited(repo.upsertNote(before)),
          ),
        ),
      );

      if (context.mounted) {
        context.push('/notes/${updated.id}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      items.add(
        AiEvidenceItem(
          key: 'note:${note.id}',
          type: AiEvidenceType.note,
          title: note.title.value,
          snippet: includeNoteSnippet ? _snippet(note.body) : '',
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

  bool _inRange(DateTime dt, DateTime startInclusive, DateTime endExclusive) {
    return !dt.isBefore(startInclusive) && dt.isBefore(endExclusive);
  }

  _WeekRange _lastWeekRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final startInclusive = thisWeekStart.subtract(const Duration(days: 7));
    final endExclusive = thisWeekStart;
    return _WeekRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    );
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

  String _formatDateYmd(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime dt) =>
      '${_formatDateYmd(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WeekRange {
  const _WeekRange({required this.startInclusive, required this.endExclusive});

  final DateTime startInclusive;
  final DateTime endExclusive;
}

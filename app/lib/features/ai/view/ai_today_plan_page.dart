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
import '../providers/ai_providers.dart';
import 'ai_send_field_chip.dart';
import 'ai_send_preview_sheet.dart';

class AiTodayPlanPage extends ConsumerStatefulWidget {
  const AiTodayPlanPage({super.key});

  @override
  ConsumerState<AiTodayPlanPage> createState() => _AiTodayPlanPageState();
}

class _AiTodayPlanPageState extends ConsumerState<AiTodayPlanPage> {
  final TextEditingController _focusController = TextEditingController();
  final TextEditingController _pomodorosController = TextEditingController();
  final TextEditingController _draftController = TextEditingController();

  String? _tagFilter;
  String _query = '';
  final Set<String> _selectedKeys = <String>{};

  bool _sendIncludeDescription = true;
  bool _sendIncludeDueDate = true;
  bool _sendIncludeTags = true;
  bool _sendIncludeEstimatedPomodoros = true;

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
    _pomodorosController.dispose();
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

    final config = configAsync.valueOrNull;
    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);
    final isLoading = tasksAsync.isLoading || notesAsync.isLoading;

    final now = DateTime.now();
    final dayKey = _formatDateYmd(now);
    final tasks = tasksAsync.valueOrNull ?? const <domain.Task>[];
    final openTasks = const domain.TaskListQuery().apply(tasks, now);

    final evidenceAll = _buildTaskEvidence(
      openTasks,
      includeDescription: _sendIncludeDescription,
      includeDueDate: _sendIncludeDueDate,
      includeTags: _sendIncludeTags,
      includeEstimatedPomodoros: _sendIncludeEstimatedPomodoros,
    );
    final availableTags = _availableTags(evidenceAll);
    final evidence = _applyFilters(evidenceAll);
    _pruneSelection(evidenceAll);
    _maybeAutoSelectTopEvidence(evidenceAll: evidenceAll, isLoading: isLoading);

    return AppPageScaffold(
      title: '今日计划（AI）',
      body: ListView(
        padding: DpInsets.page,
        children: [
          _buildConfigCard(context, configAsync),
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            child: Row(
              children: [
                Icon(Icons.today_outlined, color: colorScheme.mutedForeground),
                const SizedBox(width: DpSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '日期：今天',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: DpSpacing.xs),
                      Text(
                        dayKey,
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
              '约束（可选）',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShadInput(
                  controller: _pomodorosController,
                  enabled: !_generating && !_saving,
                  keyboardType: TextInputType.number,
                  placeholder: Text(
                    '今日可用番茄数（可选，例如：6）',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: const Icon(Icons.timer_outlined, size: 18),
                ),
                const SizedBox(height: DpSpacing.md),
                ShadInput(
                  controller: _focusController,
                  enabled: !_generating && !_saving,
                  minLines: 1,
                  maxLines: 3,
                  placeholder: Text(
                    '关注点（可选，例如：先交付，再优化；优先解决阻塞）',
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
                    _generating
                        ? '生成中…（点此停止）'
                        : (ready ? '生成今日计划草稿' : '生成离线草稿'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            title: Text(
              '任务（今天）',
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
                      label: '描述',
                      selected: _sendIncludeDescription,
                      enabled: !_generating && !_saving,
                      onTap: () => setState(
                        () =>
                            _sendIncludeDescription = !_sendIncludeDescription,
                      ),
                    ),
                    AiSendFieldChip(
                      label: '截止日期',
                      selected: _sendIncludeDueDate,
                      enabled: !_generating && !_saving,
                      onTap: () => setState(
                        () => _sendIncludeDueDate = !_sendIncludeDueDate,
                      ),
                    ),
                    AiSendFieldChip(
                      label: '标签',
                      selected: _sendIncludeTags,
                      enabled: !_generating && !_saving,
                      onTap: () =>
                          setState(() => _sendIncludeTags = !_sendIncludeTags),
                    ),
                    AiSendFieldChip(
                      label: '预计番茄',
                      selected: _sendIncludeEstimatedPomodoros,
                      enabled: !_generating && !_saving,
                      onTap: () => setState(
                        () => _sendIncludeEstimatedPomodoros =
                            !_sendIncludeEstimatedPomodoros,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DpSpacing.md),
                if (isLoading)
                  const ShadProgress(minHeight: 8)
                else if (tasksAsync.hasError)
                  ShadAlert.destructive(
                    icon: const Icon(Icons.error_outline),
                    title: const Text('任务加载失败'),
                    description: Text('${tasksAsync.error}'),
                  )
                else if (openTasks.isEmpty)
                  Text(
                    '暂无未完成任务。可先新增任务，或用 AI 拆任务。',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  )
                else ...[
                  ShadInput(
                    enabled: !_generating && !_saving,
                    placeholder: Text(
                      '筛选（标题/摘要）',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    leading: const Icon(Icons.search, size: 18),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  if (availableTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                  const SizedBox(height: 12),
                  if (evidence.isEmpty)
                    Text(
                      '没有匹配的任务，请调整筛选条件。',
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
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed:
                                (_generating ||
                                    _saving ||
                                    _selectedKeys.isEmpty)
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
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
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
                                        evidence[i].title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      sublabel: Text(
                                        evidence[i].snippet,
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

  void _cancelGenerate() {
    _cancelToken?.cancel('user');
  }

  Future<void> _openSendPreview(
    BuildContext context, {
    required domain.AiProviderConfig? config,
    required List<AiEvidenceItem> evidenceAll,
  }) async {
    final selected = evidenceAll
        .where((e) => _selectedKeys.contains(e.key))
        .toList(growable: false);
    if (selected.isEmpty) {
      _showSnack('请至少选择 1 个任务');
      return;
    }

    final now = DateTime.now();
    final dayKey = _formatDateYmd(now);
    final focus = _focusController.text.trim();
    final pomodoros = int.tryParse(_pomodorosController.text.trim());
    final pomodorosText =
        (pomodoros == null || pomodoros <= 0 || pomodoros > 24)
        ? null
        : '今日可用番茄数：$pomodoros';

    final constraintsText = [
      '日期：$dayKey',
      pomodorosText ?? '今日可用番茄数：（未填写）',
      '关注点：${focus.isEmpty ? '（未填写）' : focus}',
    ].join('\n');

    final blocks = <String>[
      for (var i = 0; i < selected.length; i++)
        '[${i + 1}] TASK ${selected[i].title}\n${selected[i].snippet}',
    ];

    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);
    final destination = ready
        ? '将发送到：${config.model} · ${_shortBaseUrl(config.baseUrl)}'
        : '离线草稿：不会联网发送';

    final previewText = [
      '# 发送预览',
      destination,
      '',
      '约束：',
      constraintsText,
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
          AiSendPreviewSection(title: '约束', body: constraintsText),
          AiSendPreviewSection(title: '证据', body: blocks.join('\n\n')),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    final tasks = await ref.read(tasksStreamProvider.future);
    final openTasks = const domain.TaskListQuery().apply(tasks, DateTime.now());
    final evidenceAll = _buildTaskEvidence(
      openTasks,
      includeDescription: _sendIncludeDescription,
      includeDueDate: _sendIncludeDueDate,
      includeTags: _sendIncludeTags,
      includeEstimatedPomodoros: _sendIncludeEstimatedPomodoros,
    );
    final selected = evidenceAll
        .where((e) => _selectedKeys.contains(e.key))
        .toList();

    if (selected.isEmpty) {
      _showSnack('请至少选择 1 个任务');
      return;
    }
    if (selected.length > 12) {
      _showSnack('任务过多：请控制在 12 条以内（当前 ${selected.length}）');
      return;
    }

    final config = await ref.read(aiConfigProvider.future);
    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);

    setState(() {
      _generating = true;
      _answer = null;
      _lastSelectedEvidence = selected;
      _draftController.text = '';
    });

    ai.AiCancelToken? cancelToken;
    try {
      final now = DateTime.now();
      final dayKey = _formatDateYmd(now);
      final focus = _focusController.text.trim();

      final pomodoros = int.tryParse(_pomodorosController.text.trim());
      final pomodorosText =
          (pomodoros == null || pomodoros <= 0 || pomodoros > 24)
          ? null
          : '今日可用番茄数：$pomodoros';

      if (!ready) {
        _cancelToken = null;
        final draft = _offlineTodayPlanDraft(
          dayKey: dayKey,
          selected: selected,
          focus: focus.isEmpty ? null : focus,
          pomodorosText: pomodorosText,
        );
        setState(() {
          _draftController.text = draft;
          _answer = ai.AiEvidenceAnswer(
            answer: draft,
            citations: const <int>[],
            insufficientEvidence: true,
          );
        });
        return;
      }

      cancelToken = ai.AiCancelToken();
      _cancelToken = cancelToken;
      final question = [
        '请基于证据，生成今日计划草稿（$dayKey）。',
        '要求：文案克制、商务稳重；只使用证据内容，禁止编造新的任务与新事实；缺少信息要用“待补：...”标记。',
        '结构：',
        '1) 今日目标（1–2 句）',
        '2) 今日计划（按优先级/截止日期排序；每项包含：任务标题 / 预计番茄数 / Next Action）',
        '3) 风险/阻塞（0–3 条）',
        '4) 今日收尾（1–2 条）',
        if (pomodorosText != null) pomodorosText,
        if (focus.isNotEmpty) '用户关注点：$focus',
      ].join('\n');

      final blocks = <String>[];
      for (var i = 0; i < selected.length; i++) {
        final e = selected[i];
        blocks.add('[${i + 1}] TASK ${e.title}\n${e.snippet}');
      }

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

  String _offlineTodayPlanDraft({
    required String dayKey,
    required List<AiEvidenceItem> selected,
    required String? focus,
    required String? pomodorosText,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# 今日计划（离线草稿）');
    buffer.writeln();
    buffer.writeln('- 日期：$dayKey');
    if (pomodorosText != null) buffer.writeln('- $pomodorosText');
    if (focus != null) buffer.writeln('- 关注点：$focus');
    buffer.writeln();
    buffer.writeln('## 今日目标');
    buffer.writeln('- （待补）');
    buffer.writeln();
    buffer.writeln('## 今日计划（候选）');
    for (var i = 0; i < selected.length; i++) {
      buffer.writeln(
        '${i + 1}. [ ] ${selected[i].title} — 预计番茄：？ — Next Action：？',
      );
    }
    buffer.writeln();
    buffer.writeln('## 风险/阻塞');
    buffer.writeln('- 待补：可能的阻塞是什么？');
    buffer.writeln();
    buffer.writeln('## 今日收尾');
    buffer.writeln('- 写一句话进展');
    buffer.writeln('- 更新明日“下一步”');
    buffer.writeln();
    buffer.writeln('## 证据（仅供参考）');
    for (final e in selected) {
      buffer.writeln('- ${e.title}');
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
              ShadAlert.destructive(
                icon: const Icon(Icons.info_outline),
                title: const Text('引用不足'),
                description: const Text('应为 2–5 条。建议补充任务信息后重试。'),
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
                              ShadBadge.secondary(
                                child: Text('${cited[i].key}'),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cited[i].value.title,
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

    final dayKey = _formatDateYmd(DateTime.now());
    final dayTag = 'today-plan:$dayKey';
    final title = '今日计划 $dayKey';

    setState(() => _saving = true);
    try {
      final repo = ref.read(noteRepositoryProvider);
      final notes = await repo.watchAllNotes().first;
      final existing = notes.where((n) => n.tags.contains(dayTag)).toList();

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
        '任务（本次发送 ${selected.length} 条）：',
        for (var i = 0; i < selected.length; i++)
          '- [${i + 1}] ${selected[i].title}${routeToken(selected[i])}',
      ].join('\n');

      final citationsList = citations.isEmpty
          ? '引用：无（证据不足或模型未按要求返回）'
          : [
              '引用：',
              for (final c in citations)
                '- [$c] ${selected[c - 1].title}${routeToken(selected[c - 1])}',
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
          tags: ['today-plan', dayTag],
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已保存为今日计划笔记'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () => unawaited(repo.deleteNote(created.id)),
            ),
          ),
        );

        if (context.mounted) {
          context.push('/notes/${created.id}');
        }
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
          content: const Text('已追加到今日计划笔记'),
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

  List<AiEvidenceItem> _buildTaskEvidence(
    List<domain.Task> openTasks, {
    required bool includeDescription,
    required bool includeDueDate,
    required bool includeTags,
    required bool includeEstimatedPomodoros,
  }) {
    final items = <AiEvidenceItem>[];
    for (final task in openTasks) {
      final status = switch (task.status) {
        domain.TaskStatus.todo => '待办',
        domain.TaskStatus.inProgress => '进行中',
        domain.TaskStatus.done => '已完成',
      };
      final due = task.dueAt == null
          ? null
          : '${task.dueAt!.month}/${task.dueAt!.day}';
      final est = task.estimatedPomodoros;
      final parts = <String>[
        status,
        if (task.priority != domain.TaskPriority.medium)
          _priorityLabel(task.priority),
        if (includeDueDate && due != null) '到期 $due',
        if (includeEstimatedPomodoros && est != null) '预计 $est 个番茄',
        if (includeTags && task.tags.isNotEmpty) task.tags.take(4).join(' · '),
        if (includeDescription && task.description?.trim().isNotEmpty == true)
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
    final tag = _tagFilter;

    return evidence
        .where((e) {
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

  String _sendHintText() {
    final fields = <String>['标题', '状态', '优先级'];
    if (_sendIncludeDescription) fields.add('描述');
    if (_sendIncludeDueDate) fields.add('截止日期');
    if (_sendIncludeTags) fields.add('标签');
    if (_sendIncludeEstimatedPomodoros) fields.add('预计番茄');
    return '将发送：你勾选的任务${fields.join('/')}（不自动附带笔记与历史问答）。';
  }

  String _priorityLabel(domain.TaskPriority priority) => switch (priority) {
    domain.TaskPriority.high => '高优先级',
    domain.TaskPriority.medium => '中优先级',
    domain.TaskPriority.low => '低优先级',
  };

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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

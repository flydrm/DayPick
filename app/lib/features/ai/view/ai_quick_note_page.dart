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
import '../../notes/view/select_task_for_note_sheet.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/ai_providers.dart';
import 'ai_send_preview_sheet.dart';

class AiQuickNotePage extends ConsumerStatefulWidget {
  const AiQuickNotePage({super.key});

  @override
  ConsumerState<AiQuickNotePage> createState() => _AiQuickNotePageState();
}

class _AiQuickNotePageState extends ConsumerState<AiQuickNotePage> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  String? _taskId;
  ai.AiCancelToken? _cancelToken;
  bool _generating = false;
  bool _saving = false;
  bool _hasDraft = false;

  @override
  void dispose() {
    _cancelToken?.cancel('dispose');
    _inputController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(aiConfigProvider);
    final config = configAsync.valueOrNull;
    final configured = configAsync.maybeWhen(
      data: (config) =>
          config != null && (config.apiKey?.trim().isNotEmpty ?? false),
      orElse: () => false,
    );
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final taskId = _taskId;
    final taskAsync = taskId == null
        ? null
        : ref.watch(taskByIdProvider(taskId));

    return AppPageScaffold(
      title: 'AI 速记',
      body: ListView(
        padding: DpInsets.page,
        children: [
          if (!configured)
            ShadCard(
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
                          '需要先配置 AI',
                          style: shadTheme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: DpSpacing.xs),
                        Text(
                          '请先在设置中填写 baseUrl / model / apiKey',
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
          const SizedBox(height: DpSpacing.md),
          ShadCard(
            padding: DpInsets.card,
            title: Text(
              '输入',
              style: shadTheme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '将发送：你在此处输入的文本（不会自动附带你的任务/笔记）。',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: DpSpacing.sm),
                ShadInput(
                  controller: _inputController,
                  enabled: !_generating && !_saving,
                  minLines: 5,
                  maxLines: 12,
                  placeholder: Text(
                    '例如：\n- 和张三对齐了接口字段\n- 需要补充错误码定义\n- 明天安排联调\n',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: const Icon(Icons.notes_outlined, size: 18),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ShadButton(
                        onPressed: _saving
                            ? null
                            : (_generating ? _cancelGenerate : _generate),
                        leading: _generating
                            ? const DpSpinner(size: 16, strokeWidth: 2)
                            : const Icon(Icons.auto_awesome_outlined, size: 18),
                        child: Text(
                          _generating
                              ? '生成中…（点此停止）'
                              : (configured ? '生成笔记草稿' : '生成离线草稿'),
                        ),
                      ),
                    ),
                    const SizedBox(width: DpSpacing.sm),
                    Tooltip(
                      message: '预览本次发送',
                      child: ShadIconButton.ghost(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        onPressed: (_generating || _saving)
                            ? null
                            : () => _openSendPreview(context, config: config),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DpSpacing.md),
          if (_hasDraft)
            ShadCard(
              padding: DpInsets.card,
              title: Text(
                '草稿（可编辑）',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadInput(
                    controller: _titleController,
                    enabled: !_saving,
                    placeholder: Text(
                      '标题（必填）',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    leading: const Icon(Icons.title_outlined, size: 18),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  ShadInput(
                    controller: _bodyController,
                    enabled: !_saving,
                    minLines: 8,
                    maxLines: 16,
                    placeholder: Text(
                      '正文',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    leading: const Icon(Icons.notes_outlined, size: 18),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  ShadCard(
                    padding: const EdgeInsets.all(DpSpacing.md),
                    title: Text(
                      '关联任务（可选）',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: taskId == null
                              ? Text(
                                  '未关联',
                                  style: shadTheme.textTheme.muted.copyWith(
                                    color: colorScheme.mutedForeground,
                                  ),
                                )
                              : taskAsync!.when(
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
                                  data: (task) => Text(
                                    task == null
                                        ? '任务不存在或已删除'
                                        : task.title.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: shadTheme.textTheme.small.copyWith(
                                      color: colorScheme.foreground,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                        Tooltip(
                          message: '选择任务',
                          child: ShadIconButton.ghost(
                            icon: const Icon(Icons.link_outlined, size: 18),
                            onPressed: _saving
                                ? null
                                : () => _pickTask(context),
                          ),
                        ),
                        Tooltip(
                          message: '清除关联',
                          child: ShadIconButton.ghost(
                            icon: const Icon(Icons.link_off_outlined, size: 18),
                            onPressed: _saving || taskId == null
                                ? null
                                : () => setState(() => _taskId = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  ShadInput(
                    controller: _tagsController,
                    enabled: !_saving,
                    placeholder: Text(
                      '标签（逗号分隔，例如：对齐, 联调, 周报）',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    leading: const Icon(Icons.tag_outlined, size: 18),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: ShadButton.outline(
                          onPressed: _saving ? null : _clearDraft,
                          child: const Text('清空草稿'),
                        ),
                      ),
                      const SizedBox(width: DpSpacing.sm),
                      Expanded(
                        child: ShadButton(
                          onPressed: _saving ? null : _saveAsNote,
                          child: Text(_saving ? '保存中…' : '保存为笔记（可撤销）'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _cancelGenerate() {
    _cancelToken?.cancel('user');
  }

  Future<void> _openSendPreview(
    BuildContext context, {
    required domain.AiProviderConfig? config,
  }) async {
    final input = _inputController.text.trimRight();
    final inputText = input.trim().isEmpty ? '（未填写）' : input;

    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);
    final destination = ready
        ? '将发送到：${config.model} · ${_shortBaseUrl(config.baseUrl)}'
        : '离线草稿：不会联网发送';

    final previewText = [
      '# 发送预览',
      destination,
      '',
      '输入：',
      inputText,
    ].join('\n');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiSendPreviewSheet(
        destination: destination,
        previewText: previewText,
        sections: [AiSendPreviewSection(title: '输入', body: inputText)],
      ),
    );
  }

  Future<void> _generate() async {
    final cancelToken = ai.AiCancelToken();
    setState(() => _generating = true);
    try {
      _cancelToken = cancelToken;
      final config = await ref.read(aiConfigProvider.future);
      if (config == null || (config.apiKey?.trim().isEmpty ?? true)) {
        final draft = _offlineDraft(_inputController.text);
        _applyDraft(draft);
        _showSnack('已生成离线草稿（可编辑）');
        return;
      }

      final draft = await ref
          .read(openAiClientProvider)
          .draftNoteFromInput(
            config: config,
            input: _inputController.text,
            cancelToken: cancelToken,
          );

      _applyDraft(draft);
    } on ai.AiClientCancelledException {
      _showSnack('已取消');
    } catch (e) {
      _showSnack('生成失败：$e');
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
      if (mounted) setState(() => _generating = false);
    }
  }

  ai.AiNoteDraft _offlineDraft(String input) {
    final trimmed = input.trimRight();
    final firstLine = trimmed.trim().isEmpty
        ? ''
        : trimmed.trim().split('\n').first.trim();
    final title = firstLine.isEmpty
        ? '快速笔记'
        : (firstLine.length <= 28
              ? firstLine
              : '${firstLine.substring(0, 28)}…');
    final body = trimmed.isEmpty ? '（空）' : trimmed;
    return ai.AiNoteDraft(title: title, body: body, tags: const []);
  }

  void _applyDraft(ai.AiNoteDraft draft) {
    setState(() {
      _hasDraft = true;
      _titleController.text = draft.title;
      _bodyController.text = draft.body;
      _tagsController.text = draft.tags.join(',');
    });
  }

  void _clearDraft() {
    setState(() {
      _hasDraft = false;
      _titleController.text = '';
      _bodyController.text = '';
      _tagsController.text = '';
      _taskId = null;
    });
  }

  Future<void> _saveAsNote() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('标题不能为空');
      return;
    }

    setState(() => _saving = true);
    try {
      final create = ref.read(createNoteUseCaseProvider);
      final note = await create(
        title: title,
        body: _bodyController.text,
        tags: _parseTags(_tagsController.text),
        taskId: _taskId,
      );

      _clearDraft();
      _inputController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已保存为笔记'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              ref.read(noteRepositoryProvider).deleteNote(note.id);
            },
          ),
        ),
      );
    } on domain.NoteTitleEmptyException {
      _showSnack('标题不能为空');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _pickTask(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const SelectTaskForNoteSheet(),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _taskId = picked);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _shortBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.length <= 32) return trimmed;
    return '${trimmed.substring(0, 32)}…';
  }
}

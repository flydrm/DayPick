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
import '../../ai/providers/ai_providers.dart';
import '../../ai/view/ai_send_preview_sheet.dart';
import '../providers/note_providers.dart';

class NoteAiRewriteSheet extends ConsumerStatefulWidget {
  const NoteAiRewriteSheet({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteAiRewriteSheet> createState() => _NoteAiRewriteSheetState();
}

class _NoteAiRewriteSheetState extends ConsumerState<NoteAiRewriteSheet> {
  final TextEditingController _draftController = TextEditingController();
  ai.AiCancelToken? _cancelToken;
  bool _generating = false;
  bool _applying = false;

  @override
  void dispose() {
    _cancelToken?.cancel('dispose');
    _draftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(aiConfigProvider);
    final noteAsync = ref.watch(noteByIdProvider(widget.noteId));

    return noteAsync.when(
      loading: () => const AppPageScaffold(
        title: '改写同步版',
        body: Center(child: DpSpinner()),
      ),
      error: (error, stack) => AppPageScaffold(
        title: '改写同步版',
        body: Center(child: Text('加载失败：$error')),
      ),
      data: (note) {
        if (note == null) {
          return const AppPageScaffold(
            title: '改写同步版',
            body: Center(child: Text('笔记不存在或已删除')),
          );
        }

        final config = configAsync.valueOrNull;
        final ready =
            config != null && (config.apiKey?.trim().isNotEmpty ?? false);
        final shadTheme = ShadTheme.of(context);
        final colorScheme = shadTheme.colorScheme;

        return AppPageScaffold(
          title: '改写同步版',
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildConfigCard(context, configAsync),
              const SizedBox(height: 12),
              ShadCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '发送范围',
                            style: shadTheme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            note.body.trim().isEmpty ? '标题（正文为空）' : '标题 + 正文',
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ShadButton(
                      onPressed: _applying
                          ? null
                          : (_generating
                                ? _cancelGenerate
                                : () => _generate(note.id)),
                      leading: _generating
                          ? const DpSpinner(size: 16, strokeWidth: 2)
                          : const Icon(Icons.auto_awesome_outlined, size: 18),
                      child: Text(
                        _generating
                            ? '生成中…（点此停止）'
                            : (ready ? '生成对外同步版草稿' : '生成离线草稿'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '预览本次发送',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      onPressed: (_generating || _applying)
                          ? null
                          : () => _openSendPreview(
                              context,
                              config: config,
                              note: note,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ShadCard(
                padding: const EdgeInsets.all(16),
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
                      controller: _draftController,
                      enabled: !_applying,
                      minLines: 8,
                      maxLines: 18,
                      placeholder: Text(
                        '先生成，再按需修改后采用到笔记',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      leading: const Icon(Icons.edit_note_outlined, size: 18),
                    ),
                    const SizedBox(height: 12),
                    ShadButton(
                      onPressed: _applying ? null : () => _applyToNote(note.id),
                      leading: _applying
                          ? const DpSpinner(size: 16, strokeWidth: 2)
                          : const Icon(Icons.check_outlined, size: 18),
                      child: Text(_applying ? '采用中…' : '采用到当前笔记（可撤销）'),
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

  void _cancelGenerate() {
    _cancelToken?.cancel('user');
  }

  Future<void> _openSendPreview(
    BuildContext context, {
    required domain.AiProviderConfig? config,
    required domain.Note note,
  }) async {
    final body = note.body.trimRight();
    final content = [
      '标题：${note.title.value}',
      if (body.trim().isNotEmpty) '',
      if (body.trim().isNotEmpty) body,
    ].join('\n');

    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);
    final destination = ready
        ? '将发送到：${config.model} · ${_shortBaseUrl(config.baseUrl)}'
        : '离线草稿：不会联网发送';

    final previewText = [
      '# 发送预览',
      destination,
      '',
      '动作：改写同步版',
      '',
      '发送内容：',
      content,
    ].join('\n');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AiSendPreviewSheet(
        destination: destination,
        previewText: previewText,
        sections: [AiSendPreviewSection(title: '发送内容', body: content)],
      ),
    );
  }

  String _offlineRewriteDraft(domain.Note note) {
    final body = note.body.trimRight();
    final snippetLines = body
        .replaceAll('\r\n', '\n')
        .split('\n')
        .take(18)
        .toList();
    final snippet = snippetLines.isEmpty ? '（正文为空）' : snippetLines.join('\n');

    return [
      '# 对外同步版（离线草稿）',
      '',
      '- 原标题：${note.title.value}',
      '',
      '## 一句话总结',
      '- （待补）',
      '',
      '## 进展',
      '- （待补，3–5 条）',
      '',
      '## 风险/阻塞',
      '- （待补，0–3 条）',
      '',
      '## 下一步',
      '- （动词开头，3–5 条）',
      '',
      '---',
      '',
      '## 原文摘录（前 18 行）',
      snippet,
    ].join('\n').trimRight();
  }

  String _shortBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.length <= 32) return trimmed;
    return '${trimmed.substring(0, 32)}…';
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
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.destructive),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 4),
                  Text(
                    '$error',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: colorScheme.mutedForeground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'AI 未配置：仍可离线生成草稿',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '离线草稿不请求网络；配置后可获得更好结果。',
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 12),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: colorScheme.primary),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
                    Text(
                      '${config.model} · ${_shortBaseUrl(config.baseUrl)}',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
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

  Future<void> _generate(String noteId) async {
    final note = await ref.read(noteByIdProvider(noteId).future);
    if (note == null) {
      _showSnack('笔记不存在或已删除');
      return;
    }

    final config = await ref.read(aiConfigProvider.future);
    final ready = config != null && (config.apiKey?.trim().isNotEmpty ?? false);

    if (note.body.trim().isEmpty) {
      _showSnack('笔记正文为空，无法改写');
      return;
    }

    if (!ready) {
      final draft = _offlineRewriteDraft(note);
      if (!mounted) return;
      setState(() => _draftController.text = draft);
      _showSnack('已生成离线草稿（可编辑）');
      return;
    }

    final cancelToken = ai.AiCancelToken();
    setState(() => _generating = true);
    try {
      _cancelToken = cancelToken;
      final onlineConfig = config;
      final rewritten = await ref
          .read(openAiClientProvider)
          .rewriteNoteForSharing(
            config: onlineConfig,
            title: note.title.value,
            body: note.body,
            cancelToken: cancelToken,
          );
      if (!mounted) return;
      setState(() => _draftController.text = rewritten);
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

  Future<void> _applyToNote(String noteId) async {
    final draft = _draftController.text.trimRight();
    if (draft.trim().isEmpty) {
      _showSnack('草稿为空，无法采用');
      return;
    }

    final note = await ref.read(noteByIdProvider(noteId).future);
    if (note == null) {
      _showSnack('笔记不存在或已删除');
      return;
    }

    final before = note;
    final timestamp = DateTime.now();
    final section = [
      '## AI 对外同步版（${_formatDateTime(timestamp)}）',
      '',
      draft,
    ].join('\n');
    final separator = note.body.trim().isEmpty ? '' : '\n\n---\n\n';
    final updatedBody = '${note.body}$separator$section';

    setState(() => _applying = true);
    try {
      final update = ref.read(updateNoteUseCaseProvider);
      await update(
        note: note,
        title: note.title.value,
        body: updatedBody,
        tags: note.tags.toSet().toList(),
        taskId: note.taskId,
      );

      if (!mounted) return;
      final repo = ref.read(noteRepositoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已写入对外同步版'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => unawaited(repo.upsertNote(before)),
          ),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

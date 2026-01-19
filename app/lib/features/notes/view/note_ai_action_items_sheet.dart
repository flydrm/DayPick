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

class NoteAiActionItemsSheet extends ConsumerStatefulWidget {
  const NoteAiActionItemsSheet({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteAiActionItemsSheet> createState() =>
      _NoteAiActionItemsSheetState();
}

class _NoteAiActionItemsSheetState
    extends ConsumerState<NoteAiActionItemsSheet> {
  List<TextEditingController> _taskControllers = const [];
  ai.AiCancelToken? _cancelToken;
  bool _generating = false;
  bool _importing = false;

  @override
  void dispose() {
    _cancelToken?.cancel('dispose');
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(aiConfigProvider);
    final noteAsync = ref.watch(noteByIdProvider(widget.noteId));

    return noteAsync.when(
      loading: () => const AppPageScaffold(
        title: '提取行动项',
        body: Center(child: DpSpinner()),
      ),
      error: (error, stack) => AppPageScaffold(
        title: '提取行动项',
        body: Center(child: Text('加载失败：$error')),
      ),
      data: (note) {
        if (note == null) {
          return const AppPageScaffold(
            title: '提取行动项',
            body: Center(child: Text('笔记不存在或已删除')),
          );
        }

        final config = configAsync.valueOrNull;
        final ready =
            config != null && (config.apiKey?.trim().isNotEmpty ?? false);
        final shadTheme = ShadTheme.of(context);
        final colorScheme = shadTheme.colorScheme;

        return AppPageScaffold(
          title: '提取行动项',
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
                      onPressed: _importing
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
                            : (ready ? '生成行动项清单' : '生成离线草稿'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: '预览本次发送',
                    child: ShadIconButton.ghost(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      onPressed: (_generating || _importing)
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
              if (_taskControllers.isNotEmpty)
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
                      for (var i = 0; i < _taskControllers.length; i++) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ShadInput(
                                controller: _taskControllers[i],
                                enabled: !_importing,
                                placeholder: Text(
                                  '行动项 ${i + 1}',
                                  style: shadTheme.textTheme.muted.copyWith(
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                                leading: const Icon(
                                  Icons.checklist_outlined,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: '移除',
                              child: ShadIconButton.ghost(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: _importing
                                    ? null
                                    : () => _removeTaskAt(i),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      ShadButton.outline(
                        onPressed: _importing ? null : _addEmptyTask,
                        leading: const Icon(Icons.add, size: 18),
                        child: const Text('添加一条'),
                      ),
                      const SizedBox(height: 12),
                      ShadButton(
                        onPressed: _importing ? null : _importDraft,
                        leading: _importing
                            ? const DpSpinner(size: 16, strokeWidth: 2)
                            : const Icon(Icons.upload_outlined, size: 18),
                        child: Text(_importing ? '导入中…' : '导入到任务（可撤销）'),
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
      _showSnack('笔记正文为空，无法提取行动项');
      return;
    }

    if (!ready) {
      final items = _offlineActionItems(note);
      _setDraft(items);
      _showSnack('已生成离线草稿（可编辑）');
      return;
    }

    final cancelToken = ai.AiCancelToken();
    setState(() => _generating = true);
    try {
      _cancelToken = cancelToken;
      final onlineConfig = config;
      final items = await ref
          .read(openAiClientProvider)
          .extractActionItemsFromNote(
            config: onlineConfig,
            title: note.title.value,
            body: note.body,
            cancelToken: cancelToken,
          );
      _setDraft(items);
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
      '动作：提取行动项',
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

  List<String> _offlineActionItems(domain.Note note) {
    final normalized = note.body.replaceAll('\r\n', '\n');
    final items = <String>[];

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final checklist = RegExp(r'^[-*]\s*\[[ xX]\]\s+(.+)$').firstMatch(line);
      if (checklist != null) {
        items.add(checklist.group(1)!.trim());
      } else {
        final todo = RegExp(r'^(TODO|待办)[:：]\s*(.+)$').firstMatch(line);
        if (todo != null) {
          items.add(todo.group(2)!.trim());
        } else if (line.toUpperCase().startsWith('TODO ')) {
          items.add(line.substring(5).trim());
        } else if (line.startsWith('- ') || line.startsWith('* ')) {
          items.add(line.replaceFirst(RegExp(r'^[-*]\s+'), '').trim());
        }
      }

      if (items.length >= 10) break;
    }

    if (items.isEmpty) {
      return const ['（离线草稿）请手动补充行动项…'];
    }

    return items.where((t) => t.trim().isNotEmpty).toSet().take(10).toList();
  }

  void _setDraft(List<String> tasks) {
    for (final c in _taskControllers) {
      c.dispose();
    }
    final next = tasks.map((t) => TextEditingController(text: t)).toList();
    setState(() => _taskControllers = next);
  }

  void _addEmptyTask() {
    setState(() {
      _taskControllers = [..._taskControllers, TextEditingController(text: '')];
    });
  }

  void _removeTaskAt(int index) {
    final removed = _taskControllers[index];
    setState(() {
      _taskControllers = [
        for (var i = 0; i < _taskControllers.length; i++)
          if (i != index) _taskControllers[i],
      ];
    });
    removed.dispose();
  }

  Future<void> _importDraft() async {
    setState(() => _importing = true);
    try {
      final create = ref.read(createTaskUseCaseProvider);
      final repo = ref.read(taskRepositoryProvider);

      final createdIds = <String>[];
      for (final controller in _taskControllers) {
        final title = controller.text.trim();
        if (title.isEmpty) continue;
        final task = await create(title: title);
        createdIds.add(task.id);
      }

      if (createdIds.isEmpty) {
        _showSnack('没有可导入的任务');
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导入 ${createdIds.length} 个任务'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              unawaited(_undoImport(repo, createdIds));
            },
          ),
        ),
      );

      _setDraft(const []);
      Navigator.of(context).pop();
    } on domain.TaskTitleEmptyException {
      _showSnack('任务标题不能为空');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _undoImport(
    domain.TaskRepository repo,
    List<String> taskIds,
  ) async {
    for (final id in taskIds) {
      await repo.deleteTask(id);
    }
  }

  String _shortBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.length <= 32) return trimmed;
    return '${trimmed.substring(0, 32)}…';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

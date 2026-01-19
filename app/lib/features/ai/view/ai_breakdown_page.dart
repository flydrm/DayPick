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
import '../providers/ai_providers.dart';
import 'ai_send_preview_sheet.dart';

class AiBreakdownPage extends ConsumerStatefulWidget {
  const AiBreakdownPage({super.key, this.initialInput});

  final String? initialInput;

  @override
  ConsumerState<AiBreakdownPage> createState() => _AiBreakdownPageState();
}

class _AiBreakdownPageState extends ConsumerState<AiBreakdownPage> {
  final TextEditingController _inputController = TextEditingController();
  List<TextEditingController> _taskControllers = const [];

  ai.AiCancelToken? _cancelToken;
  bool _generating = false;
  bool _importing = false;
  bool _addToTodayPlan = false;

  @override
  void dispose() {
    _cancelToken?.cancel('dispose');
    _inputController.dispose();
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialInput?.trim();
    if (initial != null && initial.isNotEmpty) {
      _inputController.text = initial;
    }
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

    return AppPageScaffold(
      title: '一句话拆任务',
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
                          'AI 未配置：仍可离线生成草稿',
                          style: shadTheme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: DpSpacing.xs),
                        Text(
                          '离线草稿不请求网络；配置后可获得更好结果。',
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
                ShadInput(
                  controller: _inputController,
                  enabled: !_generating && !_importing,
                  minLines: 3,
                  maxLines: 8,
                  placeholder: Text(
                    '例如：今天把新需求拆解并对齐接口，安排联调与回归',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: const Icon(Icons.notes_outlined, size: 18),
                ),
                const SizedBox(height: DpSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ShadButton(
                        onPressed: _importing
                            ? null
                            : (_generating ? _cancelGenerate : _generate),
                        leading: _generating
                            ? const DpSpinner(size: 16, strokeWidth: 2)
                            : const Icon(Icons.auto_awesome_outlined, size: 18),
                        child: Text(
                          _generating
                              ? '生成中…（点此停止）'
                              : (configured ? '生成草稿' : '生成离线草稿'),
                        ),
                      ),
                    ),
                    const SizedBox(width: DpSpacing.sm),
                    Tooltip(
                      message: '预览本次发送',
                      child: ShadIconButton.ghost(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        onPressed: (_generating || _importing)
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
          if (_taskControllers.isNotEmpty)
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
                  for (var i = 0; i < _taskControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: DpSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: ShadInput(
                              controller: _taskControllers[i],
                              enabled: !_importing,
                              placeholder: Text(
                                '任务 ${i + 1}',
                                style: shadTheme.textTheme.muted.copyWith(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: DpSpacing.sm),
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
                    ),
                  ShadButton.outline(
                    onPressed: _importing ? null : _addEmptyTask,
                    leading: const Icon(Icons.add, size: 18),
                    child: const Text('添加一条'),
                  ),
                  const SizedBox(height: DpSpacing.sm),
                  ShadCheckbox(
                    value: _addToTodayPlan,
                    enabled: !_importing,
                    onChanged: (v) => setState(() => _addToTodayPlan = v),
                    label: const Text('导入后加入今天计划'),
                    sublabel: const Text('将导入的任务追加到“今天”队列'),
                  ),
                  const SizedBox(height: DpSpacing.md),
                  ShadButton(
                    onPressed: _importing ? null : _importDraft,
                    child: Text(_importing ? '导入中…' : '导入到任务（可撤销）'),
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
    final input = _inputController.text.trim();
    final inputText = input.isEmpty ? '（未填写）' : input;

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
      final input = _inputController.text.trim();
      if (input.isEmpty) {
        _showSnack('先输入一句话再生成');
        return;
      }

      if (config == null || (config.apiKey?.trim().isEmpty ?? true)) {
        _setDraft(_offlineBreakdown(input));
        _showSnack('已生成离线草稿（可编辑）');
        return;
      }

      final items = await ref
          .read(openAiClientProvider)
          .breakdownToTasks(
            config: config,
            input: input,
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

  List<String> _offlineBreakdown(String input) {
    final normalized = input
        .replaceAll('\n', '。')
        .replaceAll('；', '。')
        .replaceAll(';', '。')
        .replaceAll('，', '。')
        .replaceAll(',', '。');
    final parts = normalized
        .split(RegExp(r'[。.!！？!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final items = <String>[];
    if (parts.length >= 2) {
      for (final p in parts.take(8)) {
        items.add(p);
      }
    } else {
      final safeInput = input.length > 32
          ? '${input.substring(0, 32)}…'
          : input;
      items.add('澄清目标：$safeInput');
      items.add('列出验收标准');
      items.add('拆分执行步骤');
      items.add('联调/回归与复盘');
    }
    return items;
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
        final task = await create(
          title: title,
          triageStatus: _addToTodayPlan
              ? domain.TriageStatus.plannedToday
              : domain.TriageStatus.scheduledLater,
        );
        createdIds.add(task.id);
      }

      if (createdIds.isEmpty) {
        _showSnack('没有可导入的任务');
        return;
      }

      if (_addToTodayPlan) {
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        final planRepo = ref.read(todayPlanRepositoryProvider);
        for (final id in createdIds) {
          await planRepo.addTask(day: day, taskId: id);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _addToTodayPlan
                ? '已导入 ${createdIds.length} 个任务，并加入今天计划'
                : '已导入 ${createdIds.length} 个任务',
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              unawaited(_undoImport(repo, createdIds));
            },
          ),
        ),
      );

      _setDraft(const []);
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

  void _showSnack(String message) {
    if (!mounted) return;
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

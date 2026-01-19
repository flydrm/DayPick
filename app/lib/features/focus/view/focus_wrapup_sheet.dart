import 'package:ai/ai.dart' as ai;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ai/providers/ai_providers.dart';
import '../../../ui/kit/dp_spinner.dart';
import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

enum FocusWrapUpAction { save, later, discard }

class FocusWrapUpResult {
  const FocusWrapUpResult({
    required this.action,
    this.progressNote,
    this.nextStepTitle,
    this.addNextStepToToday = false,
  });

  final FocusWrapUpAction action;
  final String? progressNote;
  final String? nextStepTitle;
  final bool addNextStepToToday;
}

class FocusWrapUpSheet extends ConsumerStatefulWidget {
  const FocusWrapUpSheet({
    super.key,
    required this.taskTitle,
    this.initialProgressNote,
  });

  final String taskTitle;
  final String? initialProgressNote;

  @override
  ConsumerState<FocusWrapUpSheet> createState() => _FocusWrapUpSheetState();
}

class _FocusWrapUpSheetState extends ConsumerState<FocusWrapUpSheet> {
  final TextEditingController _progressController = TextEditingController();
  final TextEditingController _nextStepController = TextEditingController();
  ai.AiCancelToken? _cancelToken;
  bool _aiLoading = false;
  bool _hasProgress = false;
  bool _hasNextStep = false;
  bool _addNextStepToToday = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProgressNote?.trim();
    if (initial != null && initial.isNotEmpty) {
      _progressController.text = initial;
      _hasProgress = true;
    }
    _progressController.addListener(() {
      final next = _progressController.text.trim().isNotEmpty;
      if (next == _hasProgress) return;
      if (!mounted) return;
      setState(() => _hasProgress = next);
    });
    _nextStepController.addListener(() {
      final next = _nextStepController.text.trim().isNotEmpty;
      if (next == _hasNextStep) return;
      if (!mounted) return;
      setState(() => _hasNextStep = next);
    });
  }

  @override
  void dispose() {
    _cancelToken?.cancel('dispose');
    _progressController.dispose();
    _nextStepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final configAsync = ref.watch(aiConfigProvider);
    final ready = configAsync.maybeWhen(
      data: (c) => c != null && (c.apiKey?.trim().isNotEmpty ?? false),
      orElse: () => false,
    );
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DpSpacing.lg,
          DpSpacing.md,
          DpSpacing.lg,
          DpSpacing.lg + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '收尾 · ${widget.taskTitle}',
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
              padding: DpInsets.card,
              title: Text(
                '进展（可选）',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              child: ShadInput(
                controller: _progressController,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                placeholder: Text(
                  '一句话也可以；写清楚“做了什么/结果如何”。',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ShadCard(
              padding: DpInsets.card,
              title: Text(
                '下一步（可选）',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadInput(
                    controller: _nextStepController,
                    minLines: 1,
                    maxLines: 3,
                    placeholder: Text(
                      '写成一句话任务标题，例如：联调并修复边界case',
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShadCheckbox(
                    value: _addNextStepToToday,
                    enabled: _hasNextStep,
                    onChanged: (v) => setState(() => _addNextStepToToday = v),
                    label: const Text('把“下一步”加入今天计划'),
                    sublabel: const Text('保存后自动创建任务并加入 Today 队列'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ShadCard(
              padding: DpInsets.card,
              child: ShadButton.outline(
                onPressed: _aiLoading
                    ? _cancelAiPolish
                    : () => _assist(ready: ready),
                leading: _aiLoading
                    ? const DpSpinner(size: 16, strokeWidth: 2)
                    : const Icon(Icons.auto_awesome_outlined, size: 16),
                child: Text(
                  _aiLoading
                      ? (_hasProgress ? 'AI 优化中…（点此停止）' : 'AI 生成中…（点此停止）')
                      : (ready
                            ? (_hasProgress ? 'AI 优化进展' : 'AI 生成进展')
                            : '离线模板'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () => Navigator.of(context).pop(
                      FocusWrapUpResult(
                        action: FocusWrapUpAction.later,
                        progressNote: _progressController.text,
                        nextStepTitle: _nextStepTitleOrNull(),
                        addNextStepToToday: _hasNextStep && _addNextStepToToday,
                      ),
                    ),
                    child: const Text('稍后补'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShadButton(
                    onPressed: () => Navigator.of(context).pop(
                      FocusWrapUpResult(
                        action: FocusWrapUpAction.save,
                        progressNote: _progressController.text,
                        nextStepTitle: _nextStepTitleOrNull(),
                        addNextStepToToday: _hasNextStep && _addNextStepToToday,
                      ),
                    ),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ShadButton.ghost(
              onPressed: () => Navigator.of(
                context,
              ).pop(const FocusWrapUpResult(action: FocusWrapUpAction.discard)),
              child: const Text('不记录这次专注'),
            ),
          ],
        ),
      ),
    );
  }

  String? _nextStepTitleOrNull() {
    final v = _nextStepController.text.trim();
    return v.isEmpty ? null : v;
  }

  void _cancelAiPolish() {
    _cancelToken?.cancel('user');
  }

  Future<void> _assist({required bool ready}) async {
    if (!ready) {
      _applyOfflineTemplate();
      return;
    }

    final input = _progressController.text.trim();
    final config = await ref.read(aiConfigProvider.future);
    if (config == null || (config.apiKey?.trim().isEmpty ?? true)) {
      _showSnack('请先完成 AI 配置');
      return;
    }

    final cancelToken = ai.AiCancelToken();
    setState(() {
      _aiLoading = true;
      _cancelToken = cancelToken;
    });
    try {
      final client = ref.read(openAiClientProvider);
      final nextText = input.isEmpty
          ? await client.generateProgressNote(
              config: config,
              taskTitle: widget.taskTitle,
              cancelToken: cancelToken,
            )
          : await client.polishProgressNote(
              config: config,
              taskTitle: widget.taskTitle,
              input: input,
              cancelToken: cancelToken,
            );
      if (!mounted) return;
      setState(() {
        _progressController.text = nextText;
        _hasProgress = nextText.trim().isNotEmpty;
      });
    } on ai.AiClientCancelledException {
      _showSnack('已取消');
    } catch (e) {
      _showSnack('${input.isEmpty ? 'AI 生成' : 'AI 优化'}失败：$e');
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _applyOfflineTemplate() {
    final current = _progressController.text.trim();
    if (current.isNotEmpty) return;

    const template = '进展：\n- \n\n阻塞（可选）：\n- \n';
    setState(() {
      _progressController.text = template;
      _hasProgress = true;
    });
    _showSnack('已插入离线模板（可直接改）');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

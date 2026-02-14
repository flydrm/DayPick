import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/capture/capture_bar_draft.dart';
import '../../core/capture/capture_submit_result.dart';
import 'capture_submit_feedback.dart';
import '../sheets/quick_create_sheet.dart';
import '../tokens/dp_accessibility.dart';
import '../tokens/dp_spacing.dart';

class DpCaptureBar extends ConsumerStatefulWidget {
  const DpCaptureBar({super.key});

  @override
  ConsumerState<DpCaptureBar> createState() => _DpCaptureBarState();
}

class _DpCaptureBarState extends ConsumerState<DpCaptureBar> {
  late final TextEditingController _controller;
  final FocusNode _inputFocusNode = FocusNode();
  late final ProviderSubscription<CaptureBarDraft> _draftSubscription;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(captureBarDraftProvider).text,
    );
    _controller.addListener(_onTextChanged);

    _draftSubscription = ref.listenManual<CaptureBarDraft>(
      captureBarDraftProvider,
      (prev, next) {
        if (next.text == _controller.text) return;
        _controller.value = _controller.value.copyWith(
          text: next.text,
          selection: TextSelection.collapsed(offset: next.text.length),
          composing: TextRange.empty,
        );
      },
    );
  }

  @override
  void dispose() {
    _draftSubscription.close();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    ref.read(captureBarDraftProvider.notifier).setText(_controller.text);
  }

  Future<void> _openQuickCreate(BuildContext context) async {
    final draft = ref.read(captureBarDraftProvider);
    if (draft.text.trim().isEmpty) return;

    final container = ProviderScope.containerOf(context, listen: false);

    final initialType = switch (draft.type) {
      CaptureBarType.task => QuickCreateType.task,
      CaptureBarType.memo => QuickCreateType.memo,
      CaptureBarType.draft => QuickCreateType.draft,
    };

    final result = await showModalBottomSheet<CaptureSubmitResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: DpAccessibility.bottomSheetAnimationStyle(context),
      builder: (context) => QuickCreateSheet(
        initialType: initialType,
        initialTaskAddToToday: false,
        initialText: draft.text,
      ),
    );

    if (!mounted) return;
    if (result != null) {
      ref.read(captureBarDraftProvider.notifier).clear();
      showCaptureSubmitSuccessToast(container: container, result: result);
      return;
    }
    _inputFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final draft = ref.watch(captureBarDraftProvider);

    return Material(
      color: colorScheme.background,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.border, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(
          DpSpacing.lg,
          DpSpacing.sm,
          DpSpacing.lg,
          DpSpacing.sm,
        ),
        child: Row(
          children: [
            Semantics(
              label: '选择捕捉类型',
              hint: '可选任务、闪念或长文',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 104),
                child: ShadSelect<CaptureBarType>(
                  key: const ValueKey('capture_bar_type'),
                  initialValue: draft.type,
                  selectedOptionBuilder: (context, value) => Text(
                    _typeLabel(value),
                    style: shadTheme.textTheme.small.copyWith(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  options: const [
                    ShadOption(value: CaptureBarType.memo, child: Text('闪念')),
                    ShadOption(value: CaptureBarType.task, child: Text('任务')),
                    ShadOption(value: CaptureBarType.draft, child: Text('长文')),
                  ],
                  onChanged: (next) {
                    if (next == null) return;
                    ref.read(captureBarDraftProvider.notifier).setType(next);
                  },
                ),
              ),
            ),
            const SizedBox(width: DpSpacing.sm),
            Expanded(
              child: Semantics(
                label: '捕捉输入',
                hint: '输入后可快速创建',
                textField: true,
                child: ShadInput(
                  key: const ValueKey('capture_bar_input'),
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  placeholder: Text(
                    '快速捕捉…（切换 Tab 不丢）',
                    style: shadTheme.textTheme.muted.copyWith(
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  leading: Icon(_typeIcon(draft.type), size: 18),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _openQuickCreate(context),
                ),
              ),
            ),
            const SizedBox(width: DpSpacing.sm),
            Semantics(
              label: '清空草稿',
              button: true,
              enabled: draft.text.isNotEmpty,
              onTap: draft.text.isEmpty
                  ? null
                  : () => ref.read(captureBarDraftProvider.notifier).clear(),
              excludeSemantics: true,
              child: Tooltip(
                message: '清空草稿',
                child: ConstrainedBox(
                  constraints: DpAccessibility.minTouchTargetConstraints,
                  child: ShadIconButton.ghost(
                    key: const ValueKey('capture_bar_clear'),
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: draft.text.isEmpty
                        ? null
                        : () => ref
                              .read(captureBarDraftProvider.notifier)
                              .clear(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: DpSpacing.xs),
            Semantics(
              key: const ValueKey('capture_bar_open'),
              label: '创建',
              button: true,
              enabled: draft.text.trim().isNotEmpty,
              onTap: draft.text.trim().isEmpty
                  ? null
                  : () => _openQuickCreate(context),
              excludeSemantics: true,
              child: Tooltip(
                message: '继续创建',
                child: ConstrainedBox(
                  constraints: DpAccessibility.minTouchTargetConstraints,
                  child: ShadButton(
                    key: const ValueKey('capture_bar_create_button'),
                    leading: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: draft.text.trim().isEmpty
                        ? null
                        : () => _openQuickCreate(context),
                    child: const Text('创建'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(CaptureBarType type) {
    return switch (type) {
      CaptureBarType.task => '任务',
      CaptureBarType.memo => '闪念',
      CaptureBarType.draft => '长文',
    };
  }

  IconData _typeIcon(CaptureBarType type) {
    return switch (type) {
      CaptureBarType.task => Icons.add_task_outlined,
      CaptureBarType.memo => Icons.bolt_outlined,
      CaptureBarType.draft => Icons.description_outlined,
    };
  }
}

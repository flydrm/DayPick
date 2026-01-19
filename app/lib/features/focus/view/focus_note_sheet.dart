import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_spacing.dart';

class FocusNoteSheet extends StatefulWidget {
  const FocusNoteSheet({super.key, this.initialText});

  final String? initialText;

  @override
  State<FocusNoteSheet> createState() => _FocusNoteSheetState();
}

class _FocusNoteSheetState extends State<FocusNoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DpSpacing.lg,
          right: DpSpacing.lg,
          top: DpSpacing.lg,
          bottom: DpSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '外周记事',
                    style: shadTheme.textTheme.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.foreground,
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
            const SizedBox(height: 6),
            Text(
              '专注过程中，把打断/想法写下来，不离开主路径。',
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: DpSpacing.md),
            ShadCard(
              padding: const EdgeInsets.all(DpSpacing.md),
              child: ShadInput(
                controller: _controller,
                minLines: 6,
                maxLines: 10,
                placeholder: Text(
                  '例如：等会要回微信 / 想法：… / 中断原因：…',
                  style: shadTheme.textTheme.muted.copyWith(
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: DpSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: DpSpacing.sm),
                Expanded(
                  child: ShadButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

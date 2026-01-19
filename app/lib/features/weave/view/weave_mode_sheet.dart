import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class WeaveModeSheet extends StatelessWidget {
  const WeaveModeSheet({
    super.key,
    this.title = '编织到长文',
    this.description = '选择“引用”或“拷贝”。拷贝会把内容插入到长文正文的收集箱锚点。',
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: shadTheme.textTheme.h4.copyWith(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            ShadButton(
              onPressed: () => Navigator.of(
                context,
              ).pop<domain.WeaveMode>(domain.WeaveMode.reference),
              leading: const Icon(Icons.link_outlined, size: 18),
              child: const Text('引用（收集箱列表）'),
            ),
            const SizedBox(height: 10),
            ShadButton.secondary(
              onPressed: () => Navigator.of(
                context,
              ).pop<domain.WeaveMode>(domain.WeaveMode.copy),
              leading: const Icon(Icons.content_copy_outlined, size: 18),
              child: const Text('拷贝（插入到正文）'),
            ),
            const SizedBox(height: 12),
            ShadButton.ghost(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}

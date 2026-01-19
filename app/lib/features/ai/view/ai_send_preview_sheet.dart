import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_insets.dart';
import '../../../ui/tokens/dp_spacing.dart';

class AiSendPreviewSection {
  const AiSendPreviewSection({required this.title, required this.body});

  final String title;
  final String body;
}

class AiSendPreviewSheet extends StatelessWidget {
  const AiSendPreviewSheet({
    super.key,
    required this.destination,
    required this.sections,
    required this.previewText,
  });

  final String destination;
  final List<AiSendPreviewSection> sections;
  final String previewText;

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
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '发送预览',
                      style: shadTheme.textTheme.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  ShadButton.ghost(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
              const SizedBox(height: DpSpacing.sm),
              Text(
                destination,
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      ShadCard(
                        padding: DpInsets.card,
                        title: Text(
                          sections[i].title,
                          style: shadTheme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                        child: SelectableText(
                          sections[i].body,
                          style: shadTheme.textTheme.small.copyWith(
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                      if (i != sections.length - 1)
                        const SizedBox(height: DpSpacing.md),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: DpSpacing.md),
              ShadButton.outline(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: previewText));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制预览内容')));
                },
                leading: const Icon(Icons.copy_all_outlined, size: 18),
                child: const Text('复制'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

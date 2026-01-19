import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/dp_insets.dart';
import '../tokens/dp_spacing.dart';

class DpSectionCard extends StatelessWidget {
  const DpSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final content = child;

    return ShadCard(
      padding: padding ?? DpInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DpSpacing.xs),
            Text(
              subtitle!,
              style: shadTheme.textTheme.muted.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
          if (content != null) ...[
            const SizedBox(height: DpSpacing.md),
            content,
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/dp_insets.dart';
import '../tokens/dp_spacing.dart';

class DpEmptyState extends StatelessWidget {
  const DpEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return ShadCard(
      padding: DpInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Icon(icon, color: colorScheme.mutedForeground),
            const SizedBox(height: DpSpacing.sm),
          ],
          Text(
            title,
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: DpSpacing.xs),
          Text(
            description,
            style: shadTheme.textTheme.muted.copyWith(
              color: colorScheme.mutedForeground,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: DpSpacing.md),
            ShadButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

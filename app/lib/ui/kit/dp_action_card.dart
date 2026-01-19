import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/dp_insets.dart';
import '../tokens/dp_spacing.dart';

class DpActionCard extends StatelessWidget {
  const DpActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.cta,
    required this.onTap,
    this.leading,
    this.enabled = true,
  });

  final String title;
  final String description;
  final String cta;
  final VoidCallback onTap;
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return ShadCard(
      padding: DpInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(color: colorScheme.mutedForeground),
                  child: leading!,
                ),
                const SizedBox(width: DpSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: shadTheme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: DpSpacing.sm),
                    Text(
                      description,
                      style: shadTheme.textTheme.muted.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DpSpacing.md),
          ShadButton(onPressed: enabled ? onTap : null, child: Text(cta)),
        ],
      ),
    );
  }
}

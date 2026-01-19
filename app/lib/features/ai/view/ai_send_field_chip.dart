import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AiSendFieldChip extends StatelessWidget {
  const AiSendFieldChip({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return selected
        ? ShadButton.secondary(
            size: ShadButtonSize.sm,
            onPressed: enabled ? onTap : null,
            child: Text(label),
          )
        : ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: enabled ? onTap : null,
            child: Text(label),
          );
  }
}

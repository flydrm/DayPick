import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/dp_radius.dart';
import '../tokens/dp_spacing.dart';

enum DpActionToastVariant { success, error }

typedef DpActionToastUndoCallback = Future<void> Function();
typedef DpActionToastBridgeCallback = Future<void> Function(String entryId);

class DpActionToastUndoAction {
  const DpActionToastUndoAction({required this.label, required this.onPressed});

  final String label;
  final DpActionToastUndoCallback onPressed;
}

class DpActionToastBridgeAction {
  const DpActionToastBridgeAction({
    required this.label,
    required this.entryId,
    required this.onPressed,
  });

  final String label;
  final String entryId;
  final DpActionToastBridgeCallback onPressed;
}

class DpActionToast extends StatelessWidget {
  const DpActionToast({
    super.key,
    required this.message,
    this.variant = DpActionToastVariant.success,
    this.undo,
    this.bridge,
  });

  final String message;
  final DpActionToastVariant variant;
  final DpActionToastUndoAction? undo;
  final DpActionToastBridgeAction? bridge;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    final icon = switch (variant) {
      DpActionToastVariant.success => Icons.check_circle_outline,
      DpActionToastVariant.error => Icons.error_outline,
    };
    final iconColor = switch (variant) {
      DpActionToastVariant.success => colorScheme.primary,
      DpActionToastVariant.error => colorScheme.destructive,
    };
    final borderColor = switch (variant) {
      DpActionToastVariant.success => colorScheme.border,
      DpActionToastVariant.error => colorScheme.destructive,
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(DpRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DpSpacing.md,
            vertical: DpSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: DpSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: shadTheme.textTheme.small.copyWith(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: DpSpacing.sm),
              _ActionRow(undo: undo, bridge: bridge),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.undo, required this.bridge});

  final DpActionToastUndoAction? undo;
  final DpActionToastBridgeAction? bridge;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (undo != null)
        ShadButton.ghost(
          key: const ValueKey('dp_action_toast_undo'),
          size: ShadButtonSize.sm,
          onPressed: () => unawaited(undo!.onPressed()),
          child: Text(undo!.label),
        ),
      if (bridge != null)
        ShadButton.ghost(
          key: const ValueKey('dp_action_toast_bridge'),
          size: ShadButtonSize.sm,
          onPressed: () => unawaited(bridge!.onPressed(bridge!.entryId)),
          child: Text(bridge!.label),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: DpSpacing.xs,
      runSpacing: DpSpacing.xs,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum DpInlineNoticeVariant { info, destructive }

class DpInlineNotice extends StatelessWidget {
  const DpInlineNotice({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.variant = DpInlineNoticeVariant.info,
  });

  final String title;
  final String description;
  final Widget? icon;
  final DpInlineNoticeVariant variant;

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = icon ?? const Icon(Icons.info_outline);
    switch (variant) {
      case DpInlineNoticeVariant.info:
        return ShadAlert(
          icon: resolvedIcon,
          title: Text(title),
          description: Text(description),
        );
      case DpInlineNoticeVariant.destructive:
        return ShadAlert.destructive(
          icon: resolvedIcon,
          title: Text(title),
          description: Text(description),
        );
    }
  }
}

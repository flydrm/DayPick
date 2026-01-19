import 'package:domain/domain.dart' as domain;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/dp_radius.dart';
import '../../../ui/tokens/dp_spacing.dart';

class NoteListItem extends StatelessWidget {
  const NoteListItem({super.key, required this.note, required this.onTap});

  final domain.Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;
    final snippet = _firstLine(note.body);
    final subtitleParts = <String>[];
    if (snippet != null) subtitleParts.add(snippet);
    if (note.tags.isNotEmpty) subtitleParts.add(note.tags.take(3).join(' · '));
    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join('  ·  ');

    return Semantics(
      button: true,
      label: note.title.value,
      child: InkWell(
        borderRadius: BorderRadius.circular(DpRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DpSpacing.md,
            vertical: DpSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: shadTheme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: DpSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: shadTheme.textTheme.muted.copyWith(
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: DpSpacing.sm),
              Text(
                _formatDate(note.updatedAt),
                style: shadTheme.textTheme.muted.copyWith(
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _firstLine(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split('\n').first.trim();
  }

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}';
}

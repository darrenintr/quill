import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/date_formats.dart';
import '../../../data/database/app_database.dart';

/// A compact list-item representation of a [NoteRow]. Material 3
/// ListTile variant that surfaces a colored leading dot for the note's
/// accent color and shows the preview text underneath the title.
class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.note,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.onLongPress,
    super.key,
  });

  final NoteRow note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noteColor = Color(note.color);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 56,
                margin: const EdgeInsets.only(right: 14, top: 2),
                decoration: BoxDecoration(
                  color: noteColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title.isEmpty ? 'Untitled' : note.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (note.pinned)
                          Icon(Icons.push_pin_rounded,
                              size: 16,
                              color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.preview.isEmpty
                          ? 'No additional text'
                          : note.preview,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    DefaultTextStyle.merge(
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: colorScheme.outline,
                      ),
                      child: Row(
                        children: [
                          Text(formatRelativeTime(note.updatedAt)),
                          if (subtitle != null) ...[
                            const SizedBox(width: 8),
                            const Text('·'),
                            const SizedBox(width: 8),
                            Expanded(child: subtitle!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
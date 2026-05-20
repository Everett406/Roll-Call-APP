import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/status_tag.dart';

class PersonCard extends StatelessWidget {
  final Member member;
  final StatusTag? currentTag;
  final bool isChecked;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PersonCard({
    super.key,
    required this.member,
    this.currentTag,
    this.isChecked = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = currentTag != null
        ? Color(currentTag!.colorValue)
        : theme.colorScheme.surfaceContainerHighest;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isChecked ? 0 : 1,
      color: isChecked
          ? tagColor.withOpacity(0.15)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isChecked
            ? BorderSide(color: tagColor.withOpacity(0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: tagColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              // Name and student ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isChecked
                            ? tagColor
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (member.studentId != null &&
                        member.studentId!.isNotEmpty)
                      Text(
                        member.studentId!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              // Status badge
              if (currentTag != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    currentTag!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '未标记',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

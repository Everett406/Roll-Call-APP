import 'package:flutter/material.dart';
import '../models/status_tag.dart';

class StatusBottomSheet extends StatefulWidget {
  final List<StatusTag> tags;
  final Function(StatusTag tag, String? note) onStatusSelected;

  const StatusBottomSheet({
    super.key,
    required this.tags,
    required this.onStatusSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<StatusTag> tags,
    required Function(StatusTag tag, String? note) onStatusSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatusBottomSheet(
        tags: tags,
        onStatusSelected: onStatusSelected,
      ),
    );
  }

  @override
  State<StatusBottomSheet> createState() => _StatusBottomSheetState();
}

class _StatusBottomSheetState extends State<StatusBottomSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _selectStatus(StatusTag tag) {
    final note = _noteController.text.trim();
    widget.onStatusSelected(tag, note.isEmpty ? null : note);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '选择状态',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Status tag buttons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.tags.map((tag) {
                return _StatusButton(
                  tag: tag,
                  onTap: () => _selectStatus(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Note input
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: '添加备注（可选）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                prefixIcon: const Icon(Icons.note_add_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final StatusTag tag;
  final VoidCallback onTap;

  const _StatusButton({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.colorValue);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            tag.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

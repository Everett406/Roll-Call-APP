import 'package:flutter/material.dart';
import '../models/status_tag.dart';

class StatusBottomSheet extends StatefulWidget {
  final List<StatusTag> tags;
  final Function(StatusTag tag, String? note) onStatusSelected;
  final VoidCallback? onAddTagPressed;

  const StatusBottomSheet({
    super.key,
    required this.tags,
    required this.onStatusSelected,
    this.onAddTagPressed,
  });

  static Future<void> show(
    BuildContext context, {
    required List<StatusTag> tags,
    required Function(StatusTag tag, String? note) onStatusSelected,
    VoidCallback? onAddTagPressed,
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
        onAddTagPressed: onAddTagPressed,
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
            const SizedBox(height: 16),
            // Add new tag button
            if (widget.onAddTagPressed != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onAddTagPressed!();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加新标签'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
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

/// 添加新标签对话框
class AddTagDialog extends StatefulWidget {
  final Function(String name, int colorValue) onConfirm;
  final int? defaultColor;

  const AddTagDialog({
    super.key,
    required this.onConfirm,
    this.defaultColor,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(String name, int colorValue) onConfirm,
    int? defaultColor,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AddTagDialog(onConfirm: onConfirm, defaultColor: defaultColor),
    );
  }

  @override
  State<AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<AddTagDialog> {
  final _nameController = TextEditingController();
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.defaultColor ?? 0xFF4CAF50;
  }

  // 预设颜色列表
  final List<Map<String, dynamic>> _presetColors = [
    {'name': '绿色', 'value': 0xFF4CAF50},
    {'name': '红色', 'value': 0xFFF44336},
    {'name': '橙色', 'value': 0xFFFF9800},
    {'name': '蓝色', 'value': 0xFF2196F3},
    {'name': '紫色', 'value': 0xFF9C27B0},
    {'name': '粉色', 'value': 0xFFE91E63},
    {'name': '青色', 'value': 0xFF009688},
    {'name': '灰色', 'value': 0xFF9E9E9E},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标签名称')),
      );
      return;
    }
    widget.onConfirm(name, _selectedColor);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('添加新标签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签名称输入框
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '标签名称',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 20),
          // 颜色选择标题
          Text(
            '选择颜色',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // 颜色网格
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((color) {
              final isSelected = _selectedColor == color['value'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color['value'];
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(color['value']),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 3,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('添加'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../models/status_tag.dart';
import '../utils/expressive_theme.dart';

class StatusBottomSheet extends StatefulWidget {
  final List<StatusTag> tags;
  final Function(StatusTag tag, String? note) onStatusSelected;
  final VoidCallback? onAddTagPressed;
  final Function(StatusTag)? onEditTag;

  const StatusBottomSheet({
    super.key,
    required this.tags,
    required this.onStatusSelected,
    this.onAddTagPressed,
    this.onEditTag,
  });

  static Future<void> show(
    BuildContext context, {
    required List<StatusTag> tags,
    required Function(StatusTag tag, String? note) onStatusSelected,
    VoidCallback? onAddTagPressed,
    Function(StatusTag)? onEditTag,
  }) {
    return showExpressiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatusBottomSheet(
        tags: tags,
        onStatusSelected: onStatusSelected,
        onAddTagPressed: onAddTagPressed,
        onEditTag: onEditTag,
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
                  onEditTag: widget.onEditTag,
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
  final Function(StatusTag)? onEditTag;

  const _StatusButton({
    required this.tag,
    required this.onTap,
    this.onEditTag,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.colorValue);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        onLongPress: onEditTag != null
            ? () => _showEditTagDialog(context, tag, onEditTag!)
            : null,
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

  void _showEditTagDialog(
    BuildContext context,
    StatusTag tag,
    Function(StatusTag) onEditTag,
  ) {
    Navigator.pop(context); // 先关闭状态选择弹窗
    
    showExpressiveDialog(
      context: context,
      builder: (context) => _EditTagDialog(
        tag: tag,
        onConfirm: (name, colorValue) {
          final updated = StatusTag(
            id: tag.id,
            name: name,
            colorValue: colorValue,
            isBuiltIn: tag.isBuiltIn,
            sortOrder: tag.sortOrder,
          );
          onEditTag(updated);
        },
        onDelete: tag.isBuiltIn ? null : () => onEditTag(tag), // TODO: 实际删除逻辑
      ),
    );
  }
}

/// 编辑标签对话框（带 Hero 动画）
class _EditTagDialog extends StatefulWidget {
  final StatusTag tag;
  final Function(String name, int colorValue) onConfirm;
  final VoidCallback? onDelete;

  const _EditTagDialog({
    required this.tag,
    required this.onConfirm,
    this.onDelete,
  });

  @override
  State<_EditTagDialog> createState() => _EditTagDialogState();
}

class _EditTagDialogState extends State<_EditTagDialog> {
  late final TextEditingController _nameController;
  late int _selectedColor;
  bool _showCustomColor = false;

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
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag.name);
    _selectedColor = widget.tag.colorValue;
  }

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
    final color = Color(_selectedColor);

    return AlertDialog(
      title: Row(
        children: [
          Hero(
            tag: 'tag_${widget.tag.id}',
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(widget.tag.isBuiltIn ? '编辑标签' : '编辑自定义标签'),
        ],
      ),
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
          // 自定义颜色折叠区域
          InkWell(
            onTap: () {
              setState(() {
                _showCustomColor = !_showCustomColor;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '自定义颜色',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showCustomColor ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _presetColors.map((c) {
                    final isSelected = _selectedColor == c['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = c['value'];
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(c['value']),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            crossFadeState: _showCustomColor
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('保存'),
        ),
      ],
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
    return showExpressiveDialog(
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
  bool _showCustomColor = false;

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
          // 自定义颜色折叠区域
          InkWell(
            onTap: () {
              setState(() {
                _showCustomColor = !_showCustomColor;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '自定义颜色',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showCustomColor ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
            crossFadeState: _showCustomColor
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
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

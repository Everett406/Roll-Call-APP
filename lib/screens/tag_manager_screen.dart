import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';
import '../models/status_tag.dart';
import '../utils/expressive_theme.dart';

class TagManagerScreen extends ConsumerStatefulWidget {
  const TagManagerScreen({super.key});

  @override
  ConsumerState<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends ConsumerState<TagManagerScreen> {
  final _nameController = TextEditingController();
  int _selectedColorValue = 0xFF607D8B;

  final _presetColors = [
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF673AB7, // Deep Purple
    0xFF3F51B5, // Indigo
    0xFF2196F3, // Blue
    0xFF03A9F4, // Light Blue
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFCDDC39, // Lime
    0xFFFFEB3B, // Yellow
    0xFFFFC107, // Amber
    0xFFFF9800, // Orange
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final tags = state.tags;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'settingsIcon_tags',
              child: Material(
                type: MaterialType.transparency,
                child: Icon(Icons.label_outline, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '标签管理',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: tags.isEmpty
                ? Center(
                    child: Text(
                      '暂无标签',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(tag.colorValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(tag.name),
                        subtitle: tag.isBuiltIn
                            ? Text(
                                '内置标签',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                        trailing: tag.isBuiltIn
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    color: theme.colorScheme.primary,
                                    onPressed: () =>
                                        _editTag(context, state, tag),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: theme.colorScheme.error,
                                    onPressed: () =>
                                        _deleteTag(context, state, tag),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
          // Add new tag section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '添加自定义标签',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Color picker
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _presetColors.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final color = _presetColors[index];
                      final isSelected = color == _selectedColorValue;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColorValue = color;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 36 : 28,
                          height: isSelected ? 36 : 28,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: theme.colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Name input and add button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: '标签名称',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addTag(state),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => _addTag(state),
                      style: FilledButton.styleFrom(
                        backgroundColor: Color(_selectedColorValue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addTag(AppState state) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标签名称')),
      );
      return;
    }

    // Check duplicate name
    if (state.tags.any((t) => t.name == name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标签"$name"已存在')),
      );
      return;
    }

    final maxSortOrder = state.tags.isEmpty
        ? 0
        : state.tags.map((t) => t.sortOrder).reduce(max) + 1;

    state.addTag(StatusTag(
      name: name,
      colorValue: _selectedColorValue,
      isBuiltIn: false,
      sortOrder: maxSortOrder,
    ));

    _nameController.clear();
  }

  void _deleteTag(BuildContext context, AppState state, StatusTag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定要删除标签"${tag.name}"吗？已使用此标签的签到记录不会受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              state.deleteTag(tag.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _editTag(BuildContext context, AppState state, StatusTag tag) {
    final nameController = TextEditingController(text: tag.name);
    int selectedColorValue = tag.colorValue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '标签名称',
                  hintText: '例如：请假、迟到',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Text(
                '选择颜色',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetColors.map((color) {
                  final isSelected = selectedColorValue == color;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColorValue = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.onSurface.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: theme.colorScheme.onPrimary,
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
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入标签名称')),
                  );
                  return;
                }
                // Check duplicate name (excluding current tag)
                if (state.tags.any((t) => t.id != tag.id && t.name == name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('标签"$name"已存在')),
                  );
                  return;
                }
                final updatedTag = tag.copyWith(
                  name: name,
                  colorValue: selectedColorValue,
                );
                state.updateTag(updatedTag);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('标签 "$name" 已更新')),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

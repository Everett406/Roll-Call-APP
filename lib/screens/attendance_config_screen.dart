import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';

class AttendanceConfigScreen extends ConsumerStatefulWidget {
  const AttendanceConfigScreen({super.key});

  @override
  ConsumerState<AttendanceConfigScreen> createState() =>
      _AttendanceConfigScreenState();
}

class _AttendanceConfigScreenState
    extends ConsumerState<AttendanceConfigScreen> {
  final Set<String> _selectedTagIds = {};
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateProvider);
    _selectedTagIds.addAll(state.attendanceTagIds);
  }

  Future<void> _save() async {
    final state = ref.read(appStateProvider);
    await state.setAttendanceTagIds(_selectedTagIds.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出勤配置已保存')),
      );
      Navigator.pop(context);
    }
  }

  void _resetToDefault() {
    setState(() {
      _selectedTagIds.clear();
      _selectedTagIds.add('tag_arrived');
      _hasChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
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
        title: Text(
          '出勤标签配置',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _hasChanged ? _save : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明卡片
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text(
                        '配置说明',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '勾选被视为「出勤」的标签。默认情况下只有「已到达」算作出勤。'
                    '如果某些状态（如上岗、公差等）也应视为出勤，请在此处勾选。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 当前配置摘要
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前视为出勤的标签',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTagIds.isEmpty
                              ? '未配置（默认仅「已到达」）'
                              : state.tags
                                  .where((t) => _selectedTagIds.contains(t.id))
                                  .map((t) => t.name)
                                  .join('、'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 标签列表
          Text(
            '标签列表',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          ...state.tags.map((tag) {
            final isSelected = _selectedTagIds.contains(tag.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                title: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(tag.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(tag.name),
                    if (tag.isBuiltIn) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '内置',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  isSelected ? '视为出勤' : '视为缺勤或其他',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: isSelected,
                activeColor: Color(tag.colorValue),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedTagIds.add(tag.id);
                    } else {
                      _selectedTagIds.remove(tag.id);
                    }
                    _hasChanged = true;
                  });
                },
              ),
            );
          }),

          const SizedBox(height: 16),

          // 重置按钮
          OutlinedButton.icon(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.restore),
            label: const Text('恢复默认（仅「已到达」算出勤）'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

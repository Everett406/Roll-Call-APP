import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';

class FilterChipBar extends ConsumerWidget {
  final String sessionId;
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;

  const FilterChipBar({
    super.key,
    required this.sessionId,
    this.selectedFilter,
    required this.onFilterChanged,
  });

  /// 常驻标签ID（始终显示在筛选栏中）
  static const _pinnedTagIds = ['tag_arrived', 'tag_absent', 'tag_sick'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final tags = state.tags;
    final statusCounts = state.getSessionStatusCounts(sessionId);
    final session = state.getSessionById(sessionId);
    final totalMembers = session?.memberIds.length ?? 0;
    final checkedCount = state.getSessionCheckedCount(sessionId);
    final uncheckedCount = totalMembers - checkedCount;

    // 常驻标签：按 _pinnedTagIds 顺序
    final pinnedTags = _pinnedTagIds
        .map((id) => tags.firstWhere(
              (t) => t.id == id,
              orElse: () => tags.firstWhere(
                (t) => t.isBuiltIn,
                orElse: () => tags.first,
              ),
            ))
        .where((t) => _pinnedTagIds.contains(t.id))
        .toList();

    // 动态标签：非内置标签 + 本次会话中使用过的内置标签（排除常驻的）
    final usedStatusIds = statusCounts.keys.toSet();
    final dynamicTags = tags.where((tag) {
      // 非内置标签且在本次会话中使用过
      if (!tag.isBuiltIn && usedStatusIds.contains(tag.id)) return true;
      // 内置标签但不在常驻列表中且使用过
      if (tag.isBuiltIn &&
          !_pinnedTagIds.contains(tag.id) &&
          usedStatusIds.contains(tag.id)) return true;
      return false;
    }).toList();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          // 全部
          _buildChip(
            context,
            label: '全部 $totalMembers人',
            isSelected: selectedFilter == null,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => onFilterChanged(null),
          ),
          const SizedBox(width: 8),
          // 未标记
          _buildChip(
            context,
            label: '未标记 $uncheckedCount',
            isSelected: selectedFilter == 'unchecked',
            color: Colors.grey,
            onTap: () =>
                onFilterChanged(selectedFilter == 'unchecked' ? null : 'unchecked'),
          ),
          const SizedBox(width: 8),
          // 常驻标签
          ...pinnedTags.map((tag) {
            final count = statusCounts[tag.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(
                context,
                label: '${tag.name} $count',
                isSelected: selectedFilter == tag.id,
                color: Color(tag.colorValue),
                onTap: () => onFilterChanged(
                    selectedFilter == tag.id ? null : tag.id),
              ),
            );
          }),
          // 动态标签（仅使用过的才显示）
          if (dynamicTags.isNotEmpty) ...[
            // 分隔符
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(width: 4),
            ...dynamicTags.map((tag) {
              final count = statusCounts[tag.id] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(
                  context,
                  label: '${tag.name} $count',
                  isSelected: selectedFilter == tag.id,
                  color: Color(tag.colorValue),
                  onTap: () => onFilterChanged(
                      selectedFilter == tag.id ? null : tag.id),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final tags = state.tags;
    final statusCounts = state.getSessionStatusCounts(sessionId);
    final session = state.getSessionById(sessionId);
    final totalMembers = session?.memberIds.length ?? 0;
    final checkedCount = state.getSessionCheckedCount(sessionId);
    final uncheckedCount = totalMembers - checkedCount;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _buildChip(
            context,
            label: '全部 $totalMembers人',
            isSelected: selectedFilter == null,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => onFilterChanged(null),
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            label: '未标记 $uncheckedCount',
            isSelected: selectedFilter == 'unchecked',
            color: Colors.grey,
            onTap: () =>
                onFilterChanged(selectedFilter == 'unchecked' ? null : 'unchecked'),
          ),
          const SizedBox(width: 8),
          ...tags.map((tag) {
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

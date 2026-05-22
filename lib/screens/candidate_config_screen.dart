import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';

/// Candidate pool configuration screen.
/// Modeled after NewSessionScreen's member selection pattern:
/// - Radio: All members
/// - Radio: Select from groups (with checkbox expansion)
/// - Radio: Custom selection (individual checkboxes)
class CandidateConfigScreen extends ConsumerStatefulWidget {
  final Set<String> initialSelectedIds;

  const CandidateConfigScreen({
    super.key,
    required this.initialSelectedIds,
  });

  @override
  ConsumerState<CandidateConfigScreen> createState() => _CandidateConfigScreenState();
}

class _CandidateConfigScreenState extends ConsumerState<CandidateConfigScreen> {
  late Set<String> _selectedIds;
  int _selectionMode = 0; // 0=all, 1=groups, 2=custom
  final Set<String> _selectedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _selectedIds = {...widget.initialSelectedIds};
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final members = state.members;
    final groups = state.groups;

    // Sort members by studentId
    final sortedMembers = [...members]..sort((a, b) {
      if (a.studentId != null && b.studentId != null) {
        return a.studentId!.compareTo(b.studentId!);
      }
      return a.name.compareTo(b.name);
    });

    // Group colors (same as NewSessionScreen)
    final groupColors = [
      const Color(0xFF4CAF50), const Color(0xFFF44336),
      const Color(0xFF2196F3), const Color(0xFFFF9800),
      const Color(0xFF9C27B0), const Color(0xFF00BCD4),
    ];

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
            onPressed: () => Navigator.pop(context, _selectedIds),
          ),
        ),
        title: const Text('候选池设置'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary card
          Card(
            shape: ExpressiveShapes.cardMedium,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.people, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedIds.length} / ${members.length} 人已选',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '将从选中的人员中随机抽取',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Mode 0: All members
          RadioListTile<int>(
            title: const Text('使用全部人员'),
            subtitle: Text('共 ${members.length} 人'),
            value: 0,
            groupValue: _selectionMode,
            onChanged: (val) {
              setState(() {
                _selectionMode = val ?? 0;
                _selectedIds = members.map((m) => m.id).toSet();
              });
            },
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 8),

          // Mode 1: From groups
          RadioListTile<int>(
            title: const Text('从分组选择'),
            subtitle: groups.isEmpty
                ? const Text('暂未创建分组')
                : Text('${groups.length} 个分组'),
            value: 1,
            groupValue: _selectionMode,
            onChanged: groups.isEmpty
                ? null
                : (val) {
                    setState(() {
                      _selectionMode = val ?? 1;
                      _syncIdsFromGroups(groups);
                    });
                  },
            contentPadding: EdgeInsets.zero,
          ),

          // Group checkboxes (only when mode=1)
          if (_selectionMode == 1 && groups.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...groups.map((group) {
              final isSelected = _selectedGroupIds.contains(group.id);
              final color = groupColors[group.colorIndex % groupColors.length];
              return CheckboxListTile(
                title: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(group.name),
                  ],
                ),
                subtitle: Text('${group.memberIds.length} 人'),
                value: isSelected,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedGroupIds.add(group.id);
                    } else {
                      _selectedGroupIds.remove(group.id);
                    }
                    _syncIdsFromGroups(groups);
                  });
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              );
            }),
          ],

          const SizedBox(height: 8),

          // Mode 2: Custom selection
          RadioListTile<int>(
            title: const Text('自定义选择'),
            subtitle: const Text('逐个勾选人员'),
            value: 2,
            groupValue: _selectionMode,
            onChanged: (val) {
              setState(() {
                _selectionMode = val ?? 2;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),

          // Individual checkboxes (only when mode=2)
          if (_selectionMode == 2) ...[
            const SizedBox(height: 8),
            // Quick actions
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIds = members.map((m) => m.id).toSet();
                    });
                  },
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIds.clear();
                    });
                  },
                  child: const Text('全不选'),
                ),
              ],
            ),
            ...sortedMembers.map((member) {
              final isSelected = _selectedIds.contains(member.id);
              return CheckboxListTile(
                dense: true,
                title: Text(member.name),
                subtitle: member.studentId != null
                    ? Text('学号: ${member.studentId}')
                    : null,
                value: isSelected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedIds.add(member.id);
                    } else {
                      _selectedIds.remove(member.id);
                    }
                  });
                },
              );
            }),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _selectedIds),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: ExpressiveShapes.pill,
            ),
            child: const Text('确认'),
          ),
        ),
      ),
    );
  }

  void _syncIdsFromGroups(dynamic groups) {
    _selectedIds.clear();
    for (final g in groups) {
      if (_selectedGroupIds.contains(g.id)) {
        _selectedIds.addAll(g.memberIds);
      }
    }
  }
}

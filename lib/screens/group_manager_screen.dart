import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../utils/constants.dart';

class GroupManagerScreen extends ConsumerStatefulWidget {
  const GroupManagerScreen({super.key});

  @override
  ConsumerState<GroupManagerScreen> createState() =>
      _GroupManagerScreenState();
}

class _GroupManagerScreenState extends ConsumerState<GroupManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final groups = state.groups;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分组管理'),
      ),
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 80,
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无分组',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角创建新分组',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final groupMembers = group.memberIds
                    .map((id) => state.getMemberById(id))
                    .whereType<Member>()
                    .toList();

                final color =
                    groupColors[group.colorIndex % groupColors.length];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _showGroupDetailDialog(context, group),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  group.name,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '${group.memberIds.length} 人',
                                style:
                                    theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (groupMembers.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: groupMembers
                                  .take(5)
                                  .map((member) => Chip(
                                        label: Text(
                                          member.name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                        backgroundColor:
                                            theme.colorScheme.surfaceContainerHighest,
                                      ))
                                  .toList()
                                ..addAll(
                                  groupMembers.length > 5
                                      ? [
                                          Chip(
                                            label: Text(
                                              '+${groupMembers.length - 5}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            backgroundColor:
                                                theme.colorScheme.surfaceContainerHighest,
                                          ),
                                        ]
                                      : [],
                                ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final state = ref.read(appStateProvider);
    final TextEditingController nameController = TextEditingController();
    int selectedColorIndex = 0;
    final Set<String> selectedMemberIds = {};

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建分组'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '分组名称',
                    prefixIcon: Icon(Icons.folder),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('选择颜色'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    groupColors.length,
                    (index) => GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedColorIndex = index;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: groupColors[index],
                          shape: BoxShape.circle,
                          border: selectedColorIndex == index
                              ? Border.all(
                                  color: Colors.black,
                                  width: 3,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('选择成员'),
                const SizedBox(height: 8),
                if (state.members.isEmpty)
                  const Text('暂无成员，请先添加人员')
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.members.length,
                      itemBuilder: (context, index) {
                        final member = state.members[index];
                        final isSelected =
                            selectedMemberIds.contains(member.id);
                        return CheckboxListTile(
                          title: Text(member.name),
                          subtitle: member.studentId != null
                              ? Text(member.studentId!)
                              : null,
                          value: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                selectedMemberIds.add(member.id);
                              } else {
                                selectedMemberIds.remove(member.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入分组名称')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final group = Group.create(
        name: nameController.text.trim(),
        memberIds: selectedMemberIds.toList(),
        colorIndex: selectedColorIndex,
      );
      await state.addGroup(group);
    }
  }

  Future<void> _showGroupDetailDialog(
      BuildContext context, Group group) async {
    final state = ref.read(appStateProvider);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final currentMembers = group.memberIds
              .map((id) => state.getMemberById(id))
              .whereType<Member>()
              .toList();

          return AlertDialog(
            title: Row(
              children: [
                Expanded(child: Text(group.name)),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('删除分组'),
                        content: const Text('确定要删除这个分组吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await state.deleteGroup(group.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentMembers.isEmpty)
                    const Text('暂无成员')
                  else
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: currentMembers.length,
                        itemBuilder: (context, index) {
                          final member = currentMembers[index];
                          return ListTile(
                            title: Text(member.name),
                            subtitle: member.studentId != null
                                ? Text(member.studentId!)
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle),
                              onPressed: () async {
                                await state.removeMemberFromGroup(
                                    group.id, member.id);
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
              FilledButton(
                onPressed: () =>
                    _showAddMemberDialog(context, group, setState),
                child: const Text('添加成员'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddMemberDialog(
    BuildContext context,
    Group group,
    StateSetter setState,
  ) async {
    final state = ref.read(appStateProvider);
    final Set<String> selectedMemberIds = {};

    final availableMembers = state.members
        .where((m) => !group.memberIds.contains(m.id))
        .toList();

    if (availableMembers.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可添加的成员')),
        );
      }
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加成员'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableMembers.length,
              itemBuilder: (context, index) {
                final member = availableMembers[index];
                final isSelected = selectedMemberIds.contains(member.id);
                return CheckboxListTile(
                  title: Text(member.name),
                  subtitle:
                      member.studentId != null ? Text(member.studentId!) : null,
                  value: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        selectedMemberIds.add(member.id);
                      } else {
                        selectedMemberIds.remove(member.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      for (final memberId in selectedMemberIds) {
        await state.addMemberToGroup(group.id, memberId);
      }
    }
  }
}

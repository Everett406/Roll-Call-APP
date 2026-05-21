import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../utils/constants.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  late Group _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    
    // 获取最新的分组数据
    final currentGroup = state.groups.firstWhere(
      (g) => g.id == _group.id,
      orElse: () => _group,
    );
    _group = currentGroup;

    final groupMembers = _group.memberIds
        .map((id) => state.getMemberById(id))
        .whereType<Member>()
        .toList();

    final color = groupColors[_group.colorIndex % groupColors.length];

    return Scaffold(
      Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(context),
            tooltip: '编辑',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            onPressed: () => _confirmDelete(context),
            tooltip: '删除',
          ),
        ],
      body: Column(
        children: [
          // 分组信息卡片
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.group,
                    color: color.computeLuminance() > 0.5 
                        ? Colors.black87 
                        : Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _group.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '共 ${groupMembers.length} 名成员',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 成员列表标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '成员列表',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (groupMembers.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showAddMemberSheet(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加成员'),
                  ),
              ],
            ),
          ),

          // 成员列表
          Expanded(
            child: groupMembers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 64,
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无成员',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => _showAddMemberSheet(context),
                          icon: const Icon(Icons.add),
                          label: const Text('添加成员'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: groupMembers.length + 1,
                    itemBuilder: (context, index) {
                      if (index == groupMembers.length) {
                        // 添加更多成员按钮
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddMemberSheet(context),
                            icon: const Icon(Icons.add),
                            label: const Text('添加更多成员'),
                          ),
                        );
                      }

                      final member = groupMembers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Text(
                              member.name.characters.first,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(member.name),
                          subtitle: member.studentId != null
                              ? Text(member.studentId!)
                              : null,
                          trailing: IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () => _removeMember(member),
                            tooltip: '移除',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
    );
  }

  void _showEditDialog(BuildContext context) {
    final state = ref.read(appStateProvider);
    final TextEditingController nameController = 
        TextEditingController(text: _group.name);
    int selectedColorIndex = _group.colorIndex;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑分组'),
          content: Column(
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
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入分组名称')),
                  );
                  return;
                }
                final updatedGroup = _group.copyWith(
                  name: name,
                  colorIndex: selectedColorIndex,
                );
                await state.updateGroup(updatedGroup);
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _group = updatedGroup;
                  });
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final state = ref.read(appStateProvider);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定要删除「${_group.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
    );

    if (confirm == true) {
      await state.deleteGroup(_group.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showAddMemberSheet(BuildContext context) {
    final state = ref.read(appStateProvider);
    final Set<String> selectedMemberIds = {};

    final availableMembers = state.members
        .where((m) => !_group.memberIds.contains(m.id))
        .toList();

    if (availableMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有成员都已在分组中')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '添加成员',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (selectedMemberIds.isNotEmpty)
                      FilledButton(
                        onPressed: () async {
                          for (final memberId in selectedMemberIds) {
                            await state.addMemberToGroup(_group.id, memberId);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            this.setState(() {});
                          }
                        },
                        child: Text('添加 ${selectedMemberIds.length} 人'),
                      ),
                  ],
                ),
              ),
              const Divider(),
              // 成员列表
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: availableMembers.length,
                  itemBuilder: (context, index) {
                    final member = availableMembers[index];
                    final isSelected = selectedMemberIds.contains(member.id);
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
    );
  }

  Future<void> _removeMember(Member member) async {
    final state = ref.read(appStateProvider);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要将「${member.name}」从分组中移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
    );

    if (confirm == true) {
      await state.removeMemberFromGroup(_group.id, member.id);
      setState(() {});
    }
  }
}

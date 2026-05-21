import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../utils/constants.dart';
import 'group_detail_screen.dart';

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
              tag: 'settingsIcon_groups',
              child: Material(
                type: MaterialType.transparency,
                child: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '分组管理',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: groups.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _buildGroupCard(context, group, state, theme);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateGroup(context),
        icon: const Icon(Icons.add),
        label: const Text('创建分组'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无分组',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮创建第一个分组',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    Group group,
    AppState state,
    ThemeData theme,
  ) {
    final groupMembers = group.memberIds
        .map((id) => state.getMemberById(id))
        .whereType<Member>()
        .toList();

    final color = groupColors[group.colorIndex % groupColors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToGroupDetail(context, group),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.group,
                      color: color.computeLuminance() > 0.5 
                          ? Colors.black87 
                          : Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.memberIds.length} 人',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (groupMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: groupMembers
                      .take(6)
                      .map((member) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              member.name,
                              style: theme.textTheme.bodySmall,
                            ),
                          ))
                      .toList()
                    ..addAll(
                      groupMembers.length > 6
                          ? [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '+${groupMembers.length - 6}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
  }

  Future<void> _navigateToCreateGroup(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分组创建成功')),
      );
    }
  }

  Future<void> _navigateToGroupDetail(BuildContext context, Group group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(group: group),
      ),
    );
  }
}

/// 创建分组独立页面
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedColorIndex = 0;
  final Set<String> _selectedMemberIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final color = groupColors[_selectedColorIndex % groupColors.length];

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建分组'),
        actions: [
          TextButton(
            onPressed: _selectedMemberIds.isEmpty || _nameController.text.isEmpty
                ? null
                : () => _createGroup(context),
            child: const Text('创建'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分组名称
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '分组名称',
                prefixIcon: Icon(Icons.folder),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // 选择颜色
            Text(
              '选择颜色',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                groupColors.length,
                (index) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColorIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: groupColors[index],
                      shape: BoxShape.circle,
                      border: _selectedColorIndex == index
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 3,
                            )
                          : Border.all(
                              color: Colors.transparent,
                              width: 3,
                            ),
                      boxShadow: _selectedColorIndex == index
                          ? [
                              BoxShadow(
                                color: groupColors[index].withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: _selectedColorIndex == index
                        ? Icon(
                            Icons.check,
                            color: groupColors[index].computeLuminance() > 0.5
                                ? Colors.black87
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 选择成员
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择成员',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedMemberIds.isNotEmpty)
                  Text(
                    '已选 ${_selectedMemberIds.length} 人',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (state.members.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '暂无成员，请先添加人员',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.members.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final member = state.members[index];
                    final isSelected = _selectedMemberIds.contains(member.id);
                    return CheckboxListTile(
                      title: Text(member.name),
                      subtitle: member.studentId != null
                          ? Text(member.studentId!)
                          : null,
                      secondary: isSelected
                          ? Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: color.computeLuminance() > 0.5
                                    ? Colors.black87
                                    : Colors.white,
                                size: 18,
                              ),
                            )
                          : null,
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedMemberIds.add(member.id);
                          } else {
                            _selectedMemberIds.remove(member.id);
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

  Future<void> _createGroup(BuildContext context) async {
    final state = ref.read(appStateProvider);
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入分组名称')),
      );
      return;
    }

    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一名成员')),
      );
      return;
    }

    final group = Group.create(
      name: name,
      memberIds: _selectedMemberIds.toList(),
      colorIndex: _selectedColorIndex,
    );

    await state.addGroup(group);

    if (context.mounted) {
      Navigator.pop(context, true);
    }
  }
}

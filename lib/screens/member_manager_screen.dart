import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';
import '../models/member.dart';
import 'import_screen.dart';
import 'member_history_screen.dart';

class MemberManagerScreen extends ConsumerStatefulWidget {
  const MemberManagerScreen({super.key});

  @override
  ConsumerState<MemberManagerScreen> createState() =>
      _MemberManagerScreenState();
}

class _MemberManagerScreenState extends ConsumerState<MemberManagerScreen> {
  final Set<String> _selectedMemberIds = {};
  bool _isMultiSelectMode = false;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    // Filter members based on search, sorted by studentId
    final members = (_isSearchExpanded
            ? state.searchMembers(_searchQuery)
            : [...state.members])
        ..sort((a, b) {
          if (a.studentId != null && b.studentId != null) {
            return a.studentId!.compareTo(b.studentId!);
          }
          return a.name.compareTo(b.name);
        });

    final hasSelected = _selectedMemberIds.isNotEmpty;
    final allSelected = members.length == _selectedMemberIds.length && members.isNotEmpty;

    return Scaffold(
      appBar: _isMultiSelectMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isMultiSelectMode = false;
                    _selectedMemberIds.clear();
                  });
                },
              ),
              title: Text('已选择 ${_selectedMemberIds.length} 人'),
              actions: [
                if (hasSelected)
                  TextButton.icon(
                    onPressed: allSelected
                        ? () {
                            setState(() {
                              _selectedMemberIds.clear();
                            });
                          }
                        : () {
                            setState(() {
                              _selectedMemberIds.addAll(members.map((m) => m.id));
                            });
                          },
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                    label: Text(allSelected ? '取消全选' : '全选'),
                  ),
                if (hasSelected)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    color: theme.colorScheme.error,
                    onPressed: () => _deleteSelectedMembers(state),
                  ),
              ],
            )
          : AppBar(
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
              title: _isSearchExpanded
                  ? TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '搜索人员...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 16),
                      ),
                      style: const TextStyle(fontSize: 16),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      autofocus: true,
                    )
                  : Row(
                      children: [
                        Hero(
                          tag: 'settingsIcon_members',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Icon(Icons.people_outline, color: theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '人员管理 (${state.members.length} 人)',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
              centerTitle: !_isSearchExpanded,
              elevation: 0,
              actions: [
                if (_isSearchExpanded)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = false;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = true;
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: '批量导入',
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImportScreen()),
                    );
                    if (result == true) {
                      ref.read(appStateProvider).loadData();
                    }
                  },
                ),
              ],
            ),
      body: members.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: 80,
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无人员',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角添加或使用批量导入',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final isSelected = _selectedMemberIds.contains(member.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(member.id),
                    direction: _isMultiSelectMode
                        ? DismissDirection.none
                        : DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      final confirmed = await showExpressiveDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('删除人员'),
                          content: Text('确定要删除 ${member.name} 吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                              ),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        state.deleteMember(member.id);
                      }
                      return false;
                    },
                    child: Card(
                      child: InkWell(
                        onTap: () {
                          if (_isMultiSelectMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedMemberIds.remove(member.id);
                                if (_selectedMemberIds.isEmpty) {
                                  _isMultiSelectMode = false;
                                }
                              } else {
                                _selectedMemberIds.add(member.id);
                              }
                            });
                          } else {
                            _showEditDialog(context, state, member);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            if (!_isMultiSelectMode) {
                              _isMultiSelectMode = true;
                              _selectedMemberIds.add(member.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              if (_isMultiSelectMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedMemberIds.add(member.id);
                                        } else {
                                          _selectedMemberIds.remove(member.id);
                                          if (_selectedMemberIds.isEmpty) {
                                            _isMultiSelectMode = false;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                )
                              else
                                CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Text(
                                    member.name.isNotEmpty ? member.name[0] : '?',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (!_isMultiSelectMode) const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Hero(
                                      tag: 'memberName_${member.id}',
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: Text(
                                          member.name,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (member.studentId != null &&
                                        member.studentId!.isNotEmpty)
                                      Text(
                                        member.studentId!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (!_isMultiSelectMode)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _showEditDialog(context, state, member),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _isMultiSelectMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddDialog(context, state),
              child: const Icon(Icons.person_add),
            ),
    );
  }

  Future<void> _deleteSelectedMembers(AppState state) async {
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${_selectedMemberIds.length} 人'),
        content: const Text('确定要删除选中的人员吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final memberId in _selectedMemberIds) {
        await state.deleteMember(memberId);
      }
      setState(() {
        _isMultiSelectMode = false;
        _selectedMemberIds.clear();
      });
    }
  }

  void _showAddDialog(BuildContext context, AppState state) {
    final nameController = TextEditingController();
    final idController = TextEditingController();

    showExpressiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加人员'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '姓名',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: '学号（可选）',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
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
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入姓名')),
                );
                return;
              }
              final studentId = idController.text.trim();
              state.addMember(Member(
                name: name,
                studentId: studentId.isEmpty ? null : studentId,
              ));
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, AppState state, Member member) {
    final nameController = TextEditingController(text: member.name);
    final idController = TextEditingController(text: member.studentId ?? '');

    showExpressiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑人员'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '姓名',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: '学号（可选）',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberHistoryScreen(
                    memberId: member.id,
                    memberName: member.name,
                  ),
                ),
              );
            },
            child: const Text('查看记录'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入姓名')),
                );
                return;
              }
              final studentId = idController.text.trim();
              state.updateMember(member.copyWith(
                name: name,
                studentId: studentId.isEmpty ? null : studentId,
              ));
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

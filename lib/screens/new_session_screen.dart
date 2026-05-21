import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/group.dart';
import '../utils/constants.dart';
import '../widgets/predictive_back_page.dart';

class NewSessionScreen extends ConsumerStatefulWidget {
  const NewSessionScreen({super.key});

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  final _titleController = TextEditingController();
  int _selectionMode = 0; // 0: all, 1: from history, 2: from groups
  String? _copyFromSessionId;
  final Set<String> _selectedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _titleController.text = _generateDefaultTitle();
  }

  /// 根据当前时间自动生成默认标题
  String _generateDefaultTitle() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    final hour = now.hour;

    String periodName;
    if (hour >= 5 && hour < 8) {
      periodName = '早点名';
    } else if (hour >= 8 && hour < 11) {
      periodName = '常规点名';
    } else if (hour >= 11 && hour < 14) {
      periodName = '午点名';
    } else if (hour >= 14 && hour < 17) {
      periodName = '常规点名';
    } else if (hour >= 17 && hour < 19) {
      periodName = '训练点名';
    } else if (hour >= 19 && hour < 22) {
      periodName = '晚点名';
    } else {
      periodName = '晚点名';
    }

    return '$month月$day日 $periodName';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final members = state.members;
    final groups = state.groups;
    final theme = Theme.of(context);
    final allSessions = [...state.archivedSessions, ...state.ongoingSessions];

    return PredictiveBackPage(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('新建点名'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title input
            Text(
              '点名标题',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '例如：5月21日 晚点名',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Member range selection
            Text(
              '人员范围',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            RadioListTile<int>(
              title: const Text('使用全部人员'),
              subtitle: Text('共 ${members.length} 人'),
              value: 0,
              groupValue: _selectionMode,
              onChanged: (val) {
                setState(() {
                  _selectionMode = val ?? 0;
                  _copyFromSessionId = null;
                  _selectedGroupIds.clear();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            RadioListTile<int>(
              title: const Text('从分组选择'),
              subtitle: groups.isEmpty
                  ? const Text('暂未创建分组')
                  : Text('${groups.length} 个分组可用'),
              value: 2,
              groupValue: _selectionMode,
              onChanged: (val) {
                setState(() {
                  _selectionMode = val ?? 2;
                  _copyFromSessionId = null;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (_selectionMode == 2) ...[
              const SizedBox(height: 8),
              if (groups.isEmpty)
                const SizedBox()
              else
                ...groups.map((group) {
                  final isSelected = _selectedGroupIds.contains(group.id);
                  final color =
                      groupColors[group.colorIndex % groupColors.length];
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
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }),
            ],

            RadioListTile<int>(
              title: const Text('从历史点名复制'),
              subtitle: const Text('复制参与人员及上次签到结果'),
              value: 1,
              groupValue: _selectionMode,
              onChanged: (val) {
                setState(() {
                  _selectionMode = val ?? 1;
                  _selectedGroupIds.clear();
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (_selectionMode == 1) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _copyFromSessionId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.history),
                ),
                items: allSessions.map((s) {
                  final date = DateFormat('MM/dd').format(s.createdAt);
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text('$date ${s.title} (${s.memberIds.length}人)'),
                  );
                }).toList(),
                hint: const Text('选择历史点名'),
                onChanged: (val) {
                  setState(() {
                    _copyFromSessionId = val;
                  });
                },
              ),
            ],

            const SizedBox(height: 32),

            // Preview
            if (members.isEmpty)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '暂无人员，请先在设置中添加人员',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '预览',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _titleController.text.isEmpty
                            ? '（未设置标题）'
                            : _titleController.text,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '参与人数：${_getPreviewCount(members, state)} 人',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: members.isEmpty ? null : () => _createSession(state),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '确认创建',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
      ),
    );
  }

  int _getPreviewCount(List<Member> members, AppState state) {
    if (_selectionMode == 0) {
      return members.length;
    } else if (_selectionMode == 1 && _copyFromSessionId != null) {
      final session = state.getSessionById(_copyFromSessionId!);
      return session?.memberIds.length ?? 0;
    } else if (_selectionMode == 2) {
      final memberIds = <String>{};
      for (final groupId in _selectedGroupIds) {
        final group = state.getGroupById(groupId);
        if (group != null) {
          memberIds.addAll(group.memberIds);
        }
      }
      return memberIds.length;
    }
    return 0;
  }

  Future<void> _createSession(AppState state) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入点名标题')),
      );
      return;
    }

    List<String> memberIds;
    List<String> memberNames;
    String? sourceSessionId;

    if (_selectionMode == 0) {
      memberIds = state.members.map((m) => m.id).toList();
      memberNames = state.members.map((m) => m.name).toList();
    } else if (_selectionMode == 1 && _copyFromSessionId != null) {
      final session = state.getSessionById(_copyFromSessionId!);
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择历史点名')),
        );
        return;
      }
      memberIds = List.from(session.memberIds);
      memberNames = List.from(session.memberNames);
      sourceSessionId = _copyFromSessionId;
    } else if (_selectionMode == 2) {
      final memberIdSet = <String>{};
      final memberMap = <String, Member>{};
      for (final member in state.members) {
        memberMap[member.id] = member;
      }

      for (final groupId in _selectedGroupIds) {
        final group = state.getGroupById(groupId);
        if (group != null) {
          memberIdSet.addAll(group.memberIds);
        }
      }

      if (memberIdSet.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少选择一个分组')),
        );
        return;
      }

      memberIds = memberIdSet.toList();
      memberNames = memberIds
          .map((id) => memberMap[id]?.name ?? '未知')
          .toList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择人员范围')),
      );
      return;
    }

    if (memberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('人员列表为空')),
      );
      return;
    }

    final newSession = await state.createSession(
      title: title,
      memberIds: memberIds,
      memberNames: memberNames,
    );

    // 如果是从历史点名复制，同时复制签到结果
    if (sourceSessionId != null) {
      await state.copyCheckInsFromSession(sourceSessionId, newSession.id);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}

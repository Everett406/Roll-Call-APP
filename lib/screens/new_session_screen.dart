import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/session.dart';

class NewSessionScreen extends ConsumerStatefulWidget {
  const NewSessionScreen({super.key});

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  final _titleController = TextEditingController();
  bool _useAllMembers = true;
  String? _copyFromSessionId;
  List<Session> _archivedSessions = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    _titleController.text = '$month月${day}日 晚自习';
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
    final theme = Theme.of(context);
    _archivedSessions = [...state.archivedSessions, ...state.ongoingSessions];

    return Scaffold(
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
                hintText: '例如：5月20日 晚自习',
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

            RadioListTile<bool>(
              title: const Text('使用全部人员'),
              subtitle: Text('共 ${members.length} 人'),
              value: true,
              groupValue: _useAllMembers,
              onChanged: (val) {
                setState(() {
                  _useAllMembers = val ?? true;
                  _copyFromSessionId = null;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            RadioListTile<bool>(
              title: const Text('从历史点名复制'),
              value: false,
              groupValue: _useAllMembers,
              onChanged: (val) {
                setState(() {
                  _useAllMembers = val ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (!_useAllMembers) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _copyFromSessionId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.history),
                ),
                items: _archivedSessions.map((s) {
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
                      Icon(Icons.warning_amber,
                          color: theme.colorScheme.error),
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
                        '参与人数：${_getPreviewCount(members)} 人',
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
            onPressed: members.isEmpty
                ? null
                : () => _createSession(state),
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
    );
  }

  int _getPreviewCount(List<Member> members) {
    if (_useAllMembers) {
      return members.length;
    } else if (_copyFromSessionId != null) {
      final state = ref.read(appStateProvider);
      final session = state.getSessionById(_copyFromSessionId!);
      return session?.memberIds.length ?? 0;
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

    if (_useAllMembers) {
      memberIds = state.members.map((m) => m.id).toList();
      memberNames = state.members.map((m) => m.name).toList();
    } else if (_copyFromSessionId != null) {
      final session = state.getSessionById(_copyFromSessionId!);
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择历史点名')),
        );
        return;
      }
      memberIds = List.from(session.memberIds);
      memberNames = List.from(session.memberNames);
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

    await state.createSession(
      title: title,
      memberIds: memberIds,
      memberNames: memberNames,
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
